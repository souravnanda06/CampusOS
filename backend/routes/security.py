import datetime
from datetime import timedelta, timezone
from flask import Blueprint, request, jsonify
from extensions import db
from models.user import User
from models.leave import LeaveRequest
from models.gate_pass import GatePass
from models.audit import RequestAudit
from middleware.auth import get_authenticated_security_guard
from utils.crypto import verify_signed_credential
from services.whatsapp_service import send_gate_exit_alert, send_gate_entry_alert

security_bp = Blueprint('security_bp', __name__)

@security_bp.route('/security/gate-pass/summary', methods=['GET'])
def get_gate_security_summary():
    """
    Returns operational gate command center metrics for Security Shell Home.
    Enforces SECURITY or ADMIN role authentication.
    """
    guard, err_resp, err_code = get_authenticated_security_guard()
    if err_resp:
        return err_resp, err_code

    now = datetime.datetime.now()
    now_iso = now.isoformat()
    today_prefix = now.strftime('%Y-%m-%d')

    hour = now.hour
    if 6 <= hour < 14:
        shift_name = "Morning Shift (06:00 - 14:00)"
    elif 14 <= hour < 22:
        shift_name = "Evening Shift (14:00 - 22:00)"
    else:
        shift_name = "Night Shift (22:00 - 06:00)"

    passes_awaiting = GatePass.query.filter_by(status='ISSUED').count()
    students_outside = GatePass.query.filter_by(status='EXITED').count()
    
    recently_exited = GatePass.query.filter(
        GatePass.status.in_(['EXITED', 'RETURNED']),
        GatePass.actual_exit_time.like(f"{today_prefix}%")
    ).count()

    recently_returned = GatePass.query.filter(
        GatePass.status == 'RETURNED',
        GatePass.actual_return_time.like(f"{today_prefix}%")
    ).count()

    failed_attempts = RequestAudit.query.filter(
        RequestAudit.entity_type == 'GATE_PASS',
        RequestAudit.action.in_(['VERIFICATION_FAILED', 'INVALID_CREDENTIAL']),
        RequestAudit.timestamp.like(f"{today_prefix}%")
    ).count()

    return jsonify({
        "gateStatus": "ONLINE",
        "currentTime": now_iso,
        "activeShift": shift_name,
        "passesAwaitingVerification": passes_awaiting,
        "studentsOutside": students_outside,
        "recentlyExited": recently_exited,
        "recentlyReturned": recently_returned,
        "failedAttempts": failed_attempts,
        "offlineSyncPendingCount": 0
    }), 200


@security_bp.route('/security/gate-passes', methods=['GET'])
def get_security_gate_passes():
    """
    Returns operational list of gate passes for security staff.
    Supports status filtering (ALL, ISSUED, EXITED, RETURNED, EXPIRED) and search.
    Enforces SECURITY or ADMIN role authentication.
    """
    guard, err_resp, err_code = get_authenticated_security_guard()
    if err_resp:
        return err_resp, err_code

    status_filter = request.args.get('status')
    search = request.args.get('search')
    limit = int(request.args.get('limit', 100))

    query = db.session.query(GatePass, User).join(User, GatePass.student_id == User.id)

    if status_filter and status_filter.upper() != 'ALL':
        query = query.filter(GatePass.status == status_filter.upper())

    if search and search.strip():
        term = f"%{search.strip()}%"
        query = query.filter(
            db.or_(
                User.name.ilike(term),
                User.registration_number.ilike(term),
                GatePass.id.ilike(term),
                GatePass.destination.ilike(term)
            )
        )

    query = query.order_by(GatePass.created_at.desc()).limit(limit)
    results = query.all()

    passes = []
    for gp, student in results:
        pass_dict = gp.to_dict()
        pass_dict["student"] = {
            "id": student.id,
            "name": student.name,
            "registrationNumber": student.registration_number or "N/A",
            "course": student.course or "N/A",
            "branch": student.branch or "N/A",
            "year": student.year or "N/A"
        }
        passes.append(pass_dict)

    return jsonify(passes), 200


