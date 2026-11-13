import datetime
from sqlalchemy import func
from flask import Blueprint, request, jsonify
from werkzeug.security import generate_password_hash
from extensions import db
from models.user import User
from models.complaint import Complaint
from models.audit import ComplaintStatusHistory, RequestAudit
from middleware.auth import verify_admin_access, get_authenticated_user_from_token
from services.complaint_service import (
    COMPLAINT_AGEING_HOURS,
    _format_admin_complaint,
    compute_recurring_complaint_clusters
)

admin_bp = Blueprint('admin_bp', __name__)

ALLOWED_USER_ROLES = {
    'admin', 'dean', 'administrator', 'superadmin', 'warden', 'staff',
    'teacher', 'faculty', 'security', 'guard', 'security_guard',
    'mess_staff', 'mess', 'student'
}


@admin_bp.route('/admin/dashboard/summary', methods=['GET'])
def get_admin_dashboard_summary():
    authorized, err_resp = verify_admin_access()
    if not authorized:
        return err_resp

    status_counts = dict(
        db.session.query(Complaint.status, func.count(Complaint.id))
        .group_by(Complaint.status).all()
    )
    total_complaints = sum(status_counts.values())

    pending_complaints = status_counts.get('PENDING', 0)
    assigned_complaints = status_counts.get('ASSIGNED', 0)
    in_progress_complaints = status_counts.get('IN_PROGRESS', 0)
    resolved_complaints = status_counts.get('RESOLVED', 0)
    closed_complaints = status_counts.get('CLOSED', 0)
    reopened_complaints = status_counts.get('REOPENED', 0)
    rejected_complaints = status_counts.get('REJECTED', 0)

    now = datetime.datetime.now()
    cutoff_iso = (now - datetime.timedelta(hours=COMPLAINT_AGEING_HOURS)).isoformat()

    ageing_complaints = Complaint.query.filter(
        Complaint.status.in_(['PENDING', 'ASSIGNED', 'IN_PROGRESS', 'REOPENED']),
        Complaint.created_at < cutoff_iso
    ).count()

    # Optimized: fetch only timestamp columns instead of full Complaint objects
    resolved_timestamps = Complaint.query.filter(
        Complaint.resolved_at.isnot(None),
        Complaint.status.in_(['RESOLVED', 'CLOSED'])
    ).with_entities(Complaint.created_at, Complaint.resolved_at).all()

    resolution_hours_list = []
    for created_at, resolved_at in resolved_timestamps:
        if created_at and resolved_at:
            try:
                c_dt = datetime.datetime.fromisoformat(created_at)
                r_dt = datetime.datetime.fromisoformat(resolved_at)
                diff = (r_dt - c_dt).total_seconds() / 3600.0
                resolution_hours_list.append(max(0.0, diff))
            except Exception:
                pass

    if resolution_hours_list:
        average_resolution_hours = round(sum(resolution_hours_list) / len(resolution_hours_list), 1)
    else:
        average_resolution_hours = 0

    pending_student_approvals = User.query.filter(
        User.role == 'student',
        User.approval_status == 'PENDING'
    ).count()

    return jsonify({
        "totalComplaints": total_complaints,
        "pendingComplaints": pending_complaints,
        "assignedComplaints": assigned_complaints,
        "inProgressComplaints": in_progress_complaints,
        "resolvedComplaints": resolved_complaints,
        "closedComplaints": closed_complaints,
        "reopenedComplaints": reopened_complaints,
        "rejectedComplaints": rejected_complaints,
        "ageingComplaints": ageing_complaints,
        "averageResolutionHours": average_resolution_hours,
        "pendingStudentApprovals": pending_student_approvals
    }), 200


