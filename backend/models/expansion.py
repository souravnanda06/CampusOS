import uuid
import datetime
from extensions import db

# Supported Document Types
SUPPORTED_DOCUMENT_TYPES = {
    'BONAFIDE_CERTIFICATE': 'Bonafide Certificate',
    'INTERNSHIP_NOC': 'Internship NOC',
    'PROVISIONAL_CERTIFICATE': 'Provisional Degree Certificate',
    'COURSE_COMPLETION': 'Course Completion Certificate',
    'CONDUCT_CERTIFICATE': 'Character & Conduct Certificate',
    'FEE_RECEIPT_SUMMARY': 'Consolidated Fee Receipt',
    'HOSTEL_RESIDENCE_CERTIFICATE': 'Hostel Residence Certificate'
}

class DocumentRequest(db.Model):
    __tablename__ = 'document_requests'

    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    student_id = db.Column(db.String(36), db.ForeignKey('users.id'), nullable=False, index=True)
    document_type = db.Column(db.String(60), nullable=False)
    purpose = db.Column(db.Text, nullable=False)
    status = db.Column(db.String(20), default='PENDING')  # PENDING, APPROVED, REJECTED, ISSUED
    admin_notes = db.Column(db.Text, nullable=True)
    approved_by = db.Column(db.String(36), db.ForeignKey('users.id'), nullable=True)
    document_number = db.Column(db.String(60), unique=True, nullable=True)
    file_url = db.Column(db.String(255), nullable=True)
    document_data_json = db.Column(db.Text, nullable=True)
    issued_at = db.Column(db.String(50), nullable=True)
    expires_at = db.Column(db.String(50), nullable=True)
    stored_in_wallet = db.Column(db.Boolean, default=False)
    wallet_added_at = db.Column(db.String(50), nullable=True)
    created_at = db.Column(db.String(50), default=lambda: datetime.datetime.now().isoformat())
    updated_at = db.Column(db.String(50), default=lambda: datetime.datetime.now().isoformat(), onupdate=lambda: datetime.datetime.now().isoformat())

    __table_args__ = (
        db.Index('idx_doc_student_status', 'student_id', 'status'),
        db.Index('idx_doc_type', 'document_type'),
    )

    def __init__(self, **kwargs):
        if 'id' not in kwargs or not kwargs['id']:
            kwargs['id'] = str(uuid.uuid4())
        super().__init__(**kwargs)

    def to_dict(self):
        return {
            "id": self.id,
            "studentId": self.student_id,
            "documentType": self.document_type,
            "documentTypeName": SUPPORTED_DOCUMENT_TYPES.get(self.document_type, self.document_type),
            "purpose": self.purpose,
            "status": self.status,
            "adminNotes": self.admin_notes,
            "approvedBy": self.approved_by,
            "documentNumber": self.document_number,
            "fileUrl": self.file_url,
            "documentDataJson": self.document_data_json,
            "issuedAt": self.issued_at,
            "expiresAt": self.expires_at,
            "storedInWallet": bool(self.stored_in_wallet),
            "walletAddedAt": self.wallet_added_at,
            "createdAt": self.created_at,
            "updatedAt": self.updated_at
        }


class FeeRecord(db.Model):
    __tablename__ = 'fee_records'

    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    student_id = db.Column(db.String(36), db.ForeignKey('users.id'), nullable=False, index=True)
    title = db.Column(db.String(120), nullable=False)
    category = db.Column(db.String(50), default='TUITION')  # TUITION, HOSTEL, MESS, EXAMINATION, LIBRARY, OTHER
    amount = db.Column(db.Float, nullable=False)
    amount_paid = db.Column(db.Float, default=0.0)
    due_date = db.Column(db.String(50), nullable=False)
    status = db.Column(db.String(20), default='DUE')  # DUE, PAID, OVERDUE, PARTIALLY_PAID
    receipt_number = db.Column(db.String(60), nullable=True)
    paid_at = db.Column(db.String(50), nullable=True)
    breakdown_json = db.Column(db.Text, nullable=True)
    academic_year = db.Column(db.String(20), default='2025-2026')
    semester = db.Column(db.Integer, nullable=True)
    created_at = db.Column(db.String(50), default=lambda: datetime.datetime.now().isoformat())
    updated_at = db.Column(db.String(50), default=lambda: datetime.datetime.now().isoformat(), onupdate=lambda: datetime.datetime.now().isoformat())

    __table_args__ = (
        db.Index('idx_fee_student_status', 'student_id', 'status'),
        db.Index('idx_fee_due_date', 'due_date'),
    )

    def __init__(self, **kwargs):
        if 'id' not in kwargs or not kwargs['id']:
            kwargs['id'] = str(uuid.uuid4())
        super().__init__(**kwargs)

    def to_dict(self):
        return {
            "id": self.id,
            "studentId": self.student_id,
            "title": self.title,
            "category": self.category,
            "amount": self.amount,
            "amountPaid": self.amount_paid,
            "balanceDue": max(0.0, self.amount - self.amount_paid),
            "dueDate": self.due_date,
            "status": self.status,
            "receiptNumber": self.receipt_number,
            "paidAt": self.paid_at,
            "breakdownJson": self.breakdown_json,
            "academicYear": self.academic_year,
            "semester": self.semester,
            "createdAt": self.created_at,
            "updatedAt": self.updated_at
        }


