import json
import uuid
import datetime
from datetime import timedelta, timezone
from flask import Blueprint, request, jsonify
from extensions import db
from models.user import User
from models.mess import (
    MessMenu,
    MessMeal,
    MessFeedback,
    MealEntry,
    SUPPORTED_FEEDBACK_CATEGORIES
)
from models.passport import DeviceIdentityKey, DeviceCertificate
from services.passport_service import PassportService
from middleware.roles import is_mess_manager
from middleware.auth import get_authenticated_requester
from utils.validators import (
    SUPPORTED_MEAL_TYPES,
    SUPPORTED_MENU_STATUSES,
    parse_and_validate_menu_date,
    validate_meals_payload
)

mess_bp = Blueprint('mess_bp', __name__)

def has_conflicting_published_menu(menu_date, exclude_menu_id=None):
    query = MessMenu.query.filter(
        MessMenu.menu_date == menu_date,
        MessMenu.status == 'PUBLISHED'
    )
    if exclude_menu_id:
        query = query.filter(MessMenu.id != exclude_menu_id)
    return query.first() is not None


# --- PUBLIC / STUDENT MESS ENDPOINTS ---

@mess_bp.route('/mess/menus', methods=['GET'])
def list_published_mess_menus():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required"}), 401

    date_filter = request.args.get('date')
    start_date_filter = request.args.get('startDate') or request.args.get('start_date')
    end_date_filter = request.args.get('endDate') or request.args.get('end_date')

    query = MessMenu.query.filter_by(status='PUBLISHED')

    if date_filter:
        valid_date, err = parse_and_validate_menu_date(date_filter)
        if err:
            return jsonify({"message": f"Invalid date filter: {err}"}), 400
        query = query.filter(MessMenu.menu_date == valid_date)

    if start_date_filter:
        valid_start, err = parse_and_validate_menu_date(start_date_filter)
        if err:
            return jsonify({"message": f"Invalid startDate filter: {err}"}), 400
        query = query.filter(MessMenu.menu_date >= valid_start)

    if end_date_filter:
        valid_end, err = parse_and_validate_menu_date(end_date_filter)
        if err:
            return jsonify({"message": f"Invalid endDate filter: {err}"}), 400
        query = query.filter(MessMenu.menu_date <= valid_end)

    menus = query.order_by(MessMenu.menu_date.asc(), MessMenu.created_at.desc()).all()
    return jsonify([m.to_dict() for m in menus]), 200


@mess_bp.route('/mess/menus/today', methods=['GET'])
def get_today_mess_menu():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required"}), 401

    today_str = datetime.date.today().strftime('%Y-%m-%d')
    menu = MessMenu.query.filter_by(menu_date=today_str, status='PUBLISHED').first()
    if not menu:
        return jsonify({"message": f"No published menu found for today ({today_str})"}), 404
    return jsonify(menu.to_dict()), 200


@mess_bp.route('/mess/menus/<id>', methods=['GET'])
def get_mess_menu(id):
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required"}), 401

    menu = MessMenu.query.get(id)
    if not menu:
        return jsonify({"message": "Menu not found"}), 404

    # Draft and archived menus are hidden from public students and teachers
    if menu.status != 'PUBLISHED' and not is_mess_manager(requester):
        return jsonify({"message": "Menu not found"}), 404

    return jsonify(menu.to_dict()), 200


# --- ADMIN / STAFF MESS MANAGEMENT ENDPOINTS ---

@mess_bp.route('/mess/menus', methods=['POST'])
def create_mess_menu():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required"}), 401
    if not is_mess_manager(requester):
        return jsonify({"message": "Forbidden: You are not authorized to create mess menus"}), 403

    data = request.json or {}
    raw_date = data.get('menuDate') or data.get('menu_date')
    menu_date, date_err = parse_and_validate_menu_date(raw_date)
    if date_err:
        return jsonify({"message": date_err}), 400

    status = (data.get('status') or 'DRAFT').upper().strip()
    if status not in SUPPORTED_MENU_STATUSES:
        return jsonify({"message": f"Invalid status '{status}'. Must be one of: {sorted(list(SUPPORTED_MENU_STATUSES))}"}), 400

    if status == 'PUBLISHED' and has_conflicting_published_menu(menu_date):
        return jsonify({"message": f"A published menu already exists for date {menu_date}"}), 409

    raw_meals = data.get('meals', [])
    if raw_meals:
        validated_meals, meals_err = validate_meals_payload(raw_meals)
        if meals_err:
            return jsonify({"message": meals_err}), 400
    else:
        if status == 'PUBLISHED':
            return jsonify({"message": "Cannot publish menu without meals"}), 400
        validated_meals = []

    now_iso = datetime.datetime.now().isoformat()
    menu = MessMenu(
        id=str(uuid.uuid4()),
        menu_date=menu_date,
        status=status,
        created_by=requester.id,
        updated_by=requester.id,
        created_at=now_iso,
        updated_at=now_iso
    )
    db.session.add(menu)

    for m in validated_meals:
        meal = MessMeal(
            id=str(uuid.uuid4()),
            menu_id=menu.id,
            meal_type=m['meal_type'],
            title=m['title'],
            description=m['description'],
            items=json.dumps(m['items']),
            availability=m['availability'],
            display_order=m['display_order'],
            created_at=now_iso,
            updated_at=now_iso
        )
        db.session.add(meal)

    db.session.commit()
    db.session.refresh(menu)
    return jsonify(menu.to_dict()), 201


