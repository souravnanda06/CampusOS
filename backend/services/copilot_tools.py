"""
CampusOS AI Copilot — Role-Scoped Tool Declarations, Executors & Action Confirmation Store.

Strict RBAC isolation:
- Students can only read their own attendance/fees/notices/requests and draft their own leave/complaint actions.
- Teachers can read their own sessions/presets, inspect low-attendance cohorts, and draft sessions/class updates/targeted notices (never ALL).
- Admins can inspect campus-wide complaint SLA/clusters, approvals, fees/mess overview, and draft campus notices or escalate complaints.
"""

import datetime
import json
import math
import threading
import time
import uuid
from sqlalchemy import func

from extensions import db
from models.attendance import Attendance, SavedClass, Session
from models.audit import ComplaintStatusHistory, RequestAudit
from models.complaint import Complaint, generate_closure_pin
from models.expansion import (
    ClassUpdate,
    DocumentRequest,
    FeeRecord,
    SUPPORTED_DOCUMENT_TYPES,
)
from models.leave import LeaveRequest
from models.mess import MessFeedback, MessMenu
from models.notice import Notice
from models.notification import NotificationDelivery
from models.user import User
from services.complaint_service import (
    COMPLAINT_AGEING_HOURS,
    _format_admin_complaint,
    compute_recurring_complaint_clusters,
)
from services.notice_service import (
    SUPPORTED_NOTICE_CATEGORIES,
    SUPPORTED_NOTICE_PRIORITIES,
    is_notice_expired,
    is_notice_targeted_to_student,
    sync_notice_deliveries,
)


PENDING_ACTION_TTL_SECONDS = 600  # 10 minutes
_pending_lock = threading.Lock()
_pending_actions = {}


def canonical_copilot_role(raw_role: str | None) -> str:
    r = (raw_role or '').strip().lower()
    if r == 'student':
        return 'student'
    if r in ('teacher', 'faculty', 'instructor'):
        return 'teacher'
    if r in ('admin', 'administrator', 'superadmin', 'dean'):
        return 'admin'
    return r


def _cleanup_expired_actions(now_ts: float | None = None):
    now = now_ts or time.time()
    expired = [
        k for k, v in _pending_actions.items()
        if (now - v.get('created_ts', 0)) > PENDING_ACTION_TTL_SECONDS
    ]
    for k in expired:
        _pending_actions.pop(k, None)


def create_pending_action(
    user: User,
    role: str,
    action_type: str,
    title: str,
    summary: str,
    payload: dict,
) -> dict:
    action_id = f"act_{uuid.uuid4().hex[:12]}"
    entry = {
        'actionId': action_id,
        'userId': user.id,
        'role': role,
        'actionType': action_type,
        'title': title,
        'summary': summary,
        'payload': payload,
        'status': 'PENDING_CONFIRMATION',
        'created_ts': time.time(),
        'createdAt': datetime.datetime.now().isoformat(),
    }
    with _pending_lock:
        _cleanup_expired_actions()
        _pending_actions[action_id] = entry
    return {
        'actionId': action_id,
        'actionType': action_type,
        'title': title,
        'summary': summary,
        'payload': payload,
        'status': 'PENDING_CONFIRMATION',
    }


def _safe_float(val, default=0.0):
    try:
        return float(val)
    except Exception:
        return default


# ==============================================================================
# STUDENT TOOL EXECUTORS
# ==============================================================================

def _student_attendance_summary(user: User, subject: str | None = None) -> dict:
    total_sessions = Session.query.filter_by(
        course=user.course, branch=user.branch, year=user.year
    ).count()
    all_sessions = Session.query.filter_by(
        course=user.course, branch=user.branch, year=user.year
    ).all()
    session_by_id = {s.id: s for s in all_sessions}
    my_att = (
        Attendance.query.filter_by(user_id=user.id)
        .with_entities(Attendance.session_id)
        .all()
    )
    attended_count = len(my_att)

    # Calculate per-subject totals
    subject_map = {}
    for s in all_sessions:
        subj = (s.subject or s.name or 'General').strip()
        if subj not in subject_map:
            subject_map[subj] = {'total': 0, 'attended': 0}
        subject_map[subj]['total'] += 1

    for (att_session_id,) in my_att:
        sess = session_by_id.get(att_session_id)
        if sess:
            subj = (sess.subject or sess.name or 'General').strip()
            if subj in subject_map:
                subject_map[subj]['attended'] += 1

    overall_pct = round((attended_count / total_sessions) * 100, 1) if total_sessions > 0 else 0.0

    # 75% target advisor
    # Safe to skip: max x where attended / (total + x) >= 0.75 => x <= (attended/0.75) - total
    safe_to_skip = 0
    needed_for_75 = 0
    if total_sessions > 0:
        if overall_pct >= 75.0:
            safe_to_skip = max(0, math.floor((attended_count / 0.75) - total_sessions))
        else:
            # min y where (attended + y) / (total + y) >= 0.75 => y >= 3*total - 4*attended
            needed_for_75 = max(0, math.ceil((0.75 * total_sessions - attended_count) / 0.25))

    subjects = []
    for subj_name, counts in sorted(subject_map.items()):
        t = counts['total']
        a = counts['attended']
        pct = round((a / t) * 100, 1) if t > 0 else 0.0
        if subject and subject.strip().lower() not in subj_name.lower():
            continue
        subjects.append({
            'subject': subj_name,
            'attended': a,
            'total': t,
            'percentage': pct,
        })

    return {
        'overallPercentage': overall_pct,
        'attended': attended_count,
        'totalSessions': total_sessions,
        'targetPercentage': 75.0,
        'safeToSkipClasses': safe_to_skip,
        'classesNeededFor75': needed_for_75,
        'subjects': subjects,
    }


def _student_notices(user: User, category: str | None = None, limit: int = 8) -> dict:
    q = Notice.query.filter(Notice.status == 'PUBLISHED')
    if category and category.strip():
        q = q.filter(func.upper(Notice.category) == category.strip().upper())
    notices = q.order_by(Notice.created_at.desc()).limit(30).all()

    matched = []
    for n in notices:
        if is_notice_expired(n):
            continue
        if is_notice_targeted_to_student(n, user):
            d = n.to_dict()
            matched.append({
                'id': d['id'],
                'title': d['title'],
                'body': d['body'],
                'category': d['category'],
                'priority': d['priority'],
                'createdAt': d['createdAt'],
                'expiresAt': d['expiresAt'],
            })
            if len(matched) >= max(1, min(limit, 15)):
                break

    return {'count': len(matched), 'notices': matched}


def _student_fees(user: User) -> dict:
    fees = FeeRecord.query.filter_by(student_id=user.id).order_by(FeeRecord.due_date.asc()).all()
    total_amount = sum(f.amount for f in fees)
    total_paid = sum(f.amount_paid for f in fees)
    total_due = round(max(0.0, total_amount - total_paid), 2)
    return {
        'totalAmount': round(total_amount, 2),
        'totalPaid': round(total_paid, 2),
        'totalDue': total_due,
        'hasOverdue': any(f.status == 'OVERDUE' for f in fees),
        'records': [
            {
                'id': f.id,
                'title': f.title,
                'category': f.category,
                'amount': f.amount,
                'amountPaid': f.amount_paid,
                'dueDate': f.due_date,
                'status': f.status,
            }
            for f in fees[:10]
        ],
    }


def _today_mess_menu() -> dict:
    today_str = datetime.date.today().isoformat()
    menu = MessMenu.query.filter_by(menu_date=today_str, status='PUBLISHED').first()
    if not menu:
        menu = (
            MessMenu.query.filter_by(status='PUBLISHED')
            .order_by(MessMenu.menu_date.desc())
            .first()
        )
    if not menu:
        return {'found': False, 'message': 'No published mess menu found.'}
    return {
        'found': True,
        'menuDate': menu.menu_date,
        'isToday': menu.menu_date == today_str,
        'meals': [
            {
                'mealType': m.meal_type,
                'title': m.title or m.meal_type,
                'items': m.get_items_list(),
                'availability': m.availability,
            }
            for m in sorted(menu.meals, key=lambda x: (x.display_order, x.meal_type))
        ],
    }


