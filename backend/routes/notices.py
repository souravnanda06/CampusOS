import json
import datetime
from sqlalchemy import func
from flask import Blueprint, request, jsonify
from extensions import db
from models.user import User
from models.notice import Notice
from models.notification import NotificationDelivery, DeviceToken
from middleware.auth import get_authenticated_requester
from services.notice_service import (
    SUPPORTED_NOTICE_PRIORITIES,
    SUPPORTED_NOTICE_CATEGORIES,
    SUPPORTED_NOTICE_TARGET_TYPES,
    SUPPORTED_NOTICE_STATUSES,
    resolve_notice_recipients,
    is_notice_targeted_to_student,
    dispatch_notice_push_notifications,
    sync_notice_deliveries,
    is_notice_expired
)

notices_bp = Blueprint('notices_bp', __name__)

@notices_bp.route('/notices', methods=['POST'])
def create_notice():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required: createdBy or requesterId required"}), 400
    if requester.role == 'student':
        return jsonify({"message": "Forbidden: Students are not authorized to create notices"}), 403

    data = request.json or {}
    title = (data.get('title') or '').strip()
    body = (data.get('body') or data.get('content') or '').strip()
    category = (data.get('category') or 'GENERAL').upper().strip()
    priority = (data.get('priority') or 'NORMAL').upper().strip()
    target_type = (data.get('target_type') or data.get('targetType') or 'ALL').upper().strip()
    target_value = (data.get('target_value') or data.get('targetValue') or '').strip() or None
    action_type = data.get('action_type') or data.get('actionType')
    action_payload = data.get('action_payload') or data.get('actionPayload')
    expires_at = data.get('expires_at') or data.get('expiresAt')
    status = (data.get('status') or 'PUBLISHED').upper().strip()

    # Validations
    if not title:
        return jsonify({"message": "Title is required and cannot be empty"}), 400
    if not body:
        return jsonify({"message": "Body is required and cannot be empty"}), 400
    if priority not in SUPPORTED_NOTICE_PRIORITIES:
        return jsonify({"message": f"Invalid priority '{priority}'. Must be one of: {sorted(list(SUPPORTED_NOTICE_PRIORITIES))}"}), 400
    if category not in SUPPORTED_NOTICE_CATEGORIES:
        return jsonify({"message": f"Invalid category '{category}'. Must be one of: {sorted(list(SUPPORTED_NOTICE_CATEGORIES))}"}), 400
    if status not in SUPPORTED_NOTICE_STATUSES:
        return jsonify({"message": f"Invalid status '{status}'. Must be one of: {sorted(list(SUPPORTED_NOTICE_STATUSES))}"}), 400
    if target_type not in SUPPORTED_NOTICE_TARGET_TYPES:
        return jsonify({"message": f"Invalid target_type '{target_type}'. Must be one of: {sorted(list(SUPPORTED_NOTICE_TARGET_TYPES))}"}), 400

    if target_type == 'HOSTEL':
        return jsonify({"message": "Hostel targeting is not currently supported: student hostel metadata is not configured in the system"}), 400

    if target_type in ['BRANCH', 'YEAR', 'STUDENT'] and not target_value:
        return jsonify({"message": f"target_value is required when target_type is {target_type}"}), 400

    if requester.role == 'teacher':
        if target_type == 'ALL':
            return jsonify({"message": "Forbidden: Teachers cannot target ALL students"}), 403

    if expires_at:
        try:
            clean_exp = expires_at.replace('Z', '+00:00')
            datetime.datetime.fromisoformat(clean_exp)
        except Exception:
            try:
                datetime.date.fromisoformat(expires_at)
            except Exception:
                return jsonify({"message": "Invalid expires_at format. Expected ISO-8601 string (e.g. YYYY-MM-DD or YYYY-MM-DDTHH:MM:SS)"}), 400

    try:
        notice = Notice(
            title=title,
            body=body,
            content=body,
            category=category,
            priority=priority,
            target_type=target_type,
            target_value=target_value,
            action_type=action_type,
            action_payload=action_payload if isinstance(action_payload, str) else json.dumps(action_payload) if action_payload else None,
            expires_at=expires_at,
            status=status,
            created_by=requester.id,
            published_by=requester.id
        )
        db.session.add(notice)
        db.session.commit()

        delivery_count = 0
        if notice.status == 'PUBLISHED':
            delivery_count = sync_notice_deliveries(notice)

        resp = notice.to_dict()
        resp['recipientCount'] = delivery_count
        return jsonify(resp), 201

    except Exception as e:
        db.session.rollback()
        return jsonify({"message": f"Server error creating notice: {str(e)}"}), 500


