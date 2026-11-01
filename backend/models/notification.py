import uuid
import datetime
from extensions import db

class NotificationDelivery(db.Model):
    __tablename__ = 'notification_deliveries'
    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    notice_id = db.Column(db.String(36), db.ForeignKey('notices.id'), nullable=True, index=True)
    user_id = db.Column(db.String(36), db.ForeignKey('users.id'), nullable=False, index=True)
    title = db.Column(db.String(120), nullable=True, default='')
    body = db.Column(db.Text, nullable=True, default='')
    notification_type = db.Column(db.String(30), nullable=True, default='NOTICE')
    reference_id = db.Column(db.String(36), nullable=True)
    status = db.Column(db.String(20), default='PENDING')  # PENDING, DELIVERED, READ, ACTIONED, FAILED
    is_read = db.Column(db.Boolean, default=False)
    delivered_at = db.Column(db.String(50), nullable=True)
    read_at = db.Column(db.String(50), nullable=True)
    action_at = db.Column(db.String(50), nullable=True)
    push_attempted = db.Column(db.Boolean, default=False)
    push_error = db.Column(db.String(255), nullable=True)
    created_at = db.Column(db.String(50), default=lambda: datetime.datetime.now().isoformat())

    __table_args__ = (
        db.Index('idx_nd_notice_user', 'notice_id', 'user_id'),
    )

    def __init__(self, **kwargs):
        if 'status' not in kwargs:
            if kwargs.get('is_read'):
                kwargs['status'] = 'READ'
            elif kwargs.get('delivered_at'):
                kwargs['status'] = 'DELIVERED'
            else:
                kwargs['status'] = 'PENDING'
        if 'notification_type' not in kwargs and kwargs.get('notice_id'):
            kwargs['notification_type'] = 'NOTICE'
        if 'reference_id' not in kwargs and kwargs.get('notice_id'):
            kwargs['reference_id'] = kwargs['notice_id']
        if 'push_attempted' not in kwargs:
            kwargs['push_attempted'] = False
        if 'push_error' not in kwargs:
            kwargs['push_error'] = None
        super().__init__(**kwargs)

    def to_dict(self):
        return {
            "id": self.id,
            "noticeId": self.notice_id,
            "userId": self.user_id,
            "title": self.title or "",
            "body": self.body or "",
            "notificationType": self.notification_type or "NOTICE",
            "referenceId": self.reference_id,
            "status": self.status or ("READ" if self.is_read else "PENDING"),
            "isRead": self.is_read,
            "deliveredAt": self.delivered_at,
            "readAt": self.read_at,
            "actionAt": self.action_at,
            "pushAttempted": bool(self.push_attempted),
            "pushError": self.push_error,
            "createdAt": self.created_at
        }

class DeviceToken(db.Model):
    __tablename__ = 'device_tokens'
    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = db.Column(db.String(36), db.ForeignKey('users.id'), nullable=False, index=True)
    token = db.Column(db.String(255), unique=True, nullable=False, index=True)
    device_type = db.Column(db.String(50), nullable=True, default='android')
    device_id = db.Column(db.String(100), nullable=True)
    is_active = db.Column(db.Boolean, default=True, nullable=False)
    created_at = db.Column(db.String(50), default=lambda: datetime.datetime.now().isoformat())
    updated_at = db.Column(db.String(50), default=lambda: datetime.datetime.now().isoformat())

    def to_dict(self):
        return {
            "id": self.id,
            "userId": self.user_id,
            "token": self.token,
            "deviceType": self.device_type or "android",
            "deviceId": self.device_id,
            "isActive": self.is_active,
            "createdAt": self.created_at,
            "updatedAt": self.updated_at
        }