def _student_requests_status(user: User) -> dict:
    leaves = (
        LeaveRequest.query.filter_by(student_id=user.id)
        .order_by(LeaveRequest.created_at.desc())
        .limit(5)
        .all()
    )
    complaints = (
        Complaint.query.filter_by(student_id=user.id)
        .order_by(Complaint.created_at.desc())
        .limit(5)
        .all()
    )
    docs = (
        DocumentRequest.query.filter_by(student_id=user.id)
        .order_by(DocumentRequest.created_at.desc())
        .limit(5)
        .all()
    )
    return {
        'leaves': [l.to_dict() for l in leaves],
        'complaints': [
            {
                'id': c.id,
                'title': c.title,
                'category': c.category,
                'status': c.status,
                'priority': c.priority,
                'location': c.location,
                'createdAt': c.created_at,
            }
            for c in complaints
        ],
        'documents': [
            {
                'id': d.id,
                'documentType': d.document_type,
                'status': d.status,
                'createdAt': d.created_at,
            }
            for d in docs
        ],
    }


def _student_draft_leave(
    user: User,
    leave_type: str,
    start_date: str,
    end_date: str,
    reason: str,
    destination: str | None = None,
) -> dict:
    clean_type = (leave_type or 'HOME_VISIT').strip().upper()
    today = datetime.date.today()
    try:
        sd = datetime.date.fromisoformat(start_date)
    except Exception:
        sd = today + datetime.timedelta(days=1)
    try:
        ed = datetime.date.fromisoformat(end_date)
    except Exception:
        ed = sd
    if ed < sd:
        ed = sd

    payload = {
        'leaveType': clean_type,
        'startDate': sd.isoformat(),
        'endDate': ed.isoformat(),
        'reason': (reason or 'Personal leave request').strip(),
        'destination': (destination or '').strip() or None,
    }
    action = create_pending_action(
        user=user,
        role='student',
        action_type='SUBMIT_LEAVE_REQUEST',
        title='Submit Leave Request',
        summary=f"{clean_type} from {payload['startDate']} to {payload['endDate']} — {payload['reason']}",
        payload=payload,
    )
    return {'status': 'DRAFTED', 'pendingAction': action}


def _student_draft_complaint(
    user: User,
    category: str,
    title: str,
    description: str,
    location: str = 'Hostel',
    priority: str = 'MEDIUM',
) -> dict:
    clean_priority = (priority or 'MEDIUM').strip().upper()
    if clean_priority not in ('LOW', 'MEDIUM', 'HIGH', 'URGENT'):
        clean_priority = 'MEDIUM'
    clean_category = (category or 'MAINTENANCE').strip().upper()
    clean_title = (title or 'Campus Issue Report').strip()[:140]
    clean_desc = (description or clean_title).strip()
    clean_loc = (location or 'Campus').strip()[:90]

    payload = {
        'category': clean_category,
        'title': clean_title,
        'description': clean_desc,
        'location': clean_loc,
        'priority': clean_priority,
    }
    action = create_pending_action(
        user=user,
        role='student',
        action_type='CREATE_COMPLAINT',
        title='File Campus Complaint',
        summary=f"[{clean_category} · {clean_priority}] {clean_title} at {clean_loc}",
        payload=payload,
    )
    return {'status': 'DRAFTED', 'pendingAction': action}


def _student_draft_document_request(
    user: User,
    document_type: str,
    purpose: str,
) -> dict:
    raw = (document_type or 'BONAFIDE_CERTIFICATE').strip().upper().replace(' ', '_')
    if raw not in SUPPORTED_DOCUMENT_TYPES:
        # Match friendly names
        if 'BONAFIDE' in raw:
            raw = 'BONAFIDE_CERTIFICATE'
        elif 'NOC' in raw or 'INTERNSHIP' in raw:
            raw = 'INTERNSHIP_NOC'
        elif 'CONDUCT' in raw or 'CHARACTER' in raw:
            raw = 'CONDUCT_CERTIFICATE'
        elif 'FEE' in raw:
            raw = 'FEE_RECEIPT_SUMMARY'
        elif 'HOSTEL' in raw:
            raw = 'HOSTEL_RESIDENCE_CERTIFICATE'
        elif 'PROVISIONAL' in raw:
            raw = 'PROVISIONAL_CERTIFICATE'
        else:
            raw = 'BONAFIDE_CERTIFICATE'

    friendly = SUPPORTED_DOCUMENT_TYPES[raw]
    clean_purpose = (purpose or f'Official request for {friendly}').strip()
    payload = {
        'documentType': raw,
        'documentTypeName': friendly,
        'purpose': clean_purpose,
    }
    action = create_pending_action(
        user=user,
        role='student',
        action_type='REQUEST_DOCUMENT',
        title=f'Request {friendly}',
        summary=f"{friendly} — Purpose: {clean_purpose}",
        payload=payload,
    )
    return {'status': 'DRAFTED', 'pendingAction': action}


def _student_format_study_practice(
    topic: str,
    subject: str = 'Computer Science',
    difficulty: str = 'Medium',
    questions_markdown: str = '',
    answers_markdown: str = '',
) -> dict:
    return {
        'documentCard': {
            'type': 'document',
            'title': f"Practice Quiz: {(topic or 'Study Topic').strip()}",
            'subtitle': f"{(subject or 'Study').strip()} · {difficulty}",
            'badges': ['PRACTICE', difficulty.upper()],
            'content': (questions_markdown or '').strip(),
            'answerKey': (answers_markdown or '').strip() or None,
        }
    }


# ==============================================================================
# TEACHER TOOL EXECUTORS
# ==============================================================================

def _teacher_sessions_summary(user: User) -> dict:
    active = (
        Session.query.filter_by(teacher_id=user.id, is_active=True)
        .order_by(Session.start_time.desc())
        .all()
    )
    recent = (
        Session.query.filter_by(teacher_id=user.id)
        .order_by(Session.start_time.desc())
        .limit(8)
        .all()
    )
    presets = (
        SavedClass.query.filter_by(user_id=user.id)
        .order_by(SavedClass.last_used.desc())
        .limit(8)
        .all()
    )
    return {
        'activeSessions': [s.to_dict() for s in active],
        'recentSessions': [s.to_dict() for s in recent],
        'savedClasses': [c.to_dict() for c in presets],
    }


def _teacher_low_attendance_students(
    user: User,
    threshold: float = 75.0,
    branch: str | None = None,
    year: str | None = None,
) -> dict:
    thresh = max(10.0, min(95.0, _safe_float(threshold, 75.0)))
    q = User.query.filter_by(role='student')
    q = q.filter(db.or_(User.approval_status == 'APPROVED', User.approval_status.is_(None)))
    if branch and branch.strip():
        q = q.filter(func.upper(User.branch) == branch.strip().upper())
    if year and year.strip():
        q = q.filter(func.upper(User.year) == year.strip().upper())
    students = q.order_by(User.registration_number.asc()).limit(150).all()

    if not students:
        return {'threshold': thresh, 'count': 0, 'students': []}

    student_ids = [s.id for s in students]
    att_counts = dict(
        db.session.query(Attendance.user_id, func.count(Attendance.id))
        .filter(Attendance.user_id.in_(student_ids))
        .group_by(Attendance.user_id)
        .all()
    )

    session_count_cache = {}
    at_risk = []
    for s in students:
        key = (s.course, s.branch, s.year)
        if key not in session_count_cache:
            session_count_cache[key] = Session.query.filter_by(
                course=s.course, branch=s.branch, year=s.year
            ).count()
        total_s = session_count_cache[key]
        if total_s == 0:
            continue
        attended = att_counts.get(s.id, 0)
        pct = round((attended / total_s) * 100, 1)
        if pct < thresh:
            at_risk.append({
                'id': s.id,
                'name': s.name,
                'registrationNumber': s.registration_number,
                'branch': s.branch,
                'year': s.year,
                'attended': attended,
                'totalSessions': total_s,
                'percentage': pct,
            })

    at_risk.sort(key=lambda x: x['percentage'])
    return {
        'threshold': thresh,
        'count': len(at_risk),
        'students': at_risk[:20],
    }


