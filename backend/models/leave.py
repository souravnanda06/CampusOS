import uuid
import datetime
from extensions import db

class LeaveRequest(db.Model):
    __tablename__ = 'leave_requests'
    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    student_id = db.Column(db.String(36), db.ForeignKey('users.id'), nullable=False, index=True)
    leave_type = db.Column(db.String(30), nullable=False)
    start_date = db.Column(db.String(50), nullable=False)
    end_date = db.Column(db.String(50), nullable=False)
    reason = db.Column(db.Text, nullable=False)
    destination = db.Column(db.String(150), nullable=True)
    parent_consent = db.Column(db.String(20), nullable=False, default='GRANTED') # PENDING, GRANTED, NOT_REQUIRED, DENIED
    parent_consent_at = db.Column(db.String(50), nullable=True)
    status = db.Column(db.String(20), nullable=False, default='PENDING')  # PENDING, APPROVED, REJECTED, CANCELLED
    reviewed_by = db.Column(db.String(36), db.ForeignKey('users.id'), nullable=True)
    review_remarks = db.Column(db.String(255), nullable=True)
    created_at = db.Column(db.String(50), default=lambda: datetime.datetime.now().isoformat())
    updated_at = db.Column(db.String(50), default=lambda: datetime.datetime.now().isoformat(), onupdate=lambda: datetime.datetime.now().isoformat())

    def to_dict(self):
        return {
            "id": self.id,
            "studentId": self.student_id,
            "leaveType": self.leave_type,
            "startDate": self.start_date,
            "endDate": self.end_date,
            "reason": self.reason,
            "destination": self.destination,
            "parentConsent": self.parent_consent,
            "parentConsentAt": self.parent_consent_at,
            "status": self.status,
            "reviewedBy": self.reviewed_by,
            "reviewRemarks": self.review_remarks,
            "createdAt": self.created_at,
            "updatedAt": self.updated_at
        }
