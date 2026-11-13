import datetime
from datetime import timedelta, timezone
from flask import Blueprint, request, jsonify
from extensions import db
from models.user import User
from models.leave import LeaveRequest
from models.gate_pass import GatePass
from models.audit import RequestAudit
from middleware.roles import is_warden
from services.whatsapp_service import send_leave_approval_alert

leave_bp = Blueprint('leave_bp', __name__)

@leave_bp.route('/requests/leave', methods=['POST'])
def submit_leave_request():
    data = request.json or {}
    student_id = data.get('studentId')
    leave_type = data.get('leaveType')
    start_date_str = data.get('startDate')
    end_date_str = data.get('endDate')
    reason = data.get('reason')

    # 1. Required fields
    if not student_id:
        return jsonify({"message": "studentId is required"}), 400
    if not leave_type:
        return jsonify({"message": "leaveType is required"}), 400
    if not start_date_str or not end_date_str:
        return jsonify({"message": "startDate and endDate are required"}), 400
    if not reason or not reason.strip():
        return jsonify({"message": "reason is required and cannot be empty"}), 400

    # 2. Student existence check
    student = User.query.get(student_id)
    if not student:
        return jsonify({"message": "Student not found"}), 404
    if student.role != 'student':
        return jsonify({"message": "User is not a student"}), 403

    # 3. Date validation
    try:
        start_date = datetime.date.fromisoformat(start_date_str)
        end_date = datetime.date.fromisoformat(end_date_str)
    except (ValueError, TypeError):
        return jsonify({"message": "Invalid date format. Expected YYYY-MM-DD"}), 400

    if end_date < start_date:
        return jsonify({"message": "End date must not be before start date"}), 400

    try:
        new_leave = LeaveRequest(
            student_id=student_id,
            leave_type=leave_type,
            start_date=start_date.isoformat(),
            end_date=end_date.isoformat(),
            reason=reason.strip(),
            status='PENDING'
        )
        db.session.add(new_leave)
        db.session.flush()

        audit = RequestAudit(
            entity_type='LEAVE',
            entity_id=new_leave.id,
            actor_id=student_id,
            action='SUBMITTED',
            remarks=f"Submitted leave request for {leave_type}",
            ip_address=request.remote_addr
        )
        db.session.add(audit)
        db.session.commit()

        return jsonify({
            "message": "Leave request submitted successfully",
            "request": new_leave.to_dict()
        }), 201

    except Exception as e:
        db.session.rollback()
        return jsonify({"message": f"Server error submitting leave request: {str(e)}"}), 500


@leave_bp.route('/requests/leave/pending', methods=['GET'])
def get_pending_leave_requests():
    # Sort oldest pending request first so the queue naturally surfaces ageing requests
    pending_items = (
        db.session.query(LeaveRequest, User)
        .join(User, LeaveRequest.student_id == User.id)
        .filter(LeaveRequest.status == 'PENDING')
        .order_by(LeaveRequest.created_at.asc())
        .all()
    )

    result = []
    for leave, user in pending_items:
        item = leave.to_dict()
        item.update({
            "studentName": user.name,
            "registrationNumber": user.registration_number,
            "course": user.course,
            "branch": user.branch,
            "year": user.year,
        })
        result.append(item)

    return jsonify(result), 200