def _teacher_check_student_issue(user: User, query: str) -> dict:
    q_str = (query or '').strip()
    if not q_str:
        return {'found': False, 'message': 'Student name or registration number is required.'}
    like = f"%{q_str}%"
    student = (
        User.query.filter(
            User.role == 'student',
            db.or_(
                User.name.ilike(like),
                User.registration_number.ilike(like),
                User.email.ilike(like),
            ),
        )
        .first()
    )
    if not student:
        return {'found': False, 'message': f"No student found matching '{q_str}'."}

    recent_att = (
        Attendance.query.filter_by(user_id=student.id)
        .with_entities(
            Attendance.session_id,
            Attendance.check_in_time,
            Attendance.verification_mode,
            Attendance.status,
        )
        .order_by(Attendance.check_in_time.desc())
        .limit(5)
        .all()
    )
    return {
        'found': True,
        'student': {
            'id': student.id,
            'name': student.name,
            'registrationNumber': student.registration_number,
            'course': student.course,
            'branch': student.branch,
            'year': student.year,
            'approvalStatus': student.approval_status or 'APPROVED',
            'hasBoundDevice': bool(student.device_id),
            'faceEnrolled': bool(student.face_enrolled),
        },
        'recentCheckIns': [
            {
                'sessionId': row[0],
                'checkInTime': row[1],
                'verificationMode': row[2],
                'status': row[3],
            }
            for row in recent_att
        ],
    }


def _teacher_draft_session(
    user: User,
    subject: str,
    course: str = 'B.Tech',
    branch: str = 'CSE',
    year: str = '3rd',
    location: str = 'Room 204',
) -> dict:
    clean_subj = (subject or 'General Lecture').strip()
    payload = {
        'name': clean_subj,
        'subject': clean_subj,
        'course': (course or 'B.Tech').strip(),
        'branch': (branch or 'CSE').strip(),
        'year': (year or '3rd').strip(),
        'location': (location or 'Room 204').strip(),
    }
    action = create_pending_action(
        user=user,
        role='teacher',
        action_type='CREATE_ATTENDANCE_SESSION',
        title='Start Attendance Session',
        summary=f"{payload['subject']} ({payload['course']} {payload['branch']} {payload['year']}) in {payload['location']}",
        payload=payload,
    )
    return {'status': 'DRAFTED', 'pendingAction': action}


def _teacher_draft_class_update(
    user: User,
    course_code: str,
    course_name: str,
    update_type: str,
    message: str,
    affected_branch: str = 'ALL',
    affected_year: str | None = None,
) -> dict:
    utype = (update_type or 'ANNOUNCEMENT').strip().upper()
    if utype not in ('CANCELLED', 'RESCHEDULED', 'ROOM_CHANGE', 'TIME_CHANGE', 'ANNOUNCEMENT'):
        utype = 'ANNOUNCEMENT'
    payload = {
        'courseCode': (course_code or 'CS101').strip().upper(),
        'courseName': (course_name or 'Class').strip(),
        'updateType': utype,
        'message': (message or '').strip() or 'Schedule update from faculty.',
        'affectedBranch': (affected_branch or 'ALL').strip(),
        'affectedYear': (affected_year or '').strip() or None,
    }
    action = create_pending_action(
        user=user,
        role='teacher',
        action_type='POST_CLASS_UPDATE',
        title='Post Class Update',
        summary=f"[{utype}] {payload['courseCode']} {payload['courseName']}: {payload['message'][:80]}",
        payload=payload,
    )
    return {'status': 'DRAFTED', 'pendingAction': action}


def _teacher_draft_notice(
    user: User,
    title: str,
    body: str,
    target_type: str = 'BRANCH',
    target_value: str = 'CSE',
    category: str = 'ACADEMIC',
    priority: str = 'NORMAL',
) -> dict:
    ttype = (target_type or 'BRANCH').strip().upper()
    if ttype == 'ALL':
        # Enforce existing CampusOS rule: Teachers cannot target ALL students
        ttype = 'BRANCH'
    if ttype not in ('BRANCH', 'YEAR', 'STUDENT'):
        ttype = 'BRANCH'
    tval = (target_value or user.branch or 'CSE').strip()
    cat = (category or 'ACADEMIC').strip().upper()
    if cat not in SUPPORTED_NOTICE_CATEGORIES:
        cat = 'ACADEMIC'
    prio = (priority or 'NORMAL').strip().upper()
    if prio not in SUPPORTED_NOTICE_PRIORITIES:
        prio = 'NORMAL'

    payload = {
        'title': (title or 'Academic Notice').strip(),
        'body': (body or '').strip() or title,
        'targetType': ttype,
        'targetValue': tval,
        'category': cat,
        'priority': prio,
    }
    action = create_pending_action(
        user=user,
        role='teacher',
        action_type='PUBLISH_NOTICE',
        title='Publish Targeted Notice',
        summary=f"[{prio} · {ttype}={tval}] {payload['title']}",
        payload=payload,
    )
    return {'status': 'DRAFTED', 'pendingAction': action}


def _teacher_format_assessment_paper(
    title: str,
    subject: str,
    assessment_type: str = 'MID_SEM_EXAM',
    total_marks: int = 30,
    duration_minutes: int = 60,
    difficulty: str = 'Balanced',
    paper_markdown: str = '',
    answer_key_markdown: str = '',
) -> dict:
    atype = (assessment_type or 'ASSESSMENT').strip().upper().replace('_', ' ')
    marks_val = max(5, min(200, int(total_marks or 30)))
    dur_val = max(10, min(240, int(duration_minutes or 60)))
    return {
        'documentCard': {
            'type': 'document',
            'title': (title or f"{subject} {atype}").strip(),
            'subtitle': f"{(subject or 'Course').strip()} · {atype}",
            'badges': [atype, f"{marks_val} Marks", f"{dur_val} Mins", (difficulty or 'Balanced')],
            'content': (paper_markdown or '').strip(),
            'answerKey': (answer_key_markdown or '').strip() or None,
        }
    }


def _teacher_format_lesson_plan(
    topic: str,
    subject: str,
    duration_minutes: int = 50,
    plan_markdown: str = '',
) -> dict:
    dur_val = max(15, min(180, int(duration_minutes or 50)))
    return {
        'documentCard': {
            'type': 'document',
            'title': f"Lesson Plan: {(topic or 'Lecture').strip()}",
            'subtitle': f"{(subject or 'Course').strip()} · {dur_val} mins",
            'badges': ['LESSON PLAN', f"{dur_val} Mins"],
            'content': (plan_markdown or '').strip(),
            'answerKey': None,
        }
    }


def _teacher_class_cohort_health(
    user: User,
    branch: str | None = None,
    year: str | None = None,
) -> dict:
    q = User.query.filter_by(role='student')
    q = q.filter(db.or_(User.approval_status == 'APPROVED', User.approval_status.is_(None)))
    if branch and branch.strip():
        q = q.filter(func.upper(User.branch) == branch.strip().upper())
    if year and year.strip():
        q = q.filter(func.upper(User.year) == year.strip().upper())
    students = q.limit(200).all()
    if not students:
        return {'totalStudents': 0, 'averagePercentage': 0.0, 'good': 0, 'borderline': 0, 'atRisk': 0}

    student_ids = [s.id for s in students]
    att_counts = dict(
        db.session.query(Attendance.user_id, func.count(Attendance.id))
        .filter(Attendance.user_id.in_(student_ids))
        .group_by(Attendance.user_id)
        .all()
    )
    session_cache = {}
    pcts = []
    good = borderline = at_risk = 0
    for s in students:
        key = (s.course, s.branch, s.year)
        if key not in session_cache:
            session_cache[key] = Session.query.filter_by(
                course=s.course, branch=s.branch, year=s.year
            ).count()
        total_s = session_cache[key]
        if total_s <= 0:
            continue
        pct = round((att_counts.get(s.id, 0) / total_s) * 100, 1)
        pcts.append(pct)
        if pct >= 85.0:
            good += 1
        elif pct >= 75.0:
            borderline += 1
        else:
            at_risk += 1

    avg_pct = round(sum(pcts) / len(pcts), 1) if pcts else 0.0
    return {
        'totalStudents': len(students),
        'evaluatedStudents': len(pcts),
        'averagePercentage': avg_pct,
        'good': good,
        'borderline': borderline,
        'atRisk': at_risk,
    }


