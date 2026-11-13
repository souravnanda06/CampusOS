import uuid
import datetime
from extensions import db

# Placement Drive Statuses
DRIVE_STATUSES = ('UPCOMING', 'REGISTRATION_CLOSED', 'ONGOING', 'COMPLETED', 'CANCELLED')

# Application Statuses
APPLICATION_STATUSES = ('APPLIED', 'SHORTLISTED', 'ASSESSMENT_SCHEDULED', 'INTERVIEW_SCHEDULED', 'OFFERED', 'REJECTED')

# Opportunity Employment & Mode Types
EMPLOYMENT_TYPES = ('INTERNSHIP', 'FULL_TIME', 'PART_TIME', 'CONTRACT')
WORK_MODES = ('ON_SITE', 'REMOTE', 'HYBRID')
EXPERIENCE_LEVELS = ('INTERN', 'ENTRY_LEVEL', 'JUNIOR', 'EXPERIENCED')


class PlacementDrive(db.Model):
    """
    Authoritative institutional recruitment drives managed by University / TPO.
    Includes strict eligibility cutoffs tied to verified student data (CGPA, attendance, branch).
    """
    __tablename__ = 'placement_drives'

    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    company_name = db.Column(db.String(120), nullable=False)
    company_logo_url = db.Column(db.Text, nullable=True)
    role_title = db.Column(db.String(150), nullable=False)
    job_description = db.Column(db.Text, nullable=False)
    location = db.Column(db.String(100), default='On-Campus / Hybrid')
    ctc_breakdown = db.Column(db.String(120), nullable=True)  # e.g., '₹8.5 LPA (₹7.5L Fixed + ₹1L Retention)'
    stipend_amount = db.Column(db.String(60), nullable=True)  # e.g., '₹35,000 / month'
    
    # Eligibility rules
    target_batches_json = db.Column(db.Text, nullable=False, default='[]')      # e.g., '["2025", "2026"]'
    eligible_branches_json = db.Column(db.Text, nullable=False, default='[]')   # e.g., '["CSE", "ECE", "IT"]'
    min_cgpa = db.Column(db.Float, default=0.0)
    max_active_backlogs = db.Column(db.Integer, default=0)
    min_attendance_percent = db.Column(db.Float, default=75.0)                  # Tied to CampusOS Attendance
    
    # Timeline
    drive_date = db.Column(db.String(50), nullable=False)
    registration_deadline = db.Column(db.String(50), nullable=False)
    venue = db.Column(db.String(200), default='Main Auditorium & Placement Labs')
    selection_process = db.Column(db.Text, nullable=True)                       # 'Aptitude Test -> Technical Round -> HR'
    attachment_url = db.Column(db.String(255), nullable=True)
    
    status = db.Column(db.String(30), default='UPCOMING')                       # DRIVE_STATUSES
    created_by = db.Column(db.String(36), db.ForeignKey('users.id'), nullable=True)
    created_at = db.Column(db.String(50), default=lambda: datetime.datetime.now().isoformat())
    updated_at = db.Column(db.String(50), default=lambda: datetime.datetime.now().isoformat(), onupdate=lambda: datetime.datetime.now().isoformat())

    def __init__(self, **kwargs):
        if 'id' not in kwargs or not kwargs['id']:
            kwargs['id'] = str(uuid.uuid4())
        super().__init__(**kwargs)

    def to_dict(self):
        import json
        batches = []
        branches = []
        try:
            batches = json.loads(self.target_batches_json or '[]')
        except Exception:
            batches = []
        try:
            branches = json.loads(self.eligible_branches_json or '[]')
        except Exception:
            branches = []

        return {
            "id": self.id,
            "companyName": self.company_name,
            "companyLogoUrl": self.company_logo_url,
            "roleTitle": self.role_title,
            "jobDescription": self.job_description,
            "location": self.location,
            "ctcBreakdown": self.ctc_breakdown,
            "stipendAmount": self.stipend_amount,
            "targetBatches": batches,
            "eligibleBranches": branches,
            "minCgpa": float(self.min_cgpa or 0.0),
            "maxActiveBacklogs": int(self.max_active_backlogs or 0),
            "minAttendancePercent": float(self.min_attendance_percent or 0.0),
            "driveDate": self.drive_date,
            "registrationDeadline": self.registration_deadline,
            "venue": self.venue,
            "selectionProcess": self.selection_process,
            "attachmentUrl": self.attachment_url,
            "status": self.status,
            "createdBy": self.created_by,
            "createdAt": self.created_at,
            "updatedAt": self.updated_at,
        }