@security_bp.route('/security/gate-pass/activity', methods=['GET'])
@security_bp.route('/security/audit-logs', methods=['GET'])
def get_security_gate_activity():
    """
    Gate security audit activity timeline.
    Filters: ALL, EXITS, RETURNS, FAILED, DUPLICATE, OFFLINE
    Enforces SECURITY or ADMIN role authentication.
    """
    guard, err_resp, err_code = get_authenticated_security_guard()
    if err_resp:
        return err_resp, err_code

    filter_type = (request.args.get('filter') or 'ALL').upper()
    limit = int(request.args.get('limit', 50))

    query = RequestAudit.query.filter(RequestAudit.entity_type == 'GATE_PASS')

    if filter_type == 'EXITS':
        query = query.filter(RequestAudit.action == 'SCANNED_OUT')
    elif filter_type == 'RETURNS':
        query = query.filter(RequestAudit.action == 'SCANNED_IN')
    elif filter_type == 'FAILED':
        query = query.filter(RequestAudit.action.in_(['VERIFICATION_FAILED', 'INVALID_CREDENTIAL']))
    elif filter_type == 'DUPLICATE':
        query = query.filter(RequestAudit.action == 'DUPLICATE_ATTEMPT')
    elif filter_type == 'OFFLINE':
        query = query.filter(RequestAudit.remarks.ilike('%offline%'))

    audits = query.order_by(RequestAudit.timestamp.desc()).limit(limit).all()

    activities = []
    for audit in audits:
        actor = User.query.get(audit.actor_id) if audit.actor_id else None
        gp = GatePass.query.get(audit.entity_id) if audit.entity_id else None
        student = User.query.get(gp.student_id) if gp else None

        if audit.action == 'SCANNED_OUT':
            op = 'EXIT'
            res = 'SUCCESS'
        elif audit.action == 'SCANNED_IN':
            op = 'RETURN'
            res = 'SUCCESS'
        elif audit.action in ['VERIFICATION_FAILED', 'INVALID_CREDENTIAL']:
            op = 'VERIFY'
            res = 'FAILED'
        elif audit.action == 'DUPLICATE_ATTEMPT':
            op = 'VERIFY'
            res = 'DUPLICATE'
        else:
            op = audit.action
            res = 'SUCCESS'

        mode = gp.verification_mode if gp and gp.verification_mode else 'QR_FALLBACK'
        if 'BLE' in (audit.remarks or ''):
            mode = 'BLE'
        elif 'OFFLINE' in (audit.remarks or '').upper():
            mode = 'OFFLINE'

        student_name = student.name if student else "Unknown Student"
        reg_number = student.registration_number if student else "N/A"
        actor_name = actor.name if actor else "Gate Security"

        activities.append({
            "id": audit.id,
            "passId": audit.entity_id,
            "operation": op,
            "result": res,
            "verificationMode": mode,
            "timestamp": audit.timestamp,
            "remarks": audit.remarks or "",
            "studentId": student.id if student else None,
            "studentName": student_name,
            "registrationNumber": reg_number,
            "operatorId": actor.id if actor else None,
            "operatorName": actor_name,
            "student": {
                "id": student.id if student else None,
                "name": student_name,
                "registrationNumber": reg_number
            },
            "securityStaff": {
                "id": actor.id if actor else None,
                "name": actor_name
            }
        })

    return jsonify(activities), 200