def _teacher_draft_reset_device(user: User, student_query: str, reason: str = '') -> dict:
    q_str = (student_query or '').strip()
    if not q_str:
        return {'status': 'NOT_FOUND', 'message': 'Specify student name or registration number.'}
    like = f"%{q_str}%"
    student = User.query.filter(
        User.role == 'student',
        db.or_(
            User.name.ilike(like),
            User.registration_number.ilike(like),
            User.email.ilike(like),
        ),
    ).first()
    if not student:
        return {'status': 'NOT_FOUND', 'message': f"No student found matching '{q_str}'."}

    payload = {
        'studentId': student.id,
        'studentName': student.name,
        'registrationNumber': student.registration_number,
        'reason': (reason or 'Device replacement / re-binding requested').strip(),
    }
    action = create_pending_action(
        user=user,
        role='teacher',
        action_type='RESET_STUDENT_DEVICE',
        title='Reset Student Device Binding',
        summary=f"Clear bound device ID for {student.name} ({student.registration_number or student.email})",
        payload=payload,
    )
    return {'status': 'DRAFTED', 'pendingAction': action}


# ==============================================================================
# ADMIN TOOL EXECUTORS
# ==============================================================================

def _admin_campus_pulse(user: User) -> dict:
    status_counts = dict(
        db.session.query(Complaint.status, func.count(Complaint.id))
        .group_by(Complaint.status)
        .all()
    )
    total_complaints = sum(status_counts.values())
    now = datetime.datetime.now()
    cutoff_iso = (now - datetime.timedelta(hours=COMPLAINT_AGEING_HOURS)).isoformat()

    ageing_count = Complaint.query.filter(
        Complaint.status.in_(['PENDING', 'ASSIGNED', 'IN_PROGRESS', 'REOPENED']),
        Complaint.created_at < cutoff_iso,
    ).count()
    pending_approvals = User.query.filter(
        User.role == 'student', User.approval_status == 'PENDING'
    ).count()
    pending_leaves = LeaveRequest.query.filter_by(status='PENDING').count()
    active_sessions = Session.query.filter_by(is_active=True).count()
    total_students = User.query.filter_by(role='student').count()

    return {
        'totalStudents': total_students,
        'activeAttendanceSessions': active_sessions,
        'totalComplaints': total_complaints,
        'pendingComplaints': status_counts.get('PENDING', 0),
        'inProgressComplaints': status_counts.get('IN_PROGRESS', 0),
        'reopenedComplaints': status_counts.get('REOPENED', 0),
        'ageingComplaintsOver48h': ageing_count,
        'pendingStudentApprovals': pending_approvals,
        'pendingLeaveRequests': pending_leaves,
    }


def _admin_ageing_and_recurring(user: User, limit: int = 8) -> dict:
    now = datetime.datetime.now()
    cutoff_iso = (now - datetime.timedelta(hours=COMPLAINT_AGEING_HOURS)).isoformat()
    ageing = (
        Complaint.query.filter(
            Complaint.status.in_(['PENDING', 'ASSIGNED', 'IN_PROGRESS', 'REOPENED']),
            Complaint.created_at < cutoff_iso,
        )
        .order_by(Complaint.created_at.asc())
        .limit(max(1, min(limit, 15)))
        .all()
    )
    clusters = compute_recurring_complaint_clusters()
    return {
        'ageingCount': len(ageing),
        'ageingComplaints': [
            {
                'id': c['id'],
                'title': c['title'],
                'category': c['category'],
                'location': c['location'],
                'priority': c['priority'],
                'status': c['status'],
                'ageHours': c['ageHours'],
                'studentName': c.get('studentName'),
            }
            for c in (_format_admin_complaint(item, now) for item in ageing)
        ],
        'recurringClusterCount': len(clusters),
        'recurringClusters': clusters[:5],
    }


def _admin_pending_student_approvals(user: User) -> dict:
    pending = (
        User.query.filter(User.role == 'student', User.approval_status == 'PENDING')
        .order_by(User.created_at.asc())
        .limit(15)
        .all()
    )
    return {
        'count': len(pending),
        'students': [
            {
                'id': s.id,
                'name': s.name,
                'email': s.email,
                'registrationNumber': s.registration_number,
                'course': s.course,
                'branch': s.branch,
                'year': s.year,
                'createdAt': s.created_at,
            }
            for s in pending
        ],
    }


def _admin_fee_and_mess_overview(user: User) -> dict:
    fees = FeeRecord.query.all()
    total_billed = sum(f.amount for f in fees)
    total_collected = sum(f.amount_paid for f in fees)
    overdue_count = sum(1 for f in fees if f.status == 'OVERDUE')
    due_count = sum(1 for f in fees if f.status in ('DUE', 'PARTIALLY_PAID', 'OVERDUE'))

    feedbacks = MessFeedback.query.order_by(MessFeedback.created_at.desc()).limit(50).all()
    avg_rating = round(sum(f.rating for f in feedbacks) / len(feedbacks), 2) if feedbacks else None

    return {
        'feeTotalBilled': round(total_billed, 2),
        'feeTotalCollected': round(total_collected, 2),
        'feeTotalOutstanding': round(max(0.0, total_billed - total_collected), 2),
        'overdueRecords': overdue_count,
        'unpaidRecords': due_count,
        'messFeedbackSampleSize': len(feedbacks),
        'messAverageRating': avg_rating,
    }


def _admin_draft_notice(
    user: User,
    title: str,
    body: str,
    target_type: str = 'ALL',
    target_value: str | None = None,
    category: str = 'GENERAL',
    priority: str = 'NORMAL',
) -> dict:
    ttype = (target_type or 'ALL').strip().upper()
    if ttype not in ('ALL', 'BRANCH', 'YEAR', 'STUDENT'):
        ttype = 'ALL'
    tval = (target_value or '').strip() or None
    if ttype in ('BRANCH', 'YEAR', 'STUDENT') and not tval:
        ttype = 'ALL'

    cat = (category or 'GENERAL').strip().upper()
    if cat not in SUPPORTED_NOTICE_CATEGORIES:
        cat = 'GENERAL'
    prio = (priority or 'NORMAL').strip().upper()
    if prio not in SUPPORTED_NOTICE_PRIORITIES:
        prio = 'NORMAL'

    payload = {
        'title': (title or 'Campus Circular').strip(),
        'body': (body or '').strip() or title,
        'targetType': ttype,
        'targetValue': tval,
        'category': cat,
        'priority': prio,
    }
    target_desc = 'ALL' if ttype == 'ALL' else f"{ttype}={tval}"
    action = create_pending_action(
        user=user,
        role='admin',
        action_type='PUBLISH_NOTICE',
        title='Publish Campus Notice',
        summary=f"[{prio} · {target_desc}] {payload['title']}",
        payload=payload,
    )
    return {'status': 'DRAFTED', 'pendingAction': action}


def _admin_draft_complaint_escalation(
    user: User,
    complaint_id: str,
    action_note: str = 'Escalated by Admin via CampusOS Copilot',
) -> dict:
    comp = Complaint.query.get(complaint_id)
    if not comp:
        return {'status': 'NOT_FOUND', 'message': f"Complaint '{complaint_id}' not found."}

    payload = {
        'complaintId': comp.id,
        'complaintTitle': comp.title,
        'currentStatus': comp.status,
        'currentPriority': comp.priority,
        'actionNote': (action_note or 'Escalated by Admin via CampusOS Copilot').strip(),
    }
    action = create_pending_action(
        user=user,
        role='admin',
        action_type='ESCALATE_COMPLAINT',
        title='Escalate Complaint to Urgent',
        summary=f"Escalate '{comp.title}' ({comp.location}) to URGENT / Level 3",
        payload=payload,
    )
    return {'status': 'DRAFTED', 'pendingAction': action}


