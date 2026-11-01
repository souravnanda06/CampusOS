import uuid
import datetime
from flask import Blueprint, request, jsonify
from extensions import db
from models.user import User
from models.expansion import VisitorRequest
from models.audit import RequestAudit
from models.notification import NotificationDelivery
from middleware.auth import get_authenticated_requester

visitors_bp = Blueprint('visitors_bp', __name__)

@visitors_bp.route('/visitors/requests', methods=['POST'])
def create_visitor_request():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required"}), 401
    if requester.role != 'student':
        return jsonify({"message": "Forbidden: Only students can register visitors"}), 403

    data = request.json or {}
    visitor_name = (data.get('visitorName') or '').strip()
    visitor_phone = (data.get('visitorPhone') or '').strip()
    relation = (data.get('relation') or 'Parent').strip()
    purpose = (data.get('purpose') or '').strip()
    visit_date = data.get('visitDate') or datetime.date.today().isoformat()
    expected_entry_time = data.get('expectedEntryTime') or '04:00 PM'
    expected_exit_time = data.get('expectedExitTime') or '08:00 PM'

    if not visitor_name:
        return jsonify({"message": "visitorName is required"}), 400
    if not visitor_phone:
        return jsonify({"message": "visitorPhone is required"}), 400
    if not purpose:
        return jsonify({"message": "purpose is required"}), 400

    new_vr = VisitorRequest(
        student_id=requester.id,
        visitor_name=visitor_name,
        visitor_phone=visitor_phone,
        relation=relation,
        purpose=purpose,
        visit_date=visit_date,
        expected_entry_time=expected_entry_time,
        expected_exit_time=expected_exit_time,
        status='PENDING'
    )
    db.session.add(new_vr)

    audit = RequestAudit(
        entity_type='VISITOR_REQUEST',
        entity_id=new_vr.id,
        actor_id=requester.id,
        action='SUBMITTED',
        remarks=f"Visitor request for {visitor_name} ({relation}) on {visit_date}",
        ip_address=request.remote_addr
    )
    db.session.add(audit)
    db.session.commit()

    return jsonify({
        "message": "Visitor request submitted successfully",
        "request": new_vr.to_dict()
    }), 201

@visitors_bp.route('/visitors/requests/my', methods=['GET'])
def get_my_visitor_requests():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required"}), 401

    reqs = VisitorRequest.query.filter_by(student_id=requester.id).order_by(VisitorRequest.created_at.desc()).all()
    return jsonify([r.to_dict() for r in reqs]), 200

@visitors_bp.route('/visitors/active-pass', methods=['GET'])
def get_active_visitor_pass():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required"}), 401

    today_str = datetime.date.today().isoformat()
    # Find approved or checked-in visitor pass for today
    active_pass = VisitorRequest.query.filter(
        VisitorRequest.student_id == requester.id,
        VisitorRequest.status.in_(['APPROVED', 'CHECKED_IN']),
        VisitorRequest.visit_date >= today_str
    ).order_by(VisitorRequest.created_at.desc()).first()

    if not active_pass:
        return jsonify({
            "hasActivePass": False,
            "pass": None
        }), 200

    d = active_pass.to_dict()
    d['hasActivePass'] = True
    d['studentName'] = requester.name
    return jsonify({
        "hasActivePass": True,
        "pass": d
    }), 200

@visitors_bp.route('/visitors/warden/pending', methods=['GET'])
def get_warden_pending_visitors():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester or requester.role not in ['warden', 'admin']:
        return jsonify({"message": "Forbidden: Warden role required"}), 403

    pending = (
        db.session.query(VisitorRequest, User)
        .join(User, VisitorRequest.student_id == User.id)
        .filter(VisitorRequest.status == 'PENDING')
        .order_by(VisitorRequest.created_at.asc())
        .all()
    )

    results = []
    for vr, student in pending:
        d = vr.to_dict()
        d.update({
            "studentName": student.name,
            "registrationNumber": student.registration_number,
            "branch": student.branch,
            "year": student.year
        })
        results.append(d)

    return jsonify(results), 200