@notices_bp.route('/notices', methods=['GET'])
def list_notices():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp

    include_expired = request.args.get('includeExpired', 'false').lower() == 'true'
    status_filter = request.args.get('status')
    category_filter = request.args.get('category')
    priority_filter = request.args.get('priority')

    query = Notice.query

    # Category and Priority filters
    if category_filter:
        query = query.filter(func.upper(Notice.category) == category_filter.upper())
    if priority_filter:
        query = query.filter(func.upper(Notice.priority) == priority_filter.upper())

    # Status filter
    if requester and requester.role == 'student':
        # Students only see PUBLISHED notices
        query = query.filter(func.upper(Notice.status) == 'PUBLISHED')
    elif status_filter:
        query = query.filter(func.upper(Notice.status) == status_filter.upper())

    if requester and requester.role == 'teacher':
        query = query.filter(Notice.created_by == requester.id)

    all_notices = query.order_by(Notice.created_at.desc()).all()

    now_iso = datetime.datetime.now().isoformat()

    # Expired filtering
    if not include_expired:
        all_notices = [n for n in all_notices if not is_notice_expired(n, now_iso)]

    # Batch fetch NotificationDelivery records for student to eliminate N+1 queries
    delivery_by_notice_id = {}
    if requester and requester.role == 'student' and all_notices:
        notice_ids = [n.id for n in all_notices]
        deliveries = NotificationDelivery.query.filter(
            NotificationDelivery.notice_id.in_(notice_ids),
            NotificationDelivery.user_id == requester.id
        ).all()
        delivery_by_notice_id = {d.notice_id: d for d in deliveries}

    # Student targeting filtering
    if requester and requester.role == 'student':
        all_notices = [n for n in all_notices if is_notice_targeted_to_student(n, requester, delivery_lookup=delivery_by_notice_id)]

    results = []
    for n in all_notices:
        n_dict = n.to_dict()
        if requester and requester.role == 'student':
            delivery = delivery_by_notice_id.get(n.id)
            if delivery:
                n_dict['deliveryStatus'] = delivery.status
                n_dict['isRead'] = delivery.is_read
                n_dict['readAt'] = delivery.read_at
        results.append(n_dict)

    return jsonify(results), 200


@notices_bp.route('/notices/<id>', methods=['GET'])
def get_notice_detail(id):
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp

    notice = Notice.query.get(id)
    if not notice:
        return jsonify({"message": "Notice not found"}), 404

    if requester and requester.role == 'student':
        if (notice.status or '').upper() != 'PUBLISHED':
            return jsonify({"message": "Access denied: Notice is not accessible"}), 403
        if not is_notice_targeted_to_student(notice, requester):
            return jsonify({"message": "Access denied: Notice is not targeted to you"}), 403
    elif requester and requester.role == 'teacher':
        if notice.created_by != requester.id:
            return jsonify({"message": "Access denied: You can only view your own notices"}), 403

    notice_dict = notice.to_dict()

    if requester and requester.role == 'student':
        delivery = NotificationDelivery.query.filter_by(notice_id=notice.id, user_id=requester.id).first()
        if delivery:
            notice_dict['deliveryStatus'] = delivery.status
            notice_dict['isRead'] = delivery.is_read
            notice_dict['readAt'] = delivery.read_at
    else:
        # Staff/Admin details
        deliveries = NotificationDelivery.query.filter_by(notice_id=notice.id).all()
        notice_dict['totalDeliveries'] = len(deliveries)
        notice_dict['readDeliveries'] = sum(1 for d in deliveries if d.is_read or d.status in ['READ', 'ACTIONED'])
        notice_dict['pushAttempts'] = sum(1 for d in deliveries if d.push_attempted)
        notice_dict['deliveredCount'] = sum(1 for d in deliveries if d.delivered_at is not None or d.status in ['DELIVERED', 'READ', 'ACTIONED'])
        notice_dict['failedCount'] = sum(1 for d in deliveries if d.status == 'FAILED')

    return jsonify(notice_dict), 200


