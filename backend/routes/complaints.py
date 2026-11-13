import datetime
from datetime import timedelta, timezone
from flask import Blueprint, request, jsonify
from sqlalchemy.exc import IntegrityError
from extensions import db
from models.user import User
from models.complaint import Complaint, generate_closure_pin
from models.audit import ComplaintStatusHistory, RequestAudit
from middleware.auth import get_authenticated_requester
from services.complaint_service import COMPLAINT_TRANSITIONS

complaints_bp = Blueprint('complaints_bp', __name__)

def find_complaint_by_identifier(identifier):
    if not identifier:
        return None
    raw_id = str(identifier).strip()
    if raw_id.startswith('cached_'):
        raw_id = raw_id[7:]
    complaint = Complaint.query.get(raw_id)
    if not complaint:
        complaint = Complaint.query.filter_by(idempotency_key=raw_id).first()
    if not complaint and raw_id.startswith('comp_'):
        complaint = Complaint.query.filter_by(idempotency_key=raw_id[5:]).first()
    return complaint

@complaints_bp.route('/complaints', methods=['POST'])
def create_complaint():
    data = request.json or {}
    student_id = data.get('studentId')
    category = data.get('category')
    title = data.get('title')
    description = data.get('description')
    location = data.get('location', 'Campus')
    priority = (data.get('priority') or 'MEDIUM').upper()
    idempotency_key = data.get('idempotencyKey') or data.get('idempotency_key')
    if idempotency_key:
        idempotency_key = str(idempotency_key).strip()
        if not idempotency_key:
            idempotency_key = None

    # 1. Required field validation
    if not student_id:
        return jsonify({"message": "studentId is required"}), 400
    if not category or not category.strip():
        return jsonify({"message": "category is required"}), 400
    if not title or not title.strip():
        return jsonify({"message": "title is required"}), 400
    if not description or not description.strip():
        return jsonify({"message": "description is required"}), 400

    if priority not in ['LOW', 'MEDIUM', 'HIGH', 'URGENT']:
        priority = 'MEDIUM'

    # 2. Student validation & ownership check
    student = User.query.get(student_id)
    if not student:
        return jsonify({"message": "Student not found"}), 404
    if student.role != 'student':
        return jsonify({"message": "User is not a student"}), 403

    requester_id = data.get('requesterId')
    if requester_id and requester_id != student_id:
        requester = User.query.get(requester_id)
        if requester and requester.role == 'student':
            return jsonify({"message": "Unauthorized: Cannot create complaints on behalf of another student"}), 403

    # 3. Idempotency pre-check
    if idempotency_key:
        existing = Complaint.query.filter_by(idempotency_key=idempotency_key).first()
        if existing:
            if existing.student_id != student_id:
                return jsonify({"message": "Unauthorized: Idempotency key belongs to another student"}), 403
            return jsonify({
                "message": "Complaint already processed",
                "complaint": existing.to_dict()
            }), 200

    try:
        client_otp = data.get('closureOtp') or data.get('closure_otp')
        if client_otp and str(client_otp).strip().isdigit() and len(str(client_otp).strip()) == 4:
            closure_otp = str(client_otp).strip()
        else:
            closure_otp = generate_closure_pin()

        new_complaint = Complaint(
            student_id=student_id,
            category=category.strip(),
            title=title.strip(),
            description=description.strip(),
            location=(location or 'Campus').strip(),
            priority=priority,
            status='PENDING',
            idempotency_key=idempotency_key,
            closure_otp=closure_otp
        )
        db.session.add(new_complaint)
        db.session.flush()

        # Audit & History entries
        history = ComplaintStatusHistory(
            complaint_id=new_complaint.id,
            changed_by=student_id,
            old_status=None,
            new_status='PENDING',
            comment="Complaint submitted"
        )
        audit = RequestAudit(
            entity_type='COMPLAINT',
            entity_id=new_complaint.id,
            actor_id=student_id,
            action='SUBMITTED',
            remarks=f"Submitted complaint: {title.strip()}",
            ip_address=request.remote_addr
        )
        db.session.add(history)
        db.session.add(audit)
        db.session.commit()

        return jsonify({
            "message": "Complaint submitted successfully",
            "complaint": new_complaint.to_dict()
        }), 201

    except IntegrityError:
        db.session.rollback()
        # Concurrent race condition recovery for duplicate idempotency key
        if idempotency_key:
            existing = Complaint.query.filter_by(idempotency_key=idempotency_key).first()
            if existing:
                if existing.student_id != student_id:
                    return jsonify({"message": "Unauthorized: Idempotency key belongs to another student"}), 403
                return jsonify({
                    "message": "Complaint already processed",
                    "complaint": existing.to_dict()
                }), 200
        return jsonify({"message": "Database conflict processing complaint"}), 409

    except Exception as e:
        db.session.rollback()
        return jsonify({"message": f"Server error submitting complaint: {str(e)}"}), 500