@visitors_bp.route('/visitors/warden/requests/<id>/action', methods=['POST'])
def action_visitor_request(id):
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester or requester.role not in ['warden', 'admin']:
        return jsonify({"message": "Forbidden: Warden role required"}), 403

    vr = VisitorRequest.query.get(id)
    if not vr:
        return jsonify({"message": "Visitor request not found"}), 404

    data = request.json or {}
    action = (data.get('action') or '').upper()  # APPROVE, REJECT
    remarks = (data.get('remarks') or '').strip()

    if action not in ['APPROVE', 'REJECT']:
        return jsonify({"message": "Invalid action. Supported: APPROVE, REJECT"}), 400

    now_iso = datetime.datetime.now().isoformat()
    if action == 'APPROVE':
        vr.status = 'APPROVED'
        vr.approved_by = requester.id
        if not vr.pass_code:
            vr.pass_code = f"VP-{uuid.uuid4().hex[:12].upper()}"

        # Send notification to student
        notif = NotificationDelivery(
            user_id=vr.student_id,
            title="Visitor Pass Approved",
            body=f"Visitor pass for {vr.visitor_name} ({vr.relation}) is approved for {vr.visit_date}. Pass code: {vr.pass_code}",
            notification_type="VISITOR",
            reference_id=vr.id,
            status="PENDING",
            delivered_at=now_iso,
            created_at=now_iso
        )
        db.session.add(notif)
    else:
        vr.status = 'REJECTED'
        vr.security_remarks = remarks or "Rejected by Warden"

    audit = RequestAudit(
        entity_type='VISITOR_REQUEST',
        entity_id=vr.id,
        actor_id=requester.id,
        action=action,
        remarks=f"Warden action {action}: {remarks}",
        ip_address=request.remote_addr
    )
    db.session.add(audit)
    db.session.commit()

    return jsonify({
        "message": f"Visitor request {vr.status.lower()} successfully",
        "request": vr.to_dict()
    }), 200

@visitors_bp.route('/visitors/security/summary', methods=['GET'])
def get_security_visitor_summary():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester or requester.role not in ['security', 'guard', 'security_guard', 'admin']:
        return jsonify({"message": "Forbidden: Security guard role required"}), 403

    today_str = datetime.date.today().isoformat()
    expected = VisitorRequest.query.filter(
        VisitorRequest.visit_date == today_str,
        VisitorRequest.status == 'APPROVED'
    ).count()

    inside = VisitorRequest.query.filter(
        VisitorRequest.status == 'CHECKED_IN'
    ).count()

    checked_out = VisitorRequest.query.filter(
        VisitorRequest.visit_date == today_str,
        VisitorRequest.status == 'CHECKED_OUT'
    ).count()

    return jsonify({
        "expectedToday": expected,
        "currentlyInside": inside,
        "checkedOutToday": checked_out
    }), 200

@visitors_bp.route('/visitors/security/verify', methods=['POST'])
def verify_visitor_pass():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester or requester.role not in ['security', 'guard', 'security_guard', 'admin']:
        return jsonify({"message": "Forbidden: Security guard role required"}), 403

    data = request.json or {}
    pass_code = (data.get('passCode') or data.get('qrData') or '').strip()

    if not pass_code:
        return jsonify({"message": "passCode is required"}), 400

    vr = VisitorRequest.query.filter_by(pass_code=pass_code).first()
    if not vr:
        return jsonify({
            "isValid": False,
            "resultCode": "NOT_FOUND",
            "message": "Visitor pass not recognized or invalid QR code"
        }), 404

    today_str = datetime.date.today().isoformat()
    is_expired = vr.visit_date < today_str
    if is_expired and vr.status in ['PENDING', 'APPROVED']:
        vr.status = 'EXPIRED'
        db.session.commit()

    student = User.query.get(vr.student_id)
    d = vr.to_dict()
    if student:
        d.update({
            "studentName": student.name,
            "registrationNumber": student.registration_number,
            "branch": student.branch,
            "year": student.year
        })

    is_valid = (vr.status in ['APPROVED', 'CHECKED_IN']) and not is_expired

    return jsonify({
        "isValid": is_valid,
        "resultCode": "VALID" if is_valid else vr.status,
        "message": f"Visitor pass is {vr.status}",
        "pass": d
    }), 200