@notices_bp.route('/notices/<id>', methods=['PATCH', 'PUT'])
def update_notice(id):
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required to update notices"}), 400
    if requester.role == 'student':
        return jsonify({"message": "Forbidden: Students are not authorized to update notices"}), 403

    notice = Notice.query.get(id)
    if not notice:
        return jsonify({"message": "Notice not found"}), 404

    if requester.role == 'teacher' and notice.created_by != requester.id:
        return jsonify({"message": "Forbidden: You can only update your own notices"}), 403

    data = request.json or {}

    # Validations on payload
    if 'title' in data:
        new_title = (data['title'] or '').strip()
        if not new_title:
            return jsonify({"message": "Title cannot be empty"}), 400
        notice.title = new_title

    if 'body' in data or 'content' in data:
        new_body = (data.get('body') or data.get('content') or '').strip()
        if not new_body:
            return jsonify({"message": "Body cannot be empty"}), 400
        notice.body = new_body
        notice.content = new_body

    if 'priority' in data:
        new_pri = (data['priority'] or '').upper().strip()
        if new_pri not in SUPPORTED_NOTICE_PRIORITIES:
            return jsonify({"message": f"Invalid priority '{new_pri}'. Must be one of: {sorted(list(SUPPORTED_NOTICE_PRIORITIES))}"}), 400
        notice.priority = new_pri

    if 'category' in data:
        new_cat = (data['category'] or '').upper().strip()
        if new_cat not in SUPPORTED_NOTICE_CATEGORIES:
            return jsonify({"message": f"Invalid category '{new_cat}'. Must be one of: {sorted(list(SUPPORTED_NOTICE_CATEGORIES))}"}), 400
        notice.category = new_cat

    if 'status' in data:
        new_status = (data['status'] or '').upper().strip()
        if new_status not in SUPPORTED_NOTICE_STATUSES:
            return jsonify({"message": f"Invalid status '{new_status}'. Must be one of: {sorted(list(SUPPORTED_NOTICE_STATUSES))}"}), 400
        notice.status = new_status

    if 'target_type' in data or 'targetType' in data:
        new_tt = (data.get('target_type') or data.get('targetType') or '').upper().strip()
        if new_tt not in SUPPORTED_NOTICE_TARGET_TYPES:
            return jsonify({"message": f"Invalid target_type '{new_tt}'. Must be one of: {sorted(list(SUPPORTED_NOTICE_TARGET_TYPES))}"}), 400
        if new_tt == 'HOSTEL':
            return jsonify({"message": "Hostel targeting is not currently supported: student hostel metadata is not configured in the system"}), 400
        if requester.role == 'teacher' and new_tt == 'ALL':
            return jsonify({"message": "Forbidden: Teachers cannot target ALL students"}), 403
        notice.target_type = new_tt

    if 'target_value' in data or 'targetValue' in data:
        notice.target_value = (data.get('target_value') or data.get('targetValue') or '').strip() or None

    # Verify target_type still has target_value if required
    if notice.target_type in ['BRANCH', 'YEAR', 'STUDENT'] and not notice.target_value:
        return jsonify({"message": f"target_value is required when target_type is {notice.target_type}"}), 400

    if 'action_type' in data or 'actionType' in data:
        notice.action_type = data.get('action_type') or data.get('actionType')

    if 'action_payload' in data or 'actionPayload' in data:
        ap = data.get('action_payload') or data.get('actionPayload')
        notice.action_payload = ap if isinstance(ap, str) else json.dumps(ap) if ap else None

    if 'expires_at' in data or 'expiresAt' in data:
        exp = data.get('expires_at') or data.get('expiresAt')
        if exp:
            try:
                datetime.datetime.fromisoformat(exp.replace('Z', '+00:00'))
            except Exception:
                try:
                    datetime.date.fromisoformat(exp)
                except Exception:
                    return jsonify({"message": "Invalid expires_at format. Expected ISO-8601 string"}), 400
            notice.expires_at = exp
        else:
            notice.expires_at = None

    try:
        db.session.commit()

        # If notice is PUBLISHED, sync deliveries (adds newly matching recipients without duplicating existing deliveries)
        delivery_count = 0
        if (notice.status or '').upper() == 'PUBLISHED':
            NotificationDelivery.query.filter_by(notice_id=notice.id, status='PENDING').update({
                'title': notice.title,
                'body': notice.body or notice.content or ""
            }, synchronize_session=False)
            db.session.commit()
            delivery_count = sync_notice_deliveries(notice)
            # Also dispatch for any pending deliveries that haven't attempted push yet
            pending = NotificationDelivery.query.filter_by(
                notice_id=notice.id,
                status='PENDING',
                push_attempted=False
            ).all()
            if pending:
                try:
                    dispatch_notice_push_notifications(notice, pending)
                except Exception as push_err:
                    print(f"[WARN] Push dispatch error on update: {push_err}")

        resp = notice.to_dict()
        resp['newDeliveriesCount'] = delivery_count
        return jsonify(resp), 200

    except Exception as e:
        db.session.rollback()
        return jsonify({"message": f"Server error updating notice: {str(e)}"}), 500