@mess_bp.route('/mess/menus/<id>', methods=['PUT', 'PATCH'])
def update_mess_menu(id):
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required"}), 401
    if not is_mess_manager(requester):
        return jsonify({"message": "Forbidden: You are not authorized to update mess menus"}), 403

    menu = MessMenu.query.get(id)
    if not menu:
        return jsonify({"message": "Menu not found"}), 404

    if menu.status == 'ARCHIVED':
        return jsonify({"message": "Cannot edit archived menu"}), 409

    data = request.json or {}

    new_date = menu.menu_date
    if 'menuDate' in data or 'menu_date' in data:
        raw_date = data.get('menuDate') or data.get('menu_date')
        parsed_date, date_err = parse_and_validate_menu_date(raw_date)
        if date_err:
            return jsonify({"message": date_err}), 400
        new_date = parsed_date

    new_status = menu.status
    if 'status' in data:
        proposed_status = str(data['status']).upper().strip()
        if proposed_status not in SUPPORTED_MENU_STATUSES:
            return jsonify({"message": f"Invalid status '{proposed_status}'. Must be one of: {sorted(list(SUPPORTED_MENU_STATUSES))}"}), 400

        # State machine transition rules
        if menu.status == 'PUBLISHED' and proposed_status == 'DRAFT':
            return jsonify({"message": "Invalid state transition: Cannot change PUBLISHED menu to DRAFT"}), 409
        new_status = proposed_status

    if new_status == 'PUBLISHED':
        if has_conflicting_published_menu(new_date, exclude_menu_id=menu.id):
            return jsonify({"message": f"A published menu already exists for date {new_date}"}), 409

    now_iso = datetime.datetime.now().isoformat()

    if 'meals' in data:
        raw_meals = data['meals']
        validated_meals, meals_err = validate_meals_payload(raw_meals)
        if meals_err:
            return jsonify({"message": meals_err}), 400
        if new_status == 'PUBLISHED' and not validated_meals:
            return jsonify({"message": "Cannot publish menu without meals"}), 400

        # Replace existing meals
        MessMeal.query.filter_by(menu_id=menu.id).delete(synchronize_session=False)
        for m in validated_meals:
            meal = MessMeal(
                id=str(uuid.uuid4()),
                menu_id=menu.id,
                meal_type=m['meal_type'],
                title=m['title'],
                description=m['description'],
                items=json.dumps(m['items']),
                availability=m['availability'],
                display_order=m['display_order'],
                created_at=now_iso,
                updated_at=now_iso
            )
            db.session.add(meal)
    elif new_status == 'PUBLISHED' and not menu.meals:
        return jsonify({"message": "Cannot publish menu without meals"}), 400

    menu.menu_date = new_date
    menu.status = new_status
    menu.updated_by = requester.id
    menu.updated_at = now_iso

    db.session.commit()
    db.session.refresh(menu)
    return jsonify(menu.to_dict()), 200


@mess_bp.route('/mess/menus/<id>/publish', methods=['POST'])
def publish_mess_menu(id):
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required"}), 401
    if not is_mess_manager(requester):
        return jsonify({"message": "Forbidden: You are not authorized to publish mess menus"}), 403

    menu = MessMenu.query.get(id)
    if not menu:
        return jsonify({"message": "Menu not found"}), 404

    if menu.status == 'ARCHIVED':
        return jsonify({"message": "Cannot publish archived menu"}), 409

    if has_conflicting_published_menu(menu.menu_date, exclude_menu_id=menu.id):
        return jsonify({"message": f"A published menu already exists for date {menu.menu_date}"}), 409

    if not menu.meals:
        return jsonify({"message": "Cannot publish menu without meals"}), 400

    for m in menu.meals:
        if not m.get_items_list():
            return jsonify({"message": f"Meal '{m.meal_type}' contains no items"}), 400

    now_iso = datetime.datetime.now().isoformat()
    menu.status = 'PUBLISHED'
    menu.updated_by = requester.id
    menu.updated_at = now_iso

    db.session.commit()
    db.session.refresh(menu)
    return jsonify(menu.to_dict()), 200


@mess_bp.route('/mess/menus/<id>/archive', methods=['POST'])
def archive_mess_menu(id):
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required"}), 401
    if not is_mess_manager(requester):
        return jsonify({"message": "Forbidden: You are not authorized to archive mess menus"}), 403

    menu = MessMenu.query.get(id)
    if not menu:
        return jsonify({"message": "Menu not found"}), 404

    now_iso = datetime.datetime.now().isoformat()
    menu.status = 'ARCHIVED'
    menu.updated_by = requester.id
    menu.updated_at = now_iso

    db.session.commit()
    db.session.refresh(menu)
    return jsonify(menu.to_dict()), 200