@security_bp.route('/security/gate-pass/verify', methods=['POST'])
def verify_gate_pass_credential():
    guard, err_resp, err_code = get_authenticated_security_guard()
    if err_resp:
        return err_resp, err_code

    security_guard_id = guard.id  # Server-resolved authenticated guard identity
    data = request.json or {}
    credential = data.get('credential')
    gate_name = data.get('gateName', 'Main Gate')

    if not credential:
        return jsonify({
            "valid": False,
            "resultCode": "INVALID_CREDENTIAL",
            "message": "Credential token is required"
        }), 400

    # Cryptographic HMAC verification using GATE_PASS_SECRET
    is_valid, payload, msg = verify_signed_credential(credential)
    if not is_valid:
        try:
            audit = RequestAudit(
                entity_type='GATE_PASS',
                entity_id='UNKNOWN',
                actor_id=security_guard_id,
                action='INVALID_CREDENTIAL',
                remarks=f"HMAC validation failed: {msg} at {gate_name}",
                ip_address=request.remote_addr
            )
            db.session.add(audit)
            db.session.commit()
        except Exception:
            db.session.rollback()

        return jsonify({
            "valid": False,
            "resultCode": "INVALID_CREDENTIAL",
            "message": f"Cryptographic verification failed: {msg}"
        }), 200

    gate_pass_id = payload.get('gatePassId')
    nonce = payload.get('nonce')

    gp = GatePass.query.get(gate_pass_id)
    if not gp:
        return jsonify({
            "valid": False,
            "resultCode": "NOT_FOUND",
            "message": "Gate pass record not found in system"
        }), 200

    if gp.qr_nonce != nonce:
        try:
            audit = RequestAudit(
                entity_type='GATE_PASS',
                entity_id=gp.id,
                actor_id=security_guard_id,
                action='VERIFICATION_FAILED',
                remarks=f"Nonce mismatch or revoked pass at {gate_name}",
                ip_address=request.remote_addr
            )
            db.session.add(audit)
            db.session.commit()
        except Exception:
            db.session.rollback()

        return jsonify({
            "valid": False,
            "resultCode": "INVALID_CREDENTIAL",
            "message": "Credential nonce mismatch or pass has been reissued/revoked"
        }), 200

    # Anti-replay / state checks
    if gp.status == 'RETURNED':
        return jsonify({
            "valid": False,
            "resultCode": "ALREADY_PROCESSED",
            "message": "This gate pass has already been used and returned. Cannot exit or return again."
        }), 200

    if gp.status in ['REJECTED', 'CANCELLED']:
        return jsonify({
            "valid": False,
            "resultCode": "INVALID_STATE",
            "message": f"Gate pass is in invalid state: {gp.status}"
        }), 200

    if gp.status == 'PENDING':
        return jsonify({
            "valid": False,
            "resultCode": "INVALID_STATE",
            "message": "Gate pass is pending Warden approval. Exit not permitted."
        }), 200

    if gp.status not in ['ISSUED', 'EXITED']:
        return jsonify({
            "valid": False,
            "resultCode": "INVALID_STATE",
            "message": f"Pass is not active for transit (Current Status: {gp.status})"
        }), 200

    # Expiry verification (with 30-minute grace period)
    try:
        return_dt = datetime.datetime.fromisoformat(gp.expected_return_time)
        if datetime.datetime.now() > return_dt + datetime.timedelta(minutes=30):
            gp.status = 'EXPIRED'
            db.session.commit()
            return jsonify({
                "valid": False,
                "resultCode": "EXPIRED",
                "message": f"Gate pass expired at {gp.expected_return_time}"
            }), 200
    except Exception:
        pass

    action = 'EXIT' if gp.status == 'ISSUED' else 'RETURN'
    student = User.query.get(gp.student_id)
    leave_req = LeaveRequest.query.get(gp.leave_request_id) if gp.leave_request_id else None
    reviewer = User.query.get(leave_req.reviewed_by) if (leave_req and leave_req.reviewed_by) else None

    return jsonify({
        "valid": True,
        "resultCode": "VERIFIED",
        "gatePassId": gp.id,
        "student": {
            "id": student.id if student else None,
            "name": student.name if student else "Unknown",
            "registrationNumber": student.registration_number if student else "N/A",
            "course": student.course if student else "N/A",
            "branch": student.branch if student else "N/A",
            "year": student.year if student else "N/A"
        },
        "pass": {
            "id": gp.id,
            "leaveRequestId": gp.leave_request_id,
            "destination": gp.destination,
            "reason": gp.reason,
            "currentStatus": gp.status,
            "issueTime": gp.created_at,
            "validFrom": gp.expected_exit_time,
            "validUntil": gp.expected_return_time,
            "actualExitTime": gp.actual_exit_time,
            "approvedBy": reviewer.name if reviewer else "Warden",
            "gateName": gp.gate_name or gate_name
        },
        "action": action,
        "message": "Gate Pass Verified"
    }), 200


