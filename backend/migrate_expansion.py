"""
Additive Migration for CampusOS Product Expansion
Creates tables:
- document_requests
- fee_records
- class_updates
- hostel_allocations
- hostel_requests
- hostel_assets
- asset_issues
- visitor_requests
Plus seed data for demonstration and test workflows.
"""
import uuid
import datetime
from app import app
from extensions import db
from models.user import User
from models.expansion import (
    DocumentRequest,
    FeeRecord,
    ClassUpdate,
    HostelAllocation,
    HostelRequest,
    HostelAsset,
    AssetIssue,
    VisitorRequest
)

def run_migration():
    with app.app_context():
        print("[MIGRATION] Creating expansion tables...")
        db.create_all()
        print("[MIGRATION] Tables verified/created successfully.")

        # Seed sample data if empty for demo & test readiness
        student = User.query.filter_by(role='student').first()
        admin = User.query.filter_by(role='admin').first()
        warden = User.query.filter_by(role='warden').first()
        teacher = User.query.filter_by(role='teacher').first()

        if student:
            # 1. Seed Bonafide Document Request (Issued and stored in wallet)
            existing_doc = DocumentRequest.query.filter_by(student_id=student.id).first()
            if not existing_doc:
                issued_doc = DocumentRequest(
                    student_id=student.id,
                    document_type='BONAFIDE_CERTIFICATE',
                    purpose='Application for National Scholarship Portal 2026',
                    status='ISSUED',
                    admin_notes='Approved and verified against institutional records.',
                    approved_by=admin.id if admin else None,
                    document_number=f"DOC-2026-BPUT-{uuid.uuid4().hex[:8].upper()}",
                    issued_at=datetime.datetime.now().isoformat(),
                    expires_at=(datetime.datetime.now() + datetime.timedelta(days=180)).isoformat(),
                    stored_in_wallet=True,
                    wallet_added_at=datetime.datetime.now().isoformat(),
                    document_data_json=f'{{"studentName": "{student.name}", "registrationNumber": "{student.registration_number or "BPUT-2023-CS-042"}", "course": "B.Tech", "branch": "{student.branch or "CSE"}", "academicYear": "2025-2026", "institution": "BPUT Campus"}}'
                )
                db.session.add(issued_doc)
                print(f"[SEED] Created sample issued Bonafide Certificate for {student.name}")

            # 2. Seed Fee Records
            existing_fee = FeeRecord.query.filter_by(student_id=student.id).first()
            if not existing_fee:
                fee1 = FeeRecord(
                    student_id=student.id,
                    title='Semester 6 Academic Fee',
                    category='TUITION',
                    amount=42500.0,
                    amount_paid=42500.0,
                    due_date='2026-02-15',
                    status='PAID',
                    receipt_number=f"REC-2026-{uuid.uuid4().hex[:6].upper()}",
                    paid_at=datetime.datetime.now().isoformat(),
                    breakdown_json='[{"item": "Tuition Fee", "amount": 35000}, {"item": "Laboratory & Internet Fee", "amount": 5500}, {"item": "Library Dues", "amount": 2000}]',
                    academic_year='2025-2026',
                    semester=6
                )
                fee2 = FeeRecord(
                    student_id=student.id,
                    title='Hostel & Mess Advance (Even Sem)',
                    category='HOSTEL',
                    amount=18000.0,
                    amount_paid=10000.0,
                    due_date='2026-10-15',
                    status='PARTIALLY_PAID',
                    receipt_number=f"REC-2026-{uuid.uuid4().hex[:6].upper()}",
                    paid_at=datetime.datetime.now().isoformat(),
                    breakdown_json='[{"item": "Room Rent & Electricity", "amount": 10000}, {"item": "Mess Operations Advance", "amount": 8000}]',
                    academic_year='2025-2026',
                    semester=6
                )
                db.session.add(fee1)
                db.session.add(fee2)
                print(f"[SEED] Created sample Fee Records for {student.name}")

            # 3. Seed Hostel & Room Allocation
            existing_alloc = HostelAllocation.query.filter_by(student_id=student.id).first()
            if not existing_alloc:
                alloc = HostelAllocation(
                    student_id=student.id,
                    hostel_name='Mahanadi Hall of Residence',
                    block='Block B',
                    room_number='304',
                    bed_number='Bed A',
                    occupancy_type='DOUBLE',
                    allocated_at='2025-08-01T00:00:00',
                    status='ACTIVE',
                    notes='Allocated during Autumn Semester 2025'
                )
                db.session.add(alloc)
                print(f"[SEED] Created sample Hostel Allocation for {student.name}")

            # 4. Seed Hostel Assets
            existing_assets = HostelAsset.query.filter_by(hostel_name='Mahanadi Hall of Residence', room_number='304').all()
            if not existing_assets:
                desk = HostelAsset(
                    hostel_name='Mahanadi Hall of Residence',
                    room_number='304',
                    asset_code='AST-MH-B304-DSK1',
                    asset_name='Solid Wood Study Desk & Shelf',
                    condition='GOOD',
                    assigned_student_id=student.id,
                    installed_date='2024-07-15'
                )
                chair = HostelAsset(
                    hostel_name='Mahanadi Hall of Residence',
                    room_number='304',
                    asset_code='AST-MH-B304-CHR1',
                    asset_name='Ergonomic Mesh Study Chair',
                    condition='GOOD',
                    assigned_student_id=student.id,
                    installed_date='2024-07-15'
                )
                fan = HostelAsset(
                    hostel_name='Mahanadi Hall of Residence',
                    room_number='304',
                    asset_code='AST-MH-B304-FAN1',
                    asset_name='Crompton High-Speed Ceiling Fan',
                    condition='GOOD',
                    assigned_student_id=None,
                    installed_date='2023-01-10'
                )
                db.session.add(desk)
                db.session.add(chair)
                db.session.add(fan)
                print("[SEED] Created sample Hostel Assets for Room 304")

            # 5. Seed Class Update (Teacher cancellation/reschedule)
            if teacher:
                existing_update = ClassUpdate.query.filter_by(teacher_id=teacher.id).first()
                if not existing_update:
                    update = ClassUpdate(
                        teacher_id=teacher.id,
                        course_code='CS601',
                        course_name='Distributed Systems & Cloud Computing',
                        update_type='RESCHEDULED',
                        original_date=datetime.date.today().isoformat(),
                        original_time='10:00 AM',
                        original_room='Room 302',
                        new_date=datetime.date.today().isoformat(),
                        new_time='02:00 PM',
                        new_room='Seminar Hall 1',
                        message='Lecture rescheduled to 2:00 PM in Seminar Hall 1 for guest speaker seminar.',
                        affected_branch=student.branch or 'CSE',
                        affected_year=student.year or 3,
                        status='ACTIVE'
                    )
                    db.session.add(update)
                    print(f"[SEED] Created sample Class Update from {teacher.name}")

            # 6. Seed Visitor Request & Pass
            existing_vr = VisitorRequest.query.filter_by(student_id=student.id).first()
            if not existing_vr:
                vr = VisitorRequest(
                    student_id=student.id,
                    visitor_name='Rajendra Kumar Patra',
                    visitor_phone='+91 9876543210',
                    relation='Father',
                    purpose='Family visit & academic review meet',
                    visit_date=datetime.date.today().isoformat(),
                    expected_entry_time='04:00 PM',
                    expected_exit_time='07:30 PM',
                    status='APPROVED',
                    approved_by=warden.id if warden else None,
                    pass_code=f"VP-{uuid.uuid4().hex[:12].upper()}"
                )
                db.session.add(vr)
                print(f"[SEED] Created sample approved Visitor Request & Pass for {student.name}")

            db.session.commit()
            print("[MIGRATION] Migration and seeding completed successfully!")

if __name__ == '__main__':
    run_migration()
