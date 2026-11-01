from flask import Blueprint, request, jsonify
from extensions import db
from models.user import User
from models.notice import Notice
from models.expansion import (
    DocumentRequest,
    FeeRecord,
    ClassUpdate,
    HostelAllocation,
    HostelRequest,
    HostelAsset,
    VisitorRequest
)
from models.complaint import Complaint
from models.gate_pass import GatePass
from models.mess import MessMenu, MessMeal
from middleware.auth import get_authenticated_requester

search_bp = Blueprint('search_bp', __name__)

@search_bp.route('/search', methods=['GET'])
def global_search():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required"}), 401

    query_str = (request.args.get('q') or '').strip()
    if not query_str or len(query_str) < 2:
        return jsonify({
            "query": query_str,
            "results": [],
            "message": "Search query must be at least 2 characters"
        }), 200

    q_like = f"%{query_str}%"
    role = (requester.role or 'student').lower()
    results = []

    # 1. NOTICES (Permission aware)
    notices_q = Notice.query.filter(
        (Notice.title.ilike(q_like)) | (Notice.body.ilike(q_like))
    )
    if role == 'student':
        notices_q = notices_q.filter(
            (Notice.status == 'PUBLISHED') &
            ((Notice.target_type == 'ALL') |
             (Notice.target_value.ilike(requester.branch or '')) |
             (Notice.target_value.ilike(str(requester.year or ''))))
        )
    for n in notices_q.limit(10).all():
        results.append({
            "category": "Notice",
            "title": n.title,
            "subtitle": (n.body or n.content or "")[:100],
            "id": n.id,
            "deepLink": f"/student/notices?id={n.id}",
            "relevance": "High" if query_str.lower() in n.title.lower() else "Medium"
        })

    # 2. ACADEMIC / CLASS UPDATES
    cu_q = ClassUpdate.query.filter(
        (ClassUpdate.course_name.ilike(q_like)) |
        (ClassUpdate.course_code.ilike(q_like)) |
        (ClassUpdate.message.ilike(q_like))
    )
    if role == 'student':
        student_branch = (requester.branch or '').strip()
        if student_branch:
            cu_q = cu_q.filter(
                (ClassUpdate.affected_branch == 'ALL') |
                (ClassUpdate.affected_branch.ilike(student_branch)) |
                (ClassUpdate.affected_branch.is_(None))
            )
    elif role == 'teacher':
        cu_q = cu_q.filter(ClassUpdate.teacher_id == requester.id)

    matching_updates = cu_q.limit(10).all()
    for cu in matching_updates:
        results.append({
            "category": "Class Update",
            "title": f"{cu.course_code}: {cu.update_type.title()}",
            "subtitle": f"{cu.course_name} - {cu.message[:80]}",
            "id": cu.id,
            "deepLink": f"/student/classes?updateId={cu.id}",
            "relevance": "High"
        })

    # 3. DOCUMENTS (Students see own; Admin sees all)
    if role in ['student', 'admin', 'staff']:
        doc_q = DocumentRequest.query.filter(
            (DocumentRequest.document_type.ilike(q_like)) |
            (DocumentRequest.purpose.ilike(q_like)) |
            (DocumentRequest.document_number.ilike(q_like))
        )
        if role == 'student':
            doc_q = doc_q.filter(DocumentRequest.student_id == requester.id)
        for doc in doc_q.limit(10).all():
            results.append({
                "category": "Document",
                "title": doc.document_type.replace('_', ' ').title(),
                "subtitle": f"Status: {doc.status} | Purpose: {doc.purpose[:60]}",
                "id": doc.id,
                "deepLink": f"/student/requests/documents?id={doc.id}",
                "relevance": "High"
            })

    # 4. COMPLAINTS (Scoped)
    comp_q = Complaint.query.filter(
        (Complaint.title.ilike(q_like)) |
        (Complaint.description.ilike(q_like)) |
        (Complaint.location.ilike(q_like))
    )
    if role == 'student':
        comp_q = comp_q.filter(Complaint.student_id == requester.id)
    elif role in ['warden']:
        comp_q = comp_q.filter(Complaint.category.in_(['Hostel/Room', 'Hostel Asset', 'Hostel', 'Electrical/Plumbing', 'Cleanliness']))
    elif role in ['mess', 'mess_staff']:
        comp_q = comp_q.filter(Complaint.category == 'Mess')
    for c in comp_q.limit(10).all():
        results.append({
            "category": "Complaint",
            "title": c.title,
            "subtitle": f"[{c.category}] Status: {c.status} | {c.location}",
            "id": c.id,
            "deepLink": f"/student/requests/complaints?id={c.id}",
            "relevance": "Medium"
        })

    # 5. FEES & DUES (Student sees own; Admin sees all)
    if role in ['student', 'admin', 'staff']:
        fee_q = FeeRecord.query.filter(
            (FeeRecord.title.ilike(q_like)) |
            (FeeRecord.category.ilike(q_like)) |
            (FeeRecord.receipt_number.ilike(q_like))
        )
        if role == 'student':
            fee_q = fee_q.filter(FeeRecord.student_id == requester.id)
        for f in fee_q.limit(10).all():
            results.append({
                "category": "Fee Record",
                "title": f.title,
                "subtitle": f"₹{f.amount:.2f} | Status: {f.status} | Due: {f.due_date}",
                "id": f.id,
                "deepLink": "/student/wallet",
                "relevance": "Medium"
            })

    # 6. HOSTEL (Student sees own; Warden & Admin see all)
    if role in ['student', 'warden', 'admin']:
        hostel_q = HostelAllocation.query.filter(
            (HostelAllocation.hostel_name.ilike(q_like)) |
            (HostelAllocation.room_number.ilike(q_like)) |
            (HostelAllocation.block.ilike(q_like))
        )
        if role == 'student':
            hostel_q = hostel_q.filter(HostelAllocation.student_id == requester.id)
        for ha in hostel_q.limit(5).all():
            results.append({
                "category": "Hostel & Room",
                "title": f"{ha.hostel_name} - Room {ha.room_number}",
                "subtitle": f"Block: {ha.block} | Bed: {ha.bed_number} | {ha.occupancy_type}",
                "id": ha.id,
                "deepLink": "/student/profile/hostel",
                "relevance": "High"
            })

    # 7. PASSES (Gate Pass & Visitor Pass)
    if role in ['student', 'security', 'guard', 'security_guard', 'warden', 'admin']:
        vp_q = VisitorRequest.query.filter(
            (VisitorRequest.visitor_name.ilike(q_like)) |
            (VisitorRequest.pass_code.ilike(q_like)) |
            (VisitorRequest.visitor_phone.ilike(q_like))
        )
        if role == 'student':
            vp_q = vp_q.filter(VisitorRequest.student_id == requester.id)
        for vp in vp_q.limit(5).all():
            results.append({
                "category": "Visitor Pass",
                "title": f"Visitor: {vp.visitor_name} ({vp.relation})",
                "subtitle": f"Pass: {vp.pass_code or 'Pending'} | Status: {vp.status} | {vp.visit_date}",
                "id": vp.id,
                "deepLink": "/student/wallet",
                "relevance": "High"
            })

    return jsonify({
        "query": query_str,
        "count": len(results),
        "results": results
    }), 200
