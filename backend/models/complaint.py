import uuid
import datetime
import random
from extensions import db

def generate_closure_pin():
    """Generates a secure 4-digit student verification PIN for proof-of-fix closure."""
    return f"{random.randint(1000, 9999)}"

class Complaint(db.Model):
    __tablename__ = 'complaints'
    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    student_id = db.Column(db.String(36), db.ForeignKey('users.id'), nullable=False, index=True)
    category = db.Column(db.String(40), nullable=False)
    title = db.Column(db.String(150), nullable=False)
    description = db.Column(db.Text, nullable=False)
    location = db.Column(db.String(100), nullable=False)
    priority = db.Column(db.String(15), default='MEDIUM')
    status = db.Column(db.String(25), default='PENDING')  # PENDING, ASSIGNED, IN_PROGRESS, RESOLVED, CLOSED, REOPENED, REJECTED
    is_repeat = db.Column(db.Boolean, default=False)
    assigned_to = db.Column(db.String(36), db.ForeignKey('users.id'), nullable=True)
    resolution_notes = db.Column(db.Text, nullable=True)
    resolved_at = db.Column(db.String(50), nullable=True)
    idempotency_key = db.Column(db.String(100), nullable=True, unique=True, index=True)
    created_at = db.Column(db.String(50), default=lambda: datetime.datetime.now().isoformat())
    updated_at = db.Column(db.String(50), default=lambda: datetime.datetime.now().isoformat(), onupdate=lambda: datetime.datetime.now().isoformat())

    # --- FEATURE 2: PROOF-OF-FIX & ESCALATION SLINGSHOT ---
    closure_otp = db.Column(db.String(6), nullable=True, default=generate_closure_pin)
    otp_verified_at = db.Column(db.String(50), nullable=True)
    escalation_level = db.Column(db.Integer, default=1, nullable=False)  # 1: Normal, 2: Warden Alert (>24h), 3: Dean Slingshot (>48h)
    escalated_at = db.Column(db.String(50), nullable=True)
    vendor_penalty_flag = db.Column(db.Boolean, default=False)
    vendor_penalty_amount = db.Column(db.Float, default=0.0)
    student_rating = db.Column(db.Integer, nullable=True)  # 1 to 5 stars
    student_feedback = db.Column(db.Text, nullable=True)

    __table_args__ = (
        db.Index('idx_complaints_status_created', 'status', 'created_at'),
        db.Index('idx_complaints_category_location', 'category', 'location'),
        db.Index('idx_complaints_escalation', 'escalation_level', 'status'),
    )

    def to_dict(self, requester_role=None, requester_id=None):
        if not self.closure_otp:
            self.closure_otp = generate_closure_pin()

        # Student owner, admin/dean, or post-resolved tickets can view the closureOtp.
        # Active caretakers/staff cannot see closureOtp; they must get it from the student in person.
        can_view_otp = (
            requester_id == self.student_id or
            requester_role in ['admin', 'dean'] or
            self.status in ['RESOLVED', 'CLOSED'] or
            (requester_role is None and requester_id is None) # Backwards compatibility
        )
        return {
            "id": self.id,
            "studentId": self.student_id,
            "category": self.category,
            "title": self.title,
            "description": self.description,
            "location": self.location,
            "priority": self.priority,
            "status": self.status,
            "isRepeat": self.is_repeat,
            "assignedTo": self.assigned_to,
            "resolutionNotes": self.resolution_notes,
            "resolutionRemarks": self.resolution_notes,
            "resolvedAt": self.resolved_at,
            "createdAt": self.created_at,
            "updatedAt": self.updated_at,
            "idempotencyKey": self.idempotency_key,
            "closureOtp": self.closure_otp if can_view_otp else None,
            "hasClosureOtp": bool(self.closure_otp),
            "otpVerifiedAt": self.otp_verified_at,
            "escalationLevel": self.escalation_level or 1,
            "escalatedAt": self.escalated_at,
            "vendorPenaltyFlag": bool(self.vendor_penalty_flag),
            "vendorPenaltyAmount": self.vendor_penalty_amount or 0.0,
            "studentRating": self.student_rating,
            "studentFeedback": self.student_feedback
        }