@admin_bp.route('/admin/complaints/ageing', methods=['GET'])
def get_admin_complaints_ageing():
    authorized, err_resp = verify_admin_access()
    if not authorized:
        return err_resp

    now = datetime.datetime.now()
    cutoff_iso = (now - datetime.timedelta(hours=COMPLAINT_AGEING_HOURS)).isoformat()

    ageing_records = Complaint.query.filter(
        Complaint.status.in_(['PENDING', 'ASSIGNED', 'IN_PROGRESS', 'REOPENED']),
        Complaint.created_at < cutoff_iso
    ).order_by(Complaint.created_at.asc()).all()

    results = []
    for c in ageing_records:
        age_hours = 0.0
        try:
            c_dt = datetime.datetime.fromisoformat(c.created_at)
            age_hours = round(max(0.0, (now - c_dt).total_seconds() / 3600.0), 1)
        except Exception:
            pass

        assigned_to_name = None
        if c.assigned_to:
            staff = User.query.get(c.assigned_to)
            if staff:
                assigned_to_name = staff.name

        results.append({
            "id": c.id,
            "complaintId": c.id,
            "title": c.title,
            "category": c.category,
            "priority": c.priority,
            "status": c.status,
            "createdAt": c.created_at,
            "ageHours": age_hours,
            "assignedTo": c.assigned_to,
            "assignedToName": assigned_to_name,
            "thresholdHours": COMPLAINT_AGEING_HOURS
        })

    return jsonify(results), 200


@admin_bp.route('/admin/complaints/workload', methods=['GET'])
def get_admin_complaints_workload():
    authorized, err_resp = verify_admin_access()
    if not authorized:
        return err_resp

    staff_users = User.query.filter(User.role.in_(['teacher', 'faculty', 'admin', 'warden', 'staff'])).all()
    assigned_user_ids = [
        r[0] for r in db.session.query(Complaint.assigned_to)
        .filter(Complaint.assigned_to.isnot(None)).distinct().all()
    ]
    all_staff_dict = {u.id: u for u in staff_users}
    for uid in assigned_user_ids:
        if uid not in all_staff_dict:
            extra_user = User.query.get(uid)
            if extra_user:
                all_staff_dict[uid] = extra_user

    counts_query = db.session.query(
        Complaint.assigned_to,
        Complaint.status,
        func.count(Complaint.id)
    ).filter(
        Complaint.assigned_to.isnot(None)
    ).group_by(
        Complaint.assigned_to,
        Complaint.status
    ).all()

    workload_map = {}
    for assigned_to, status, count in counts_query:
        if assigned_to not in workload_map:
            workload_map[assigned_to] = {'ASSIGNED': 0, 'IN_PROGRESS': 0, 'RESOLVED': 0, 'CLOSED': 0}
        workload_map[assigned_to][status] = count

    workload_results = []
    for staff_id, staff in all_staff_dict.items():
        counts = workload_map.get(staff_id, {})
        assigned_cnt = counts.get('ASSIGNED', 0)
        in_progress_cnt = counts.get('IN_PROGRESS', 0)
        resolved_cnt = counts.get('RESOLVED', 0) + counts.get('CLOSED', 0)
        total_active = assigned_cnt + in_progress_cnt

        workload_results.append({
            "staffId": staff_id,
            "staffName": staff.name,
            "staffRole": staff.role,
            "assignedCount": assigned_cnt,
            "inProgressCount": in_progress_cnt,
            "resolvedCount": resolved_cnt,
            "totalActive": total_active
        })

    workload_results.sort(key=lambda x: (x['totalActive'], x['assignedCount']), reverse=True)
    return jsonify(workload_results), 200


@admin_bp.route('/admin/complaints/categories', methods=['GET'])
def get_admin_complaints_categories():
    authorized, err_resp = verify_admin_access()
    if not authorized:
        return err_resp

    cat_counts = db.session.query(
        Complaint.category,
        func.count(Complaint.id)
    ).group_by(
        Complaint.category
    ).order_by(
        func.count(Complaint.id).desc()
    ).all()

    results = [{"category": row[0], "count": row[1]} for row in cat_counts]
    return jsonify(results), 200