@mess_bp.route('/mess/admin/menus', methods=['GET'])
def list_admin_mess_menus():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required"}), 401
    if not is_mess_manager(requester):
        return jsonify({"message": "Forbidden: You are not authorized to view admin mess menus"}), 403

    status_filter = request.args.get('status')
    date_filter = request.args.get('date')
    start_date_filter = request.args.get('startDate') or request.args.get('start_date')
    end_date_filter = request.args.get('endDate') or request.args.get('end_date')

    query = MessMenu.query

    if status_filter:
        s_upper = status_filter.upper().strip()
        if s_upper in SUPPORTED_MENU_STATUSES:
            query = query.filter(MessMenu.status == s_upper)

    if date_filter:
        valid_date, err = parse_and_validate_menu_date(date_filter)
        if err:
            return jsonify({"message": f"Invalid date filter: {err}"}), 400
        query = query.filter(MessMenu.menu_date == valid_date)

    if start_date_filter:
        valid_start, err = parse_and_validate_menu_date(start_date_filter)
        if err:
            return jsonify({"message": f"Invalid startDate filter: {err}"}), 400
        query = query.filter(MessMenu.menu_date >= valid_start)

    if end_date_filter:
        valid_end, err = parse_and_validate_menu_date(end_date_filter)
        if err:
            return jsonify({"message": f"Invalid endDate filter: {err}"}), 400
        query = query.filter(MessMenu.menu_date <= valid_end)

    menus = query.order_by(MessMenu.menu_date.desc(), MessMenu.created_at.desc()).all()
    return jsonify([m.to_dict() for m in menus]), 200


@mess_bp.route('/mess/admin/menus/<id>', methods=['GET'])
def get_admin_mess_menu(id):
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required"}), 401
    if not is_mess_manager(requester):
        return jsonify({"message": "Forbidden: You are not authorized to view admin mess menus"}), 403

    menu = MessMenu.query.get(id)
    if not menu:
        return jsonify({"message": "Menu not found"}), 404

    return jsonify(menu.to_dict()), 200


# ==============================================================================
# --- STEP 22D: MESS FEEDBACK & ANALYTICS ENDPOINTS ---
# ==============================================================================

@mess_bp.route('/mess/feedback', methods=['POST'])
def submit_mess_feedback():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required"}), 401
    if requester.role.lower() != 'student':
        return jsonify({"message": "Forbidden: Only students can submit meal feedback"}), 403

    data = request.json or {}
    menu_id = data.get('menuId') or data.get('menu_id')
    meal_id = data.get('mealId') or data.get('meal_id')
    rating = data.get('rating')
    category = data.get('category')
    comment = data.get('comment')

    if not menu_id or not isinstance(menu_id, str) or not menu_id.strip():
        return jsonify({"message": "menuId is required"}), 400
    if not meal_id or not isinstance(meal_id, str) or not meal_id.strip():
        return jsonify({"message": "mealId is required"}), 400

    if rating is None or not isinstance(rating, int) or rating < 1 or rating > 5:
        return jsonify({"message": "Rating must be an integer between 1 and 5"}), 400

    clean_category = None
    if category is not None and str(category).strip():
        cat_str = str(category).strip().upper()
        if cat_str not in SUPPORTED_FEEDBACK_CATEGORIES:
            return jsonify({"message": f"Invalid category '{cat_str}'. Must be one of: {sorted(list(SUPPORTED_FEEDBACK_CATEGORIES))}"}), 400
        clean_category = cat_str

    clean_comment = None
    if comment is not None and isinstance(comment, str) and comment.strip():
        clean_comment = comment.strip()[:1000]

    menu = MessMenu.query.get(menu_id.strip())
    if not menu:
        return jsonify({"message": "Mess menu not found"}), 404
    if menu.status != 'PUBLISHED':
        return jsonify({"message": f"Feedback can only be submitted for PUBLISHED menus (current status: {menu.status})"}), 400

    meal = MessMeal.query.get(meal_id.strip())
    if not meal:
        return jsonify({"message": "Mess meal not found"}), 404
    if meal.menu_id != menu.id:
        return jsonify({"message": "Meal does not belong to the specified menu"}), 400

    # Enforce uniqueness policy: 1 student -> 1 feedback per meal per published menu
    existing = MessFeedback.query.filter_by(meal_id=meal.id, student_id=requester.id).first()
    if existing:
        return jsonify({
            "message": "Feedback already submitted for this meal. Use PUT/PATCH to update your feedback.",
            "existingFeedbackId": existing.id
        }), 409

    now_iso = datetime.datetime.now().isoformat()
    feedback = MessFeedback(
        id=str(uuid.uuid4()),
        menu_id=menu.id,
        meal_id=meal.id,
        student_id=requester.id,
        rating=rating,
        category=clean_category,
        comment=clean_comment,
        created_at=now_iso,
        updated_at=now_iso
    )
    db.session.add(feedback)
    db.session.commit()
    db.session.refresh(feedback)
    return jsonify(feedback.to_dict(anonymize=False)), 201


@mess_bp.route('/mess/feedback/my', methods=['GET'])
def get_my_mess_feedback():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required"}), 401

    menu_id = request.args.get('menuId') or request.args.get('menu_id')
    meal_id = request.args.get('mealId') or request.args.get('meal_id')
    date_filter = request.args.get('date')

    query = MessFeedback.query.filter_by(student_id=requester.id)
    if menu_id:
        query = query.filter_by(menu_id=menu_id.strip())
    if meal_id:
        query = query.filter_by(meal_id=meal_id.strip())
    if date_filter:
        query = query.join(MessMenu, MessFeedback.menu_id == MessMenu.id).filter(MessMenu.menu_date == date_filter.strip())

    feedbacks = query.order_by(MessFeedback.created_at.desc()).all()
    return jsonify([f.to_dict(anonymize=False) for f in feedbacks]), 200