@complaints_bp.route('/complaints/pending', methods=['GET'])
def get_pending_complaints():
    # Return complaints waiting for action
    complaints = Complaint.query.filter(
        Complaint.status.in_(['PENDING', 'REOPENED', 'ASSIGNED', 'IN_PROGRESS'])
    ).order_by(Complaint.created_at.desc()).all()
    return jsonify([c.to_dict() for c in complaints]), 200


@complaints_bp.route('/complaints/<id>/history', methods=['GET'])
def get_complaint_history(id):
    complaint = find_complaint_by_identifier(id)
    if not complaint:
        return jsonify({"message": "Complaint not found"}), 404

    requester_id = request.args.get('requesterId')
    if requester_id:
        requester = User.query.get(requester_id)
        if requester and requester.role == 'student' and complaint.student_id != requester.id:
            return jsonify({"message": "Unauthorized: Cannot view another student's complaint history"}), 403

    history_records = ComplaintStatusHistory.query.filter_by(
        complaint_id=complaint.id
    ).order_by(ComplaintStatusHistory.timestamp.asc()).all()

    result = []
    for h in history_records:
        h_dict = h.to_dict()
        actor = User.query.get(h.changed_by)
        if actor:
            h_dict['actorName'] = actor.name
            h_dict['actorRole'] = actor.role
        result.append(h_dict)

    if not result:
        student = User.query.get(complaint.student_id)
        result.append({
            "id": f"init_{complaint.id}",
            "complaintId": complaint.id,
            "changedBy": complaint.student_id,
            "actorName": student.name if student else "Student",
            "actorRole": "student",
            "oldStatus": None,
            "newStatus": complaint.status or "PENDING",
            "comment": "Complaint submitted",
            "remarks": "Complaint submitted",
            "timestamp": complaint.created_at
        })

    return jsonify(result), 200


@complaints_bp.route('/complaints/<id>/assign', methods=['POST'])
def assign_complaint(id):
    data = request.json or {}
    actor_id = data.get('actorId') or data.get('reviewerId')
    if not actor_id:
        requester, err_resp = get_authenticated_requester()
        if err_resp:
            return err_resp
        if requester:
            actor_id = requester.id
    assigned_to = data.get('assignedTo')
    remarks = data.get('remarks', '')

    if not actor_id:
        return jsonify({"message": "actorId is required"}), 400
    if not assigned_to:
        return jsonify({"message": "assignedTo is required"}), 400

    actor = User.query.get(actor_id)
    if not actor:
        return jsonify({"message": "Actor user not found"}), 404
    if actor.role == 'student':
        return jsonify({"message": "Unauthorized: Students cannot assign complaints"}), 403

    staff = User.query.get(assigned_to)
    if not staff:
        return jsonify({"message": "Assigned user not found"}), 404
    if staff.role == 'student':
        return jsonify({"message": "Cannot assign complaint to a student. Target must be staff/faculty/admin"}), 400

    complaint = find_complaint_by_identifier(id)
    if not complaint:
        return jsonify({"message": "Complaint not found"}), 404

    if complaint.status in ['RESOLVED', 'CLOSED', 'REJECTED']:
        return jsonify({"message": f"Cannot assign complaint in '{complaint.status}' status"}), 409

    try:
        old_status = complaint.status
        complaint.status = 'ASSIGNED'
        complaint.assigned_to = assigned_to
        complaint.updated_at = datetime.datetime.now().isoformat()

        comment = remarks or f"Assigned to {staff.name}"
        history = ComplaintStatusHistory(
            complaint_id=complaint.id,
            changed_by=actor_id,
            old_status=old_status,
            new_status='ASSIGNED',
            comment=comment
        )
        audit = RequestAudit(
            entity_type='COMPLAINT',
            entity_id=complaint.id,
            actor_id=actor_id,
            action='ASSIGNED',
            remarks=comment,
            ip_address=request.remote_addr
        )
        db.session.add(history)
        db.session.add(audit)
        db.session.commit()

        return jsonify({
            "message": "Complaint assigned successfully",
            "complaint": {**complaint.to_dict(), "assignedToName": staff.name}
        }), 200

    except Exception as e:
        db.session.rollback()
        return jsonify({"message": f"Server error assigning complaint: {str(e)}"}), 500


