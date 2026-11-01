import uuid
import datetime
from flask import Blueprint, request, jsonify
from extensions import db
from models.user import User
from models.expansion import DocumentRequest, SUPPORTED_DOCUMENT_TYPES
from models.audit import RequestAudit
from models.notification import NotificationDelivery
from middleware.auth import get_authenticated_requester

documents_bp = Blueprint('documents_bp', __name__)

@documents_bp.route('/documents/types', methods=['GET'])
def get_document_types():
    types_list = [
        {"type": k, "name": v} for k, v in SUPPORTED_DOCUMENT_TYPES.items()
    ]
    return jsonify(types_list), 200

@documents_bp.route('/documents/requests', methods=['POST'])
def create_document_request():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required"}), 401
    if requester.role != 'student':
        return jsonify({"message": "Forbidden: Only students can request official documents"}), 403

    data = request.json or {}
    doc_type = (data.get('documentType') or '').strip().upper()
    purpose = (data.get('purpose') or '').strip()

    if not doc_type:
        return jsonify({"message": "documentType is required"}), 400
    if doc_type not in SUPPORTED_DOCUMENT_TYPES:
        return jsonify({"message": f"Invalid documentType. Supported: {list(SUPPORTED_DOCUMENT_TYPES.keys())}"}), 400
    if not purpose:
        return jsonify({"message": "purpose is required"}), 400

    new_req = DocumentRequest(
        student_id=requester.id,
        document_type=doc_type,
        purpose=purpose,
        status='PENDING'
    )
    db.session.add(new_req)

    audit = RequestAudit(
        entity_type='DOCUMENT_REQUEST',
        entity_id=new_req.id,
        actor_id=requester.id,
        action='SUBMITTED',
        remarks=f"Requested {SUPPORTED_DOCUMENT_TYPES.get(doc_type, doc_type)}: {purpose}",
        ip_address=request.remote_addr
    )
    db.session.add(audit)
    db.session.commit()

    return jsonify({
        "message": "Document request submitted successfully",
        "request": new_req.to_dict()
    }), 201

@documents_bp.route('/documents/requests/my', methods=['GET'])
def get_my_document_requests():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required"}), 401

    requests = DocumentRequest.query.filter_by(student_id=requester.id).order_by(DocumentRequest.created_at.desc()).all()
    return jsonify([r.to_dict() for r in requests]), 200

@documents_bp.route('/documents/requests/<id>/wallet', methods=['POST'])
def toggle_wallet_storage(id):
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required"}), 401

    doc = DocumentRequest.query.get(id)
    if not doc:
        return jsonify({"message": "Document request not found"}), 404

    if requester.role == 'student' and doc.student_id != requester.id:
        return jsonify({"message": "Forbidden: Cannot alter another student's document"}), 403

    if doc.status != 'ISSUED':
        return jsonify({"message": "Cannot store unissued document in Wallet"}), 400

    data = request.json or {}
    store_in_wallet = data.get('storedInWallet', True)

    doc.stored_in_wallet = bool(store_in_wallet)
    doc.wallet_added_at = datetime.datetime.now().isoformat() if doc.stored_in_wallet else None
    db.session.commit()

    return jsonify({
        "message": "Wallet storage updated successfully",
        "document": doc.to_dict()
    }), 200

@documents_bp.route('/documents/requests/pending', methods=['GET'])
def get_pending_document_requests():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester or requester.role not in ['admin', 'staff']:
        return jsonify({"message": "Forbidden: Admin/Staff privileges required"}), 403

    pending = (
        db.session.query(DocumentRequest, User)
        .join(User, DocumentRequest.student_id == User.id)
        .filter(DocumentRequest.status.in_(['PENDING', 'APPROVED']))
        .order_by(DocumentRequest.created_at.asc())
        .all()
    )

    results = []
    for doc, student in pending:
        d = doc.to_dict()
        d.update({
            "studentName": student.name,
            "registrationNumber": student.registration_number,
            "branch": student.branch,
            "year": student.year,
            "email": student.email
        })
        results.append(d)

    return jsonify(results), 200

@documents_bp.route('/documents/requests/all', methods=['GET'])
def get_all_document_requests():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester or requester.role not in ['admin', 'staff']:
        return jsonify({"message": "Forbidden: Admin/Staff privileges required"}), 403

    status_filter = request.args.get('status')
    query = db.session.query(DocumentRequest, User).join(User, DocumentRequest.student_id == User.id)

    if status_filter:
        query = query.filter(DocumentRequest.status == status_filter.upper())

    records = query.order_by(DocumentRequest.created_at.desc()).all()
    results = []
    for doc, student in records:
        d = doc.to_dict()
        d.update({
            "studentName": student.name,
            "registrationNumber": student.registration_number,
            "branch": student.branch,
            "year": student.year
        })
        results.append(d)

    return jsonify(results), 200