class ClassUpdate(db.Model):
    __tablename__ = 'class_updates'

    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    teacher_id = db.Column(db.String(36), db.ForeignKey('users.id'), nullable=False, index=True)
    course_code = db.Column(db.String(50), nullable=False)
    course_name = db.Column(db.String(120), nullable=False)
    update_type = db.Column(db.String(30), nullable=False)  # CANCELLED, RESCHEDULED, ROOM_CHANGE, TIME_CHANGE, ANNOUNCEMENT
    original_date = db.Column(db.String(50), nullable=False)
    original_time = db.Column(db.String(50), nullable=True)
    original_room = db.Column(db.String(50), nullable=True)
    new_date = db.Column(db.String(50), nullable=True)
    new_time = db.Column(db.String(50), nullable=True)
    new_room = db.Column(db.String(50), nullable=True)
    message = db.Column(db.Text, nullable=False)
    affected_branch = db.Column(db.String(50), nullable=True)  # 'CSE', 'ALL', etc.
    affected_year = db.Column(db.Integer, nullable=True)
    affected_section = db.Column(db.String(20), nullable=True)
    status = db.Column(db.String(20), default='ACTIVE')  # ACTIVE, EXPIRED, CANCELLED
    created_at = db.Column(db.String(50), default=lambda: datetime.datetime.now().isoformat())
    updated_at = db.Column(db.String(50), default=lambda: datetime.datetime.now().isoformat(), onupdate=lambda: datetime.datetime.now().isoformat())

    __table_args__ = (
        db.Index('idx_cu_teacher_status', 'teacher_id', 'status'),
        db.Index('idx_cu_branch_year', 'affected_branch', 'affected_year'),
        db.Index('idx_cu_date', 'original_date'),
    )

    def __init__(self, **kwargs):
        if 'id' not in kwargs or not kwargs['id']:
            kwargs['id'] = str(uuid.uuid4())
        super().__init__(**kwargs)

    def to_dict(self):
        return {
            "id": self.id,
            "teacherId": self.teacher_id,
            "courseCode": self.course_code,
            "courseName": self.course_name,
            "updateType": self.update_type,
            "originalDate": self.original_date,
            "originalTime": self.original_time,
            "originalRoom": self.original_room,
            "newDate": self.new_date,
            "newTime": self.new_time,
            "newRoom": self.new_room,
            "message": self.message,
            "affectedBranch": self.affected_branch,
            "affectedYear": self.affected_year,
            "affectedSection": self.affected_section,
            "status": self.status,
            "createdAt": self.created_at,
            "updatedAt": self.updated_at
        }


