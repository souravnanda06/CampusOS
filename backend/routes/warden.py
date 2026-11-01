import datetime
from datetime import timedelta, timezone
from flask import Blueprint, request, jsonify
from extensions import db
from models.user import User
from models.leave import LeaveRequest
from models.gate_pass import GatePass
from models.audit import RequestAudit
from middleware.auth import get_authenticated_warden
from routes.leave import action_leave_request

warden_bp = Blueprint('warden_bp', __name__)

@warden_bp.route('/warden/leave-requests/pending', methods=['GET'])
def get_warden_pending_leaves():
    warden, err_resp, err_code = get_authenticated_warden()
    if err_resp:
        return err_resp, err_code

    pending_items = (
        db.session.query(LeaveRequest, User)
        .join(User, LeaveRequest.student_id == User.id)
        .filter(LeaveRequest.status == 'PENDING')
        .order_by(LeaveRequest.created_at.asc())
        .all()
    )

    result = []
    for leave, user in pending_items:
        prior_count = LeaveRequest.query.filter(
            LeaveRequest.student_id == user.id,
            LeaveRequest.id != leave.id
        ).count()
        item = leave.to_dict()
        item.update({
            "studentName": user.name,
            "registrationNumber": user.registration_number,
            "course": user.course,
            "branch": user.branch,
            "year": user.year,
            "previousRequestsCount": prior_count,
        })
        result.append(item)

    return jsonify(result), 200

@warden_bp.route('/warden/leave-requests/<request_id>/action', methods=['POST'])
def warden_action_leave_request(request_id):
    return action_leave_request(request_id)

@warden_bp.route('/warden/summary', methods=['GET'])
def get_warden_summary():
    """
    Returns operational overview metrics for the Warden Dashboard.
    Enforces WARDEN or ADMIN role authentication.
    """
    warden, err_resp, err_code = get_authenticated_warden()
    if err_resp:
        return err_resp, err_code

    today_str = datetime.date.today().isoformat()

    pending_count = LeaveRequest.query.filter_by(status='PENDING').count()
    approved_today = LeaveRequest.query.filter(
        LeaveRequest.status == 'APPROVED',
        LeaveRequest.updated_at.like(f"{today_str}%")
    ).count()
    if approved_today == 0:
        approved_today = LeaveRequest.query.filter(
            LeaveRequest.status == 'APPROVED',
            LeaveRequest.created_at.like(f"{today_str}%")
        ).count()

    active_gate_passes = GatePass.query.filter(
        GatePass.status.in_(['ISSUED', 'EXITED'])
    ).count()

    recent_activity_count = RequestAudit.query.filter(
        RequestAudit.entity_type.in_(['LEAVE', 'GATE_PASS'])
    ).count()

    try:
        from models.expansion import VisitorRequest
        pending_visitors = VisitorRequest.query.filter_by(status='PENDING').count()
    except Exception:
        pending_visitors = 0

    pending_items = (
        db.session.query(LeaveRequest, User)
        .join(User, LeaveRequest.student_id == User.id)
        .filter(LeaveRequest.status == 'PENDING')
        .order_by(LeaveRequest.created_at.desc())
        .limit(5)
        .all()
    )
    pending_preview = []
    for leave, user in pending_items:
        prior_count = LeaveRequest.query.filter(
            LeaveRequest.student_id == user.id,
            LeaveRequest.id != leave.id
        ).count()
        item = leave.to_dict()
        item.update({
            "studentName": user.name,
            "registrationNumber": user.registration_number,
            "course": user.course,
            "branch": user.branch,
            "year": user.year,
            "previousRequestsCount": prior_count,
        })
        pending_preview.append(item)

    return jsonify({
        "pendingRequests": pending_count,
        "pendingVisitors": pending_visitors,
        "approvedToday": approved_today,
        "activeGatePasses": active_gate_passes,
        "recentActivityCount": recent_activity_count,
        "pendingPreview": pending_preview,
    }), 200