@mess_bp.route('/mess/feedback/<id>', methods=['PUT', 'PATCH'])
def update_mess_feedback(id):
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required"}), 401

    feedback = MessFeedback.query.get(id)
    if not feedback:
        return jsonify({"message": "Feedback not found"}), 404

    # Privacy and authorization: student can ONLY update their own feedback
    if requester.role.lower() != 'student' or feedback.student_id != requester.id:
        return jsonify({"message": "Forbidden: You are not authorized to update another student's feedback"}), 403

    if feedback.menu and feedback.menu.status == 'ARCHIVED':
        return jsonify({"message": "Cannot update feedback for an archived menu"}), 409

    data = request.json or {}

    if 'rating' in data:
        r = data.get('rating')
        if r is None or not isinstance(r, int) or r < 1 or r > 5:
            return jsonify({"message": "Rating must be an integer between 1 and 5"}), 400
        feedback.rating = r

    if 'category' in data:
        cat = data.get('category')
        if cat is not None and str(cat).strip():
            cat_str = str(cat).strip().upper()
            if cat_str not in SUPPORTED_FEEDBACK_CATEGORIES:
                return jsonify({"message": f"Invalid category '{cat_str}'. Must be one of: {sorted(list(SUPPORTED_FEEDBACK_CATEGORIES))}"}), 400
            feedback.category = cat_str
        else:
            feedback.category = None

    if 'comment' in data:
        cmt = data.get('comment')
        if cmt is not None and isinstance(cmt, str) and cmt.strip():
            feedback.comment = cmt.strip()[:1000]
        else:
            feedback.comment = None

    feedback.updated_at = datetime.datetime.now().isoformat()
    db.session.commit()
    db.session.refresh(feedback)
    return jsonify(feedback.to_dict(anonymize=False)), 200


@mess_bp.route('/mess/meals/<id>/feedback', methods=['GET'])
def get_meal_feedback_for_student(id):
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required"}), 401

    meal = MessMeal.query.get(id)
    if not meal:
        return jsonify({"message": "Mess meal not found"}), 404

    feedback = MessFeedback.query.filter_by(meal_id=meal.id, student_id=requester.id).first()
    return jsonify({"feedback": feedback.to_dict(anonymize=False) if feedback else None}), 200


# --- ADMIN / STAFF / WARDEN ANALYTICS ---

def _build_admin_feedback_query():
    query = MessFeedback.query.join(MessMenu, MessFeedback.menu_id == MessMenu.id).join(MessMeal, MessFeedback.meal_id == MessMeal.id)

    start_date = request.args.get('startDate') or request.args.get('start_date')
    end_date = request.args.get('endDate') or request.args.get('end_date')
    meal_type = request.args.get('mealType') or request.args.get('meal_type')
    menu_id = request.args.get('menuId') or request.args.get('menu_id')
    meal_id = request.args.get('mealId') or request.args.get('meal_id')
    category = request.args.get('category')

    if start_date:
        query = query.filter(MessMenu.menu_date >= start_date.strip())
    if end_date:
        query = query.filter(MessMenu.menu_date <= end_date.strip())
    if meal_type and meal_type.strip().upper() in SUPPORTED_MEAL_TYPES:
        query = query.filter(MessMeal.meal_type == meal_type.strip().upper())
    if menu_id:
        query = query.filter(MessFeedback.menu_id == menu_id.strip())
    if meal_id:
        query = query.filter(MessFeedback.meal_id == meal_id.strip())
    if category and category.strip().upper() in SUPPORTED_FEEDBACK_CATEGORIES:
        query = query.filter(MessFeedback.category == category.strip().upper())

    return query


@mess_bp.route('/mess/admin/feedback/summary', methods=['GET'])
def get_mess_feedback_summary():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required"}), 401
    if not is_mess_manager(requester):
        return jsonify({"message": "Forbidden: You are not authorized to view mess feedback analytics"}), 403

    query = _build_admin_feedback_query()
    feedbacks = query.all()

    total_ratings = len(feedbacks)
    avg_rating = round(sum(f.rating for f in feedbacks) / total_ratings, 2) if total_ratings > 0 else 0.0

    rating_distribution = {"1": 0, "2": 0, "3": 0, "4": 0, "5": 0}
    total_comments = 0
    meal_breakdown = {
        m: {"count": 0, "totalRating": 0, "averageRating": 0.0}
        for m in sorted(list(SUPPORTED_MEAL_TYPES))
    }

    for f in feedbacks:
        r_str = str(f.rating)
        rating_distribution[r_str] = rating_distribution.get(r_str, 0) + 1
        if f.comment and f.comment.strip():
            total_comments += 1
        m_type = f.meal.meal_type if f.meal else None
        if m_type and m_type in meal_breakdown:
            meal_breakdown[m_type]["count"] += 1
            meal_breakdown[m_type]["totalRating"] += f.rating

    for m_type, stat in meal_breakdown.items():
        c = stat["count"]
        stat["averageRating"] = round(stat["totalRating"] / c, 2) if c > 0 else 0.0
        del stat["totalRating"]

    return jsonify({
        "totalRatings": total_ratings,
        "feedbackCount": total_ratings,
        "averageRating": avg_rating,
        "totalComments": total_comments,
        "ratingDistribution": rating_distribution,
        "mealBreakdown": meal_breakdown
    }), 200