class HostelAllocation(db.Model):
    __tablename__ = 'hostel_allocations'

    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    student_id = db.Column(db.String(36), db.ForeignKey('users.id'), unique=True, nullable=False, index=True)
    hostel_name = db.Column(db.String(100), nullable=False)
    block = db.Column(db.String(20), nullable=True)
    room_number = db.Column(db.String(30), nullable=False)
    bed_number = db.Column(db.String(20), nullable=True)
    occupancy_type = db.Column(db.String(30), default='DOUBLE')  # SINGLE, DOUBLE, TRIPLE, DORM
    allocated_at = db.Column(db.String(50), default=lambda: datetime.datetime.now().isoformat())
    status = db.Column(db.String(20), default='ACTIVE')  # ACTIVE, VACATED, TRANSFERRED
    notes = db.Column(db.Text, nullable=True)

    __table_args__ = (
        db.Index('idx_ha_hostel_room', 'hostel_name', 'room_number'),
    )

    def __init__(self, **kwargs):
        if 'id' not in kwargs or not kwargs['id']:
            kwargs['id'] = str(uuid.uuid4())
        super().__init__(**kwargs)

    def to_dict(self):
        return {
            "id": self.id,
            "studentId": self.student_id,
            "hostelName": self.hostel_name,
            "block": self.block or "",
            "roomNumber": self.room_number,
            "bedNumber": self.bed_number or "",
            "occupancyType": self.occupancy_type,
            "allocatedAt": self.allocated_at,
            "status": self.status,
            "notes": self.notes or ""
        }


class HostelRequest(db.Model):
    __tablename__ = 'hostel_requests'

    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    student_id = db.Column(db.String(36), db.ForeignKey('users.id'), nullable=False, index=True)
    request_type = db.Column(db.String(40), nullable=False)  # ROOM_CHANGE, MAINTENANCE, HOSTEL_CHANGE, SPECIAL_ASSISTANCE
    preferred_hostel = db.Column(db.String(100), nullable=True)
    preferred_room = db.Column(db.String(30), nullable=True)
    reason = db.Column(db.Text, nullable=False)
    status = db.Column(db.String(20), default='PENDING')  # PENDING, UNDER_REVIEW, APPROVED, REJECTED, COMPLETED
    warden_id = db.Column(db.String(36), db.ForeignKey('users.id'), nullable=True)
    warden_remarks = db.Column(db.Text, nullable=True)
    created_at = db.Column(db.String(50), default=lambda: datetime.datetime.now().isoformat())
    updated_at = db.Column(db.String(50), default=lambda: datetime.datetime.now().isoformat(), onupdate=lambda: datetime.datetime.now().isoformat())

    __table_args__ = (
        db.Index('idx_hr_student_status', 'student_id', 'status'),
    )

    def __init__(self, **kwargs):
        if 'id' not in kwargs or not kwargs['id']:
            kwargs['id'] = str(uuid.uuid4())
        super().__init__(**kwargs)

    def to_dict(self):
        return {
            "id": self.id,
            "studentId": self.student_id,
            "requestType": self.request_type,
            "preferredHostel": self.preferred_hostel,
            "preferredRoom": self.preferred_room,
            "reason": self.reason,
            "status": self.status,
            "wardenId": self.warden_id,
            "wardenRemarks": self.warden_remarks,
            "createdAt": self.created_at,
            "updatedAt": self.updated_at
        }


class HostelAsset(db.Model):
    __tablename__ = 'hostel_assets'

    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    hostel_name = db.Column(db.String(100), nullable=False)
    room_number = db.Column(db.String(30), nullable=False)
    asset_code = db.Column(db.String(60), unique=True, nullable=False)
    asset_name = db.Column(db.String(100), nullable=False)
    condition = db.Column(db.String(30), default='GOOD')  # EXCELLENT, GOOD, FAIR, DAMAGED, UNDER_REPAIR
    assigned_student_id = db.Column(db.String(36), db.ForeignKey('users.id'), nullable=True, index=True)
    installed_date = db.Column(db.String(50), nullable=True)
    last_inspected_at = db.Column(db.String(50), nullable=True)

    __table_args__ = (
        db.Index('idx_h_assets_room', 'hostel_name', 'room_number'),
        db.Index('idx_h_assets_student', 'assigned_student_id'),
    )

    def __init__(self, **kwargs):
        if 'id' not in kwargs or not kwargs['id']:
            kwargs['id'] = str(uuid.uuid4())
        super().__init__(**kwargs)

    def to_dict(self):
        return {
            "id": self.id,
            "hostelName": self.hostel_name,
            "roomNumber": self.room_number,
            "assetCode": self.asset_code,
            "assetName": self.asset_name,
            "condition": self.condition,
            "assignedStudentId": self.assigned_student_id,
            "installedDate": self.installed_date,
            "lastInspectedAt": self.last_inspected_at
        }