@complaints_bp.route('/complaints/<id>/action', methods=['POST'])
def action_complaint(id):
    data = request.json or {}
    actor_id = data.get('actorId')
    if not actor_id:
        requester, err_resp = get_authenticated_requester()
        if err_resp:
            return err_resp
        if requester:
            actor_id = requester.id
    action = (data.get('action') or '').upper()
    remarks = (data.get('remarks') or '').strip()
    assigned_to = data.get('assignedTo')

    if not actor_id:
        return jsonify({"message": "actorId is required"}), 400
    if not action:
        return jsonify({"message": "action is required"}), 400

    if action not in COMPLAINT_TRANSITIONS:
        return jsonify({"message": f"Invalid action '{action}'. Supported actions: {list(COMPLAINT_TRANSITIONS.keys())}"}), 400

    complaint = find_complaint_by_identifier(id)
    if not complaint:
        return jsonify({"message": "Complaint not found"}), 404

    actor = User.query.get(actor_id)
    if not actor:
        return jsonify({"message": "Actor user not found"}), 404
    if action in ['ASSIGN', 'START', 'RESOLVE', 'CLOSE', 'REJECT'] and actor.role == 'student':
        return jsonify({"message": f"Unauthorized: Students cannot perform '{action}' on complaints"}), 403

    allowed_statuses, next_status = COMPLAINT_TRANSITIONS[action]
    if complaint.status not in allowed_statuses:
        return jsonify({
            "message": f"Cannot transition complaint from status '{complaint.status}' using action '{action}' (Allowed from: {allowed_statuses})"
        }), 409

    # Specific action validations
    if action == 'RESOLVE':
        if not remarks:
            return jsonify({"message": "resolution remarks are required for RESOLVE action"}), 400
        
        # Enforce Proof-of-Fix 2-Way OTP handshake
        provided_otp = str(data.get('otp') or '').strip()
        if complaint.closure_otp:
            if not provided_otp:
                return jsonify({
                    "message": "Student closure OTP is required to verify physical inspection and resolve the ticket"
                }), 400
            if provided_otp != complaint.closure_otp:
                return jsonify({
                    "message": "Invalid Closure OTP. Please request the 4-digit verification code from the student after physically inspecting the completed work."
                }), 403
            complaint.otp_verified_at = datetime.datetime.now().isoformat()

    if action == 'REOPEN' and not remarks:
        return jsonify({"message": "reopen remarks are required for REOPEN action"}), 400

    if action == 'ASSIGN':
        if not assigned_to:
            return jsonify({"message": "assignedTo is required for ASSIGN action"}), 400
        staff = User.query.get(assigned_to)
        if not staff:
            return jsonify({"message": "Assigned staff not found"}), 404
        if staff.role == 'student':
            return jsonify({"message": "Cannot assign complaint to a student. Target must be staff/faculty/admin"}), 400
        complaint.assigned_to = assigned_to

    try:
        old_status = complaint.status
        complaint.status = next_status
        complaint.updated_at = datetime.datetime.now().isoformat()

        if action == 'RESOLVE':
            complaint.resolution_notes = remarks
            complaint.resolved_at = datetime.datetime.now().isoformat()

        comment = remarks or f"Status changed to {next_status}"
        history = ComplaintStatusHistory(
            complaint_id=complaint.id,
            changed_by=actor_id,
            old_status=old_status,
            new_status=next_status,
            comment=comment
        )
        audit = RequestAudit(
            entity_type='COMPLAINT',
            entity_id=complaint.id,
            actor_id=actor_id,
            action=action,
            remarks=comment,
            ip_address=request.remote_addr
        )
        db.session.add(history)
        db.session.add(audit)
        db.session.commit()

        return jsonify({
            "message": f"Complaint {next_status.lower()} successfully",
            "complaint": complaint.to_dict()
        }), 200

    except Exception as e:
        db.session.rollback()
        return jsonify({"message": f"Server error updating complaint: {str(e)}"}), 500


