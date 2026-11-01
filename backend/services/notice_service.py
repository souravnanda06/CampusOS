import datetime
from sqlalchemy import func
from extensions import db, FIREBASE_AVAILABLE, send_fcm_message

# pyrefly: ignore [missing-import]
if FIREBASE_AVAILABLE:
    from firebase_admin import messaging

from models.user import User
from models.notice import Notice
from models.notification import NotificationDelivery, DeviceToken

SUPPORTED_NOTICE_PRIORITIES = {'NORMAL', 'HIGH', 'URGENT'}
SUPPORTED_NOTICE_CATEGORIES = {
    'GENERAL', 'ACADEMIC', 'EXAM', 'HOSTEL', 'MESS', 'SECURITY', 'EVENT', 'FEE', 'OTHER'
}
SUPPORTED_NOTICE_TARGET_TYPES = {'ALL', 'BRANCH', 'YEAR', 'HOSTEL', 'STUDENT'}
SUPPORTED_NOTICE_STATUSES = {'DRAFT', 'PUBLISHED', 'ARCHIVED', 'EXPIRED'}

def resolve_notice_recipients(notice):
    target_type = (notice.target_type or 'ALL').upper()
    target_value = (notice.target_value or '').strip()

    if target_type == 'HOSTEL':
        raise ValueError("Hostel targeting is not currently supported: student hostel metadata is not configured in the system")

    query = User.query

    # Campus notices target students
    if notice.target_role and notice.target_role.lower() != 'all':
        query = query.filter(User.role == notice.target_role.lower())
    else:
        query = query.filter(User.role == 'student')

    if target_type == 'ALL':
        recipients = query.order_by(User.id.asc()).all()
    elif target_type == 'BRANCH':
        if not target_value:
            return []
        recipients = query.filter(func.lower(User.branch) == target_value.lower()).order_by(User.id.asc()).all()
    elif target_type == 'YEAR':
        if not target_value:
            return []
        recipients = query.filter(func.lower(User.year) == target_value.lower()).order_by(User.id.asc()).all()
    elif target_type == 'STUDENT':
        if not target_value:
            return []
        recipients = query.filter(
            (User.id == target_value) | (func.lower(User.registration_number) == target_value.lower())
        ).order_by(User.id.asc()).all()
    else:
        raise ValueError(f"Invalid target_type: {target_type}. Supported types: {list(SUPPORTED_NOTICE_TARGET_TYPES)}")

    # Deduplicate deterministically by user.id
    seen_ids = set()
    unique_recipients = []
    for u in recipients:
        if u.id not in seen_ids:
            seen_ids.add(u.id)
            unique_recipients.append(u)
    return unique_recipients

def is_notice_targeted_to_student(notice, student, delivery_lookup=None):
    if not student or student.role != 'student':
        return False

    # Check if an existing delivery record is already attached to this student
    if delivery_lookup is not None:
        delivery = delivery_lookup.get(notice.id)
    else:
        delivery = NotificationDelivery.query.filter_by(notice_id=notice.id, user_id=student.id).first()

    if delivery:
        return True

    target_type = (notice.target_type or 'ALL').upper()
    target_value = (notice.target_value or '').strip()

    if notice.target_role and notice.target_role.lower() not in ['all', 'student']:
        return False

    if target_type == 'ALL':
        return True
    elif target_type == 'BRANCH':
        if not target_value or not student.branch:
            return False
        return student.branch.strip().lower() == target_value.lower()
    elif target_type == 'YEAR':
        if not target_value or not student.year:
            return False
        return student.year.strip().lower() == target_value.lower()
    elif target_type == 'STUDENT':
        if not target_value:
            return False
        return (student.id == target_value) or (
            student.registration_number and student.registration_number.strip().lower() == target_value.lower()
        )
    elif target_type == 'HOSTEL':
        return False
    return False