@admin_bp.route('/admin/staff', methods=['GET'])
def get_admin_staff():
    authorized, err_resp = verify_admin_access()
    if not authorized:
        return err_resp

    staff_members = User.query.filter(User.role != 'student').order_by(User.name.asc()).all()
    results = [
        {
            "id": u.id,
            "name": u.name,
            "email": u.email,
            "role": u.role,
            "branch": u.branch,
            "course": u.course
        }
        for u in staff_members
    ]
    return jsonify(results), 200


@admin_bp.route('/admin/complaints', methods=['GET'])
def get_admin_complaints():
    authorized, err_resp = verify_admin_access()
    if not authorized:
        return err_resp

    now = datetime.datetime.now()
    cutoff_iso = (now - datetime.timedelta(hours=COMPLAINT_AGEING_HOURS)).isoformat()

    query = Complaint.query

    status_filter = request.args.get('status')
    if status_filter:
        query = query.filter(Complaint.status == status_filter.strip().upper())

    priority_filter = request.args.get('priority')
    if priority_filter:
        query = query.filter(Complaint.priority == priority_filter.strip().upper())

    category_filter = request.args.get('category')
    if category_filter:
        query = query.filter(Complaint.category == category_filter.strip())

    assigned_to_filter = request.args.get('assignedTo')
    if assigned_to_filter:
        query = query.filter(Complaint.assigned_to == assigned_to_filter.strip())

    ageing_filter = request.args.get('ageing')
    if ageing_filter and ageing_filter.lower() in ['true', '1', 'yes']:
        query = query.filter(
            Complaint.status.in_(['PENDING', 'ASSIGNED', 'IN_PROGRESS', 'REOPENED']),
            Complaint.created_at < cutoff_iso
        )

    search = request.args.get('search')
    if search and search.strip():
        search_term = f"%{search.strip()}%"
        query = query.filter(
            db.or_(
                Complaint.title.ilike(search_term),
                Complaint.description.ilike(search_term),
                Complaint.location.ilike(search_term),
                Complaint.id.ilike(search_term)
            )
        )

    order = (request.args.get('order') or request.args.get('orderBy') or 'newest').lower()
    if order == 'oldest':
        query = query.order_by(Complaint.created_at.asc())
    elif order == 'priority':
        priority_order = db.case(
            (Complaint.priority == 'URGENT', 1),
            (Complaint.priority == 'HIGH', 2),
            (Complaint.priority == 'MEDIUM', 3),
            (Complaint.priority == 'LOW', 4),
            else_=5
        )
        query = query.order_by(priority_order, Complaint.created_at.desc())
    elif order == 'ageing':
        query = query.order_by(Complaint.created_at.asc())
    else:  # newest
        query = query.order_by(Complaint.created_at.desc())

    complaints = query.all()
    return jsonify([_format_admin_complaint(c, now) for c in complaints]), 200


@admin_bp.route('/admin/complaints/recurring', methods=['GET'])
def get_admin_recurring_complaints():
    authorized, err_resp = verify_admin_access()
    if not authorized:
        return err_resp

    category_filter = request.args.get('category')
    location_filter = request.args.get('location')
    status_filter = request.args.get('status')
    order = (request.args.get('order') or request.args.get('orderBy') or 'default').lower()

    clusters = compute_recurring_complaint_clusters(
        category_filter=category_filter,
        location_filter=location_filter,
        status_filter=status_filter
    )

    priority_map = {'URGENT': 0, 'HIGH': 1, 'MEDIUM': 2, 'LOW': 3}
    if order == 'complaintcount':
        clusters.sort(key=lambda x: x['complaintCount'], reverse=True)
    elif order == 'latestcomplaint':
        clusters.sort(key=lambda x: x['latestComplaintAt'], reverse=True)
    elif order == 'averageresolution':
        clusters.sort(key=lambda x: x['averageResolutionHours'], reverse=True)
    elif order == 'priority':
        clusters.sort(key=lambda x: priority_map.get(x['highestPriority'], 4))
    else:  # default: ACTIVE first, then latestComplaintAt desc
        clusters.sort(key=lambda x: (x['recurrenceStatus'] == 'ACTIVE', x['latestComplaintAt']), reverse=True)

    results = [{k: v for k, v in c.items() if k != '_complaints'} for c in clusters]
    return jsonify(results), 200