@notices_bp.route('/notices/<id>/archive', methods=['POST'])
def archive_notice(id):
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required to archive notice"}), 400
    if requester.role == 'student':
        return jsonify({"message": "Forbidden: Students are not authorized to archive notices"}), 403

    notice = Notice.query.get(id)
    if not notice:
        return jsonify({"message": "Notice not found"}), 404

    if requester.role == 'teacher' and notice.created_by != requester.id:
        return jsonify({"message": "Forbidden: You can only archive your own notices"}), 403

    try:
        notice.status = 'ARCHIVED'
        db.session.commit()
        return jsonify(notice.to_dict()), 200
    except Exception as e:
        db.session.rollback()
        return jsonify({"message": f"Server error archiving notice: {str(e)}"}), 500


@notices_bp.route('/notices/<id>/read', methods=['POST'])
def mark_notice_read(id):
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required: requesterId or userId required"}), 400

    notice = Notice.query.get(id)
    if not notice:
        return jsonify({"message": "Notice not found"}), 404

    # Authorization check for students
    if requester.role == 'student':
        if (notice.status or '').upper() != 'PUBLISHED':
            return jsonify({"message": "Access denied: Notice is not accessible"}), 403
        if not is_notice_targeted_to_student(notice, requester):
            return jsonify({"message": "Access denied: Notice is not targeted to you"}), 403

    now_iso = datetime.datetime.now().isoformat()

    try:
        delivery = NotificationDelivery.query.filter_by(
            notice_id=notice.id,
            user_id=requester.id
        ).first()

        if not delivery:
            # If notice is legitimately accessible to this user, create delivery record idempotently
            delivery = NotificationDelivery(
                notice_id=notice.id,
                user_id=requester.id,
                title=notice.title,
                body=notice.body or notice.content or "",
                notification_type='NOTICE',
                reference_id=notice.id,
                status='READ',
                is_read=True,
                delivered_at=now_iso,
                read_at=now_iso,
                created_at=now_iso
            )
            db.session.add(delivery)
        else:
            delivery.is_read = True
            if not delivery.read_at:
                delivery.read_at = now_iso
            # Do not downgrade ACTIONED to READ
            if delivery.status != 'ACTIONED':
                delivery.status = 'READ'

        db.session.commit()
        return jsonify(delivery.to_dict()), 200

    except Exception as e:
        db.session.rollback()
        return jsonify({"message": f"Server error marking notice as read: {str(e)}"}), 500


