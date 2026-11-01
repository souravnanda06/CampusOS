import uuid
import datetime
from extensions import db

class Notice(db.Model):
    __tablename__ = 'notices'
    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    title = db.Column(db.String(150), nullable=False)
    content = db.Column(db.Text, nullable=True)
    body = db.Column(db.Text, nullable=True)
    created_by = db.Column(db.String(36), db.ForeignKey('users.id'), nullable=True)
    published_by = db.Column(db.String(36), db.ForeignKey('users.id'), nullable=True)
    priority = db.Column(db.String(20), default='NORMAL')  # NORMAL, HIGH, URGENT
    category = db.Column(db.String(50), default='GENERAL')  # GENERAL, ACADEMIC, EXAM, HOSTEL, MESS, SECURITY, EVENT, FEE, OTHER
    target_type = db.Column(db.String(30), default='ALL')  # ALL, BRANCH, YEAR, HOSTEL, STUDENT
    target_value = db.Column(db.String(100), nullable=True)
    target_role = db.Column(db.String(20), default='all')
    target_course = db.Column(db.String(50), nullable=True)
    target_branch = db.Column(db.String(50), nullable=True)
    target_year = db.Column(db.String(20), nullable=True)
    action_type = db.Column(db.String(50), nullable=True)
    action_payload = db.Column(db.Text, nullable=True)
    status = db.Column(db.String(20), default='PUBLISHED')  # DRAFT, PUBLISHED, ARCHIVED, EXPIRED
    expires_at = db.Column(db.String(50), nullable=True)
    created_at = db.Column(db.String(50), default=lambda: datetime.datetime.now().isoformat())

    __table_args__ = (
        db.Index('idx_notices_status_created', 'status', 'created_at'),
    )

    def __init__(self, **kwargs):
        # Synchronize body/content and created_by/published_by for compatibility
        if 'body' in kwargs and 'content' not in kwargs:
            kwargs['content'] = kwargs['body']
        elif 'content' in kwargs and 'body' not in kwargs:
            kwargs['body'] = kwargs['content']

        if 'created_by' in kwargs and 'published_by' not in kwargs:
            kwargs['published_by'] = kwargs['created_by']
        elif 'published_by' in kwargs and 'created_by' not in kwargs:
            kwargs['created_by'] = kwargs['published_by']

        super().__init__(**kwargs)

    def to_dict(self):
        return {
            "id": self.id,
            "title": self.title,
            "body": self.body or self.content or "",
            "content": self.content or self.body or "",
            "createdBy": self.created_by or self.published_by,
            "publishedBy": self.published_by or self.created_by,
            "priority": self.priority or "NORMAL",
            "category": self.category or "GENERAL",
            "targetType": self.target_type or "ALL",
            "targetValue": self.target_value,
            "targetRole": self.target_role,
            "targetCourse": self.target_course,
            "targetBranch": self.target_branch,
            "targetYear": self.target_year,
            "actionType": self.action_type,
            "actionPayload": self.action_payload,
            "status": self.status or "PUBLISHED",
            "expiresAt": self.expires_at,
            "createdAt": self.created_at
        }
