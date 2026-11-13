import uuid
import datetime
from flask import Blueprint, request, jsonify
from extensions import db
from models.user import User
from models.expansion import (
    HostelAllocation,
    HostelRequest,
    HostelAsset,
    AssetIssue
)
from models.audit import RequestAudit
from models.notification import NotificationDelivery
from middleware.auth import get_authenticated_requester

hostel_bp = Blueprint('hostel_bp', __name__)

@hostel_bp.route('/hostel/my-room', methods=['GET'])
def get_my_room():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required"}), 401

    alloc = HostelAllocation.query.filter_by(student_id=requester.id, status='ACTIVE').first()
    if not alloc:
        return jsonify({
            "hasAllocation": False,
            "message": "No active hostel allocation found for your account."
        }), 200

    # Find roommates sharing same hostel and room
    roommates_query = (
        db.session.query(HostelAllocation, User)
        .join(User, HostelAllocation.student_id == User.id)
        .filter(
            HostelAllocation.hostel_name == alloc.hostel_name,
            HostelAllocation.room_number == alloc.room_number,
            HostelAllocation.student_id != requester.id,
            HostelAllocation.status == 'ACTIVE'
        )
        .all()
    )

    roommates = []
    for r_alloc, r_user in roommates_query:
        roommates.append({
            "id": r_user.id,
            "name": r_user.name,
            "branch": r_user.branch,
            "year": r_user.year,
            "bedNumber": r_alloc.bed_number,
            "phone": r_user.phone if hasattr(r_user, 'phone') else None
        })

    alloc_dict = alloc.to_dict()
    alloc_dict['hasAllocation'] = True
    alloc_dict['studentName'] = requester.name
    alloc_dict['roommates'] = roommates

    return jsonify(alloc_dict), 200

@hostel_bp.route('/hostel/my-assets', methods=['GET'])
def get_my_assets():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required"}), 401

    alloc = HostelAllocation.query.filter_by(student_id=requester.id, status='ACTIVE').first()
    if not alloc:
        return jsonify([]), 200

    assets = HostelAsset.query.filter_by(
        hostel_name=alloc.hostel_name,
        room_number=alloc.room_number
    ).all()

    return jsonify([a.to_dict() for a in assets]), 200

@hostel_bp.route('/hostel/requests', methods=['POST'])
def create_hostel_request():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required"}), 401
    if requester.role != 'student':
        return jsonify({"message": "Forbidden: Only students can submit hostel requests"}), 403

    data = request.json or {}
    req_type = (data.get('requestType') or '').strip().upper()
    reason = (data.get('reason') or '').strip()
    preferred_hostel = data.get('preferredHostel')
    preferred_room = data.get('preferredRoom')

    if not req_type or req_type not in ['ROOM_CHANGE', 'MAINTENANCE', 'HOSTEL_CHANGE', 'SPECIAL_ASSISTANCE']:
        return jsonify({"message": "Valid requestType is required"}), 400
    if not reason:
        return jsonify({"message": "reason is required"}), 400

    new_req = HostelRequest(
        student_id=requester.id,
        request_type=req_type,
        preferred_hostel=preferred_hostel,
        preferred_room=preferred_room,
        reason=reason,
        status='PENDING'
    )
    db.session.add(new_req)

    audit = RequestAudit(
        entity_type='HOSTEL_REQUEST',
        entity_id=new_req.id,
        actor_id=requester.id,
        action='SUBMITTED',
        remarks=f"Hostel {req_type} request: {reason}",
        ip_address=request.remote_addr
    )
    db.session.add(audit)
    db.session.commit()

    return jsonify({
        "message": "Hostel request submitted successfully",
        "request": new_req.to_dict()
    }), 201

@hostel_bp.route('/hostel/requests/my', methods=['GET'])
def get_my_hostel_requests():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required"}), 401

    reqs = HostelRequest.query.filter_by(student_id=requester.id).order_by(HostelRequest.created_at.desc()).all()
    return jsonify([r.to_dict() for r in reqs]), 200