@admin_bp.route('/admin/complaints/recurring/<recurrence_id>', methods=['GET'])
def get_admin_recurring_complaint_detail(recurrence_id):
    authorized, err_resp = verify_admin_access()
    if not authorized:
        return err_resp

    clusters = compute_recurring_complaint_clusters()
    target_cluster = next((c for c in clusters if c['recurrenceId'] == recurrence_id.strip().lower()), None)

    if not target_cluster:
        return jsonify({"message": f"Recurring issue '{recurrence_id}' not found"}), 404

    complaints_data = []
    for c in target_cluster['_complaints']:
        c_dict = _format_admin_complaint(c)
        # Include brief status history for each complaint in cluster
        history_records = ComplaintStatusHistory.query.filter_by(complaint_id=c.id).order_by(ComplaintStatusHistory.timestamp.asc()).all()
        hist_list = []
        for h in history_records:
            h_data = h.to_dict()
            actor = User.query.get(h.changed_by)
            if actor:
                h_data['actorName'] = actor.name
                h_data['actorRole'] = actor.role
            hist_list.append(h_data)
        c_dict['statusHistory'] = hist_list
        complaints_data.append(c_dict)

    summary = {k: v for k, v in target_cluster.items() if k != '_complaints'}

    return jsonify({
        "recurrence": summary,
        "complaints": complaints_data
    }), 200


@admin_bp.route('/admin/complaints/<id>', methods=['GET'])
def get_admin_complaint_detail(id):
    authorized, err_resp = verify_admin_access()
    if not authorized:
        return err_resp

    complaint = Complaint.query.get(id)
    if not complaint:
        return jsonify({"message": "Complaint not found"}), 404

    complaint_data = _format_admin_complaint(complaint)

    student = User.query.get(complaint.student_id)
    student_data = None
    if student:
        student_data = {
            "id": student.id,
            "name": student.name,
            "email": student.email,
            "registrationNumber": student.registration_number,
            "branch": student.branch,
            "year": student.year,
            "course": student.course
        }

    assigned_staff_data = None
    if complaint.assigned_to:
        staff = User.query.get(complaint.assigned_to)
        if staff:
            assigned_staff_data = {
                "id": staff.id,
                "name": staff.name,
                "email": staff.email,
                "role": staff.role
            }

    history_records = ComplaintStatusHistory.query.filter_by(
        complaint_id=id
    ).order_by(ComplaintStatusHistory.timestamp.asc()).all()

    history_list = []
    for h in history_records:
        h_dict = h.to_dict()
        actor = User.query.get(h.changed_by)
        if actor:
            h_dict['actorName'] = actor.name
            h_dict['actorRole'] = actor.role
        history_list.append(h_dict)

    audit_records = RequestAudit.query.filter_by(
        entity_type='COMPLAINT',
        entity_id=id
    ).order_by(RequestAudit.timestamp.asc()).all()

    audit_list = []
    for a in audit_records:
        a_dict = a.to_dict()
        actor = User.query.get(a.actor_id)
        if actor:
            a_dict['actorName'] = actor.name
            a_dict['actorRole'] = actor.role
        audit_list.append(a_dict)

    return jsonify({
        "complaint": complaint_data,
        "student": student_data,
        "assignedStaff": assigned_staff_data,
        "statusHistory": history_list,
        "auditHistory": audit_list
    }), 200


# --- STEP 21B: NOTICE MANAGEMENT & TARGETING ROUTES ---