def _admin_draft_approve_student(user: User, student_query: str) -> dict:
    q_str = (student_query or '').strip()
    q = User.query.filter(User.role == 'student', User.approval_status == 'PENDING')
    if q_str:
        like = f"%{q_str}%"
        q = q.filter(db.or_(
            User.name.ilike(like),
            User.registration_number.ilike(like),
            User.email.ilike(like),
        ))
    student = q.order_by(User.created_at.asc()).first()
    if not student:
        return {'status': 'NOT_FOUND', 'message': 'No matching pending student registration found.'}

    payload = {
        'studentId': student.id,
        'studentName': student.name,
        'registrationNumber': student.registration_number,
        'branch': student.branch,
        'year': student.year,
    }
    action = create_pending_action(
        user=user,
        role='admin',
        action_type='APPROVE_STUDENT_REGISTRATION',
        title='Approve Student Registration',
        summary=f"Activate {student.name} ({student.registration_number or student.email} · {student.branch or ''} {student.year or ''})",
        payload=payload,
    )
    return {'status': 'DRAFTED', 'pendingAction': action}


def _admin_generate_executive_report(user: User) -> dict:
    pulse = _admin_campus_pulse(user)
    fees = _admin_fee_and_mess_overview(user)
    ageing = _admin_ageing_and_recurring(user, limit=5)

    today_str = datetime.date.today().isoformat()
    report_lines = [
        f"CAMPUSOS EXECUTIVE BRIEFING — {today_str}",
        "",
        "1. Academic & Attendance Operations",
        f"- Total Enrolled Students: {pulse['totalStudents']}",
        f"- Active Attendance Sessions Now: {pulse['activeAttendanceSessions']}",
        "",
        "2. Grievance & SLA Health",
        f"- Total Complaints: {pulse['totalComplaints']} (Pending: {pulse['pendingComplaints']}, In Progress: {pulse['inProgressComplaints']}, Reopened: {pulse['reopenedComplaints']})",
        f"- Ageing (>48h SLA Breach): {pulse['ageingComplaintsOver48h']}",
        f"- Recurring Issue Clusters: {ageing['recurringClusterCount']}",
        "",
        "3. Approvals & Leaves",
        f"- Pending Student Approvals: {pulse['pendingStudentApprovals']}",
        f"- Pending Hostel/Leave Requests: {pulse['pendingLeaveRequests']}",
        "",
        "4. Finance & Mess",
        f"- Fees Collected: ₹{fees['feeTotalCollected']} / ₹{fees['feeTotalBilled']} (Outstanding: ₹{fees['feeTotalOutstanding']}, Overdue: {fees['overdueRecords']})",
        f"- Mess Average Rating: {fees['messAverageRating'] or 'N/A'} (from {fees['messFeedbackSampleSize']} reviews)",
    ]
    return {
        'documentCard': {
            'type': 'document',
            'title': f"Executive Campus Report ({today_str})",
            'subtitle': 'CampusOS Command Summary',
            'badges': ['ADMIN REPORT', f"{pulse['ageingComplaintsOver48h']} Ageing"],
            'content': "\n".join(report_lines),
            'answerKey': None,
        },
        'pulse': pulse,
    }


# ==============================================================================
# TOOL DECLARATIONS & DISPATCH PER ROLE
# ==============================================================================

STUDENT_TOOLS = [
    {
        'type': 'function',
        'name': 'get_my_attendance_summary',
        'description': 'Get the signed-in student overall attendance percentage, per-subject breakdown, and how many classes can be safely skipped or are needed to reach 75%.',
        'parameters': {
            'type': 'object',
            'properties': {
                'subject': {'type': 'string', 'description': 'Optional subject name filter.'},
            },
        },
    },
    {
        'type': 'function',
        'name': 'get_my_notices',
        'description': 'Fetch published campus notices and circulars visible to the signed-in student.',
        'parameters': {
            'type': 'object',
            'properties': {
                'category': {'type': 'string', 'description': 'Optional category like ACADEMIC, EXAM, HOSTEL, MESS, FEE, GENERAL.'},
                'limit': {'type': 'integer', 'description': 'Max notices to return (default 8).'},
            },
        },
    },
    {
        'type': 'function',
        'name': 'get_my_fees',
        'description': 'Get the signed-in student fee summary, total due, overdue flags, and fee records.',
        'parameters': {'type': 'object', 'properties': {}},
    },
    {
        'type': 'function',
        'name': 'get_today_mess_menu',
        'description': "Get today's or latest published campus mess menu meals and dishes.",
        'parameters': {'type': 'object', 'properties': {}},
    },
    {
        'type': 'function',
        'name': 'get_my_requests_status',
        'description': 'Get the signed-in student recent leave requests, complaints, and document requests with statuses.',
        'parameters': {'type': 'object', 'properties': {}},
    },
    {
        'type': 'function',
        'name': 'draft_leave_request',
        'description': 'Draft a hostel/academic leave request for user confirmation before submitting.',
        'parameters': {
            'type': 'object',
            'properties': {
                'leave_type': {'type': 'string', 'description': 'e.g. HOME_VISIT, MEDICAL, ACADEMIC, OUTING'},
                'start_date': {'type': 'string', 'description': 'YYYY-MM-DD start date'},
                'end_date': {'type': 'string', 'description': 'YYYY-MM-DD end date'},
                'reason': {'type': 'string', 'description': 'Reason for leave'},
                'destination': {'type': 'string', 'description': 'Optional destination'},
            },
            'required': ['leave_type', 'start_date', 'end_date', 'reason'],
        },
    },
    {
        'type': 'function',
        'name': 'draft_complaint',
        'description': 'Draft a campus or hostel complaint ticket for user confirmation before filing.',
        'parameters': {
            'type': 'object',
            'properties': {
                'category': {'type': 'string', 'description': 'ELECTRICAL, PLUMBING, INTERNET, HOUSEKEEPING, MAINTENANCE, MESS, SECURITY, OTHER'},
                'title': {'type': 'string', 'description': 'Short complaint title'},
                'description': {'type': 'string', 'description': 'Detailed description of the issue'},
                'location': {'type': 'string', 'description': 'Room, hostel block, or campus location'},
                'priority': {'type': 'string', 'enum': ['LOW', 'MEDIUM', 'HIGH', 'URGENT']},
            },
            'required': ['category', 'title', 'description', 'location'],
        },
    },
    {
        'type': 'function',
        'name': 'draft_document_request',
        'description': 'Draft an official certificate or document request (BONAFIDE_CERTIFICATE, INTERNSHIP_NOC, PROVISIONAL_CERTIFICATE, COURSE_COMPLETION, CONDUCT_CERTIFICATE, FEE_RECEIPT_SUMMARY, HOSTEL_RESIDENCE_CERTIFICATE) for confirmation.',
        'parameters': {
            'type': 'object',
            'properties': {
                'document_type': {'type': 'string'},
                'purpose': {'type': 'string', 'description': 'Reason or purpose for requesting the document'},
            },
            'required': ['document_type', 'purpose'],
        },
    },
    {
        'type': 'function',
        'name': 'format_study_practice_card',
        'description': 'Package generated study practice questions, viva prep, or mock quiz with answer key into a structured study card.',
        'parameters': {
            'type': 'object',
            'properties': {
                'topic': {'type': 'string'},
                'subject': {'type': 'string'},
                'difficulty': {'type': 'string'},
                'questions_markdown': {'type': 'string'},
                'answers_markdown': {'type': 'string'},
            },
            'required': ['topic', 'questions_markdown'],
        },
    },
]