@mess_bp.route('/mess/admin/feedback/trends', methods=['GET'])
def get_mess_feedback_trends():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required"}), 401
    if not is_mess_manager(requester):
        return jsonify({"message": "Forbidden: You are not authorized to view mess feedback analytics"}), 403

    query = _build_admin_feedback_query()
    feedbacks = query.all()

    # Group by menu_date
    date_groups = {}
    for f in feedbacks:
        d = f.menu.menu_date if f.menu else (f.created_at[:10] if f.created_at else 'Unknown')
        if d not in date_groups:
            date_groups[d] = []
        date_groups[d].append(f)

    sorted_dates = sorted(date_groups.keys())
    trends = []
    for d in sorted_dates:
        group = date_groups[d]
        count = len(group)
        avg = round(sum(item.rating for item in group) / count, 2) if count > 0 else 0.0

        m_breakdown = {}
        for item in group:
            mt = item.meal.meal_type if item.meal else 'OTHER'
            if mt not in m_breakdown:
                m_breakdown[mt] = {"count": 0, "totalRating": 0}
            m_breakdown[mt]["count"] += 1
            m_breakdown[mt]["totalRating"] += item.rating

        for mt, data in m_breakdown.items():
            c = data["count"]
            data["averageRating"] = round(data["totalRating"] / c, 2) if c > 0 else 0.0
            del data["totalRating"]

        trends.append({
            "date": d,
            "ratingCount": count,
            "averageRating": avg,
            "mealBreakdown": m_breakdown
        })

    return jsonify({"trends": trends}), 200


@mess_bp.route('/mess/admin/feedback/categories', methods=['GET'])
def get_mess_feedback_categories():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required"}), 401
    if not is_mess_manager(requester):
        return jsonify({"message": "Forbidden: You are not authorized to view mess feedback analytics"}), 403

    query = _build_admin_feedback_query()
    feedbacks = query.all()

    # Aggregate by category
    cat_groups = {cat: [] for cat in sorted(list(SUPPORTED_FEEDBACK_CATEGORIES))}
    for f in feedbacks:
        cat = f.category or 'OTHER'
        if cat not in cat_groups:
            cat_groups[cat] = []
        cat_groups[cat].append(f)

    categories_stats = []
    signals = []

    for cat in sorted(cat_groups.keys()):
        items = cat_groups[cat]
        count = len(items)
        avg = round(sum(i.rating for i in items) / count, 2) if count > 0 else 0.0
        neg_count = sum(1 for i in items if i.rating <= 2)
        pos_count = sum(1 for i in items if i.rating >= 4)
        neg_pct = round((neg_count / count) * 100, 1) if count > 0 else 0.0

        categories_stats.append({
            "category": cat,
            "feedbackCount": count,
            "averageRating": avg,
            "negativeCount": neg_count,
            "positiveCount": pos_count,
            "negativePercentage": neg_pct
        })

        # Deterministic Recurring Negative Signal Rule:
        # Flag a category when:
        # 1. feedback_count >= 2 (sufficient evidence)
        # 2. average_rating < 3.0 OR negative_percentage >= 35.0%
        if count >= 2 and (avg < 3.0 or neg_pct >= 35.0):
            flag_reason = (
                f"Low average rating ({avg}/5.0)"
                if avg < 3.0
                else f"High negative share ({neg_pct}% rated 1-2★)"
            )
            signals.append({
                "category": cat,
                "feedbackCount": count,
                "averageRating": avg,
                "negativeCount": neg_count,
                "negativePercentage": neg_pct,
                "flagged": True,
                "flagReason": flag_reason
            })
        else:
            signals.append({
                "category": cat,
                "feedbackCount": count,
                "averageRating": avg,
                "negativeCount": neg_count,
                "negativePercentage": neg_pct,
                "flagged": False,
                "flagReason": "Normal" if count >= 2 else "Insufficient feedback sample"
            })

    return jsonify({
        "categories": categories_stats,
        "signals": signals
    }), 200


@mess_bp.route('/mess/admin/feedback/comments', methods=['GET'])
def get_mess_feedback_comments():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required"}), 401
    if not is_mess_manager(requester):
        return jsonify({"message": "Forbidden: You are not authorized to view mess feedback comments"}), 403

    query = _build_admin_feedback_query()
    # Filter only rows with non-empty comments
    query = query.filter(MessFeedback.comment.isnot(None), MessFeedback.comment != '')

    min_rating = request.args.get('minRating')
    max_rating = request.args.get('maxRating')
    if min_rating and min_rating.isdigit():
        query = query.filter(MessFeedback.rating >= int(min_rating))
    if max_rating and max_rating.isdigit():
        query = query.filter(MessFeedback.rating <= int(max_rating))

    limit = request.args.get('limit', 50)
    try:
        limit = min(int(limit), 200)
    except Exception:
        limit = 50

    feedbacks = query.order_by(MessFeedback.created_at.desc()).limit(limit).all()

    # Privacy model: Anonymize studentId to protect student identity
    return jsonify([f.to_dict(anonymize=True) for f in feedbacks]), 200