@hostel_bp.route('/hostel/assets/report-issue', methods=['POST'])
def report_asset_issue():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required"}), 401

    data = request.json or {}
    asset_id = data.get('assetId')
    issue_type = (data.get('issueType') or '').strip().upper()
    description = (data.get('description') or '').strip()

    if not asset_id:
        return jsonify({"message": "assetId is required"}), 400
    if issue_type not in ['DAMAGED', 'MISSING', 'REPAIR_NEEDED', 'REPLACEMENT_REQUESTED']:
        return jsonify({"message": "Valid issueType is required"}), 400
    if not description:
        return jsonify({"message": "description is required"}), 400

    asset = HostelAsset.query.get(asset_id)
    if not asset:
        return jsonify({"message": "Asset not found"}), 404

    issue = AssetIssue(
        asset_id=asset.id,
        student_id=requester.id,
        issue_type=issue_type,
        description=description,
        status='REPORTED'
    )
    db.session.add(issue)

    # Update asset condition if damaged
    if issue_type in ['DAMAGED', 'REPAIR_NEEDED']:
        asset.condition = 'DAMAGED'

    audit = RequestAudit(
        entity_type='ASSET_ISSUE',
        entity_id=issue.id,
        actor_id=requester.id,
        action='REPORTED',
        remarks=f"{issue_type} reported for {asset.asset_name}: {description}",
        ip_address=request.remote_addr
    )
    db.session.add(audit)
    db.session.commit()

    return jsonify({
        "message": "Asset issue reported successfully",
        "issue": issue.to_dict()
    }), 201

@hostel_bp.route('/hostel/assets/issues/my', methods=['GET'])
def get_my_asset_issues():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required"}), 401

    issues = (
        db.session.query(AssetIssue, HostelAsset)
        .join(HostelAsset, AssetIssue.asset_id == HostelAsset.id)
        .filter(AssetIssue.student_id == requester.id)
        .order_by(AssetIssue.reported_at.desc())
        .all()
    )

    results = []
    for issue, asset in issues:
        d = issue.to_dict()
        d.update({
            "assetName": asset.asset_name,
            "assetCode": asset.asset_code,
            "roomNumber": asset.room_number,
            "hostelName": asset.hostel_name
        })
        results.append(d)

    return jsonify(results), 200

@hostel_bp.route('/hostel/warden/overview', methods=['GET'])
def get_warden_hostel_overview():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester or requester.role not in ['warden', 'admin']:
        return jsonify({"message": "Forbidden: Warden role required"}), 403

    total_allocations = HostelAllocation.query.filter_by(status='ACTIVE').count()
    pending_requests = HostelRequest.query.filter_by(status='PENDING').count()
    pending_issues = AssetIssue.query.filter(AssetIssue.status.in_(['REPORTED', 'ACKNOWLEDGED', 'IN_REPAIR'])).count()

    return jsonify({
        "totalResidents": total_allocations,
        "pendingHostelRequests": pending_requests,
        "activeAssetIssues": pending_issues,
        "hostelName": "Mahanadi Hall of Residence"
    }), 200

@hostel_bp.route('/hostel/warden/requests', methods=['GET'])
def get_warden_hostel_requests():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester or requester.role not in ['warden', 'admin']:
        return jsonify({"message": "Forbidden: Warden role required"}), 403

    reqs = (
        db.session.query(HostelRequest, User)
        .join(User, HostelRequest.student_id == User.id)
        .order_by(HostelRequest.created_at.desc())
        .all()
    )

    results = []
    for r, student in reqs:
        d = r.to_dict()
        d.update({
            "studentName": student.name,
            "registrationNumber": student.registration_number,
            "branch": student.branch,
            "year": student.year
        })
        results.append(d)

    return jsonify(results), 200