# --- STEP 21E: DEVICE TOKEN & DELIVERY METRICS ROUTES ---

@notices_bp.route('/notifications/device-token', methods=['POST'])
def register_device_token():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required to register device token"}), 401

    data = request.json or {}
    token = data.get('token')
    if not token or not isinstance(token, str) or not token.strip():
        return jsonify({"message": "Token is required and cannot be empty"}), 400

    token = token.strip()
    device_type = data.get('deviceType', 'android')
    device_id = data.get('deviceId')
    now_iso = datetime.datetime.now().isoformat()

    existing = DeviceToken.query.filter_by(token=token).first()
    if existing:
        existing.user_id = requester.id
        existing.device_type = device_type
        if device_id:
            existing.device_id = device_id
        existing.is_active = True
        existing.updated_at = now_iso
        db.session.commit()
        return jsonify(existing.to_dict()), 200
    else:
        new_token = DeviceToken(
            user_id=requester.id,
            token=token,
            device_type=device_type,
            device_id=device_id,
            is_active=True,
            created_at=now_iso,
            updated_at=now_iso
        )
        db.session.add(new_token)
        db.session.commit()
        return jsonify(new_token.to_dict()), 201


@notices_bp.route('/notifications/device-token', methods=['DELETE'])
def remove_device_token():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required to remove device token"}), 401

    data = request.json or {}
    token = data.get('token') or request.args.get('token')

    if token:
        token = token.strip()
        record = DeviceToken.query.filter_by(user_id=requester.id, token=token).first()
        if record:
            db.session.delete(record)
            db.session.commit()
            return jsonify({"message": "Device token removed successfully"}), 200
        else:
            return jsonify({"message": "Device token not found"}), 404
    else:
        deleted = DeviceToken.query.filter_by(user_id=requester.id).delete(synchronize_session=False)
        db.session.commit()
        return jsonify({"message": f"All ({deleted}) device tokens removed for user"}), 200


@notices_bp.route('/notices/<id>/delivery', methods=['GET'])
def get_notice_delivery_metrics(id):
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required"}), 401

    if requester.role == 'student':
        return jsonify({"message": "Forbidden: Students are not authorized to view delivery metrics"}), 403

    notice = Notice.query.get(id)
    if not notice:
        return jsonify({"message": "Notice not found"}), 404

    if requester.role == 'teacher' and notice.created_by != requester.id:
        return jsonify({"message": "Forbidden: You are only authorized to view delivery metrics for your own notices"}), 403

    deliveries = NotificationDelivery.query.filter_by(notice_id=notice.id).all()
    total_recipients = len(deliveries)
    push_attempts = sum(1 for d in deliveries if d.push_attempted)
    delivered = sum(1 for d in deliveries if d.delivered_at is not None or d.status in ['DELIVERED', 'READ', 'ACTIONED'])
    failed = sum(1 for d in deliveries if d.status == 'FAILED')
    read_count = sum(1 for d in deliveries if d.is_read or d.status in ['READ', 'ACTIONED'])
    unread_count = total_recipients - read_count

    sanitized_deliveries = []
    for d in deliveries:
        sanitized_deliveries.append({
            "id": d.id,
            "userId": d.user_id,
            "status": d.status,
            "isRead": d.is_read,
            "deliveredAt": d.delivered_at,
            "readAt": d.read_at,
            "actionAt": d.action_at,
            "pushAttempted": bool(d.push_attempted),
            "createdAt": d.created_at
        })

    return jsonify({
        "noticeId": notice.id,
        "title": notice.title,
        "status": notice.status,
        "metrics": {
            "recipients": total_recipients,
            "pushAttempts": push_attempts,
            "delivered": delivered,
            "failed": failed,
            "read": read_count,
            "unread": unread_count
        },
        "deliveries": sanitized_deliveries
    }), 200