@security_bp.route('/security/gate-pass/<id>/exit', methods=['POST'])
def exit_gate_pass(id):
    guard, err_resp, err_code = get_authenticated_security_guard()
    if err_resp:
        return err_resp, err_code

    security_guard_id = guard.id  # Overwrite client-supplied identity with authenticated guard
    data = request.json or {}
    gate_name = data.get('gateName', 'Main Gate')
    verification_mode = data.get('verificationMode', 'QR_FALLBACK')
    idempotency_key = data.get('idempotencyKey')
    remarks = data.get('remarks', '')

    gp = GatePass.query.get(id)
    if not gp:
        return jsonify({"message": "Gate pass not found", "resultCode": "NOT_FOUND"}), 404

    # Idempotent replay check
    if idempotency_key and gp.idempotency_key == idempotency_key and gp.status == 'EXITED':
        return jsonify({
            "message": "Student exit already recorded (idempotent)",
            "resultCode": "ALREADY_PROCESSED",
            "gatePass": gp.to_dict()
        }), 200

    if gp.status == 'EXITED':
        try:
            audit = RequestAudit(
                entity_type='GATE_PASS',
                entity_id=gp.id,
                actor_id=security_guard_id,
                action='DUPLICATE_ATTEMPT',
                remarks=f"Duplicate exit attempt prevented at {gate_name}",
                ip_address=request.remote_addr
            )
            db.session.add(audit)
            db.session.commit()
        except Exception:
            db.session.rollback()

        return jsonify({
            "message": "Student has already exited campus with this pass",
            "resultCode": "ALREADY_PROCESSED"
        }), 409

    if gp.status != 'ISSUED':
        return jsonify({
            "message": f"Cannot scan out: Gate pass status is {gp.status} (expected ISSUED)",
            "resultCode": "INVALID_STATE"
        }), 409

    try:
        gp.status = 'EXITED'
        gp.actual_exit_time = datetime.datetime.now().isoformat()
        gp.gate_name = gate_name
        gp.verification_mode = verification_mode
        gp.security_guard_id = guard.id  # Enforce authenticated security guard
        if idempotency_key:
            gp.idempotency_key = idempotency_key
        
        audit_actor_id = guard.id

        terminal_info = f" [Gate: {gate_name} | Mode: {verification_mode}]"
        audit = RequestAudit(
            entity_type='GATE_PASS',
            entity_id=gp.id,
            actor_id=audit_actor_id,
            action='SCANNED_OUT',
            remarks=(remarks or f"Exited towards {gp.destination}") + terminal_info,
            ip_address=request.remote_addr
        )
        db.session.add(audit)
        db.session.commit()

        # Dispatch automated WhatsApp transit alert to parent via OpenWA
        try:
            student_user = User.query.get(gp.student_id)
            if student_user and student_user.parent_phone:
                send_gate_exit_alert(
                    parent_phone=student_user.parent_phone,
                    student_name=student_user.name,
                    reg_no=student_user.registration_number or '',
                    gate_name=gate_name,
                    timestamp_str=gp.actual_exit_time,
                    destination=gp.destination
                )
        except Exception:
            pass

        return jsonify({
            "message": "Student exit recorded successfully",
            "resultCode": "EXITED",
            "gatePass": gp.to_dict()
        }), 200

    except Exception as e:
        db.session.rollback()
        return jsonify({"message": f"Server error recording exit: {str(e)}"}), 500