# ==============================================================================
# --- STEP 23: MESS VERIFICATION & BATCH / QR FALLBACK ENDPOINTS ---
# ==============================================================================

@mess_bp.route('/mess/entries/verify', methods=['POST'])
def verify_meal_entry():
    """
    CampusOS Mess Verification Endpoint (Single Student / QR Fallback / Direct).
    Validates:
    1. Verifier authorization (MESS_STAFF, staff, warden, admin).
    2. Optional cryptographic passport signature/presentation if provided.
    3. Student eligibility (must be a valid student).
    4. Idempotency (replays return 200 with existing entry).
    5. Duplicate meal entry (same student, date, and mealType returns ALREADY_USED).
    """
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required", "status": "INVALID"}), 401
    if not is_mess_manager(requester):
        return jsonify({"message": "Forbidden: Not authorized for mess verification", "status": "NOT_ELIGIBLE"}), 403

    data = request.json or {}
    student_id = data.get('studentId')
    meal_type = (data.get('mealType') or 'LUNCH').upper().strip()
    date_str = data.get('date') or datetime.date.today().strftime('%Y-%m-%d')
    verification_mode = data.get('verificationMode') or 'QR_PRESENTATION'
    idempotency_key = data.get('idempotencyKey')
    qr_payload = data.get('qrPayload') or data.get('payload')
    signature = data.get('signature')
    presentation_nonce = None
    p_data = None

    # Security Fix P0-03: Cryptographic verification of passport presentation is MANDATORY.
    # No bare studentId + mealType bypass is permitted under any circumstances.
    if not qr_payload:
        return jsonify({
            "status": "INVALID",
            "message": "Cryptographic presentation required: qrPayload is missing",
            "valid": False
        }), 400

    if isinstance(qr_payload, str) and not qr_payload.strip():
        return jsonify({
            "status": "INVALID",
            "message": "Cryptographic presentation required: qrPayload is empty",
            "valid": False
        }), 400

    try:
        if isinstance(qr_payload, str):
            try:
                payload_dict = json.loads(qr_payload)
            except Exception:
                return jsonify({
                    "status": "INVALID",
                    "message": "Cryptographic presentation malformed: invalid JSON in qrPayload",
                    "valid": False
                }), 400
        elif isinstance(qr_payload, dict):
            payload_dict = qr_payload
        else:
            return jsonify({
                "status": "INVALID",
                "message": "Cryptographic presentation malformed: expected JSON string or object",
                "valid": False
            }), 400

        if not isinstance(payload_dict, dict) or not payload_dict:
            return jsonify({
                "status": "INVALID",
                "message": "Cryptographic presentation malformed: empty presentation payload",
                "valid": False
            }), 400

        p_data = None
        s_data = None
        if 'p' in payload_dict and 's' in payload_dict:
            # Compact presentation format
            p_data = payload_dict['p']
            s_data = payload_dict['s']
        elif 'payload' in payload_dict and 'signature' in payload_dict:
            # Verbose envelope format
            p_data = payload_dict['payload']
            s_data = payload_dict['signature']
        elif signature:
            p_data = payload_dict
            s_data = signature
        elif 'signature' in data:
            p_data = payload_dict
            s_data = data['signature']
        elif 's' in data:
            p_data = payload_dict
            s_data = data['s']

        if not p_data or not s_data:
            return jsonify({
                "status": "INVALID",
                "message": "Cryptographic verification failed: missing signature or presentation payload",
                "valid": False
            }), 400

        if not isinstance(p_data, dict):
            return jsonify({
                "status": "INVALID",
                "message": "Cryptographic presentation malformed: payload must be an object",
                "valid": False
            }), 400

        if not isinstance(s_data, str) or not s_data.strip():
            return jsonify({
                "status": "INVALID",
                "message": "Cryptographic presentation missing or invalid signature string",
                "valid": False
            }), 400

        # Cryptographically verify Ed25519 signature & certificate chain
        result = PassportService.verify_presentation(
            payload=p_data,
            signature_b64=s_data,
            device_identity_key_model=DeviceIdentityKey,
            device_certificate_model=DeviceCertificate,
            user_model=User
        )

        if not result.get("valid"):
            reason = result.get("reason") or "Presentation verification failed"
            return jsonify({
                "status": "INVALID",
                "message": f"Cryptographic verification failed: {reason}",
                "reason": reason,
                "valid": False
            }), 400

        verified_sub = p_data.get('userId') or p_data.get('sub')
        if not verified_sub:
            return jsonify({
                "status": "INVALID",
                "message": "Missing student userId in presentation payload",
                "valid": False
            }), 400

        if student_id and student_id != verified_sub:
            return jsonify({
                "status": "INVALID",
                "message": f"Student ID mismatch: provided '{student_id}' does not match presentation subject '{verified_sub}'",
                "reason": "STUDENT_ID_MISMATCH",
                "valid": False
            }), 400

        student_id = verified_sub

        # Replay protection: check presentation nonce
        presentation_nonce = p_data.get('nonce')
        if presentation_nonce:
            existing_nonce_entry = MealEntry.query.filter_by(response_nonce=str(presentation_nonce)).first()
            if existing_nonce_entry and existing_nonce_entry.idempotency_key != idempotency_key:
                return jsonify({
                    "status": "REJECTED",
                    "message": "Presentation replay detected: nonce has already been used",
                    "reason": "REPLAY_DETECTED",
                    "valid": False
                }), 409

    except Exception as e:
        return jsonify({
            "status": "INVALID",
            "message": f"Cryptographic presentation verification error: {str(e)}",
            "valid": False
        }), 400

    if not student_id:
        return jsonify({"status": "INVALID", "message": "studentId is required"}), 400

    # Verify student identity & eligibility
    student = User.query.get(student_id)
    if not student:
        return jsonify({"status": "INVALID", "message": "Student identity not found"}), 404

    if student.role.lower() != 'student':
        return jsonify({"status": "NOT_ELIGIBLE", "message": "Non-student role is not eligible for student mess meals"}), 403

    # Idempotency check: Replay of same idempotency key
    if idempotency_key:
        existing_idem = MealEntry.query.filter_by(idempotency_key=idempotency_key).first()
        if existing_idem:
            return jsonify({
                "status": "VERIFIED",
                "message": "Meal entry confirmed (idempotent replay)",
                "entry": existing_idem.to_dict(),
                "isReplay": True
            }), 200

    # Duplicate check: Student already checked in for this meal today
    existing_entry = MealEntry.query.filter_by(
        student_id=student.id,
        entry_date=date_str,
        meal_type=meal_type
    ).first()

    if existing_entry:
        return jsonify({
            "status": "ALREADY_USED",
            "message": f"Student has already checked in for {meal_type.capitalize()} on {date_str}",
            "existingEntry": existing_entry.to_dict()
        }), 409

    # Record verified meal entry
    new_entry = MealEntry(
        menu_id=data.get('menuId'),
        meal_id=data.get('mealId'),
        meal_type=meal_type,
        entry_date=date_str,
        student_id=student.id,
        student_name=student.name,
        registration_number=student.registration_number or data.get('registrationNumber'),
        verified_by=requester.id,
        verification_mode=verification_mode,
        idempotency_key=idempotency_key or f"idem-{uuid.uuid4()}",
        device_key_id=(p_data.get('keyId') if p_data else None) or data.get('deviceKeyId'),
        response_nonce=str(presentation_nonce) if presentation_nonce else data.get('responseNonce'),
        status='VERIFIED'
    )
    db.session.add(new_entry)
    db.session.commit()

    return jsonify({
        "status": "VERIFIED",
        "message": f"Student verified for {meal_type.capitalize()}",
        "entry": new_entry.to_dict()
    }), 201


