import uuid
import datetime
from flask import Blueprint, request, jsonify
from extensions import db
from models.user import User
from models.expansion import FeeRecord
from models.audit import RequestAudit
from models.notification import NotificationDelivery
from middleware.auth import get_authenticated_requester

fees_bp = Blueprint('fees_bp', __name__)

@fees_bp.route('/fees/my', methods=['GET'])
def get_my_fees():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required"}), 401

    fees = FeeRecord.query.filter_by(student_id=requester.id).order_by(FeeRecord.due_date.asc()).all()

    total_amount = sum(f.amount for f in fees)
    total_paid = sum(f.amount_paid for f in fees)
    total_due = max(0.0, total_amount - total_paid)

    return jsonify({
        "records": [f.to_dict() for f in fees],
        "summary": {
            "totalAmount": total_amount,
            "totalPaid": total_paid,
            "totalDue": total_due,
            "hasOverdue": any(f.status == 'OVERDUE' for f in fees)
        }
    }), 200

@fees_bp.route('/fees/my/summary', methods=['GET'])
def get_my_fee_summary():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required"}), 401

    fees = FeeRecord.query.filter_by(student_id=requester.id).all()
    total_amount = sum(f.amount for f in fees)
    total_paid = sum(f.amount_paid for f in fees)
    total_due = max(0.0, total_amount - total_paid)

    active_due = next((f for f in fees if f.status in ['DUE', 'PARTIALLY_PAID', 'OVERDUE']), None)

    return jsonify({
        "totalDue": total_due,
        "status": "DUE" if total_due > 0 else "PAID",
        "nextDueDate": active_due.due_date if active_due else "None",
        "primaryCategory": active_due.category if active_due else "All Cleared",
        "recordsCount": len(fees)
    }), 200

@fees_bp.route('/fees/<id>/record-payment', methods=['POST'])
def record_fee_payment(id):
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required"}), 401

    fee = FeeRecord.query.get(id)
    if not fee:
        return jsonify({"message": "Fee record not found"}), 404

    # Allow student to simulate/record payment or Admin to record cashier receipt
    if requester.role == 'student' and fee.student_id != requester.id:
        return jsonify({"message": "Forbidden: Cannot record payment for another student"}), 403

    data = request.json or {}
    payment_amount = float(data.get('amount') or (fee.amount - fee.amount_paid))

    if payment_amount <= 0:
        return jsonify({"message": "Payment amount must be greater than zero"}), 400

    fee.amount_paid = min(fee.amount, fee.amount_paid + payment_amount)
    now_iso = datetime.datetime.now().isoformat()
    fee.paid_at = now_iso

    if fee.amount_paid >= fee.amount:
        fee.status = 'PAID'
    else:
        fee.status = 'PARTIALLY_PAID'

    if not fee.receipt_number:
        fee.receipt_number = f"REC-{datetime.datetime.now().year}-{uuid.uuid4().hex[:6].upper()}"

    audit = RequestAudit(
        entity_type='FEE_PAYMENT',
        entity_id=fee.id,
        actor_id=requester.id,
        action='PAYMENT_RECORDED',
        remarks=f"Recorded payment of ₹{payment_amount:.2f} for {fee.title}. Status: {fee.status}. Receipt: {fee.receipt_number}",
        ip_address=request.remote_addr
    )
    db.session.add(audit)

    # Notify student
    notif = NotificationDelivery(
        user_id=fee.student_id,
        title="Fee Payment Recorded",
        body=f"Payment of ₹{payment_amount:.2f} for '{fee.title}' was recorded. Receipt #{fee.receipt_number}.",
        notification_type="FEE",
        reference_id=fee.id,
        status="PENDING",
        delivered_at=now_iso,
        created_at=now_iso
    )
    db.session.add(notif)
    db.session.commit()

    return jsonify({
        "message": "Payment recorded successfully",
        "fee": fee.to_dict()
    }), 200

@fees_bp.route('/fees/all', methods=['GET'])
def get_all_fees():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester or requester.role not in ['admin', 'staff', 'warden']:
        return jsonify({"message": "Forbidden: Admin/Staff privileges required"}), 403

    status_filter = request.args.get('status')
    category_filter = request.args.get('category')

    query = db.session.query(FeeRecord, User).join(User, FeeRecord.student_id == User.id)

    if status_filter:
        query = query.filter(FeeRecord.status == status_filter.upper())
    if category_filter:
        query = query.filter(FeeRecord.category == category_filter.upper())

    records = query.order_by(FeeRecord.due_date.asc()).all()
    results = []
    for fee, student in records:
        f = fee.to_dict()
        f.update({
            "studentName": student.name,
            "registrationNumber": student.registration_number,
            "branch": student.branch,
            "year": student.year
        })
        results.append(f)

    return jsonify(results), 200