SUPPORTED_NOTICE_PRIORITIES = {'NORMAL', 'HIGH', 'URGENT'}
SUPPORTED_NOTICE_CATEGORIES = {
    'GENERAL', 'ACADEMIC', 'EXAM', 'HOSTEL', 'MESS', 'SECURITY', 'EVENT', 'FEE', 'OTHER'
}
SUPPORTED_NOTICE_TARGET_TYPES = {'ALL', 'BRANCH', 'YEAR', 'HOSTEL', 'STUDENT'}
SUPPORTED_NOTICE_STATUSES = {'DRAFT', 'PUBLISHED', 'ARCHIVED', 'EXPIRED'}


# --- STUDENT REGISTRATION APPROVAL ROUTES ---

@admin_bp.route('/admin/students', methods=['GET'])
def get_admin_students():
    authorized, err_resp = verify_admin_access()
    if not authorized:
        return err_resp

    approval_status = (request.args.get('approvalStatus') or 'ALL').strip().upper()
    branch = request.args.get('branch')
    year = request.args.get('year')
    course = request.args.get('course')
    search = request.args.get('search')

    query = User.query.filter(User.role == 'student')

    if approval_status == 'APPROVED':
        query = query.filter(db.or_(User.approval_status == 'APPROVED', User.approval_status.is_(None)))
    elif approval_status in ('PENDING', 'REJECTED'):
        query = query.filter(User.approval_status == approval_status)

    if branch and branch.upper() != 'ALL':
        query = query.filter(User.branch == branch.strip())
    if year and year.upper() != 'ALL':
        query = query.filter(User.year == year.strip())
    if course and course.upper() != 'ALL':
        query = query.filter(User.course == course.strip())
    if search and search.strip():
        term = f"%{search.strip()}%"
        query = query.filter(
            db.or_(
                User.name.ilike(term),
                User.email.ilike(term),
                User.registration_number.ilike(term),
            )
        )

    students = query.order_by(User.created_at.desc()).all()
    return jsonify([s.to_dict() for s in students]), 200


@admin_bp.route('/admin/students/pending', methods=['GET'])
def get_pending_students():
    authorized, err_resp = verify_admin_access()
    if not authorized:
        return err_resp

    students = User.query.filter(
        User.role == 'student',
        User.approval_status == 'PENDING'
    ).order_by(User.created_at.desc()).all()
    return jsonify([s.to_dict() for s in students]), 200


@admin_bp.route('/admin/students/<student_id>/approve', methods=['POST'])
def approve_student_registration(student_id):
    authorized, err_resp = verify_admin_access()
    if not authorized:
        return err_resp

    admin_user, _, _ = get_authenticated_user_from_token()
    student = User.query.filter_by(id=student_id, role='student').first()
    if not student:
        return jsonify({"message": "Student account not found"}), 404

    now_iso = datetime.datetime.now().isoformat()
    student.approval_status = 'APPROVED'
    student.approved_by = admin_user.id if admin_user else None
    student.approved_at = now_iso
    student.rejection_reason = None

    audit = RequestAudit(
        entity_type='STUDENT_REGISTRATION',
        entity_id=student.id,
        actor_id=admin_user.id if admin_user else 'admin',
        action='APPROVED',
        remarks=f"Student account activated for {student.name} ({student.registration_number or student.email}).",
        ip_address=request.remote_addr,
    )
    db.session.add(audit)
    db.session.commit()

    return jsonify({
        "message": f"Student account for {student.name} has been approved and activated.",
        "student": student.to_dict()
    }), 200


@admin_bp.route('/admin/students/<student_id>/reject', methods=['POST'])
def reject_student_registration(student_id):
    authorized, err_resp = verify_admin_access()
    if not authorized:
        return err_resp

    admin_user, _, _ = get_authenticated_user_from_token()
    student = User.query.filter_by(id=student_id, role='student').first()
    if not student:
        return jsonify({"message": "Student account not found"}), 404

    data = request.get_json(silent=True) or {}
    reason = (data.get('reason') or '').strip() or None

    now_iso = datetime.datetime.now().isoformat()
    student.approval_status = 'REJECTED'
    student.approved_by = admin_user.id if admin_user else None
    student.approved_at = now_iso
    student.rejection_reason = reason

    audit = RequestAudit(
        entity_type='STUDENT_REGISTRATION',
        entity_id=student.id,
        actor_id=admin_user.id if admin_user else 'admin',
        action='REJECTED',
        remarks=f"Student registration rejected for {student.name}. Reason: {reason or 'Not specified'}.",
        ip_address=request.remote_addr,
    )
    db.session.add(audit)
    db.session.commit()

    return jsonify({
        "message": f"Student registration for {student.name} has been rejected.",
        "student": student.to_dict()
    }), 200