@security_bp.route('/security/gate-pass/<id>/return', methods=['POST'])
def return_gate_pass(id):
    guard, err_resp, err_code = get_authenticated_security_guard()
    if err_resp:
        return err_resp, err_code

    security_guard_id = guard.id  # Overwrite client-supplied identity with authenticated guard
    data = request.json or {}
    gate_name = data.get('gateName', 'Main Gate')
    verification_mode = data.get('verificationMode', 'QR_FALLBACK')
    idempotency_key = data.get('idempotencyKey')
    remarks = data.get('remarks', '')

    gp = GatePass.query.get(id)
    if not gp:
        return jsonify({"message": "Gate pass not found", "resultCode": "NOT_FOUND"}), 404

    # Idempotent replay check: cannot return twice
    if gp.status == 'RETURNED':
        if idempotency_key and gp.idempotency_key == idempotency_key:
            return jsonify({
                "message": "Student return already recorded (idempotent)",
                "resultCode": "ALREADY_PROCESSED",
                "gatePass": gp.to_dict()
            }), 200
        
        try:
            audit = RequestAudit(
                entity_type='GATE_PASS',
                entity_id=gp.id,
                actor_id=security_guard_id,
                action='DUPLICATE_ATTEMPT',
                remarks=f"Duplicate return attempt prevented at {gate_name}",
                ip_address=request.remote_addr
            )
            db.session.add(audit)
            db.session.commit()
        except Exception:
            db.session.rollback()

        return jsonify({
            "message": "Gate pass has already been returned. Cannot mark returned again.",
            "resultCode": "ALREADY_PROCESSED"
        }), 409

    if gp.status != 'EXITED':
        return jsonify({
            "message": f"Cannot scan in: Gate pass status is {gp.status} (expected EXITED)",
            "resultCode": "INVALID_STATE"
        }), 409

    try:
        gp.status = 'RETURNED'
        gp.actual_return_time = datetime.datetime.now().isoformat()
        gp.gate_name = gate_name
        gp.verification_mode = verification_mode
        gp.security_guard_id = guard.id  # Enforce authenticated security guard
        if idempotency_key:
            gp.idempotency_key = idempotency_key

        audit_actor_id = guard.id

        terminal_info = f" [Gate: {gate_name} | Mode: {verification_mode}]"
        audit = RequestAudit(
            entity_type='GATE_PASS',
            entity_id=gp.id,
            actor_id=audit_actor_id,
            action='SCANNED_IN',
            remarks=(remarks or "Returned to campus") + terminal_info,
            ip_address=request.remote_addr
        )
        db.session.add(audit)
        db.session.commit()

        # Dispatch automated WhatsApp transit alert to parent via OpenWA
        try:
            student_user = User.query.get(gp.student_id)
            if student_user and student_user.parent_phone:
                send_gate_entry_alert(
                    parent_phone=student_user.parent_phone,
                    student_name=student_user.name,
                    reg_no=student_user.registration_number or '',
                    gate_name=gate_name,
                    timestamp_str=gp.actual_entry_time
                )
        except Exception:
            pass

        return jsonify({
            "message": "Student return recorded successfully",
            "resultCode": "RETURNED",
            "gatePass": gp.to_dict()
        }), 200

    except Exception as e:
        db.session.rollback()
        return jsonify({"message": f"Server error recording return: {str(e)}"}), 500