@mess_bp.route('/mess/entries/batch-sync', methods=['POST'])
def batch_sync_meal_entries():
    """
    CampusOS Mess Batch Synchronization Endpoint.
    Idempotently ingests verified student dining records collected via batch or offline queues.
    """
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required"}), 401
    if not is_mess_manager(requester):
        return jsonify({"message": "Forbidden: Not authorized for mess verification"}), 403

    data = request.json or {}
    meal_type = (data.get('mealType') or 'LUNCH').upper().strip()
    date_str = data.get('date') or datetime.date.today().strftime('%Y-%m-%d')
    records = data.get('records', [])

    synced_records = []
    duplicate_count = 0
    new_count = 0

    for r in records:
        student_id = r.get('studentId')
        student_name = r.get('studentName') or ''
        registration_number = r.get('registrationNumber')
        idempotency_key = r.get('idempotencyKey')
        rec_meal_type = (r.get('mealType') or meal_type).upper().strip()
        rec_date = r.get('entryDate') or date_str

        if not student_id:
            continue

        existing = None
        if idempotency_key:
            existing = MealEntry.query.filter_by(idempotency_key=idempotency_key).first()
        if not existing:
            existing = MealEntry.query.filter_by(
                student_id=student_id,
                entry_date=rec_date,
                meal_type=rec_meal_type
            ).first()

        if existing:
            duplicate_count += 1
            synced_records.append(existing.to_dict())
            continue

        if not student_name:
            st = User.query.get(student_id)
            if st:
                student_name = st.name
                registration_number = registration_number or st.registration_number

        new_entry = MealEntry(
            menu_id=r.get('menuId') or data.get('menuId'),
            meal_id=r.get('mealId') or data.get('mealId'),
            meal_type=rec_meal_type,
            entry_date=rec_date,
            student_id=student_id,
            student_name=student_name,
            registration_number=registration_number,
            verified_by=requester.id,
            verification_mode=r.get('verificationMode', 'BATCH'),
            idempotency_key=idempotency_key or f"idem-{uuid.uuid4()}",
            device_key_id=r.get('deviceKeyId'),
            response_nonce=r.get('responseNonce'),
            status='VERIFIED',
            created_at=r.get('createdAt') or datetime.datetime.now().isoformat()
        )
        db.session.add(new_entry)
        new_count += 1
        synced_records.append(new_entry.to_dict())

    db.session.commit()
    return jsonify({
        "mealType": meal_type,
        "entryDate": date_str,
        "newSynced": new_count,
        "duplicates": duplicate_count,
        "totalRecords": len(synced_records),
        "records": synced_records
    }), 200