@complaints_bp.route('/complaints/student/<student_id>', methods=['GET'])
def get_student_complaints(student_id):
    student = User.query.get(student_id)
    if not student:
        return jsonify({"message": "Student not found"}), 404

    requester_id = request.args.get('requesterId')
    if requester_id:
        requester = User.query.get(requester_id)
        if requester and requester.role == 'student' and requester.id != student_id:
            return jsonify({"message": "Unauthorized: Cannot view another student's complaints"}), 403

    complaints = Complaint.query.filter_by(student_id=student_id).order_by(Complaint.created_at.desc()).all()
    return jsonify([c.to_dict() for c in complaints]), 200


@complaints_bp.route('/complaints/<identifier>', methods=['GET'])
def get_complaint_or_student_complaints(identifier):
    # Check if identifier is a Complaint ID first
    complaint = find_complaint_by_identifier(identifier)
    if complaint:
        requester_id = request.args.get('requesterId')
        requester = User.query.get(requester_id) if requester_id else None
        requester_role = requester.role if requester else None
        if requester and requester.role == 'student' and complaint.student_id != requester.id:
            return jsonify({"message": "Unauthorized: Cannot view another student's complaint"}), 403

        c_dict = complaint.to_dict(requester_role=requester_role, requester_id=requester_id)
        student = User.query.get(complaint.student_id)
        if student:
            c_dict['studentName'] = student.name
            c_dict['studentEmail'] = student.email
            c_dict['registrationNumber'] = student.registration_number
            c_dict['branch'] = student.branch
            c_dict['year'] = student.year

        if complaint.assigned_to:
            staff = User.query.get(complaint.assigned_to)
            if staff:
                c_dict['assignedToName'] = staff.name
                c_dict['assignedToEmail'] = staff.email

        return jsonify(c_dict), 200

    # Otherwise check if identifier is a Student ID
    student = User.query.get(identifier)
    if student:
        requester_id = request.args.get('requesterId')
        requester = User.query.get(requester_id) if requester_id else None
        requester_role = requester.role if requester else None
        if requester and requester.role == 'student' and requester.id != identifier:
            return jsonify({"message": "Unauthorized: Cannot view another student's complaints"}), 403

        complaints = Complaint.query.filter_by(student_id=identifier).order_by(Complaint.created_at.desc()).all()
        return jsonify([c.to_dict(requester_role=requester_role, requester_id=requester_id) for c in complaints]), 200

    return jsonify({"message": "Complaint or Student not found"}), 404


# ==============================================================================
# --- FEATURE 2: 2-WAY OTP CLOSURE & ESCALATION SLINGSHOT ENDPOINTS ---
# ==============================================================================

@complaints_bp.route('/complaints/<id>/verify-resolve', methods=['POST'])
def verify_resolve_complaint(id):
    """
    Dedicated Proof-of-Fix Endpoint.
    Enforces that staff/caretakers physically enter the student's 4-digit OTP to resolve.
    """
    data = request.json or {}
    actor_id = data.get('actorId') or request.headers.get('X-User-Id')
    otp = str(data.get('otp') or '').strip()
    remarks = (data.get('remarks') or data.get('resolutionNotes') or '').strip()

    if not actor_id:
        return jsonify({"message": "actorId is required"}), 400
    if not otp:
        return jsonify({"message": "Student closure OTP is required to verify physical inspection and resolve the ticket"}), 400
    if not remarks:
        return jsonify({"message": "Resolution remarks explaining the fix are required"}), 400

    complaint = find_complaint_by_identifier(id)
    if not complaint:
        return jsonify({"message": "Complaint not found"}), 404

    actor = User.query.get(actor_id)
    if not actor:
        return jsonify({"message": "Actor user not found"}), 404
    if actor.role == 'student':
        return jsonify({"message": "Unauthorized: Students cannot perform RESOLVE action"}), 403

    if complaint.status not in ['ASSIGNED', 'IN_PROGRESS', 'REOPENED']:
        return jsonify({
            "message": f"Cannot resolve complaint in status '{complaint.status}'. Ticket must be ASSIGNED or IN_PROGRESS."
        }), 409

    # Cryptographic OTP Handshake check
    if complaint.closure_otp and otp != complaint.closure_otp:
        return jsonify({
            "message": "Invalid Closure OTP. Please request the 4-digit verification code from the student after physically inspecting the completed work."
        }), 403

    try:
        old_status = complaint.status
        complaint.status = 'RESOLVED'
        complaint.resolved_at = datetime.datetime.now().isoformat()
        complaint.resolution_notes = remarks
        complaint.otp_verified_at = datetime.datetime.now().isoformat()
        complaint.updated_at = datetime.datetime.now().isoformat()

        comment = f"Verified & Resolved via Student Closure OTP. Remarks: {remarks}"
        history = ComplaintStatusHistory(
            complaint_id=complaint.id,
            changed_by=actor_id,
            old_status=old_status,
            new_status='RESOLVED',
            comment=comment
        )
        audit = RequestAudit(
            entity_type='COMPLAINT',
            entity_id=complaint.id,
            actor_id=actor_id,
            action='OTP_RESOLVED',
            remarks=comment,
            ip_address=request.remote_addr
        )
        db.session.add(history)
        db.session.add(audit)
        db.session.commit()

        return jsonify({
            "message": "Complaint verified and resolved successfully via Student Closure OTP",
            "complaint": complaint.to_dict(requester_role=actor.role, requester_id=actor.id)
        }), 200

    except Exception as e:
        db.session.rollback()
        return jsonify({"message": f"Server error resolving complaint: {str(e)}"}), 500