TEACHER_TOOLS = [
    {
        'type': 'function',
        'name': 'get_teacher_sessions_summary',
        'description': "Get the teacher's active sessions, recent attendance sessions, and saved class presets.",
        'parameters': {'type': 'object', 'properties': {}},
    },
    {
        'type': 'function',
        'name': 'get_low_attendance_students',
        'description': 'Find students below an attendance threshold percentage (default 75%).',
        'parameters': {
            'type': 'object',
            'properties': {
                'threshold': {'type': 'number', 'description': 'Percentage threshold, default 75.'},
                'branch': {'type': 'string', 'description': 'Optional branch filter like CSE, ECE.'},
                'year': {'type': 'string', 'description': 'Optional year filter like 3rd.'},
            },
        },
    },
    {
        'type': 'function',
        'name': 'check_student_attendance_issue',
        'description': 'Look up a specific student by name or registration number to inspect device binding, approval status, and recent check-ins.',
        'parameters': {
            'type': 'object',
            'properties': {
                'query': {'type': 'string', 'description': 'Student name, registration number, or email.'},
            },
            'required': ['query'],
        },
    },
    {
        'type': 'function',
        'name': 'draft_attendance_session',
        'description': 'Draft a new live attendance session for teacher confirmation before starting.',
        'parameters': {
            'type': 'object',
            'properties': {
                'subject': {'type': 'string'},
                'course': {'type': 'string'},
                'branch': {'type': 'string'},
                'year': {'type': 'string'},
                'location': {'type': 'string'},
            },
            'required': ['subject'],
        },
    },
    {
        'type': 'function',
        'name': 'draft_class_update',
        'description': 'Draft a class update (ANNOUNCEMENT, CANCELLED, RESCHEDULED, ROOM_CHANGE, TIME_CHANGE) for teacher confirmation.',
        'parameters': {
            'type': 'object',
            'properties': {
                'course_code': {'type': 'string'},
                'course_name': {'type': 'string'},
                'update_type': {'type': 'string', 'enum': ['ANNOUNCEMENT', 'CANCELLED', 'RESCHEDULED', 'ROOM_CHANGE', 'TIME_CHANGE']},
                'message': {'type': 'string'},
                'affected_branch': {'type': 'string'},
                'affected_year': {'type': 'string'},
            },
            'required': ['course_code', 'course_name', 'update_type', 'message'],
        },
    },
    {
        'type': 'function',
        'name': 'draft_targeted_notice',
        'description': 'Draft a targeted notice for a specific BRANCH, YEAR, or STUDENT (teachers cannot target ALL) for confirmation.',
        'parameters': {
            'type': 'object',
            'properties': {
                'title': {'type': 'string'},
                'body': {'type': 'string'},
                'target_type': {'type': 'string', 'enum': ['BRANCH', 'YEAR', 'STUDENT']},
                'target_value': {'type': 'string'},
                'category': {'type': 'string'},
                'priority': {'type': 'string', 'enum': ['NORMAL', 'HIGH', 'URGENT']},
            },
            'required': ['title', 'body', 'target_type', 'target_value'],
        },
    },
    {
        'type': 'function',
        'name': 'format_assessment_paper',
        'description': 'Package a complete teacher-authored exam paper, quiz, question bank, or assignment with sections, marks, and optional answer key into a structured copyable document card.',
        'parameters': {
            'type': 'object',
            'properties': {
                'title': {'type': 'string'},
                'subject': {'type': 'string'},
                'assessment_type': {'type': 'string', 'description': 'MID_SEM_EXAM, END_SEM_EXAM, QUIZ, ASSIGNMENT, LAB_TEST, VIVA'},
                'total_marks': {'type': 'integer'},
                'duration_minutes': {'type': 'integer'},
                'difficulty': {'type': 'string', 'description': 'Easy, Balanced, Challenging'},
                'paper_markdown': {'type': 'string', 'description': 'Full formatted question paper with sections and marks per question'},
                'answer_key_markdown': {'type': 'string', 'description': 'Marking scheme and answers'},
            },
            'required': ['title', 'subject', 'paper_markdown'],
        },
    },
    {
        'type': 'function',
        'name': 'format_lesson_plan',
        'description': 'Package a structured lecture plan (learning objectives, topic timeline, examples, and exit-ticket questions) into a copyable document card.',
        'parameters': {
            'type': 'object',
            'properties': {
                'topic': {'type': 'string'},
                'subject': {'type': 'string'},
                'duration_minutes': {'type': 'integer'},
                'plan_markdown': {'type': 'string'},
            },
            'required': ['topic', 'subject', 'plan_markdown'],
        },
    },
    {
        'type': 'function',
        'name': 'get_class_cohort_health',
        'description': 'Get attendance health distribution (>=85% Good, 75-84% Borderline, <75% At Risk) for a class cohort.',
        'parameters': {
            'type': 'object',
            'properties': {
                'branch': {'type': 'string'},
                'year': {'type': 'string'},
            },
        },
    },
    {
        'type': 'function',
        'name': 'draft_reset_student_device',
        'description': 'Draft a student device binding reset when a student changed phones or is locked out of attendance check-in.',
        'parameters': {
            'type': 'object',
            'properties': {
                'student_query': {'type': 'string', 'description': 'Student name, registration number, or email'},
                'reason': {'type': 'string'},
            },
            'required': ['student_query'],
        },
    },
]

ADMIN_TOOLS = [
    {
        'type': 'function',
        'name': 'get_campus_pulse',
        'description': 'Get campus-wide operational metrics: active sessions, complaints by status, >48h ageing count, pending student approvals, and pending leaves.',
        'parameters': {'type': 'object', 'properties': {}},
    },
    {
        'type': 'function',
        'name': 'get_ageing_and_recurring_complaints',
        'description': 'Inspect complaints ageing over 48 hours and recurring complaint clusters.',
        'parameters': {
            'type': 'object',
            'properties': {
                'limit': {'type': 'integer', 'description': 'Max ageing complaints to list (default 8).'},
            },
        },
    },
    {
        'type': 'function',
        'name': 'get_pending_student_approvals',
        'description': 'List student registrations currently awaiting admin approval.',
        'parameters': {'type': 'object', 'properties': {}},
    },
    {
        'type': 'function',
        'name': 'get_fee_and_mess_overview',
        'description': 'Get campus-wide fee collection/overdue totals and recent mess feedback average rating.',
        'parameters': {'type': 'object', 'properties': {}},
    },
    {
        'type': 'function',
        'name': 'draft_campus_notice',
        'description': 'Draft a campus notice or circular for ALL, BRANCH, YEAR, or STUDENT for admin confirmation.',
        'parameters': {
            'type': 'object',
            'properties': {
                'title': {'type': 'string'},
                'body': {'type': 'string'},
                'target_type': {'type': 'string', 'enum': ['ALL', 'BRANCH', 'YEAR', 'STUDENT']},
                'target_value': {'type': 'string'},
                'category': {'type': 'string'},
                'priority': {'type': 'string', 'enum': ['NORMAL', 'HIGH', 'URGENT']},
            },
            'required': ['title', 'body'],
        },
    },
    {
        'type': 'function',
        'name': 'draft_complaint_escalation',
        'description': 'Draft an escalation of a complaint to URGENT priority and Level 3 Dean Slingshot for admin confirmation.',
        'parameters': {
            'type': 'object',
            'properties': {
                'complaint_id': {'type': 'string'},
                'action_note': {'type': 'string'},
            },
            'required': ['complaint_id'],
        },
    },
    {
        'type': 'function',
        'name': 'draft_approve_student',
        'description': 'Draft approval of a pending student registration account for admin confirmation.',
        'parameters': {
            'type': 'object',
            'properties': {
                'student_query': {'type': 'string', 'description': 'Student name, registration number, or email (optional to pick oldest pending)'},
            },
        },
    },
    {
        'type': 'function',
        'name': 'generate_executive_report',
        'description': 'Generate a comprehensive copyable Executive Campus Briefing report combining attendance, complaints SLA, approvals, fees, and mess ratings.',
        'parameters': {'type': 'object', 'properties': {}},
    },
]


def get_tools_for_role(role: str) -> list[dict]:
    if role == 'student':
        return STUDENT_TOOLS
    if role == 'teacher':
        return TEACHER_TOOLS
    if role == 'admin':
        return ADMIN_TOOLS
    return []