@hostel_bp.route('/hostel/warden/requests/<id>/action', methods=['POST'])
def action_hostel_request(id):
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester or requester.role not in ['warden', 'admin']:
        return jsonify({"message": "Forbidden: Warden role required"}), 403

    req_obj = HostelRequest.query.get(id)
    if not req_obj:
        return jsonify({"message": "Hostel request not found"}), 404

    data = request.json or {}
    action = (data.get('action') or '').upper()  # APPROVE, REJECT, COMPLETE
    remarks = (data.get('remarks') or '').strip()

    if action not in ['APPROVE', 'REJECT', 'COMPLETE']:
        return jsonify({"message": "Invalid action. Supported: APPROVE, REJECT, COMPLETE"}), 400

    req_obj.status = 'APPROVED' if action == 'APPROVE' else 'REJECTED' if action == 'REJECT' else 'COMPLETED'
    req_obj.warden_id = requester.id
    req_obj.warden_remarks = remarks or f"Actioned ({action}) by Warden"

    # Notification to student
    now_iso = datetime.datetime.now().isoformat()
    notif = NotificationDelivery(
        user_id=req_obj.student_id,
        title=f"Hostel Request {req_obj.status.title()}",
        body=f"Your {req_obj.request_type} request was {req_obj.status.lower()}. {remarks}",
        notification_type="HOSTEL",
        reference_id=req_obj.id,
        status="PENDING",
        delivered_at=now_iso,
        created_at=now_iso
    )
    db.session.add(notif)

    audit = RequestAudit(
        entity_type='HOSTEL_REQUEST',
        entity_id=req_obj.id,
        actor_id=requester.id,
        action=action,
        remarks=f"Warden action {action}: {remarks}",
        ip_address=request.remote_addr
    )
    db.session.add(audit)
    db.session.commit()

    return jsonify({
        "message": f"Hostel request {req_obj.status.lower()} successfully",
        "request": req_obj.to_dict()
    }), 200

@hostel_bp.route('/hostel/warden/asset-issues', methods=['GET'])
def get_warden_asset_issues():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester or requester.role not in ['warden', 'admin']:
        return jsonify({"message": "Forbidden: Warden role required"}), 403

    issues = (
        db.session.query(AssetIssue, HostelAsset, User)
        .join(HostelAsset, AssetIssue.asset_id == HostelAsset.id)
        .join(User, AssetIssue.student_id == User.id)
        .order_by(AssetIssue.reported_at.desc())
        .all()
    )

    results = []
    for issue, asset, student in issues:
        d = issue.to_dict()
        d.update({
            "assetName": asset.asset_name,
            "assetCode": asset.asset_code,
            "hostelName": asset.hostel_name,
            "roomNumber": asset.room_number,
            "studentName": student.name,
            "registrationNumber": student.registration_number
        })
        results.append(d)

    return jsonify(results), 200

@hostel_bp.route('/hostel/warden/asset-issues/<id>/action', methods=['POST'])
def action_asset_issue(id):
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester or requester.role not in ['warden', 'admin']:
        return jsonify({"message": "Forbidden: Warden role required"}), 403

    issue = AssetIssue.query.get(id)
    if not issue:
        return jsonify({"message": "Asset issue not found"}), 404

    data = request.json or {}
    status = (data.get('status') or '').upper()  # ACKNOWLEDGED, IN_REPAIR, RESOLVED, CLOSED
    resolution_notes = (data.get('resolutionNotes') or '').strip()

    if status not in ['ACKNOWLEDGED', 'IN_REPAIR', 'RESOLVED', 'CLOSED']:
        return jsonify({"message": "Valid status is required"}), 400

    issue.status = status
    issue.resolution_notes = resolution_notes or f"Updated to {status} by Warden"
    if status in ['RESOLVED', 'CLOSED']:
        issue.resolved_at = datetime.datetime.now().isoformat()
        # Restore asset condition
        asset = HostelAsset.query.get(issue.asset_id)
        if asset:
            asset.condition = 'GOOD'

    audit = RequestAudit(
        entity_type='ASSET_ISSUE',
        entity_id=issue.id,
        actor_id=requester.id,
        action=status,
        remarks=f"Asset issue {status}: {resolution_notes}",
        ip_address=request.remote_addr
    )
    db.session.add(audit)
    db.session.commit()

    return jsonify({
        "message": f"Asset issue {status.lower()} successfully",
        "issue": issue.to_dict()
    }), 200