@mess_bp.route('/mess/entries/today', methods=['GET'])
def get_today_meal_stats():
    """
    Returns today's meal verification statistics and current meal information.
    """
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required"}), 401
    if not is_mess_manager(requester):
        return jsonify({"message": "Forbidden"}), 403

    today_str = datetime.date.today().strftime('%Y-%m-%d')
    now = datetime.datetime.now()
    current_hour = now.hour + now.minute / 60.0

    # Determine active meal window
    if 6.0 <= current_hour < 10.5:
        active_meal = 'BREAKFAST'
        meal_timing = '7:00 AM – 10:00 AM'
    elif 11.5 <= current_hour < 15.5:
        active_meal = 'LUNCH'
        meal_timing = '12:00 PM – 3:00 PM'
    elif 16.0 <= current_hour < 18.75:
        active_meal = 'SNACKS'
        meal_timing = '4:30 PM – 6:30 PM'
    elif 19.0 <= current_hour < 22.5:
        active_meal = 'DINNER'
        meal_timing = '7:30 PM – 10:00 PM'
    else:
        active_meal = 'LUNCH'
        meal_timing = '12:00 PM – 3:00 PM'

    # Optimized: SQL GROUP BY for counts instead of loading all objects into Python
    from sqlalchemy import func

    count_rows = db.session.query(
        MealEntry.meal_type,
        MealEntry.verification_mode,
        func.count(MealEntry.id)
    ).filter_by(entry_date=today_str).group_by(
        MealEntry.meal_type, MealEntry.verification_mode
    ).all()

    counts = {
        'BREAKFAST': {'total': 0, 'batch': 0, 'qr': 0},
        'LUNCH': {'total': 0, 'batch': 0, 'qr': 0},
        'SNACKS': {'total': 0, 'batch': 0, 'qr': 0},
        'DINNER': {'total': 0, 'batch': 0, 'qr': 0},
    }

    total_verified_today = 0
    for meal_type, verification_mode, cnt in count_rows:
        m = meal_type.upper() if meal_type else ''
        if m in counts:
            counts[m]['total'] += cnt
            if verification_mode == 'QR_FALLBACK':
                counts[m]['qr'] += cnt
            else:
                counts[m]['batch'] += cnt
        total_verified_today += cnt

    # Check today's menu status
    today_menu = MessMenu.query.filter_by(menu_date=today_str).first()
    menu_status = today_menu.status if today_menu else "NONE"

    # Optimized: only fetch the 15 most recent entries, not all today's entries
    recent_entries = MealEntry.query.filter_by(entry_date=today_str).order_by(
        MealEntry.created_at.desc()
    ).limit(15).all()
    recent = [e.to_dict() for e in recent_entries]

    return jsonify({
        "date": today_str,
        "activeMeal": active_meal,
        "mealTiming": meal_timing,
        "menuStatus": menu_status,
        "todayMenuId": today_menu.id if today_menu else None,
        "totalVerifiedToday": total_verified_today,
        "counts": counts,
        "recentEntries": recent
    }), 200


@mess_bp.route('/mess/entries/analytics', methods=['GET'])
def get_mess_entries_analytics():
    """
    Returns aggregated dining operational metrics for staff and admin analytics.
    Optimized: single conditional-aggregation query instead of 8 sequential COUNTs.
    """
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required"}), 401
    if not is_mess_manager(requester):
        return jsonify({"message": "Forbidden"}), 403

    from sqlalchemy import func, case

    today_str = datetime.date.today().strftime('%Y-%m-%d')

    row = db.session.query(
        func.count(MealEntry.id),
        func.sum(case((MealEntry.verification_mode == 'BATCH', 1), else_=0)),
        func.sum(case((MealEntry.verification_mode == 'QR_FALLBACK', 1), else_=0)),
        func.sum(case((MealEntry.meal_type == 'BREAKFAST', 1), else_=0)),
        func.sum(case((MealEntry.meal_type == 'LUNCH', 1), else_=0)),
        func.sum(case((MealEntry.meal_type == 'SNACKS', 1), else_=0)),
        func.sum(case((MealEntry.meal_type == 'DINNER', 1), else_=0)),
        func.sum(case((MealEntry.entry_date == today_str, 1), else_=0)),
    ).one()

    total_entries = row[0] or 0
    batch_entries = int(row[1] or 0)
    qr_entries = int(row[2] or 0)
    breakfast_count = int(row[3] or 0)
    lunch_count = int(row[4] or 0)
    snacks_count = int(row[5] or 0)
    dinner_count = int(row[6] or 0)
    today_count = int(row[7] or 0)

    meal_breakdown = {
        'BREAKFAST': breakfast_count,
        'LUNCH': lunch_count,
        'SNACKS': snacks_count,
        'DINNER': dinner_count,
    }

    return jsonify({
        "totalEntries": total_entries,
        "batchEntries": batch_entries,
        "qrEntries": qr_entries,
        "todayEntries": today_count,
        "mealBreakdown": meal_breakdown
    }), 200


# ==============================================================================
# --- PASSPORT PHASE 1C: BACKEND KEY REGISTRY & INSTITUTION CERTIFICATION API ---
# ==============================================================================