def execute_tool(role: str, user: User, name: str, arguments: dict | None) -> dict:
    args = arguments or {}

    if role == 'student':
        if name == 'get_my_attendance_summary':
            return _student_attendance_summary(user, subject=args.get('subject'))
        if name == 'get_my_notices':
            return _student_notices(user, category=args.get('category'), limit=int(args.get('limit') or 8))
        if name == 'get_my_fees':
            return _student_fees(user)
        if name == 'get_today_mess_menu':
            return _today_mess_menu()
        if name == 'get_my_requests_status':
            return _student_requests_status(user)
        if name == 'draft_leave_request':
            return _student_draft_leave(
                user,
                leave_type=args.get('leave_type', 'HOME_VISIT'),
                start_date=args.get('start_date', ''),
                end_date=args.get('end_date', ''),
                reason=args.get('reason', 'Personal leave'),
                destination=args.get('destination'),
            )
        if name == 'draft_complaint':
            return _student_draft_complaint(
                user,
                category=args.get('category', 'MAINTENANCE'),
                title=args.get('title', 'Campus Issue'),
                description=args.get('description', ''),
                location=args.get('location', 'Campus'),
                priority=args.get('priority', 'MEDIUM'),
            )
        if name == 'draft_document_request':
            return _student_draft_document_request(
                user,
                document_type=args.get('document_type', 'BONAFIDE_CERTIFICATE'),
                purpose=args.get('purpose', 'Official purpose'),
            )
        if name == 'format_study_practice_card':
            return _student_format_study_practice(
                topic=args.get('topic', 'Topic'),
                subject=args.get('subject', 'Study'),
                difficulty=args.get('difficulty', 'Medium'),
                questions_markdown=args.get('questions_markdown', ''),
                answers_markdown=args.get('answers_markdown', ''),
            )

    elif role == 'teacher':
        if name == 'get_teacher_sessions_summary':
            return _teacher_sessions_summary(user)
        if name == 'get_low_attendance_students':
            return _teacher_low_attendance_students(
                user,
                threshold=_safe_float(args.get('threshold'), 75.0),
                branch=args.get('branch'),
                year=args.get('year'),
            )
        if name == 'check_student_attendance_issue':
            return _teacher_check_student_issue(user, query=args.get('query', ''))
        if name == 'draft_attendance_session':
            return _teacher_draft_session(
                user,
                subject=args.get('subject', 'Lecture'),
                course=args.get('course', 'B.Tech'),
                branch=args.get('branch', user.branch or 'CSE'),
                year=args.get('year', user.year or '3rd'),
                location=args.get('location', 'Room 204'),
            )
        if name == 'draft_class_update':
            return _teacher_draft_class_update(
                user,
                course_code=args.get('course_code', 'CS101'),
                course_name=args.get('course_name', 'Course'),
                update_type=args.get('update_type', 'ANNOUNCEMENT'),
                message=args.get('message', ''),
                affected_branch=args.get('affected_branch', user.branch or 'ALL'),
                affected_year=args.get('affected_year'),
            )
        if name == 'draft_targeted_notice':
            return _teacher_draft_notice(
                user,
                title=args.get('title', 'Notice'),
                body=args.get('body', ''),
                target_type=args.get('target_type', 'BRANCH'),
                target_value=args.get('target_value', user.branch or 'CSE'),
                category=args.get('category', 'ACADEMIC'),
                priority=args.get('priority', 'NORMAL'),
            )
        if name == 'format_assessment_paper':
            return _teacher_format_assessment_paper(
                title=args.get('title', 'Assessment Paper'),
                subject=args.get('subject', 'Course'),
                assessment_type=args.get('assessment_type', 'MID_SEM_EXAM'),
                total_marks=int(args.get('total_marks') or 30),
                duration_minutes=int(args.get('duration_minutes') or 60),
                difficulty=args.get('difficulty', 'Balanced'),
                paper_markdown=args.get('paper_markdown', ''),
                answer_key_markdown=args.get('answer_key_markdown', ''),
            )
        if name == 'format_lesson_plan':
            return _teacher_format_lesson_plan(
                topic=args.get('topic', 'Lecture'),
                subject=args.get('subject', 'Course'),
                duration_minutes=int(args.get('duration_minutes') or 50),
                plan_markdown=args.get('plan_markdown', ''),
            )
        if name == 'get_class_cohort_health':
            return _teacher_class_cohort_health(
                user,
                branch=args.get('branch'),
                year=args.get('year'),
            )
        if name == 'draft_reset_student_device':
            return _teacher_draft_reset_device(
                user,
                student_query=args.get('student_query', ''),
                reason=args.get('reason', ''),
            )

    elif role == 'admin':
        if name == 'get_campus_pulse':
            return _admin_campus_pulse(user)
        if name == 'get_ageing_and_recurring_complaints':
            return _admin_ageing_and_recurring(user, limit=int(args.get('limit') or 8))
        if name == 'get_pending_student_approvals':
            return _admin_pending_student_approvals(user)
        if name == 'get_fee_and_mess_overview':
            return _admin_fee_and_mess_overview(user)
        if name == 'draft_campus_notice':
            return _admin_draft_notice(
                user,
                title=args.get('title', 'Campus Notice'),
                body=args.get('body', ''),
                target_type=args.get('target_type', 'ALL'),
                target_value=args.get('target_value'),
                category=args.get('category', 'GENERAL'),
                priority=args.get('priority', 'NORMAL'),
            )
        if name == 'draft_complaint_escalation':
            return _admin_draft_complaint_escalation(
                user,
                complaint_id=args.get('complaint_id', ''),
                action_note=args.get('action_note', 'Escalated by Admin via CampusOS Copilot'),
            )
        if name == 'draft_approve_student':
            return _admin_draft_approve_student(
                user,
                student_query=args.get('student_query', ''),
            )
        if name == 'generate_executive_report':
            return _admin_generate_executive_report(user)

    return {'error': f"Tool '{name}' is not available for role '{role}'."}


# ==============================================================================
# CONFIRM & EXECUTE PENDING ACTION
# ==============================================================================