@fees_bp.route('/fees/kpis', methods=['GET'])
def get_fee_kpis():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester or requester.role not in ['admin', 'staff', 'warden']:
        return jsonify({"message": "Forbidden: Admin/Staff privileges required"}), 403

    all_fees = FeeRecord.query.all()
    total_billed = sum(f.amount for f in all_fees)
    total_collected = sum(f.amount_paid for f in all_fees)
    total_outstanding = max(0.0, total_billed - total_collected)

    today_str = datetime.date.today().isoformat()
    overdue_records = [f for f in all_fees if f.status != 'PAID' and f.due_date < today_str]
    overdue_amount = sum(f.amount - f.amount_paid for f in overdue_records)

    return jsonify({
        "totalBilled": total_billed,
        "totalCollected": total_collected,
        "totalOutstanding": total_outstanding,
        "overdueAmount": overdue_amount,
        "overdueCount": len(overdue_records),
        "totalRecords": len(all_fees)
    }), 200

@fees_bp.route('/fees', methods=['POST'])
def create_fee_record():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester or requester.role not in ['admin', 'staff']:
        return jsonify({"message": "Forbidden: Admin/Staff privileges required"}), 403

    data = request.json or {}
    student_id = data.get('studentId')
    title = (data.get('title') or '').strip()
    category = (data.get('category') or 'TUITION').upper().strip()
    amount = float(data.get('amount') or 0)
    due_date = data.get('dueDate')

    if not student_id:
        return jsonify({"message": "studentId is required"}), 400
    if not title:
        return jsonify({"message": "title is required"}), 400
    if amount <= 0:
        return jsonify({"message": "amount must be positive"}), 400
    if not due_date:
        return jsonify({"message": "dueDate is required"}), 400

    new_fee = FeeRecord(
        student_id=student_id,
        title=title,
        category=category,
        amount=amount,
        due_date=due_date,
        status='DUE',
        academic_year=data.get('academicYear', '2025-2026'),
        semester=data.get('semester', 6)
    )
    db.session.add(new_fee)
    db.session.commit()

    return jsonify({
        "message": "Fee record created successfully",
        "fee": new_fee.to_dict()
    }), 201


@fees_bp.route('/fees/<id>', methods=['PATCH'])
def update_fee_record(id):
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester or requester.role not in ['admin', 'staff']:
        return jsonify({"message": "Forbidden: Admin/Staff privileges required"}), 403

    fee = FeeRecord.query.get(id)
    if not fee:
        return jsonify({"message": "Fee record not found"}), 404

    data = request.json or {}
    if 'title' in data and (data.get('title') or '').strip():
        fee.title = data['title'].strip()
    if 'category' in data and (data.get('category') or '').strip():
        fee.category = data['category'].upper().strip()
    if 'dueDate' in data and data.get('dueDate'):
        fee.due_date = str(data['dueDate'])
    if 'amount' in data and data.get('amount') is not None:
        new_amt = float(data['amount'])
        if new_amt <= 0:
            return jsonify({"message": "amount must be positive"}), 400
        fee.amount = new_amt
    if 'status' in data and (data.get('status') or '').strip():
        fee.status = data['status'].upper().strip()

    db.session.add(RequestAudit(
        entity_type='FEE_RECORD',
        entity_id=fee.id,
        actor_id=requester.id,
        action='UPDATED',
        remarks=f"Updated fee '{fee.title}' (₹{fee.amount}, status={fee.status})",
        ip_address=request.remote_addr,
    ))
    db.session.commit()
    return jsonify({"message": "Fee record updated", "fee": fee.to_dict()}), 200


@fees_bp.route('/fees/<id>', methods=['DELETE'])
def delete_fee_record(id):
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester or requester.role not in ['admin', 'staff']:
        return jsonify({"message": "Forbidden: Admin/Staff privileges required"}), 403

    fee = FeeRecord.query.get(id)
    if not fee:
        return jsonify({"message": "Fee record not found"}), 404
    if fee.amount_paid and fee.amount_paid > 0:
        return jsonify({"message": "Cannot delete a fee record that already has recorded payments"}), 409

    title = fee.title
    db.session.add(RequestAudit(
        entity_type='FEE_RECORD',
        entity_id=fee.id,
        actor_id=requester.id,
        action='DELETED',
        remarks=f"Cancelled fee demand '{title}' (₹{fee.amount})",
        ip_address=request.remote_addr,
    ))
    db.session.delete(fee)
    db.session.commit()
    return jsonify({"message": f"Fee record '{title}' cancelled"}), 200