@warden_bp.route('/warden/leave-requests', methods=['GET'])
def get_warden_leave_requests():
    """
    Returns operational list of leave requests for the Warden.
    Supports status filtering (ALL, PENDING, APPROVED, REJECTED) and search.
    Enforces WARDEN or ADMIN role authentication.
    """
    warden, err_resp, err_code = get_authenticated_warden()
    if err_resp:
        return err_resp, err_code

    status_filter = request.args.get('status', 'ALL').upper()
    search = (request.args.get('search') or '').strip().lower()

    query = db.session.query(LeaveRequest, User).join(User, LeaveRequest.student_id == User.id)

    if status_filter != 'ALL':
        query = query.filter(LeaveRequest.status == status_filter)

    query = query.order_by(LeaveRequest.created_at.desc())
    items = query.all()

    result = []
    for leave, user in items:
        if search:
            matched = (
                search in (user.name or '').lower() or
                search in (user.registration_number or '').lower() or
                search in (leave.reason or '').lower() or
                search in (leave.destination or '').lower()
            )
            if not matched:
                continue

        prior_count = LeaveRequest.query.filter(
            LeaveRequest.student_id == user.id,
            LeaveRequest.id != leave.id
        ).count()

        item = leave.to_dict()
        item.update({
            "studentName": user.name,
            "registrationNumber": user.registration_number,
            "course": user.course,
            "branch": user.branch,
            "year": user.year,
            "previousRequestsCount": prior_count,
        })
        result.append(item)

    return jsonify(result), 200

@warden_bp.route('/warden/leave-requests/<request_id>', methods=['GET'])
def get_warden_leave_request_detail(request_id):
    """
    Returns detailed leave request by ID, including student academic profile
    and associated gate pass details if issued.
    Enforces WARDEN or ADMIN role authentication.
    """
    warden, err_resp, err_code = get_authenticated_warden()
    if err_resp:
        return err_resp, err_code

    leave = LeaveRequest.query.get(request_id)
    if not leave:
        return jsonify({"message": "Leave request not found"}), 404

    user = User.query.get(leave.student_id)
    prior_count = LeaveRequest.query.filter(
        LeaveRequest.student_id == leave.student_id,
        LeaveRequest.id != leave.id
    ).count()

    item = leave.to_dict()
    item.update({
        "studentName": user.name if user else "Unknown Student",
        "registrationNumber": user.registration_number if user else "N/A",
        "course": user.course if user else "N/A",
        "branch": user.branch if user else "N/A",
        "year": user.year if user else "N/A",
        "studentPhone": user.phone if user and hasattr(user, 'phone') else None,
        "previousRequestsCount": prior_count,
    })

    gp = GatePass.query.filter_by(leave_request_id=leave.id).first()
    if gp:
        item["gatePass"] = gp.to_dict()

    return jsonify(item), 200

@warden_bp.route('/warden/activity', methods=['GET'])
def get_warden_activity():
    """
    Returns chronological audit trail for leave and gate pass operations.
    Enforces WARDEN or ADMIN role authentication.
    """
    warden, err_resp, err_code = get_authenticated_warden()
    if err_resp:
        return err_resp, err_code

    filter_type = request.args.get('filter', 'ALL').upper()

    query = db.session.query(RequestAudit, User).join(User, RequestAudit.actor_id == User.id)
    query = query.filter(RequestAudit.entity_type.in_(['LEAVE', 'GATE_PASS']))

    if filter_type == 'LEAVE':
        query = query.filter(RequestAudit.entity_type == 'LEAVE')
    elif filter_type == 'GATE_PASS':
        query = query.filter(RequestAudit.entity_type == 'GATE_PASS')

    query = query.order_by(RequestAudit.timestamp.desc()).limit(100)
    audits = query.all()

    result = []
    for audit, actor in audits:
        item = audit.to_dict()
        item["actorName"] = actor.name
        item["actorRole"] = actor.role

        if audit.entity_type == 'LEAVE':
            lr = LeaveRequest.query.get(audit.entity_id)
            if lr:
                student = User.query.get(lr.student_id)
                if student:
                    item["studentName"] = student.name
                    item["registrationNumber"] = student.registration_number
                    item["destination"] = lr.destination
        elif audit.entity_type == 'GATE_PASS':
            gp = GatePass.query.get(audit.entity_id)
            if gp:
                student = User.query.get(gp.student_id)
                if student:
                    item["studentName"] = student.name
                    item["registrationNumber"] = student.registration_number
                    item["destination"] = gp.destination

        result.append(item)

    return jsonify(result), 200