class AssetIssue(db.Model):
    __tablename__ = 'asset_issues'

    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    asset_id = db.Column(db.String(36), db.ForeignKey('hostel_assets.id'), nullable=False, index=True)
    student_id = db.Column(db.String(36), db.ForeignKey('users.id'), nullable=False, index=True)
    issue_type = db.Column(db.String(40), nullable=False)  # DAMAGED, MISSING, REPAIR_NEEDED, REPLACEMENT_REQUESTED
    description = db.Column(db.Text, nullable=False)
    status = db.Column(db.String(20), default='REPORTED')  # REPORTED, ACKNOWLEDGED, IN_REPAIR, RESOLVED, CLOSED
    resolution_notes = db.Column(db.Text, nullable=True)
    reported_at = db.Column(db.String(50), default=lambda: datetime.datetime.now().isoformat())
    resolved_at = db.Column(db.String(50), nullable=True)

    __table_args__ = (
        db.Index('idx_ai_asset_student', 'asset_id', 'student_id'),
        db.Index('idx_ai_status', 'status'),
    )

    def __init__(self, **kwargs):
        if 'id' not in kwargs or not kwargs['id']:
            kwargs['id'] = str(uuid.uuid4())
        super().__init__(**kwargs)

    def to_dict(self):
        return {
            "id": self.id,
            "assetId": self.asset_id,
            "studentId": self.student_id,
            "issueType": self.issue_type,
            "description": self.description,
            "status": self.status,
            "resolutionNotes": self.resolution_notes,
            "reportedAt": self.reported_at,
            "resolvedAt": self.resolved_at
        }


class VisitorRequest(db.Model):
    __tablename__ = 'visitor_requests'

    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    student_id = db.Column(db.String(36), db.ForeignKey('users.id'), nullable=False, index=True)
    visitor_name = db.Column(db.String(100), nullable=False)
    visitor_phone = db.Column(db.String(20), nullable=False)
    relation = db.Column(db.String(50), nullable=False)
    purpose = db.Column(db.Text, nullable=False)
    visit_date = db.Column(db.String(50), nullable=False)
    expected_entry_time = db.Column(db.String(50), nullable=False)
    expected_exit_time = db.Column(db.String(50), nullable=False)
    status = db.Column(db.String(20), default='PENDING')  # PENDING, APPROVED, REJECTED, CHECKED_IN, CHECKED_OUT, EXPIRED
    approved_by = db.Column(db.String(36), db.ForeignKey('users.id'), nullable=True)
    pass_code = db.Column(db.String(64), unique=True, nullable=True)
    entry_guard_id = db.Column(db.String(36), db.ForeignKey('users.id'), nullable=True)
    entered_at = db.Column(db.String(50), nullable=True)
    exit_guard_id = db.Column(db.String(36), db.ForeignKey('users.id'), nullable=True)
    exited_at = db.Column(db.String(50), nullable=True)
    security_remarks = db.Column(db.Text, nullable=True)
    created_at = db.Column(db.String(50), default=lambda: datetime.datetime.now().isoformat())
    updated_at = db.Column(db.String(50), default=lambda: datetime.datetime.now().isoformat(), onupdate=lambda: datetime.datetime.now().isoformat())

    __table_args__ = (
        db.Index('idx_vr_student_status', 'student_id', 'status'),
        db.Index('idx_vr_date_status', 'visit_date', 'status'),
        db.Index('idx_vr_pass_code', 'pass_code'),
    )

    def __init__(self, **kwargs):
        if 'id' not in kwargs or not kwargs['id']:
            kwargs['id'] = str(uuid.uuid4())
        super().__init__(**kwargs)

    def to_dict(self):
        return {
            "id": self.id,
            "studentId": self.student_id,
            "visitorName": self.visitor_name,
            "visitorPhone": self.visitor_phone,
            "relation": self.relation,
            "purpose": self.purpose,
            "visitDate": self.visit_date,
            "expectedEntryTime": self.expected_entry_time,
            "expectedExitTime": self.expected_exit_time,
            "status": self.status,
            "approvedBy": self.approved_by,
            "passCode": self.pass_code,
            "entryGuardId": self.entry_guard_id,
            "enteredAt": self.entered_at,
            "exitGuardId": self.exit_guard_id,
            "exitedAt": self.exited_at,
            "securityRemarks": self.security_remarks,
            "createdAt": self.created_at,
            "updatedAt": self.updated_at
        }
