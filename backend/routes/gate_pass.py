import uuid
import datetime
from datetime import timedelta, timezone
from flask import Blueprint, request, jsonify
from extensions import db
from models.user import User
from models.leave import LeaveRequest
from models.gate_pass import GatePass
from models.audit import RequestAudit
from middleware.roles import is_warden
from utils.crypto import generate_signed_credential

gate_pass_bp = Blueprint('gate_pass_bp', __name__)

@gate_pass_bp.route('/requests/gate-pass', methods=['POST'])
def create_gate_pass():
    data = request.json or {}
    student_id = data.get('studentId')
    leave_request_id = data.get('leaveRequestId')
    destination = data.get('destination')
    reason = data.get('reason')
    expected_exit_time = data.get('expectedExitTime')
    expected_return_time = data.get('expectedReturnTime')

    # 1. Required fields
    if not student_id or not leave_request_id:
        return jsonify({"message": "studentId and leaveRequestId are required"}), 400
    if not destination or not destination.strip():
        return jsonify({"message": "destination is required"}), 400
    if not reason or not reason.strip():
        return jsonify({"message": "reason is required"}), 400
    if not expected_exit_time or not expected_return_time:
        return jsonify({"message": "expectedExitTime and expectedReturnTime are required"}), 400

    # 2. Student validation
    student = User.query.get(student_id)
    if not student:
        return jsonify({"message": "Student not found"}), 404
    if student.role != 'student':
        return jsonify({"message": "User is not a student"}), 403

    # 3. Leave request validation (Must exist, belong to student, and be APPROVED)
    leave_req = LeaveRequest.query.get(leave_request_id)
    if not leave_req:
        return jsonify({"message": "Leave request not found"}), 404
    if leave_req.student_id != student_id:
        return jsonify({"message": "Unauthorized: Leave request does not belong to this student"}), 403
    if leave_req.status != 'APPROVED':
        return jsonify({"message": f"A Gate Pass requires an APPROVED leave request. Current status is {leave_req.status}"}), 400

    # 4. Timestamp validation
    try:
        exit_dt = datetime.datetime.fromisoformat(expected_exit_time)
        return_dt = datetime.datetime.fromisoformat(expected_return_time)
    except (ValueError, TypeError):
        return jsonify({"message": "Invalid timestamp format for exit/return time"}), 400

    if return_dt <= exit_dt:
        return jsonify({"message": "Expected return time must be strictly after expected exit time"}), 400

    try:
        new_gp = GatePass(
            student_id=student_id,
            leave_request_id=leave_request_id,
            destination=destination.strip(),
            reason=reason.strip(),
            expected_exit_time=expected_exit_time,
            expected_return_time=expected_return_time,
            status='APPROVED',
            qr_nonce=str(uuid.uuid4())
        )
        db.session.add(new_gp)
        db.session.flush()

        audit = RequestAudit(
            entity_type='GATE_PASS',
            entity_id=new_gp.id,
            actor_id=student_id,
            action='APPROVED',
            remarks=f"Gate pass approved following Warden leave approval for {destination.strip()}",
            ip_address=request.remote_addr
        )
        db.session.add(audit)
        db.session.commit()

        return jsonify({
            "message": "Gate pass created and approved following Warden leave approval",
            "gatePass": new_gp.to_dict()
        }), 201

    except Exception as e:
        db.session.rollback()
        return jsonify({"message": f"Server error creating gate pass: {str(e)}"}), 500


@gate_pass_bp.route('/requests/gate-pass/active/<student_id>', methods=['GET'])
def get_active_gate_pass(student_id):
    student = User.query.get(student_id)
    if not student:
        return jsonify({"message": "Student not found"}), 404

    gp = GatePass.query.filter(
        GatePass.student_id == student_id,
        GatePass.status.in_(['ISSUED', 'EXITED'])
    ).order_by(GatePass.created_at.desc()).first()

    if not gp:
        return jsonify({"hasActive": False, "gatePass": None, "credential": None}), 200

    payload = {
        "gatePassId": gp.id,
        "studentId": gp.student_id,
        "leaveRequestId": gp.leave_request_id,
        "nonce": gp.qr_nonce,
        "issuedAt": gp.created_at,
        "expiresAt": gp.expected_return_time,
        "destination": gp.destination,
        "version": "1.0"
    }
    signed_token = generate_signed_credential(payload)

    return jsonify({
        "hasActive": True,
        "gatePass": gp.to_dict(),
        "credential": signed_token
    }), 200