@admin_bp.route('/admin/students/bulk-approve', methods=['POST'])
def bulk_approve_students():
    authorized, err_resp = verify_admin_access()
    if not authorized:
        return err_resp

    admin_user, _, _ = get_authenticated_user_from_token()
    data = request.get_json(silent=True) or {}
    student_ids = data.get('studentIds') or []
    if not isinstance(student_ids, list) or not student_ids:
        return jsonify({"message": "studentIds array is required"}), 400

    now_iso = datetime.datetime.now().isoformat()
    students = User.query.filter(
        User.id.in_(student_ids),
        User.role == 'student'
    ).all()

    approved_ids = []
    for student in students:
        student.approval_status = 'APPROVED'
        student.approved_by = admin_user.id if admin_user else None
        student.approved_at = now_iso
        student.rejection_reason = None
        approved_ids.append(student.id)
        db.session.add(RequestAudit(
            entity_type='STUDENT_REGISTRATION',
            entity_id=student.id,
            actor_id=admin_user.id if admin_user else 'admin',
            action='APPROVED',
            remarks=f"Bulk approved student account for {student.name}.",
            ip_address=request.remote_addr,
        ))

    db.session.commit()
    return jsonify({
        "message": f"Approved {len(approved_ids)} student account(s).",
        "approvedCount": len(approved_ids),
        "approvedIds": approved_ids
    }), 200


@admin_bp.route('/admin/users', methods=['POST'])
def create_admin_user():
    authorized, err_resp = verify_admin_access()
    if not authorized:
        return err_resp

    admin_user, _, _ = get_authenticated_user_from_token()
    data = request.get_json(silent=True) or {}

    name = (data.get('name') or '').strip()
    email = (data.get('email') or '').strip().lower()
    password = data.get('password') or ''
    role = (data.get('role') or 'staff').strip().lower()

    if not name or not email or not password:
        return jsonify({"message": "name, email, and password are required"}), 400
    if role not in ALLOWED_USER_ROLES:
        return jsonify({"message": f"Invalid role '{role}'"}), 400
    if User.query.filter(User.email.ilike(email)).first():
        return jsonify({"message": "A user with this email already exists"}), 409

    user = User(
        name=name,
        email=email,
        password=generate_password_hash(password),
        role=role,
        registration_number=(data.get('registrationNumber') or '').strip() or None,
        course=(data.get('course') or '').strip() or None,
        branch=(data.get('branch') or '').strip() or None,
        year=(str(data.get('year')).strip() if data.get('year') is not None else None) or None,
        approval_status='APPROVED',
        approved_by=admin_user.id if admin_user else None,
        approved_at=datetime.datetime.now().isoformat(),
    )
    db.session.add(user)
    db.session.flush()

    db.session.add(RequestAudit(
        entity_type='USER_MANAGEMENT',
        entity_id=user.id,
        actor_id=admin_user.id if admin_user else 'admin',
        action='CREATED',
        remarks=f"Provisioned {role} account for {name} ({email}).",
        ip_address=request.remote_addr,
    ))
    db.session.commit()

    return jsonify({
        "message": f"Account created for {user.name} ({user.role})",
        "user": user.to_dict()
    }), 201