@hostel_bp.route('/hostel/admin/kpis', methods=['GET'])
def get_hostel_admin_kpis():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester or requester.role not in ['admin', 'staff', 'warden']:
        return jsonify({"message": "Forbidden: Admin privileges required"}), 403

    total_allocations = HostelAllocation.query.filter_by(status='ACTIVE').count()
    total_assets = HostelAsset.query.count()
    damaged_assets = HostelAsset.query.filter(HostelAsset.condition.in_(['DAMAGED', 'UNDER_REPAIR'])).count()
    pending_requests = HostelRequest.query.filter_by(status='PENDING').count()

    return jsonify({
        "totalResidents": total_allocations,
        "totalAssets": total_assets,
        "damagedAssets": damaged_assets,
        "pendingRequests": pending_requests,
        "occupancyRate": 92.5
    }), 200

@hostel_bp.route('/hostel/admin/allocations', methods=['GET'])
def get_all_allocations():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester or requester.role not in ['admin', 'staff', 'warden']:
        return jsonify({"message": "Forbidden: Admin privileges required"}), 403

    allocs = (
        db.session.query(HostelAllocation, User)
        .join(User, HostelAllocation.student_id == User.id)
        .order_by(HostelAllocation.hostel_name, HostelAllocation.room_number)
        .all()
    )

    results = []
    for a, student in allocs:
        d = a.to_dict()
        d.update({
            "studentName": student.name,
            "registrationNumber": student.registration_number,
            "branch": student.branch,
            "year": student.year
        })
        results.append(d)

    return jsonify(results), 200


@hostel_bp.route('/hostel/admin/assets', methods=['GET'])
def get_all_hostel_assets():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester or requester.role not in ['admin', 'staff', 'warden']:
        return jsonify({"message": "Forbidden: Admin privileges required"}), 403

    assets = HostelAsset.query.order_by(HostelAsset.hostel_name, HostelAsset.room_number).all()
    student_ids = {a.assigned_student_id for a in assets if a.assigned_student_id}
    students_by_id = {}
    if student_ids:
        for s in User.query.filter(User.id.in_(student_ids)).all():
            students_by_id[s.id] = s

    results = []
    for asset in assets:
        d = asset.to_dict()
        st = students_by_id.get(asset.assigned_student_id)
        if st:
            d["studentName"] = st.name
            d["registrationNumber"] = st.registration_number
        results.append(d)

    return jsonify(results), 200


@hostel_bp.route('/hostel/admin/assets', methods=['POST'])
def create_hostel_asset():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester or requester.role not in ['admin', 'staff', 'warden']:
        return jsonify({"message": "Forbidden: Admin privileges required"}), 403

    data = request.json or {}
    hostel_name = (data.get('hostelName') or '').strip()
    room_number = (data.get('roomNumber') or '').strip()
    asset_code = (data.get('assetCode') or '').strip().upper()
    asset_name = (data.get('assetName') or '').strip()
    condition = (data.get('condition') or 'GOOD').strip().upper()

    if not hostel_name or not room_number or not asset_code or not asset_name:
        return jsonify({"message": "hostelName, roomNumber, assetCode, and assetName are required"}), 400

    if HostelAsset.query.filter_by(asset_code=asset_code).first():
        return jsonify({"message": f"Asset code '{asset_code}' already exists"}), 409

    asset = HostelAsset(
        hostel_name=hostel_name,
        room_number=room_number,
        asset_code=asset_code,
        asset_name=asset_name,
        condition=condition,
        assigned_student_id=data.get('assignedStudentId') or None,
        installed_date=datetime.date.today().isoformat(),
        last_inspected_at=datetime.datetime.now().isoformat(),
    )
    db.session.add(asset)
    db.session.add(RequestAudit(
        entity_type='HOSTEL_ASSET',
        entity_id=asset.id,
        actor_id=requester.id,
        action='CREATED',
        remarks=f"Added {asset_name} ({asset_code}) to {hostel_name} Room {room_number}",
        ip_address=request.remote_addr,
    ))
    db.session.commit()

    return jsonify({
        "message": "Hostel asset added successfully",
        "asset": asset.to_dict()
    }), 201