@security_bp.route('/security/gate-pass/batch-sync', methods=['POST'])
def batch_sync_gate_passes():
    """
    Synchronizes offline verified gate events with central backend.
    Ensures idempotency, audit trail recording, and server confirmation.
    Enforces SECURITY or ADMIN role authentication.
    """
    guard, err_resp, err_code = get_authenticated_security_guard()
    if err_resp:
        return err_resp, err_code

    data = request.json or {}
    events = data.get('events', [])
    if not isinstance(events, list):
        return jsonify({"message": "events must be an array"}), 400

    synced_results = []
    synced_count = 0

    for ev in events:
        pass_id = ev.get('passId') or ev.get('gatePassId')
        action = (ev.get('action') or 'EXIT').upper()
        # Bind actor identity to the authenticated security guard
        guard_id = guard.id
        gate_name = ev.get('gateName', 'Main Gate')
        idempotency_key = ev.get('idempotencyKey')
        timestamp = ev.get('timestamp') or datetime.datetime.now().isoformat()

        if not pass_id:
            synced_results.append({
                "passId": None,
                "status": "FAILED",
                "message": "Missing passId"
            })
            continue

        gp = GatePass.query.get(pass_id)
        if not gp:
            synced_results.append({
                "passId": pass_id,
                "status": "FAILED",
                "message": "Pass not found"
            })
            continue

        if idempotency_key and gp.idempotency_key == idempotency_key:
            synced_results.append({
                "passId": pass_id,
                "status": "ALREADY_PROCESSED",
                "message": "Already synced with this idempotency key",
                "gatePass": gp.to_dict()
            })
            continue

        try:
            if action == 'EXIT':
                if gp.status == 'ISSUED':
                    gp.status = 'EXITED'
                    gp.actual_exit_time = timestamp
                    gp.verification_mode = 'OFFLINE_SYNC'
                    gp.gate_name = gate_name
                    if idempotency_key:
                        gp.idempotency_key = idempotency_key
                    gp.security_guard_id = guard_id

                    audit = RequestAudit(
                        entity_type='GATE_PASS',
                        entity_id=gp.id,
                        actor_id=guard_id,
                        action='SCANNED_OUT',
                        remarks=f"Offline exit synchronized [Gate: {gate_name}]",
                        timestamp=timestamp,
                        ip_address=request.remote_addr
                    )
                    db.session.add(audit)
                    db.session.commit()
                    synced_count += 1
                    synced_results.append({
                        "passId": pass_id,
                        "status": "CONFIRMED",
                        "gatePass": gp.to_dict()
                    })
                elif gp.status == 'EXITED':
                    synced_results.append({
                        "passId": pass_id,
                        "status": "ALREADY_PROCESSED",
                        "message": "Already exited"
                    })
                else:
                    synced_results.append({
                        "passId": pass_id,
                        "status": "INVALID_STATE",
                        "message": f"Cannot exit in status {gp.status}"
                    })

            elif action == 'RETURN':
                if gp.status == 'EXITED':
                    gp.status = 'RETURNED'
                    gp.actual_return_time = timestamp
                    gp.verification_mode = 'OFFLINE_SYNC'
                    gp.gate_name = gate_name
                    if idempotency_key:
                        gp.idempotency_key = idempotency_key
                    gp.security_guard_id = guard_id

                    audit = RequestAudit(
                        entity_type='GATE_PASS',
                        entity_id=gp.id,
                        actor_id=guard_id,
                        action='SCANNED_IN',
                        remarks=f"Offline return synchronized [Gate: {gate_name}]",
                        timestamp=timestamp,
                        ip_address=request.remote_addr
                    )
                    db.session.add(audit)
                    db.session.commit()
                    synced_count += 1
                    synced_results.append({
                        "passId": pass_id,
                        "status": "CONFIRMED",
                        "gatePass": gp.to_dict()
                    })
                elif gp.status == 'RETURNED':
                    synced_results.append({
                        "passId": pass_id,
                        "status": "ALREADY_PROCESSED",
                        "message": "Already returned"
                    })
                else:
                    synced_results.append({
                        "passId": pass_id,
                        "status": "INVALID_STATE",
                        "message": f"Cannot return in status {gp.status}"
                    })
        except Exception as e:
            db.session.rollback()
            synced_results.append({
                "passId": pass_id,
                "status": "ERROR",
                "message": str(e)
            })

    return jsonify({
        "syncedCount": synced_count,
        "totalEvents": len(events),
        "results": synced_results
    }), 200


# --- COMPLAINT & RESOLUTION ROUTES ---

COMPLAINT_AGEING_HOURS = 48
RECURRENCE_WINDOW_DAYS = 14
MIN_COMPLAINTS_FOR_RECURRENCE = 3
ESCALATION_ELEVATED_THRESHOLD = 4
ESCALATION_HIGH_THRESHOLD = 6

COMPLAINT_TRANSITIONS = {
    'ASSIGN': (['PENDING', 'REOPENED'], 'ASSIGNED'),
    'REJECT': (['PENDING'], 'REJECTED'),
    'START': (['ASSIGNED', 'REOPENED'], 'IN_PROGRESS'),
    'RESOLVE': (['IN_PROGRESS'], 'RESOLVED'),
    'CLOSE': (['RESOLVED'], 'CLOSED'),
    'REOPEN': (['RESOLVED'], 'REOPENED'),
}

