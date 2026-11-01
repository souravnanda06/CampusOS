import uuid
import datetime
from extensions import db

class Session(db.Model):
    __tablename__ = 'sessions'
    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    name = db.Column(db.String(100), nullable=False)
    subject = db.Column(db.String(100))
    instructor_name = db.Column(db.String(100), nullable=False)
    course = db.Column(db.String(50))
    branch = db.Column(db.String(50))
    year = db.Column(db.String(20))
    start_time = db.Column(db.String(50), nullable=False)
    end_time = db.Column(db.String(50), nullable=False)
    location = db.Column(db.String(100), nullable=False)
    is_active = db.Column(db.Boolean, default=True)
    attendance_count = db.Column(db.Integer, default=0)
    tx_power_level = db.Column(db.Integer, default=3)
    session_nonce = db.Column(db.String(64), nullable=True)
    teacher_key_id = db.Column(db.String(64), nullable=True)
    teacher_id = db.Column(db.String(36), nullable=True)
    idempotency_key = db.Column(db.String(128), unique=True, nullable=True, index=True)

    __table_args__ = (
        db.Index('idx_sessions_active_start', 'is_active', 'start_time'),
        db.Index('idx_sessions_course_branch_year', 'course', 'branch', 'year'),
    )

    def to_dict(self):
        return {
            "id": self.id,
            "name": self.name,
            "subject": self.subject,
            "instructorName": self.instructor_name,
            "course": self.course,
            "branch": self.branch,
            "year": self.year,
            "startTime": self.start_time,
            "endTime": self.end_time,
            "location": self.location,
            "isActive": self.is_active,
            "attendanceCount": self.attendance_count,
            "txPowerLevel": self.tx_power_level,
            "sessionNonce": self.session_nonce,
            "teacherKeyId": self.teacher_key_id,
            "teacherId": self.teacher_id,
            "idempotencyKey": self.idempotency_key
        }

class Attendance(db.Model):
    __tablename__ = 'attendance'
    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    session_id = db.Column(db.String(36), nullable=False, index=True)
    user_id = db.Column(db.String(36), nullable=False, index=True)
    student_name = db.Column(db.String(100), nullable=False)
    check_in_time = db.Column(db.String(50), default=lambda: datetime.datetime.now().isoformat())
    status = db.Column(db.String(20), default='present')
    coupon_earned = db.Column(db.Boolean, default=False)
    idempotency_key = db.Column(db.String(128), unique=True, nullable=True, index=True)
    device_key_id = db.Column(db.String(64), nullable=True)
    response_nonce = db.Column(db.String(64), nullable=True)
    verification_mode = db.Column(db.String(32), default='LEGACY')
    proximity_tier = db.Column(db.String(32), nullable=True)

    __table_args__ = (
        db.UniqueConstraint('session_id', 'user_id', name='uq_attendance_session_user'),
        db.Index('idx_attendance_session_user', 'session_id', 'user_id'),
    )

    def to_dict(self):
        session = Session.query.get(self.session_id)
        session_name = session.name if session else "Unknown Session"
        location = session.location if session and session.location else ""
        return {
            "id": self.id,
            "sessionId": self.session_id,
            "sessionName": session_name,
            "userId": self.user_id,
            "studentName": self.student_name,
            "checkInTime": self.check_in_time,
            "status": self.status,
            "couponEarned": self.coupon_earned,
            "location": location,
            "idempotencyKey": self.idempotency_key,
            "deviceKeyId": self.device_key_id,
            "responseNonce": self.response_nonce,
            "verificationMode": self.verification_mode,
            "proximityTier": self.proximity_tier
        }

class Coupon(db.Model):
    __tablename__ = 'coupons'
    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = db.Column(db.String(36), nullable=False)
    code = db.Column(db.String(20), nullable=False)
    description = db.Column(db.String(200), nullable=False)
    earned_date = db.Column(db.String(50), default=lambda: datetime.datetime.now().isoformat())
    expiry_date = db.Column(db.String(50), nullable=False)
    is_used = db.Column(db.Boolean, default=False)

    def to_dict(self):
        return {
            "id": self.id,
            "userId": self.user_id,
            "code": self.code,
            "description": self.description,
            "earnedDate": self.earned_date,
            "expiryDate": self.expiry_date,
            "isUsed": self.is_used
        }

class SavedClass(db.Model):
    __tablename__ = 'saved_classes'
    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = db.Column(db.String(36), nullable=False)
    course = db.Column(db.String(50))
    branch = db.Column(db.String(50))
    year = db.Column(db.String(20))
    subject = db.Column(db.String(100), nullable=False)
    last_used = db.Column(db.DateTime, default=datetime.datetime.utcnow)

    def to_dict(self):
        return {
            "id": self.id,
            "course": self.course,
            "branch": self.branch,
            "year": self.year,
            "subject": self.subject
        }
