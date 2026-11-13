import uuid
import datetime
from extensions import db

class User(db.Model):
    __tablename__ = 'users'
    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    email = db.Column(db.String(120), unique=True, nullable=False)
    password = db.Column(db.String(120), nullable=False)
    name = db.Column(db.String(100), nullable=False)
    role = db.Column(db.String(20), nullable=False)
    registration_number = db.Column(db.String(20))
    course = db.Column(db.String(50))
    branch = db.Column(db.String(50))
    year = db.Column(db.String(20))
    phone = db.Column(db.String(20), nullable=True)
    parent_phone = db.Column(db.String(20), nullable=True)
    parent_name = db.Column(db.String(100), nullable=True)
    device_id = db.Column(db.String(100))
    face_enrolled = db.Column(db.Boolean, default=False)
    face_enrolled_at = db.Column(db.String(50), nullable=True)
    face_embedding_hash = db.Column(db.String(128), nullable=True)
    face_embedding = db.Column(db.Text, nullable=True)
    approval_status = db.Column(db.String(20), nullable=False, default='APPROVED')
    approved_by = db.Column(db.String(36), nullable=True)
    approved_at = db.Column(db.String(50), nullable=True)
    rejection_reason = db.Column(db.String(255), nullable=True)
    photo_url = db.Column(db.Text, nullable=True)
    created_at = db.Column(db.String(50), default=lambda: datetime.datetime.now().isoformat())

    def to_dict(self):
        return {
            "id": self.id,
            "email": self.email,
            "name": self.name,
            "role": self.role,
            "registrationNumber": self.registration_number,
            "course": self.course,
            "branch": self.branch,
            "year": self.year,
            "phone": self.phone,
            "parentPhone": self.parent_phone,
            "parentName": self.parent_name,
            "deviceId": self.device_id,
            "faceEnrolled": bool(self.face_enrolled),
            "faceEnrolledAt": self.face_enrolled_at,
            "approvalStatus": self.approval_status or "APPROVED",
            "approvedBy": self.approved_by,
            "approvedAt": self.approved_at,
            "rejectionReason": self.rejection_reason,
            "photoUrl": self.photo_url,
            "createdAt": self.created_at,
        }