def execute_pending_action(
    user: User,
    role: str,
    action_id: str,
    remote_addr: str | None = None,
) -> tuple[dict, int]:
    with _pending_lock:
        _cleanup_expired_actions()
        entry = _pending_actions.get(action_id)
        if not entry:
            return {'message': 'Pending action not found or expired.'}, 404
        if entry['userId'] != user.id or entry['role'] != role:
            return {'message': 'Forbidden: Action belongs to another user or role.'}, 403
        if entry.get('status') == 'EXECUTED':
            return {'message': 'Action already executed.', 'result': entry.get('result')}, 200
        # Pop or mark executing
        action_type = entry['actionType']
        payload = dict(entry['payload'])

    try:
        result_data = {}
        human_msg = 'Action completed.'

        if action_type == 'SUBMIT_LEAVE_REQUEST' and role == 'student':
            new_leave = LeaveRequest(
                student_id=user.id,
                leave_type=payload['leaveType'],
                start_date=payload['startDate'],
                end_date=payload['endDate'],
                reason=payload['reason'],
                destination=payload.get('destination'),
                status='PENDING',
            )
            db.session.add(new_leave)
            db.session.flush()
            db.session.add(RequestAudit(
                entity_type='LEAVE',
                entity_id=new_leave.id,
                actor_id=user.id,
                action='SUBMITTED',
                remarks=f"[via Copilot] Submitted leave request for {payload['leaveType']}",
                ip_address=remote_addr,
            ))
            db.session.commit()
            result_data = {'leave': new_leave.to_dict()}
            human_msg = f"Leave request submitted ({payload['startDate']} to {payload['endDate']})."

        elif action_type == 'CREATE_COMPLAINT' and role == 'student':
            new_comp = Complaint(
                student_id=user.id,
                category=payload['category'],
                title=payload['title'],
                description=payload['description'],
                location=payload['location'],
                priority=payload['priority'],
                status='PENDING',
                closure_otp=generate_closure_pin(),
            )
            db.session.add(new_comp)
            db.session.flush()
            db.session.add(ComplaintStatusHistory(
                complaint_id=new_comp.id,
                changed_by=user.id,
                old_status=None,
                new_status='PENDING',
                comment='Complaint submitted via CampusOS Copilot',
            ))
            db.session.add(RequestAudit(
                entity_type='COMPLAINT',
                entity_id=new_comp.id,
                actor_id=user.id,
                action='SUBMITTED',
                remarks=f"[via Copilot] Submitted complaint: {payload['title']}",
                ip_address=remote_addr,
            ))
            db.session.commit()
            result_data = {'complaint': new_comp.to_dict(requester_role=role, requester_id=user.id)}
            human_msg = f"Complaint filed under {payload['category']} (PIN: {new_comp.closure_otp})."

        elif action_type == 'CREATE_ATTENDANCE_SESSION' and role == 'teacher':
            prior = Session.query.filter_by(teacher_id=user.id, is_active=True).all()
            for ps in prior:
                ps.is_active = False
            now_dt = datetime.datetime.now()
            new_session = Session(
                name=payload['name'],
                subject=payload['subject'],
                instructor_name=user.name,
                course=payload.get('course'),
                branch=payload.get('branch'),
                year=payload.get('year'),
                start_time=now_dt.isoformat(),
                end_time=(now_dt + datetime.timedelta(hours=1)).isoformat(),
                location=payload.get('location') or 'Room 204',
                teacher_id=user.id,
            )
            db.session.add(new_session)
            db.session.flush()
            db.session.add(RequestAudit(
                entity_type='SESSION',
                entity_id=new_session.id,
                actor_id=user.id,
                action='CREATED',
                remarks=f"[via Copilot] Started session {payload['subject']}",
                ip_address=remote_addr,
            ))
            db.session.commit()
            result_data = {'session': new_session.to_dict()}
            human_msg = f"Attendance session started for {payload['subject']} in {new_session.location}."

        elif action_type == 'POST_CLASS_UPDATE' and role in ('teacher', 'admin'):
            upd = ClassUpdate(
                teacher_id=user.id,
                course_code=payload['courseCode'],
                course_name=payload['courseName'],
                update_type=payload['updateType'],
                original_date=datetime.date.today().isoformat(),
                message=payload['message'],
                affected_branch=payload.get('affectedBranch') or 'ALL',
                affected_year=payload.get('affectedYear'),
                status='ACTIVE',
            )
            db.session.add(upd)
            db.session.flush()
            db.session.add(RequestAudit(
                entity_type='CLASS_UPDATE',
                entity_id=upd.id,
                actor_id=user.id,
                action=payload['updateType'],
                remarks=f"[via Copilot] {payload['courseCode']}: {payload['message'][:80]}",
                ip_address=remote_addr,
            ))
            # Notify matching students
            q = User.query.filter_by(role='student')
            if upd.affected_branch and upd.affected_branch.upper() != 'ALL':
                q = q.filter(User.branch.ilike(upd.affected_branch))
            if upd.affected_year:
                q = q.filter(User.year.ilike(str(upd.affected_year)))
            students = q.all()
            for st in students:
                db.session.add(NotificationDelivery(
                    user_id=st.id,
                    title=f"{upd.course_code}: {upd.update_type}",
                    body=upd.message,
                    category='ACADEMIC',
                    priority='NORMAL',
                ))
            db.session.commit()
            result_data = {'classUpdate': upd.to_dict(), 'notifiedCount': len(students)}
            human_msg = f"Class update posted for {upd.course_code} ({len(students)} students notified)."

        elif action_type == 'PUBLISH_NOTICE' and role in ('teacher', 'admin'):
            if role == 'teacher' and payload.get('targetType') == 'ALL':
                return {'message': 'Forbidden: Teachers cannot publish notices to ALL.'}, 403
            notice = Notice(
                title=payload['title'],
                body=payload['body'],
                content=payload['body'],
                category=payload.get('category') or 'GENERAL',
                priority=payload.get('priority') or 'NORMAL',
                target_type=payload.get('targetType') or 'ALL',
                target_value=payload.get('targetValue'),
                status='PUBLISHED',
                created_by=user.id,
                published_by=user.id,
            )
            db.session.add(notice)
            db.session.commit()
            delivery_count = sync_notice_deliveries(notice)
            db.session.add(RequestAudit(
                entity_type='NOTICE',
                entity_id=notice.id,
                actor_id=user.id,
                action='PUBLISHED',
                remarks=f"[via Copilot] Published notice: {notice.title}",
                ip_address=remote_addr,
            ))
            db.session.commit()
            n_dict = notice.to_dict()
            n_dict['recipientCount'] = delivery_count
            result_data = {'notice': n_dict}
            human_msg = f"Notice '{notice.title}' published to {delivery_count} recipient(s)."

        elif action_type == 'ESCALATE_COMPLAINT' and role == 'admin':
            comp = Complaint.query.get(payload['complaintId'])
            if not comp:
                return {'message': 'Complaint no longer exists.'}, 404
            comp.priority = 'URGENT'
            comp.escalation_level = 3
            comp.escalated_at = datetime.datetime.now().isoformat()
            db.session.add(ComplaintStatusHistory(
                complaint_id=comp.id,
                changed_by=user.id,
                old_status=comp.status,
                new_status=comp.status,
                comment=f"[via Copilot] {payload.get('actionNote', 'Escalated to Level 3 Urgent')}",
            ))
            db.session.add(RequestAudit(
                entity_type='COMPLAINT',
                entity_id=comp.id,
                actor_id=user.id,
                action='ESCALATED',
                remarks=f"[via Copilot] Escalated to URGENT Level 3: {payload.get('actionNote', '')}",
                ip_address=remote_addr,
            ))
            db.session.commit()
            result_data = {'complaint': comp.to_dict(requester_role=role, requester_id=user.id)}
            human_msg = f"Complaint '{comp.title}' escalated to URGENT (Level 3)."

        elif action_type == 'REQUEST_DOCUMENT' and role == 'student':
            new_doc = DocumentRequest(
                student_id=user.id,
                document_type=payload['documentType'],
                purpose=payload['purpose'],
                status='PENDING',
            )
            db.session.add(new_doc)
            db.session.flush()
            db.session.add(RequestAudit(
                entity_type='DOCUMENT_REQUEST',
                entity_id=new_doc.id,
                actor_id=user.id,
                action='SUBMITTED',
                remarks=f"[via Copilot] Requested {payload['documentTypeName']}: {payload['purpose']}",
                ip_address=remote_addr,
            ))
            db.session.commit()
            result_data = {'documentRequest': new_doc.to_dict()}
            human_msg = f"{payload['documentTypeName']} request submitted."

        elif action_type == 'RESET_STUDENT_DEVICE' and role in ('teacher', 'admin'):
            student = User.query.get(payload['studentId'])
            if not student:
                return {'message': 'Student account not found.'}, 404
            student.device_id = None
            db.session.add(RequestAudit(
                entity_type='DEVICE_RESET',
                entity_id=student.id,
                actor_id=user.id,
                action='RESET',
                remarks=f"[via Copilot] Reset device binding for {student.name}: {payload.get('reason', '')}",
                ip_address=remote_addr,
            ))
            db.session.commit()
            result_data = {'studentId': student.id, 'studentName': student.name}
            human_msg = f"Device binding reset for {student.name}. They can check in from their new device."

        elif action_type == 'APPROVE_STUDENT_REGISTRATION' and role == 'admin':
            student = User.query.filter_by(id=payload['studentId'], role='student').first()
            if not student:
                return {'message': 'Student account not found.'}, 404
            student.approval_status = 'APPROVED'
            student.approved_by = user.id
            student.approved_at = datetime.datetime.now().isoformat()
            student.rejection_reason = None
            db.session.add(RequestAudit(
                entity_type='STUDENT_REGISTRATION',
                entity_id=student.id,
                actor_id=user.id,
                action='APPROVED',
                remarks=f"[via Copilot] Approved registration for {student.name}",
                ip_address=remote_addr,
            ))
            db.session.commit()
            result_data = {'student': student.to_dict()}
            human_msg = f"Approved and activated {student.name}'s student account."

        else:
            return {'message': f"Unsupported action '{action_type}' for role '{role}'."}, 400

        with _pending_lock:
            if action_id in _pending_actions:
                _pending_actions[action_id]['status'] = 'EXECUTED'
                _pending_actions[action_id]['result'] = result_data

        return {
            'status': 'EXECUTED',
            'actionId': action_id,
            'actionType': action_type,
            'message': human_msg,
            'result': result_data,
        }, 200

    except Exception as e:
        db.session.rollback()
        return {'message': f"Failed to execute action: {str(e)}"}, 500