@leave_bp.route('/requests/leave/<request_id>/action', methods=['POST'])
def action_leave_request(request_id):
    data = request.json or {}
    reviewer_id = data.get('reviewerId') or request.headers.get('X-User-Id')
    action = data.get('action')
    remarks = data.get('remarks', '')

    if not reviewer_id:
        return jsonify({"message": "reviewerId is required"}), 400
    if not action or action not in ['APPROVE', 'REJECT', 'ASK_STUDENT']:
        return jsonify({"message": "Valid action ('APPROVE', 'REJECT', or 'ASK_STUDENT') is required"}), 400

    reviewer = User.query.get(reviewer_id)
    if not reviewer:
        return jsonify({"message": "Reviewer not found"}), 404

    # The WARDEN is the institutional approver for leave. Teachers, students, and security cannot approve.
    if not is_warden(reviewer):
        return jsonify({"message": "Forbidden: Only institutional Warden or Admin can approve/reject student leave requests"}), 403

    leave_req = LeaveRequest.query.get(request_id)
    if not leave_req:
        return jsonify({"message": "Leave request not found"}), 404

    if leave_req.status != 'PENDING':
        return jsonify({"message": f"Cannot act on request in {leave_req.status} status. Only PENDING requests can be processed."}), 409

    try:
        if action == 'APPROVE':
            leave_req.status = 'APPROVED'
            leave_req.reviewed_by = reviewer_id
            if remarks:
                leave_req.review_remarks = remarks
            
            # If an associated gate pass exists, transition it towards ISSUED
            gp = GatePass.query.filter_by(leave_request_id=leave_req.id, status='PENDING').first()
            if gp:
                gp.status = 'ISSUED'
                audit_gp = RequestAudit(
                    entity_type='GATE_PASS',
                    entity_id=gp.id,
                    actor_id=reviewer_id,
                    action='ISSUED',
                    remarks="Gate pass issued following Warden leave approval",
                    ip_address=request.remote_addr
                )
                db.session.add(audit_gp)
        elif action == 'REJECT':
            leave_req.status = 'REJECTED'
            leave_req.reviewed_by = reviewer_id
            leave_req.review_remarks = remarks

            # Cancel associated gate pass if present
            gp = GatePass.query.filter_by(leave_request_id=leave_req.id, status='PENDING').first()
            if gp:
                gp.status = 'REJECTED'
        elif action == 'ASK_STUDENT':
            # Remains pending but appends warden inquiry remarks
            leave_req.review_remarks = f"Warden Inquiry: {remarks}" if remarks else "Warden requested clarification"

        leave_req.updated_at = datetime.datetime.now().isoformat()

        audit = RequestAudit(
            entity_type='LEAVE',
            entity_id=leave_req.id,
            actor_id=reviewer_id,
            action=action,
            remarks=remarks or f"Leave request {action.lower()}d",
            ip_address=request.remote_addr
        )
        db.session.add(audit)
        db.session.commit()

        if action == 'APPROVE':
            try:
                student_user = User.query.get(leave_req.student_id)
                if student_user and student_user.parent_phone:
                    gp_id = gp.id if gp else None
                    send_leave_approval_alert(
                        parent_phone=student_user.parent_phone,
                        student_name=student_user.name,
                        reason=leave_req.reason,
                        from_date=str(leave_req.start_date),
                        to_date=str(leave_req.end_date),
                        gate_pass_code=gp_id
                    )
            except Exception:
                pass

        return jsonify({
            "message": f"Leave request {leave_req.status.lower()} successfully",
            "request": leave_req.to_dict()
        }), 200

    except Exception as e:
        db.session.rollback()
        return jsonify({"message": f"Server error processing leave request: {str(e)}"}), 500

@leave_bp.route('/requests/leave/<request_id>/cancel', methods=['POST'])
def cancel_leave_request(request_id):
    data = request.json or {}
    student_id = data.get('studentId')
    if not student_id:
        return jsonify({"message": "studentId is required"}), 400

    leave_req = LeaveRequest.query.get(request_id)
    if not leave_req:
        return jsonify({"message": "Leave request not found"}), 404

    # Ownership check
    if leave_req.student_id != student_id:
        return jsonify({"message": "Unauthorized: Only the owning student can cancel this request"}), 403

    # Status check
    if leave_req.status != 'PENDING':
        return jsonify({"message": f"Cannot cancel request in {leave_req.status} status. Only PENDING requests can be cancelled."}), 409

    try:
        leave_req.status = 'CANCELLED'
        leave_req.updated_at = datetime.datetime.now().isoformat()

        audit = RequestAudit(
            entity_type='LEAVE',
            entity_id=leave_req.id,
            actor_id=student_id,
            action='CANCELLED',
            remarks=data.get('remarks', 'Cancelled by student'),
            ip_address=request.remote_addr
        )
        db.session.add(audit)
        db.session.commit()

        return jsonify({
            "message": "Leave request cancelled successfully",
            "request": leave_req.to_dict()
        }), 200

    except Exception as e:
        db.session.rollback()
        return jsonify({"message": f"Server error cancelling leave request: {str(e)}"}), 500


@leave_bp.route('/requests/leave/<student_id>', methods=['GET'])
def get_student_leave_requests(student_id):
    student = User.query.get(student_id)
    if not student:
        return jsonify({"message": "Student not found"}), 404

    requests = LeaveRequest.query.filter_by(student_id=student_id).order_by(LeaveRequest.created_at.desc()).all()
    return jsonify([r.to_dict() for r in requests]), 200

# --- GATE PASS SIGNING & CREDENTIAL HELPERS ---

