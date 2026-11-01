import uuid
import datetime
from flask import Blueprint, request, jsonify
from extensions import db
from models.user import User
from models.expansion import ClassUpdate
from models.audit import RequestAudit
from models.notification import NotificationDelivery
from middleware.auth import get_authenticated_requester

academic_updates_bp = Blueprint('academic_updates_bp', __name__)

@academic_updates_bp.route('/academic-updates', methods=['POST'])
def create_class_update():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required"}), 401
    if requester.role not in ['teacher', 'faculty', 'admin']:
        return jsonify({"message": "Forbidden: Only faculty or admin can post class updates"}), 403

    data = request.json or {}
    course_code = (data.get('courseCode') or '').strip()
    course_name = (data.get('courseName') or '').strip()
    update_type = (data.get('updateType') or '').strip().upper()
    original_date = data.get('originalDate')
    original_time = data.get('originalTime')
    original_room = data.get('originalRoom')
    new_date = data.get('newDate')
    new_time = data.get('newTime')
    new_room = data.get('newRoom')
    message = (data.get('message') or '').strip()
    affected_branch = data.get('affectedBranch') or 'ALL'
    affected_year = data.get('affectedYear')
    affected_section = data.get('affectedSection')

    if not course_code or not course_name:
        return jsonify({"message": "courseCode and courseName are required"}), 400
    if update_type not in ['CANCELLED', 'RESCHEDULED', 'ROOM_CHANGE', 'TIME_CHANGE', 'ANNOUNCEMENT']:
        return jsonify({"message": "Invalid updateType. Must be CANCELLED, RESCHEDULED, ROOM_CHANGE, TIME_CHANGE, or ANNOUNCEMENT"}), 400
    if not message:
        return jsonify({"message": "message is required"}), 400
    if not original_date:
        original_date = datetime.date.today().isoformat()

    update = ClassUpdate(
        teacher_id=requester.id,
        course_code=course_code,
        course_name=course_name,
        update_type=update_type,
        original_date=original_date,
        original_time=original_time,
        original_room=original_room,
        new_date=new_date,
        new_time=new_time,
        new_room=new_room,
        message=message,
        affected_branch=affected_branch,
        affected_year=affected_year,
        affected_section=affected_section,
        status='ACTIVE'
    )
    db.session.add(update)

    audit = RequestAudit(
        entity_type='CLASS_UPDATE',
        entity_id=update.id,
        actor_id=requester.id,
        action=update_type,
        remarks=f"{update_type} for {course_code} - {course_name}: {message}",
        ip_address=request.remote_addr
    )
    db.session.add(audit)

    # Deliver targeted notifications to affected students
    query = User.query.filter_by(role='student')
    if affected_branch and affected_branch.upper() != 'ALL':
        query = query.filter(User.branch.ilike(affected_branch))
    if affected_year:
        query = query.filter(User.year == affected_year)

    affected_students = query.all()
    now_iso = datetime.datetime.now().isoformat()
    for student in affected_students:
        notif = NotificationDelivery(
            user_id=student.id,
            title=f"Class Update: {course_code} {update_type.title()}",
            body=f"{message}",
            notification_type="CLASS_UPDATE",
            reference_id=update.id,
            status="PENDING",
            delivered_at=now_iso,
            created_at=now_iso
        )
        db.session.add(notif)

    db.session.commit()

    return jsonify({
        "message": "Class update published successfully",
        "update": update.to_dict(),
        "affectedStudentsCount": len(affected_students)
    }), 201

@academic_updates_bp.route('/academic-updates/my', methods=['GET'])
def get_my_academic_updates():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required"}), 401

    query = ClassUpdate.query.filter_by(status='ACTIVE')
    if requester.role == 'student':
        student_branch = (requester.branch or '').strip()
        if student_branch:
            query = query.filter(
                (ClassUpdate.affected_branch == 'ALL') |
                (ClassUpdate.affected_branch.ilike(student_branch)) |
                (ClassUpdate.affected_branch.is_(None))
            )

        year_num = None
        if requester.year:
            try:
                digits = ''.join(c for c in str(requester.year) if c.isdigit())
                if digits:
                    year_num = int(digits)
            except Exception:
                pass

        if year_num is not None:
            query = query.filter(
                (ClassUpdate.affected_year == year_num) |
                (ClassUpdate.affected_year.is_(None))
            )

    updates = query.order_by(ClassUpdate.created_at.desc()).limit(20).all()

    results = []
    for u in updates:
        d = u.to_dict()
        teacher = User.query.get(u.teacher_id)
        if teacher:
            d['teacherName'] = teacher.name
        results.append(d)

    return jsonify(results), 200

@academic_updates_bp.route('/academic-updates/teacher', methods=['GET'])
def get_teacher_academic_updates():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required"}), 401

    updates = ClassUpdate.query.filter_by(teacher_id=requester.id).order_by(ClassUpdate.created_at.desc()).all()
    return jsonify([u.to_dict() for u in updates]), 200

@academic_updates_bp.route('/academic-updates/all', methods=['GET'])
def get_all_academic_updates():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester or requester.role not in ['admin', 'staff', 'teacher']:
        return jsonify({"message": "Forbidden"}), 403

    updates = ClassUpdate.query.order_by(ClassUpdate.created_at.desc()).limit(50).all()
    results = []
    for u in updates:
        d = u.to_dict()
        teacher = User.query.get(u.teacher_id)
        if teacher:
            d['teacherName'] = teacher.name
        results.append(d)

    return jsonify(results), 200

@academic_updates_bp.route('/academic-updates/today-summary', methods=['GET'])
def get_today_updates_summary():
    today_str = datetime.date.today().isoformat()
    today_updates = ClassUpdate.query.filter(
        ClassUpdate.original_date == today_str,
        ClassUpdate.status == 'ACTIVE'
    ).all()

    cancellations = [u for u in today_updates if u.update_type == 'CANCELLED']
    rescheduled = [u for u in today_updates if u.update_type in ['RESCHEDULED', 'TIME_CHANGE', 'ROOM_CHANGE']]

    return jsonify({
        "todayTotal": len(today_updates),
        "cancellationsCount": len(cancellations),
        "rescheduledCount": len(rescheduled),
        "updates": [u.to_dict() for u in today_updates]
    }), 200