def dispatch_notice_push_notifications(notice, deliveries=None):
    """
    Dispatches FCM push notifications for a published notice to targeted recipients.
    Records delivery attempts, updates status (DELIVERED/FAILED), preserves READ/ACTIONED,
    and handles invalid tokens without crashing notice publishing.
    """
    if not notice or (notice.status or '').upper() != 'PUBLISHED':
        return 0

    if deliveries is None:
        deliveries = NotificationDelivery.query.filter_by(notice_id=notice.id).all()

    now_iso = datetime.datetime.now().isoformat()
    dispatched_count = 0

    # Build structured data payload (no sensitive personal info)
    data_payload = {
        "noticeId": str(notice.id),
        "notificationType": "NOTICE",
        "actionType": str(notice.action_type or "NONE"),
        "actionPayload": str(notice.action_payload or ""),
        "priority": str(notice.priority or "NORMAL"),
        "title": str(notice.title or ""),
        "body": str(notice.body or notice.content or "")[:200]
    }

    title = str(notice.title or "CampusOS Notice")
    body_text = str(notice.body or notice.content or "")[:200]

    for delivery in deliveries:
        # Do not overwrite if already opened (READ) or ACTIONED
        if delivery.status in ['READ', 'ACTIONED']:
            continue

        # Look up active device tokens for this recipient
        user_tokens = DeviceToken.query.filter_by(
            user_id=delivery.user_id,
            is_active=True
        ).all()

        if not user_tokens:
            # No device registered yet; notice remains in in-app feed as PENDING
            delivery.push_attempted = False
            continue

        delivery.push_attempted = True
        success_tokens = 0
        fail_tokens = 0
        last_error = None

        for dt in user_tokens:
            try:
                # Build FCM Message
                if FIREBASE_AVAILABLE:
                    android_cfg = messaging.AndroidConfig(
                        priority='high' if notice.priority in ['HIGH', 'URGENT'] else 'normal',
                        notification=messaging.AndroidNotification(
                            channel_id='campusos_notices',
                            priority='max' if notice.priority in ['HIGH', 'URGENT'] else 'default',
                        )
                    )
                    fcm_msg = messaging.Message(
                        notification=messaging.Notification(
                            title=title,
                            body=body_text
                        ),
                        data=data_payload,
                        token=dt.token,
                        android=android_cfg
                    )
                else:
                    fcm_msg = {
                        "token": dt.token,
                        "data": data_payload,
                        "notification": {"title": title, "body": body_text}
                    }

                # Send via helper (supports mock override in tests)
                send_fcm_message(fcm_msg)
                success_tokens += 1

            except Exception as e:
                err_str = str(e)
                last_error = err_str
                fail_tokens += 1

                # Clean up / deactivate invalid or stale tokens safely
                lower_err = err_str.lower()
                if any(x in lower_err for x in [
                    'not-registered', 'unregistered', 'invalid registration',
                    'registration-token-not-registered', 'invalid-argument', 'not_found'
                ]):
                    dt.is_active = False

        if success_tokens > 0:
            if delivery.status == 'PENDING':
                delivery.status = 'DELIVERED'
                delivery.delivered_at = now_iso
            delivery.push_error = None
            dispatched_count += 1
        elif fail_tokens > 0:
            if delivery.status == 'PENDING':
                delivery.status = 'FAILED'
            delivery.push_error = (last_error or 'Push delivery failed')[:255]

    try:
        db.session.commit()
    except Exception:
        db.session.rollback()

    return dispatched_count

def sync_notice_deliveries(notice):
    if (notice.status or '').upper() != 'PUBLISHED':
        return 0

    try:
        recipients = resolve_notice_recipients(notice)
    except ValueError:
        return 0

    existing_deliveries = NotificationDelivery.query.filter_by(notice_id=notice.id).all()
    existing_user_ids = {d.user_id for d in existing_deliveries}

    now_iso = datetime.datetime.now().isoformat()
    new_deliveries = []

    for recipient in recipients:
        if recipient.id not in existing_user_ids:
            delivery = NotificationDelivery(
                notice_id=notice.id,
                user_id=recipient.id,
                title=notice.title,
                body=notice.body or notice.content or "",
                notification_type='NOTICE',
                reference_id=notice.id,
                status='PENDING',
                delivered_at=None,
                read_at=None,
                action_at=None,
                push_attempted=False,
                push_error=None,
                created_at=now_iso
            )
            db.session.add(delivery)
            existing_user_ids.add(recipient.id)
            new_deliveries.append(delivery)

    if new_deliveries:
        db.session.commit()

    # Now dispatch push notifications for new deliveries
    try:
        dispatch_notice_push_notifications(notice, new_deliveries)
    except Exception as push_err:
        print(f"[WARN] Push notification dispatch error (non-fatal): {push_err}")

    return len(new_deliveries)

def is_notice_expired(notice, now_iso=None):
    if (notice.status or '').upper() == 'EXPIRED':
        return True
    if notice.expires_at:
        if now_iso is None:
            now_iso = datetime.datetime.now().isoformat()
        if notice.expires_at < now_iso:
            return True
    return False