@hostel_bp.route('/hostel/admin/allocations', methods=['POST'])
def upsert_hostel_allocation():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester or requester.role not in ['admin', 'staff', 'warden']:
        return jsonify({"message": "Forbidden: Admin privileges required"}), 403

    data = request.json or {}
    student_id = data.get('studentId')
    hostel_name = (data.get('hostelName') or '').strip()
    room_number = (data.get('roomNumber') or '').strip()
    bed_number = (data.get('bedNumber') or '').strip()
    block = (data.get('block') or '').strip()
    occupancy_type = (data.get('occupancyType') or 'DOUBLE').strip().upper()

    if not student_id or not hostel_name or not room_number:
        return jsonify({"message": "studentId, hostelName, and roomNumber are required"}), 400

    student = User.query.get(student_id)
    if not student:
        return jsonify({"message": "Student not found"}), 404

    alloc = HostelAllocation.query.filter_by(student_id=student_id).first()
    if alloc:
        alloc.hostel_name = hostel_name
        alloc.block = block or alloc.block
        alloc.room_number = room_number
        alloc.bed_number = bed_number
        alloc.occupancy_type = occupancy_type
        alloc.status = 'ACTIVE'
        alloc.allocated_at = datetime.datetime.now().isoformat()
        action_name = 'TRANSFERRED'
    else:
        alloc = HostelAllocation(
            student_id=student_id,
            hostel_name=hostel_name,
            block=block,
            room_number=room_number,
            bed_number=bed_number,
            occupancy_type=occupancy_type,
            status='ACTIVE',
        )
        db.session.add(alloc)
        db.session.flush()
        action_name = 'ALLOCATED'

    db.session.add(RequestAudit(
        entity_type='HOSTEL_ALLOCATION',
        entity_id=alloc.id,
        actor_id=requester.id,
        action=action_name,
        remarks=f"{action_name} {student.name} to {hostel_name} Rm {room_number} Bed {bed_number}",
        ip_address=request.remote_addr,
    ))
    db.session.commit()

    return jsonify({
        "message": f"Hostel room {action_name.lower()} successfully",
        "allocation": {**alloc.to_dict(), "studentName": student.name, "registrationNumber": student.registration_number}
    }), 200


@hostel_bp.route('/hostel/admin/allocations/<id>/vacate', methods=['POST'])
def vacate_hostel_allocation(id):
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester or requester.role not in ['admin', 'staff', 'warden']:
        return jsonify({"message": "Forbidden: Admin privileges required"}), 403

    alloc = HostelAllocation.query.get(id)
    if not alloc:
        return jsonify({"message": "Allocation not found"}), 404

    alloc.status = 'VACATED'
    db.session.add(RequestAudit(
        entity_type='HOSTEL_ALLOCATION',
        entity_id=alloc.id,
        actor_id=requester.id,
        action='VACATED',
        remarks=f"Vacated {alloc.hostel_name} Rm {alloc.room_number} Bed {alloc.bed_number}",
        ip_address=request.remote_addr,
    ))
    db.session.commit()

    return jsonify({"message": "Hostel bed vacated", "allocation": alloc.to_dict()}), 200