@visitors_bp.route('/visitors/security/check-in', methods=['POST'])
def check_in_visitor():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester or requester.role not in ['security', 'guard', 'security_guard', 'admin']:
        return jsonify({"message": "Forbidden: Security guard role required"}), 403

    data = request.json or {}
    pass_code = (data.get('passCode') or '').strip()
    remarks = (data.get('remarks') or '').strip()

    vr = VisitorRequest.query.filter_by(pass_code=pass_code).first()
    if not vr:
        return jsonify({"message": "Visitor pass not found"}), 404

    # Anti-replay / double-entry check
    if vr.status == 'CHECKED_IN':
        return jsonify({
            "message": "Double-entry violation: Visitor is already checked in and inside campus",
            "resultCode": "ALREADY_CHECKED_IN"
        }), 409

    if vr.status != 'APPROVED':
        return jsonify({
            "message": f"Cannot check in visitor with pass status '{vr.status}'",
            "resultCode": "INVALID_STATUS"
        }), 400

    today_str = datetime.date.today().isoformat()
    if vr.visit_date < today_str:
        vr.status = 'EXPIRED'
        db.session.commit()
        return jsonify({"message": "Visitor pass has expired", "resultCode": "EXPIRED"}), 400

    now_iso = datetime.datetime.now().isoformat()
    vr.status = 'CHECKED_IN'
    vr.entry_guard_id = requester.id
    vr.entered_at = now_iso
    if remarks:
        vr.security_remarks = remarks

    audit = RequestAudit(
        entity_type='VISITOR_PASS',
        entity_id=vr.id,
        actor_id=requester.id,
        action='CHECKED_IN',
        remarks=f"Checked in visitor {vr.visitor_name}. Guard: {requester.name}",
        ip_address=request.remote_addr
    )
    db.session.add(audit)
    db.session.commit()

    return jsonify({
        "message": f"Visitor {vr.visitor_name} checked in successfully",
        "pass": vr.to_dict()
    }), 200

@visitors_bp.route('/visitors/security/check-out', methods=['POST'])
def check_out_visitor():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester or requester.role not in ['security', 'guard', 'security_guard', 'admin']:
        return jsonify({"message": "Forbidden: Security guard role required"}), 403

    data = request.json or {}
    pass_code = (data.get('passCode') or '').strip()
    remarks = (data.get('remarks') or '').strip()

    vr = VisitorRequest.query.filter_by(pass_code=pass_code).first()
    if not vr:
        return jsonify({"message": "Visitor pass not found"}), 404

    # Anti-replay / double-exit check
    if vr.status == 'CHECKED_OUT':
        return jsonify({
            "message": "Double-exit violation: Visitor has already checked out",
            "resultCode": "ALREADY_CHECKED_OUT"
        }), 409

    if vr.status != 'CHECKED_IN':
        return jsonify({
            "message": f"Cannot check out visitor who has not checked in (Current status: '{vr.status}')",
            "resultCode": "NOT_CHECKED_IN"
        }), 400

    now_iso = datetime.datetime.now().isoformat()
    vr.status = 'CHECKED_OUT'
    vr.exit_guard_id = requester.id
    vr.exited_at = now_iso
    if remarks:
        vr.security_remarks = (vr.security_remarks or '') + f" | Exit remarks: {remarks}"

    audit = RequestAudit(
        entity_type='VISITOR_PASS',
        entity_id=vr.id,
        actor_id=requester.id,
        action='CHECKED_OUT',
        remarks=f"Checked out visitor {vr.visitor_name}. Guard: {requester.name}",
        ip_address=request.remote_addr
    )
    db.session.add(audit)
    db.session.commit()

    return jsonify({
        "message": f"Visitor {vr.visitor_name} checked out successfully",
        "pass": vr.to_dict()
    }), 200

@visitors_bp.route('/visitors/admin/kpis', methods=['GET'])
def get_visitor_admin_kpis():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester or requester.role not in ['admin', 'staff', 'warden']:
        return jsonify({"message": "Forbidden: Admin privileges required"}), 403

    all_visitors = VisitorRequest.query.all()
    today_str = datetime.date.today().isoformat()

    return jsonify({
        "totalVisitorRequests": len(all_visitors),
        "pendingApprovals": sum(1 for v in all_visitors if v.status == 'PENDING'),
        "approvedPasses": sum(1 for v in all_visitors if v.status == 'APPROVED'),
        "insideCampusNow": sum(1 for v in all_visitors if v.status == 'CHECKED_IN'),
        "completedVisitsToday": sum(1 for v in all_visitors if v.visit_date == today_str and v.status == 'CHECKED_OUT')
    }), 200