@admin_bp.route('/admin/users/<user_id>', methods=['PATCH'])
def update_admin_user(user_id):
    authorized, err_resp = verify_admin_access()
    if not authorized:
        return err_resp

    admin_user, _, _ = get_authenticated_user_from_token()
    user = User.query.get(user_id)
    if not user:
        return jsonify({"message": "User not found"}), 404

    data = request.get_json(silent=True) or {}
    changes = []

    if 'name' in data and (data.get('name') or '').strip():
        user.name = data['name'].strip()
        changes.append('name')
    if 'role' in data and (data.get('role') or '').strip():
        new_role = data['role'].strip().lower()
        if new_role not in ALLOWED_USER_ROLES:
            return jsonify({"message": f"Invalid role '{new_role}'"}), 400
        user.role = new_role
        changes.append(f"role={new_role}")
    if 'branch' in data:
        user.branch = (data.get('branch') or '').strip() or None
        changes.append('branch')
    if 'course' in data:
        user.course = (data.get('course') or '').strip() or None
        changes.append('course')
    if 'year' in data:
        user.year = (str(data.get('year')).strip() if data.get('year') is not None else None) or None
        changes.append('year')
    if 'registrationNumber' in data:
        user.registration_number = (data.get('registrationNumber') or '').strip() or None
        changes.append('registrationNumber')
    if data.get('resetDeviceId') is True:
        user.device_id = None
        changes.append('resetDeviceId')
    if data.get('password'):
        user.password = generate_password_hash(str(data['password']))
        changes.append('passwordReset')

    db.session.add(RequestAudit(
        entity_type='USER_MANAGEMENT',
        entity_id=user.id,
        actor_id=admin_user.id if admin_user else 'admin',
        action='UPDATED',
        remarks=f"Updated user {user.name}: {', '.join(changes) or 'no-op'}",
        ip_address=request.remote_addr,
    ))
    db.session.commit()

    return jsonify({
        "message": f"Updated user {user.name}",
        "user": user.to_dict()
    }), 200


@admin_bp.route('/admin/users/<user_id>', methods=['DELETE'])
def delete_admin_user(user_id):
    authorized, err_resp = verify_admin_access()
    if not authorized:
        return err_resp

    admin_user, _, _ = get_authenticated_user_from_token()
    if admin_user and admin_user.id == user_id:
        return jsonify({"message": "Cannot delete your own active administrator account"}), 400

    user = User.query.get(user_id)
    if not user:
        return jsonify({"message": "User not found"}), 404

    name = user.name
    email = user.email
    db.session.add(RequestAudit(
        entity_type='USER_MANAGEMENT',
        entity_id=user.id,
        actor_id=admin_user.id if admin_user else 'admin',
        action='DELETED',
        remarks=f"Deleted user {name} ({email}, role={user.role}).",
        ip_address=request.remote_addr,
    ))
    db.session.delete(user)
    db.session.commit()

    return jsonify({"message": f"User {name} deleted"}), 200


@admin_bp.route('/admin/audit-logs', methods=['GET'])
def get_unified_admin_audit_logs():
    authorized, err_resp = verify_admin_access()
    if not authorized:
        return err_resp

    entity_type = (request.args.get('entityType') or 'ALL').strip().upper()
    limit = min(max(int(request.args.get('limit', 200) or 200), 1), 500)

    query = RequestAudit.query
    if entity_type and entity_type != 'ALL':
        query = query.filter(func.upper(RequestAudit.entity_type) == entity_type)

    audits = query.order_by(RequestAudit.timestamp.desc()).limit(limit).all()

    actor_ids = {a.actor_id for a in audits if a.actor_id}
    actors_by_id = {}
    if actor_ids:
        for u in User.query.filter(User.id.in_(actor_ids)).all():
            actors_by_id[u.id] = u

    results = []
    for a in audits:
        actor = actors_by_id.get(a.actor_id)
        item = a.to_dict()
        item["actorName"] = actor.name if actor else ("System" if a.actor_id == "system" else "Staff / User")
        item["actorRole"] = actor.role if actor else "system"
        results.append(item)

    return jsonify(results), 200