@gate_pass_bp.route('/requests/gate-pass/<id>/credential', methods=['GET'])
def get_gate_pass_credential(id):
    student_id = request.args.get('studentId')
    gp = GatePass.query.get(id)
    if not gp:
        return jsonify({"message": "Gate pass not found"}), 404

    if student_id and gp.student_id != student_id:
        return jsonify({"message": "Unauthorized: Only the owning student can retrieve this credential"}), 403

    if gp.status not in ['ISSUED', 'EXITED']:
        return jsonify({"message": f"Credential is only available for ISSUED or EXITED passes. Current status: {gp.status}"}), 409

    payload = {
        "gatePassId": gp.id,
        "studentId": gp.student_id,
        "leaveRequestId": gp.leave_request_id,
        "nonce": gp.qr_nonce,
        "issuedAt": gp.created_at,
        "expiresAt": gp.expected_return_time,
        "destination": gp.destination,
        "version": "1.0"
    }
    signed_token = generate_signed_credential(payload)

    return jsonify({
        "gatePassId": gp.id,
        "studentId": gp.student_id,
        "status": gp.status,
        "destination": gp.destination,
        "validFrom": gp.expected_exit_time,
        "validUntil": gp.expected_return_time,
        "credential": signed_token,
        "nonce": gp.qr_nonce
    }), 200


@gate_pass_bp.route('/requests/gate-pass/<id>/action', methods=['POST'])
def action_gate_pass(id):
    data = request.json or {}
    header_user_id = request.headers.get('X-User-Id') or request.headers.get('X-Requester-Id')
    if header_user_id:
        header_user = User.query.get(header_user_id)
        if header_user and not is_warden(header_user):
            return jsonify({"message": "Forbidden: Only institutional Warden or Admin can approve/reject gate passes"}), 403

    reviewer_id = header_user_id or data.get('reviewerId')
    action = data.get('action')
    remarks = data.get('remarks', '')

    if not reviewer_id:
        return jsonify({"message": "reviewerId is required"}), 400
    if not action or action not in ['APPROVE', 'REJECT']:
        return jsonify({"message": "action must be 'APPROVE' or 'REJECT'"}), 400

    reviewer = User.query.get(reviewer_id)
    if not reviewer:
        return jsonify({"message": "Reviewer not found"}), 404

    # Enforce institutional Warden / Admin authority
    if not is_warden(reviewer):
        return jsonify({"message": "Forbidden: Only institutional Warden or Admin can approve/reject gate passes"}), 403

    gp = GatePass.query.get(id)
    if not gp:
        return jsonify({"message": "Gate pass not found"}), 404

    if gp.status != 'PENDING':
        return jsonify({"message": f"Cannot act on gate pass in {gp.status} status. Only PENDING passes can be approved/rejected."}), 409

    try:
        gp.status = 'APPROVED' if action == 'APPROVE' else 'REJECTED'
        audit = RequestAudit(
            entity_type='GATE_PASS',
            entity_id=gp.id,
            actor_id=reviewer_id,
            action=action,
            remarks=remarks or f"Gate pass {action.lower()}d",
            ip_address=request.remote_addr
        )
        db.session.add(audit)
        db.session.commit()

        return jsonify({
            "message": f"Gate pass {gp.status.lower()} successfully",
            "gatePass": gp.to_dict()
        }), 200

    except Exception as e:
        db.session.rollback()
        return jsonify({"message": f"Server error updating gate pass: {str(e)}"}), 500


@gate_pass_bp.route('/requests/gate-pass/<id>/issue', methods=['POST'])
def issue_gate_pass(id):
    data = request.json or {}
    issuer_id = data.get('issuerId')

    gp = GatePass.query.get(id)
    if not gp:
        return jsonify({"message": "Gate pass not found"}), 404

    if gp.status == 'ISSUED':
        return jsonify({"message": "Gate pass already issued", "gatePass": gp.to_dict()}), 200

    if gp.status != 'APPROVED':
        return jsonify({"message": f"Cannot issue gate pass with status {gp.status}. Only APPROVED passes can be issued."}), 409

    try:
        gp.status = 'ISSUED'
        audit = RequestAudit(
            entity_type='GATE_PASS',
            entity_id=gp.id,
            actor_id=issuer_id or gp.student_id,
            action='ISSUED',
            remarks="Gate pass issued and credential activated",
            ip_address=request.remote_addr
        )
        db.session.add(audit)
        db.session.commit()

        return jsonify({
            "message": "Gate pass issued successfully",
            "gatePass": gp.to_dict()
        }), 200

    except Exception as e:
        db.session.rollback()
        return jsonify({"message": f"Server error issuing gate pass: {str(e)}"}), 500


@gate_pass_bp.route('/requests/gate-pass/<student_id>', methods=['GET'])
def get_student_gate_passes(student_id):
    student = User.query.get(student_id)
    if not student:
        return jsonify({"message": "Student not found"}), 404

    passes = GatePass.query.filter_by(student_id=student_id).order_by(GatePass.created_at.desc()).all()
    return jsonify([p.to_dict() for p in passes]), 200


# --- GATE SECURITY OPERATIONAL ENDPOINTS ---