@complaints_bp.route('/complaints/<id>/feedback', methods=['POST'])
def submit_complaint_feedback(id):
    """
    Allows the student owner to submit post-resolution star ratings (1-5) and feedback.
    """
    data = request.json or {}
    student_id = data.get('studentId') or request.headers.get('X-User-Id')
    rating = data.get('rating')
    feedback = (data.get('feedback') or '').strip()

    if not student_id:
        return jsonify({"message": "studentId is required"}), 400
    if rating is None:
        return jsonify({"message": "Rating is required"}), 400
    
    try:
        rating_int = int(rating)
        if not (1 <= rating_int <= 5):
            raise ValueError()
    except (ValueError, TypeError):
        return jsonify({"message": "Valid star rating between 1 and 5 is required"}), 400

    complaint = find_complaint_by_identifier(id)
    if not complaint:
        return jsonify({"message": "Complaint not found"}), 404
    if complaint.student_id != student_id:
        return jsonify({"message": "Unauthorized: Only the student who submitted the complaint can provide feedback"}), 403
    if complaint.status not in ['RESOLVED', 'CLOSED']:
        return jsonify({"message": "Feedback can only be submitted for RESOLVED or CLOSED complaints"}), 409

    try:
        complaint.student_rating = rating_int
        complaint.student_feedback = feedback
        complaint.updated_at = datetime.datetime.now().isoformat()

        audit = RequestAudit(
            entity_type='COMPLAINT',
            entity_id=complaint.id,
            actor_id=student_id,
            action='FEEDBACK_SUBMITTED',
            remarks=f"Rating: {rating_int}/5 Stars. Comments: {feedback}",
            ip_address=request.remote_addr
        )
        db.session.add(audit)
        db.session.commit()

        return jsonify({
            "message": "Feedback recorded successfully",
            "complaint": complaint.to_dict(requester_role='student', requester_id=student_id)
        }), 200

    except Exception as e:
        db.session.rollback()
        return jsonify({"message": f"Server error recording feedback: {str(e)}"}), 500