class OpportunityListing(db.Model):
    """
    Curated opportunities aggregated from free external APIs (Remotive, Jobicy, Adzuna)
    or institutional postings. Deduplicated via SHA-256 fingerprint with 21-day TTL.
    """
    __tablename__ = 'opportunity_listings'

    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    source_type = db.Column(db.String(30), default='EXTERNAL')  # 'INSTITUTIONAL', 'EXTERNAL_REMOTIVE', 'EXTERNAL_JOBICY', 'EXTERNAL_ADZUNA'
    fingerprint = db.Column(db.String(64), unique=True, index=True, nullable=False)
    title = db.Column(db.String(150), nullable=False)
    company_name = db.Column(db.String(120), nullable=False)
    company_logo_url = db.Column(db.Text, nullable=True)
    location = db.Column(db.String(100), default='Remote')
    work_mode = db.Column(db.String(20), default='REMOTE')      # WORK_MODES
    employment_type = db.Column(db.String(30), default='INTERNSHIP') # EMPLOYMENT_TYPES
    experience_level = db.Column(db.String(30), default='INTERN')    # EXPERIENCE_LEVELS
    skills_json = db.Column(db.Text, nullable=True, default='[]')
    salary_range = db.Column(db.String(80), nullable=True)
    description = db.Column(db.Text, nullable=False)
    apply_url = db.Column(db.Text, nullable=False)
    expires_at = db.Column(db.String(50), nullable=True)
    status = db.Column(db.String(20), default='ACTIVE')         # ACTIVE, EXPIRED, ARCHIVED
    created_at = db.Column(db.String(50), default=lambda: datetime.datetime.now().isoformat())
    updated_at = db.Column(db.String(50), default=lambda: datetime.datetime.now().isoformat(), onupdate=lambda: datetime.datetime.now().isoformat())

    def __init__(self, **kwargs):
        if 'id' not in kwargs or not kwargs['id']:
            kwargs['id'] = str(uuid.uuid4())
        super().__init__(**kwargs)

    def to_dict(self):
        import json
        skills = []
        try:
            skills = json.loads(self.skills_json or '[]')
        except Exception:
            skills = []

        return {
            "id": self.id,
            "sourceType": self.source_type,
            "fingerprint": self.fingerprint,
            "title": self.title,
            "companyName": self.company_name,
            "companyLogoUrl": self.company_logo_url,
            "location": self.location,
            "workMode": self.work_mode,
            "employmentType": self.employment_type,
            "experienceLevel": self.experience_level,
            "skills": skills,
            "salaryRange": self.salary_range,
            "description": self.description,
            "applyUrl": self.apply_url,
            "expiresAt": self.expires_at,
            "status": self.status,
            "createdAt": self.created_at,
            "updatedAt": self.updated_at,
        }


