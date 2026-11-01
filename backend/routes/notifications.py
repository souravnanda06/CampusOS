import datetime
from flask import Blueprint, request, jsonify
from extensions import db
from models.user import User
from models.notification import NotificationDelivery, DeviceToken
from middleware.auth import get_authenticated_requester

notifications_bp = Blueprint('notifications_bp', __name__)

@notifications_bp.route('/notifications', methods=['GET'])
def get_user_notifications():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required"}), 401

    unread_only = request.args.get('unread') == 'true'
    query = NotificationDelivery.query.filter_by(user_id=requester.id)

    if unread_only:
        query = query.filter_by(is_read=False)

    notifications = query.order_by(NotificationDelivery.created_at.desc()).limit(50).all()
    unread_count = NotificationDelivery.query.filter_by(user_id=requester.id, is_read=False).count()

    results = []
    for n in notifications:
        d = n.to_dict()
        # Add deep-link route hint
        notif_type = (n.notification_type or 'NOTICE').upper()
        if notif_type == 'DOCUMENT':
            d['deepLinkRoute'] = '/student/requests/documents'
            d['actionLabel'] = 'View Document'
        elif notif_type == 'CLASS_UPDATE':
            d['deepLinkRoute'] = '/student/classes'
            d['actionLabel'] = 'View Class Update'
        elif notif_type == 'FEE':
            d['deepLinkRoute'] = '/student/wallet'
            d['actionLabel'] = 'View Fees & Dues'
        elif notif_type == 'VISITOR':
            d['deepLinkRoute'] = '/student/wallet'
            d['actionLabel'] = 'View Visitor Pass'
        elif notif_type == 'HOSTEL':
            d['deepLinkRoute'] = '/student/requests/hostel'
            d['actionLabel'] = 'View Hostel Request'
        elif notif_type == 'COMPLAINT':
            d['deepLinkRoute'] = '/student/requests/complaints'
            d['actionLabel'] = 'View Complaint'
        elif notif_type == 'GATE_PASS':
            d['deepLinkRoute'] = '/student/wallet'
            d['actionLabel'] = 'View Gate Pass'
        else:
            d['deepLinkRoute'] = '/student/notices'
            d['actionLabel'] = 'View Notice'
        results.append(d)

    return jsonify({
        "notifications": results,
        "unreadCount": unread_count
    }), 200

@notifications_bp.route('/notifications/unread-count', methods=['GET'])
def get_unread_count():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required"}), 401

    unread_count = NotificationDelivery.query.filter_by(user_id=requester.id, is_read=False).count()
    return jsonify({
        "unreadCount": unread_count,
        "userId": requester.id
    }), 200

@notifications_bp.route('/notifications/<id>/read', methods=['POST'])
def mark_notification_read(id):
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required"}), 401

    notif = NotificationDelivery.query.get(id)
    if not notif:
        return jsonify({"message": "Notification not found"}), 404

    if notif.user_id != requester.id and requester.role != 'admin':
        return jsonify({"message": "Forbidden: Cannot alter another user's notification"}), 403

    now_iso = datetime.datetime.now().isoformat()
    notif.is_read = True
    notif.read_at = now_iso
    if notif.status != 'ACTIONED':
        notif.status = 'READ'
    db.session.commit()

    return jsonify({
        "message": "Notification marked as read",
        "notification": notif.to_dict()
    }), 200

@notifications_bp.route('/notifications/read-all', methods=['POST'])
def mark_all_notifications_read():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required"}), 401

    now_iso = datetime.datetime.now().isoformat()
    updated_count = NotificationDelivery.query.filter_by(
        user_id=requester.id,
        is_read=False
    ).update({
        'is_read': True,
        'read_at': now_iso,
        'status': 'READ'
    }, synchronize_session=False)
    db.session.commit()

    return jsonify({
        "message": f"Marked {updated_count} notifications as read",
        "readCount": updated_count
    }), 200

@notifications_bp.route('/notifications/<id>/action', methods=['POST'])
def action_notification(id):
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required"}), 401

    notif = NotificationDelivery.query.get(id)
    if not notif:
        return jsonify({"message": "Notification not found"}), 404

    now_iso = datetime.datetime.now().isoformat()
    notif.is_read = True
    notif.status = 'ACTIONED'
    notif.action_at = now_iso
    db.session.commit()

    return jsonify({
        "message": "Notification marked as actioned",
        "notification": notif.to_dict()
    }), 200

@notifications_bp.route('/notifications/admin/analytics', methods=['GET'])
def get_notification_analytics():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester or requester.role not in ['admin', 'staff']:
        return jsonify({"message": "Forbidden: Admin privileges required"}), 403

    all_deliveries = NotificationDelivery.query.all()
    total = len(all_deliveries)
    delivered = sum(1 for d in all_deliveries if d.delivered_at is not None or d.status in ['DELIVERED', 'READ', 'ACTIONED'])
    read_count = sum(1 for d in all_deliveries if d.is_read or d.status in ['READ', 'ACTIONED'])
    actioned_count = sum(1 for d in all_deliveries if d.status == 'ACTIONED')
    failed_count = sum(1 for d in all_deliveries if d.status == 'FAILED')

    return jsonify({
        "totalDispatched": total,
        "deliveredCount": delivered,
        "deliveryRate": round((delivered / total * 100) if total > 0 else 0, 1),
        "readCount": read_count,
        "readRate": round((read_count / total * 100) if total > 0 else 0, 1),
        "actionedCount": actioned_count,
        "actionRate": round((actioned_count / total * 100) if total > 0 else 0, 1),
        "failedCount": failed_count,
        "registeredDevices": DeviceToken.query.filter_by(is_active=True).count()
    }), 200