@complaints_bp.route('/complaints/slingshot/evaluate', methods=['POST'])
def evaluate_slingshot_escalations():
    """
    Automated SLA Slingshot Evaluation Engine.
    Scans active tickets and auto-escalates based on aging SLA:
      - >24h without resolution: Tier 2 (Warden Alert)
      - >48h without resolution: Tier 3 (Dean Slingshot Red Alert + Vendor Penalty Flag)
    """
    now = datetime.datetime.now()
    active_complaints = Complaint.query.filter(
        Complaint.status.in_(['PENDING', 'ASSIGNED', 'IN_PROGRESS', 'REOPENED'])
    ).all()

    escalated_tier2 = []
    escalated_tier3 = []

    for c in active_complaints:
        if not c.created_at:
            continue
        try:
            created_dt = datetime.datetime.fromisoformat(c.created_at)
            age_hours = (now - created_dt).total_seconds() / 3600.0
        except Exception:
            continue

        # Tier 3 Dean Slingshot (>48h)
        if age_hours >= 48 and c.escalation_level < 3:
            c.escalation_level = 3
            c.escalated_at = now.isoformat()
            c.vendor_penalty_flag = True
            c.vendor_penalty_amount = 500.0  # ₹500/ticket vendor penalty
            c.updated_at = now.isoformat()

            comment = f"SLA Breach ({round(age_hours, 1)}h): Auto-escalated to Tier 3 Dean Slingshot with ₹500 vendor penalty"
            history = ComplaintStatusHistory(
                complaint_id=c.id,
                changed_by=c.assigned_to or c.student_id,
                old_status=c.status,
                new_status=c.status,
                comment=comment
            )
            audit = RequestAudit(
                entity_type='COMPLAINT',
                entity_id=c.id,
                actor_id=c.assigned_to or c.student_id,
                action='SLINGSHOT_TIER3',
                remarks=comment,
                ip_address=request.remote_addr
            )
            db.session.add(history)
            db.session.add(audit)
            escalated_tier3.append(c.id)

        # Tier 2 Warden Alert (>24h)
        elif age_hours >= 24 and c.escalation_level < 2:
            c.escalation_level = 2
            c.escalated_at = now.isoformat()
            c.updated_at = now.isoformat()

            comment = f"SLA Warning ({round(age_hours, 1)}h): Auto-escalated to Tier 2 Warden Alert"
            history = ComplaintStatusHistory(
                complaint_id=c.id,
                changed_by=c.assigned_to or c.student_id,
                old_status=c.status,
                new_status=c.status,
                comment=comment
            )
            audit = RequestAudit(
                entity_type='COMPLAINT',
                entity_id=c.id,
                actor_id=c.assigned_to or c.student_id,
                action='SLINGSHOT_TIER2',
                remarks=comment,
                ip_address=request.remote_addr
            )
            db.session.add(history)
            db.session.add(audit)
            escalated_tier2.append(c.id)

    db.session.commit()

    return jsonify({
        "message": "SLA Slingshot evaluation completed",
        "evaluatedCount": len(active_complaints),
        "escalatedToTier2Count": len(escalated_tier2),
        "escalatedToTier3Count": len(escalated_tier3),
        "tier2ComplaintIds": escalated_tier2,
        "tier3ComplaintIds": escalated_tier3
    }), 200


@complaints_bp.route('/complaints/slingshot/dashboard', methods=['GET'])
def get_slingshot_dashboard():
    """
    Returns executive metrics for the SLA Escalation Slingshot and vendor penalties.
    """
    now = datetime.datetime.now()
    active_complaints = Complaint.query.filter(
        Complaint.status.in_(['PENDING', 'ASSIGNED', 'IN_PROGRESS', 'REOPENED'])
    ).all()

    tier1_count = 0
    tier2_count = 0
    tier3_count = 0
    vendor_penalties_count = 0
    total_penalty_amount = 0.0
    slingshot_tickets = []

    for c in active_complaints:
        level = c.escalation_level or 1
        age_hours = 0.0
        if c.created_at:
            try:
                age_hours = round((now - datetime.datetime.fromisoformat(c.created_at)).total_seconds() / 3600.0, 1)
            except Exception:
                pass

        if level == 1:
            tier1_count += 1
        elif level == 2:
            tier2_count += 1
        elif level == 3:
            tier3_count += 1

        if c.vendor_penalty_flag:
            vendor_penalties_count += 1
            total_penalty_amount += (c.vendor_penalty_amount or 0.0)

        if level >= 2 or age_hours >= 24:
            c_dict = c.to_dict()
            c_dict['ageHours'] = age_hours
            student = User.query.get(c.student_id)
            if student:
                c_dict['studentName'] = student.name
                c_dict['studentEmail'] = student.email
            if c.assigned_to:
                staff = User.query.get(c.assigned_to)
                if staff:
                    c_dict['assignedToName'] = staff.name
            slingshot_tickets.append(c_dict)

    # Sort most delayed tickets first
    slingshot_tickets.sort(key=lambda x: x.get('ageHours', 0), reverse=True)

    return jsonify({
        "totalActive": len(active_complaints),
        "tier1Normal": tier1_count,
        "tier2WardenAlert": tier2_count,
        "tier3DeanSlingshot": tier3_count,
        "vendorPenaltiesTriggered": vendor_penalties_count,
        "totalVendorPenaltyAmount": total_penalty_amount,
        "slingshotTickets": slingshot_tickets
    }), 200