class PlacementApplication(db.Model):
    """
    Student application record for either an on-campus drive or an externally tracked job.
    """
    __tablename__ = 'placement_applications'

    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    student_id = db.Column(db.String(36), db.ForeignKey('users.id'), nullable=False, index=True)
    drive_id = db.Column(db.String(36), db.ForeignKey('placement_drives.id'), nullable=True, index=True)
    opportunity_id = db.Column(db.String(36), db.ForeignKey('opportunity_listings.id'), nullable=True, index=True)
    application_type = db.Column(db.String(20), default='ON_CAMPUS')  # 'ON_CAMPUS', 'EXTERNAL_TRACKED'
    resume_url = db.Column(db.String(255), nullable=True)
    status = db.Column(db.String(30), default='APPLIED')              # APPLICATION_STATUSES
    admin_notes = db.Column(db.Text, nullable=True)
    applied_at = db.Column(db.String(50), default=lambda: datetime.datetime.now().isoformat())
    updated_at = db.Column(db.String(50), default=lambda: datetime.datetime.now().isoformat(), onupdate=lambda: datetime.datetime.now().isoformat())

    def __init__(self, **kwargs):
        if 'id' not in kwargs or not kwargs['id']:
            kwargs['id'] = str(uuid.uuid4())
        super().__init__(**kwargs)

    def to_dict(self):
        return {
            "id": self.id,
            "studentId": self.student_id,
            "driveId": self.drive_id,
            "opportunityId": self.opportunity_id,
            "applicationType": self.application_type,
            "resumeUrl": self.resume_url,
            "status": self.status,
            "adminNotes": self.admin_notes,
            "appliedAt": self.applied_at,
            "updatedAt": self.updated_at,
        }


class StudentCareerProfile(db.Model):
    """
    Student professional profile, ATS scores, skills inventory, and social/portfolio links.
    """
    __tablename__ = 'student_career_profiles'

    student_id = db.Column(db.String(36), db.ForeignKey('users.id'), primary_key=True)
    target_role = db.Column(db.String(100), default='Software Engineer')
    bio = db.Column(db.Text, nullable=True)
    skills_json = db.Column(db.Text, nullable=True, default='[]')
    projects_json = db.Column(db.Text, nullable=True, default='[]')
    certifications_json = db.Column(db.Text, nullable=True, default='[]')
    academic_records_json = db.Column(db.Text, nullable=True, default='{}')
    resume_url = db.Column(db.String(255), nullable=True)
    resume_filename = db.Column(db.String(120), nullable=True)
    ats_score = db.Column(db.Integer, default=0)
    ats_feedback_json = db.Column(db.Text, nullable=True)
    github_url = db.Column(db.String(150), nullable=True)
    linkedin_url = db.Column(db.String(150), nullable=True)
    portfolio_url = db.Column(db.String(150), nullable=True)
    cgpa = db.Column(db.Float, default=8.0)
    active_backlogs = db.Column(db.Integer, default=0)
    preferred_roles_json = db.Column(db.Text, nullable=True, default='[]')
    created_at = db.Column(db.String(50), default=lambda: datetime.datetime.now().isoformat())
    updated_at = db.Column(db.String(50), default=lambda: datetime.datetime.now().isoformat(), onupdate=lambda: datetime.datetime.now().isoformat())

    def to_dict(self):
        import json
        skills = []
        projects = []
        certifications = []
        academic_records = {}
        preferred_roles = []
        ats_feedback = {}
        try:
            skills = json.loads(self.skills_json or '[]')
        except Exception:
            skills = []
        try:
            projects = json.loads(self.projects_json or '[]')
        except Exception:
            projects = []
        try:
            certifications = json.loads(self.certifications_json or '[]')
        except Exception:
            certifications = []
        try:
            academic_records = json.loads(self.academic_records_json or '{}')
        except Exception:
            academic_records = {}
        try:
            preferred_roles = json.loads(self.preferred_roles_json or '[]')
        except Exception:
            preferred_roles = []
        try:
            ats_feedback = json.loads(self.ats_feedback_json or '{}')
        except Exception:
            ats_feedback = {}

        return {
            "studentId": self.student_id,
            "targetRole": self.target_role or 'Software Engineer',
            "bio": self.bio or '',
            "skills": skills,
            "projects": projects,
            "certifications": certifications,
            "academicRecords": academic_records,
            "resumeUrl": self.resume_url,
            "resumeFilename": self.resume_filename,
            "atsScore": int(self.ats_score or 0),
            "atsFeedback": ats_feedback,
            "githubUrl": self.github_url,
            "linkedinUrl": self.linkedin_url,
            "portfolioUrl": self.portfolio_url,
            "cgpa": float(self.cgpa or 0.0),
            "activeBacklogs": int(self.active_backlogs or 0),
            "preferredRoles": preferred_roles,
            "createdAt": self.created_at,
            "updatedAt": self.updated_at,
        }
