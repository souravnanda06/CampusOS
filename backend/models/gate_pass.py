import uuid
import datetime
from extensions import db

class GatePass(db.Model):
    __tablename__ = 'gate_passes'
    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    student_id = db.Column(db.String(36), db.ForeignKey('users.id'), nullable=False, index=True)
    leave_request_id = db.Column(db.String(36), db.ForeignKey('leave_requests.id'), nullable=True)
    destination = db.Column(db.String(150), nullable=False)
    reason = db.Column(db.Text, nullable=False)
    expected_exit_time = db.Column(db.String(50), nullable=False)
    expected_return_time = db.Column(db.String(50), nullable=False)
    actual_exit_time = db.Column(db.String(50), nullable=True)
    actual_return_time = db.Column(db.String(50), nullable=True)
    status = db.Column(db.String(25), nullable=False, default='PENDING')  # PENDING, APPROVED, ISSUED, EXITED, RETURNED, EXPIRED, REJECTED
    qr_nonce = db.Column(db.String(64), unique=True, nullable=False, default=lambda: str(uuid.uuid4()))
    security_guard_id = db.Column(db.String(36), db.ForeignKey('users.id'), nullable=True)
    gate_name = db.Column(db.String(50), nullable=True, default='Main Gate')
    verification_mode = db.Column(db.String(25), nullable=True, default='QR_FALLBACK') # BLE, QR_FALLBACK
    idempotency_key = db.Column(db.String(100), nullable=True, index=True)
    created_at = db.Column(db.String(50), default=lambda: datetime.datetime.now().isoformat())

    __table_args__ = (
        db.Index('idx_gp_student_status', 'student_id', 'status'),
    )

    def to_dict(self):
        return {
            "id": self.id,
            "studentId": self.student_id,
            "leaveRequestId": self.leave_request_id,
            "destination": self.destination,
            "reason": self.reason,
            "expectedExitTime": self.expected_exit_time,
            "expectedReturnTime": self.expected_return_time,
            "actualExitTime": self.actual_exit_time,
            "actualReturnTime": self.actual_return_time,
            "status": self.status,
            "qrNonce": self.qr_nonce,
            "securityGuardId": self.security_guard_id,
            "gateName": self.gate_name or 'Main Gate',
            "verificationMode": self.verification_mode or 'QR_FALLBACK',
            "idempotencyKey": self.idempotency_key,
            "createdAt": self.created_at
        }