@documents_bp.route('/documents/requests/<id>', methods=['GET'])
def get_document_request_details(id):
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp

    doc = DocumentRequest.query.get(id)
    if not doc:
        return jsonify({"message": "Document request not found"}), 404

    if requester and requester.role == 'student' and doc.student_id != requester.id:
        return jsonify({"message": "Forbidden: Cannot view another student's document"}), 403

    student = User.query.get(doc.student_id)
    d = doc.to_dict()
    if student:
        d.update({
            "studentName": student.name,
            "registrationNumber": student.registration_number,
            "branch": student.branch,
            "year": student.year
        })

    return jsonify(d), 200

@documents_bp.route('/documents/requests/<id>/action', methods=['POST'])
def action_document_request(id):
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester or requester.role not in ['admin', 'staff']:
        return jsonify({"message": "Forbidden: Admin/Staff privileges required"}), 403

    doc = DocumentRequest.query.get(id)
    if not doc:
        return jsonify({"message": "Document request not found"}), 404

    data = request.json or {}
    action = (data.get('action') or '').upper()  # APPROVE, REJECT, ISSUE
    admin_notes = (data.get('adminNotes') or data.get('remarks') or '').strip()

    if action not in ['APPROVE', 'REJECT', 'ISSUE']:
        return jsonify({"message": "Invalid action. Supported: APPROVE, REJECT, ISSUE"}), 400

    now_iso = datetime.datetime.now().isoformat()
    old_status = doc.status

    if action == 'APPROVE':
        doc.status = 'APPROVED'
        doc.approved_by = requester.id
        doc.admin_notes = admin_notes or "Approved by administration"
    elif action == 'REJECT':
        if not admin_notes:
            return jsonify({"message": "Remarks are required for rejecting a document request"}), 400
        doc.status = 'REJECTED'
        doc.admin_notes = admin_notes
    elif action == 'ISSUE':
        doc.status = 'ISSUED'
        doc.approved_by = requester.id
        doc.issued_at = now_iso
        doc.expires_at = (datetime.datetime.now() + datetime.timedelta(days=180)).isoformat()
        if not doc.document_number:
            doc.document_number = f"DOC-2026-BPUT-{uuid.uuid4().hex[:8].upper()}"
        doc.admin_notes = admin_notes or "Document officially issued by Registrar Office"

        # Populate document metadata json
        student = User.query.get(doc.student_id)
        doc.document_data_json = str({
            "documentNumber": doc.document_number,
            "documentType": doc.document_type,
            "studentName": student.name if student else "",
            "registrationNumber": student.registration_number if student else "",
            "branch": student.branch if student else "",
            "course": student.course if student else "B.Tech",
            "issuedAt": doc.issued_at,
            "issuer": "BPUT Institutional Registry",
            "issuerAuthority": requester.name
        })

        # Send notification to student
        notif = NotificationDelivery(
            user_id=doc.student_id,
            title="Document Issued",
            body=f"Your {SUPPORTED_DOCUMENT_TYPES.get(doc.document_type, doc.document_type)} has been approved and issued. You can now store it in your Campus Wallet.",
            notification_type="DOCUMENT",
            reference_id=doc.id,
            status="PENDING",
            delivered_at=now_iso,
            created_at=now_iso
        )
        db.session.add(notif)

    audit = RequestAudit(
        entity_type='DOCUMENT_REQUEST',
        entity_id=doc.id,
        actor_id=requester.id,
        action=action,
        remarks=f"Status changed from {old_status} to {doc.status}. {admin_notes}",
        ip_address=request.remote_addr
    )
    db.session.add(audit)
    db.session.commit()

    return jsonify({
        "message": f"Document request {doc.status.lower()} successfully",
        "document": doc.to_dict()
    }), 200

@documents_bp.route('/documents/kpis', methods=['GET'])
def get_document_kpis():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester or requester.role not in ['admin', 'staff']:
        return jsonify({"message": "Forbidden: Admin/Staff privileges required"}), 403

    pending_count = DocumentRequest.query.filter_by(status='PENDING').count()
    approved_count = DocumentRequest.query.filter_by(status='APPROVED').count()
    issued_count = DocumentRequest.query.filter_by(status='ISSUED').count()
    rejected_count = DocumentRequest.query.filter_by(status='REJECTED').count()

    return jsonify({
        "pendingRequests": pending_count,
        "approvedAwaitingIssue": approved_count,
        "totalIssued": issued_count,
        "totalRejected": rejected_count
    }), 200
