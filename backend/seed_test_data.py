"""
CampusOS Deterministic Pre-Deployment Test Seed System.
Created for automated validation, LAN testing, and physical multi-device testing.

Generates realistic relational data for all 6 institutional roles:
1. ADMIN       (admin@campusos.edu / Admin@1234)
2. TEACHER     (teacher@campusos.edu / Teacher@1234)
3. STUDENT     (student@campusos.edu / Student@1234)
4. WARDEN      (warden@campusos.edu / Warden@1234)
5. MESS_STAFF  (mess@campusos.edu / Mess@1234)
6. SECURITY    (security@campusos.edu / Security@1234)

Usage:
  python seed_test_data.py [--reset] [--verify]
"""

import sys
import os
import uuid
import json
import datetime
from datetime import timedelta

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app import app, db
from models.user import User
from models.attendance import Session, Attendance, Coupon, SavedClass
from models.leave import LeaveRequest
from models.gate_pass import GatePass
from models.audit import RequestAudit, ComplaintStatusHistory
from models.complaint import Complaint
from models.notice import Notice
from models.notification import NotificationDelivery, DeviceToken
from models.mess import MessMenu, MessMeal, MessFeedback, MealEntry
from models.passport import DeviceIdentityKey, DeviceCertificate
from models.expansion import (
    DocumentRequest,
    FeeRecord,
    ClassUpdate,
    HostelAllocation,
    HostelRequest,
    HostelAsset,
    AssetIssue,
    VisitorRequest,
    SUPPORTED_DOCUMENT_TYPES
)

TEST_USER_EMAILS = [
    "admin@campusos.edu",
    "teacher@campusos.edu",
    "student@campusos.edu",
    "warden@campusos.edu",
    "mess@campusos.edu",
    "security@campusos.edu",
]


def clean_test_data(test_user_ids):
    """Removes relational test records for the given test user IDs."""
    if not test_user_ids:
        return

    print("[CLEAN] Purging relational test child entities...")
    MealEntry.query.filter(MealEntry.student_id.in_(test_user_ids)).delete(synchronize_session=False)
    MessFeedback.query.filter(MessFeedback.student_id.in_(test_user_ids)).delete(synchronize_session=False)
    DeviceCertificate.query.filter(DeviceCertificate.subject_user_id.in_(test_user_ids)).delete(synchronize_session=False)
    DeviceIdentityKey.query.filter(DeviceIdentityKey.user_id.in_(test_user_ids)).delete(synchronize_session=False)
    DeviceToken.query.filter(DeviceToken.user_id.in_(test_user_ids)).delete(synchronize_session=False)
    NotificationDelivery.query.filter(NotificationDelivery.user_id.in_(test_user_ids)).delete(synchronize_session=False)
    
    ComplaintStatusHistory.query.filter(ComplaintStatusHistory.changed_by.in_(test_user_ids)).delete(synchronize_session=False)
    RequestAudit.query.filter(RequestAudit.actor_id.in_(test_user_ids)).delete(synchronize_session=False)
    
    Complaint.query.filter(Complaint.student_id.in_(test_user_ids)).delete(synchronize_session=False)
    GatePass.query.filter(GatePass.student_id.in_(test_user_ids)).delete(synchronize_session=False)
    LeaveRequest.query.filter(LeaveRequest.student_id.in_(test_user_ids)).delete(synchronize_session=False)
    
    Attendance.query.filter(Attendance.user_id.in_(test_user_ids)).delete(synchronize_session=False)
    Coupon.query.filter(Coupon.user_id.in_(test_user_ids)).delete(synchronize_session=False)
    Session.query.filter(Session.teacher_id.in_(test_user_ids)).delete(synchronize_session=False)
    SavedClass.query.filter(SavedClass.user_id.in_(test_user_ids)).delete(synchronize_session=False)
    ClassUpdate.query.filter(ClassUpdate.teacher_id.in_(test_user_ids)).delete(synchronize_session=False)

    DocumentRequest.query.filter(DocumentRequest.student_id.in_(test_user_ids)).delete(synchronize_session=False)
    FeeRecord.query.filter(FeeRecord.student_id.in_(test_user_ids)).delete(synchronize_session=False)
    HostelRequest.query.filter(HostelRequest.student_id.in_(test_user_ids)).delete(synchronize_session=False)
    AssetIssue.query.filter(AssetIssue.student_id.in_(test_user_ids)).delete(synchronize_session=False)
    HostelAsset.query.filter(HostelAsset.assigned_student_id.in_(test_user_ids)).delete(synchronize_session=False)
    HostelAllocation.query.filter(HostelAllocation.student_id.in_(test_user_ids)).delete(synchronize_session=False)
    VisitorRequest.query.filter(VisitorRequest.student_id.in_(test_user_ids)).delete(synchronize_session=False)

    Notice.query.filter(Notice.created_by.in_(test_user_ids)).delete(synchronize_session=False)
    db.session.commit()
    print("[CLEAN] Relational child records purged cleanly.")


def get_or_create_user(email, **fields):
    """Finds existing test user or creates a new one with correct attributes."""
    user = User.query.filter_by(email=email).first()
    if user:
        for k, v in fields.items():
            setattr(user, k, v)
    else:
        user = User(id=str(uuid.uuid4()), email=email, **fields)
        db.session.add(user)
    return user


def seed_test_system():
    """Seeds a complete, realistic, interconnected dataset for physical multi-device testing."""
    with app.app_context():
        now = datetime.datetime.now()
        today_str = now.strftime('%Y-%m-%d')
        now_iso = now.isoformat()

        print("[SEED] Provisioning test accounts across all 6 institutional roles...")

        # 1. ADMIN
        admin = get_or_create_user(
            email="admin@campusos.edu",
            password="Admin@1234",
            name="Institutional Registrar & Dean",
            role="admin",
            registration_number="ADM-2026-001"
        )

        # 2. TEACHER
        teacher = get_or_create_user(
            email="teacher@campusos.edu",
            password="Teacher@1234",
            name="Prof. Sarah Jenkins",
            role="teacher",
            registration_number="FAC-CSE-104",
            course="B.Tech",
            branch="Computer Science & Engineering",
            year="3"
        )

        # 3. STUDENT
        student = get_or_create_user(
            email="student@campusos.edu",
            password="Student@1234",
            name="Aarav Sharma",
            role="student",
            registration_number="2023CSE042",
            course="B.Tech",
            branch="Computer Science & Engineering",
            year="3",
            device_id="physical-test-device-student-01"
        )

        # 4. WARDEN
        warden = get_or_create_user(
            email="warden@campusos.edu",
            password="Warden@1234",
            name="Dr. Rajesh Sharma (Chief Warden)",
            role="warden",
            registration_number="WRD-BH-01"
        )

        # 5. MESS STAFF
        mess_staff = get_or_create_user(
            email="mess@campusos.edu",
            password="Mess@1234",
            name="Ramesh Kumar (Mess Manager)",
            role="mess_staff",
            registration_number="MSS-NORTH-01"
        )

        # 6. GATE SECURITY
        security = get_or_create_user(
            email="security@campusos.edu",
            password="Security@1234",
            name="Officer Vikram Singh",
            role="security",
            registration_number="SEC-MAIN-007"
        )

        db.session.commit()
        test_user_ids = [admin.id, teacher.id, student.id, warden.id, mess_staff.id, security.id]
        clean_test_data(test_user_ids)

        # --- HOSTEL & ACCOMMODATION ---
        print("[SEED] Creating Hostel allocation & room assets...")
        allocation = HostelAllocation(
            student_id=student.id,
            hostel_name="Aryabhatta Hall of Residence",
            block="Block B",
            room_number="B-204",
            bed_number="Bed-1",
            occupancy_type="DOUBLE",
            status="ACTIVE",
            notes="Allocated for Academic Year 2025-2026"
        )
        db.session.add(allocation)

        asset1 = HostelAsset(
            hostel_name="Aryabhatta Hall of Residence",
            room_number="B-204",
            asset_code="ABH-B204-DSK-01",
            asset_name="Ergonomic Study Desk & Lamp",
            condition="GOOD",
            assigned_student_id=student.id,
            installed_date=(now - timedelta(days=60)).strftime('%Y-%m-%d')
        )
        db.session.add(asset1)

        hostel_req = HostelRequest(
            student_id=student.id,
            request_type="MAINTENANCE",
            preferred_hostel="Aryabhatta Hall of Residence",
            preferred_room="B-204",
            reason="Ceiling fan bearing requires lubrication; mild squeaking noise.",
            status="PENDING"
        )
        db.session.add(hostel_req)

        # --- ACADEMIC SESSIONS & ATTENDANCE ---
        print("[SEED] Creating Classes, Sessions & Attendance...")
        saved_class = SavedClass(
            user_id=teacher.id,
            subject="Distributed Systems (CS304)",
            course="B.Tech",
            branch="Computer Science & Engineering",
            year="3"
        )
        db.session.add(saved_class)

        active_session = Session(
            name="Distributed Systems Lecture 14: Paxos & Raft",
            subject="Distributed Systems (CS304)",
            instructor_name=teacher.name,
            course="B.Tech",
            branch="Computer Science & Engineering",
            year="3",
            start_time=(now - timedelta(minutes=15)).isoformat(),
            end_time=(now + timedelta(minutes=45)).isoformat(),
            location="Room 302",
            tx_power_level=3,
            session_nonce=str(uuid.uuid4())[:8],
            teacher_id=teacher.id,
            is_active=True,
            attendance_count=1
        )
        db.session.add(active_session)
        db.session.flush()

        attendance_rec = Attendance(
            session_id=active_session.id,
            user_id=student.id,
            student_name=student.name,
            check_in_time=(now - timedelta(minutes=10)).isoformat(),
            status="present",
            coupon_earned=True,
            verification_mode="BLE_ACTIVE_PRESENTATION",
            proximity_tier="NEAR"
        )
        db.session.add(attendance_rec)

        coupon = Coupon(
            user_id=student.id,
            code=f"CAMPUS-{str(uuid.uuid4())[:6].upper()}",
            description="10% discount on Campus Cafeteria on 100% weekly attendance",
            expiry_date=(now + timedelta(days=14)).isoformat(),
            is_used=False
        )
        db.session.add(coupon)

        class_update = ClassUpdate(
            teacher_id=teacher.id,
            course_code="CS304",
            course_name="Distributed Systems",
            update_type="ANNOUNCEMENT",
            original_date=today_str,
            message="Mid-semester project submission portal is now open. Teams of 2 permitted.",
            affected_branch="Computer Science & Engineering",
            affected_year=3,
            status="ACTIVE"
        )
        db.session.add(class_update)

        # --- LEAVE & GATE PASS ---
        print("[SEED] Creating Leave Requests & Gate Passes...")
        approved_leave = LeaveRequest(
            student_id=student.id,
            leave_type="WEEKEND_OUTING",
            start_date=(now + timedelta(days=1)).strftime('%Y-%m-%d 14:00'),
            end_date=(now + timedelta(days=2)).strftime('%Y-%m-%d 20:00'),
            reason="Attending family function in hometown",
            destination="City Residence",
            parent_consent="GRANTED",
            status="APPROVED",
            reviewed_by=warden.id,
            review_remarks="Approved by Chief Warden. Return strictly before 20:00."
        )
        db.session.add(approved_leave)
        db.session.flush()

        gate_pass = GatePass(
            student_id=student.id,
            leave_request_id=approved_leave.id,
            destination="City Residence",
            reason="Attending family function in hometown",
            expected_exit_time=(now + timedelta(days=1, hours=2)).isoformat(),
            expected_return_time=(now + timedelta(days=2, hours=8)).isoformat(),
            status="ISSUED",
            gate_name="Main North Gate",
            verification_mode="QR_FALLBACK"
        )
        db.session.add(gate_pass)

        # --- COMPLAINTS ---
        print("[SEED] Creating Complaints & History...")
        complaint = Complaint(
            student_id=student.id,
            category="WIFI_NETWORK",
            title="Intermittent Wi-Fi signal in Block B 2nd floor",
            description="Wi-Fi coverage in Room B-204 drops frequently between 20:00 and 23:00.",
            location="Aryabhatta Hall Block B",
            priority="HIGH",
            status="IN_PROGRESS"
        )
        db.session.add(complaint)
        db.session.flush()

        comp_hist = ComplaintStatusHistory(
            complaint_id=complaint.id,
            old_status="PENDING",
            new_status="IN_PROGRESS",
            changed_by=admin.id,
            comment="Assigned to Campus IT Network Team for AP inspection"
        )
        db.session.add(comp_hist)

        # --- NOTICES & NOTIFICATIONS ---
        print("[SEED] Creating Notices & Push Deliveries...")
        notice1 = Notice(
            title="Campus-wide Spring Placement Drive 2026 Registration Open",
            content="Final and pre-final year students are requested to complete resume upload by Oct 15.",
            created_by=admin.id,
            published_by=admin.id,
            priority="HIGH",
            category="CAREER",
            target_type="ALL",
            status="PUBLISHED"
        )
        db.session.add(notice1)

        notice2 = Notice(
            title="CS304 Lab Test Schedule Update",
            content="Distributed Systems lab test will be conducted in Lab 302 on Friday 10:00 AM.",
            created_by=teacher.id,
            published_by=teacher.id,
            priority="NORMAL",
            category="ACADEMIC",
            target_type="BRANCH",
            target_branch="Computer Science & Engineering",
            target_year="3",
            status="PUBLISHED"
        )
        db.session.add(notice2)
        db.session.flush()

        delivery1 = NotificationDelivery(
            notice_id=notice1.id,
            user_id=student.id,
            title=notice1.title,
            body="Placement registration deadline is Oct 15.",
            notification_type="NOTICE",
            status="DELIVERED",
            is_read=False,
            delivered_at=now_iso
        )
        db.session.add(delivery1)

        delivery2 = NotificationDelivery(
            notice_id=notice2.id,
            user_id=student.id,
            title=notice2.title,
            body=notice2.content,
            notification_type="NOTICE",
            status="READ",
            is_read=True,
            delivered_at=(now - timedelta(hours=2)).isoformat(),
            read_at=(now - timedelta(hours=1)).isoformat()
        )
        db.session.add(delivery2)

        # --- MESS MENUS & FEEDBACK ---
        print("[SEED] Creating Mess menus for Yesterday, Today, Tomorrow...")
        for days_offset, label in [(-1, "Yesterday"), (0, "Today"), (1, "Tomorrow")]:
            m_date = (now + timedelta(days=days_offset)).strftime('%Y-%m-%d')
            menu = MessMenu.query.filter_by(menu_date=m_date, status='PUBLISHED').first()
            if not menu:
                menu = MessMenu(
                    menu_date=m_date,
                    status="PUBLISHED",
                    created_by=admin.id,
                    updated_by=admin.id
                )
                db.session.add(menu)
                db.session.flush()

                meals_spec = [
                    ("BREAKFAST", f"Buffet Breakfast ({label})", ["Masala Dosa", "Sambar & Chutney", "Boiled Eggs", "Tea/Coffee"], 1),
                    ("LUNCH", f"Executive Thali ({label})", ["Paneer Butter Masala", "Dal Tadka", "Jeera Rice", "Roti", "Gulab Jamun"], 2),
                    ("SNACKS", f"Evening High Tea ({label})", ["Veg Cutlet", "Mint Chutney", "Special Chai", "Biscuits"], 3),
                    ("DINNER", f"Comfort Dinner ({label})", ["Mix Veg Curry", "Phulkas", "Basmati Rice", "Dal Makhani", "Ice Cream"], 4),
                ]
                for m_type, m_title, items, order in meals_spec:
                    meal = MessMeal(
                        menu_id=menu.id,
                        meal_type=m_type,
                        title=m_title,
                        description="Nutritious hygienic meal prepared under campus chef supervision.",
                        items=json.dumps(items),
                        availability="AVAILABLE",
                        display_order=order
                    )
                    db.session.add(meal)

        today_menu = MessMenu.query.filter_by(menu_date=today_str, status='PUBLISHED').first()
        today_lunch = MessMeal.query.filter_by(menu_id=today_menu.id, meal_type='LUNCH').first() if today_menu else None

        # Meal entry for student
        meal_entry = MealEntry(
            menu_id=today_menu.id if today_menu else None,
            meal_id=today_lunch.id if today_lunch else None,
            student_id=student.id,
            student_name=student.name,
            registration_number=student.registration_number,
            meal_type="LUNCH",
            entry_date=today_str,
            verification_mode="QR_PRESENTATION",
            verified_by=mess_staff.id,
            status="VERIFIED",
            idempotency_key=f"SEED-{student.id}-{today_str}-LUNCH"
        )
        db.session.add(meal_entry)

        if today_menu and today_lunch:
            feedback = MessFeedback(
                menu_id=today_menu.id,
                meal_id=today_lunch.id,
                student_id=student.id,
                rating=5,
                category="TASTE",
                comment="Paneer curry was exceptionally fresh and well spiced."
            )
            db.session.add(feedback)

        # --- EXPANSION: DOCUMENTS, FEES, VISITORS ---
        print("[SEED] Creating Documents, Fees & Visitor Passes...")
        doc = DocumentRequest(
            student_id=student.id,
            document_type="BONAFIDE_CERTIFICATE",
            purpose="Passport renewal application",
            status="ISSUED",
            document_number="DOC-2026-BON-0042",
            approved_by=admin.id,
            issued_at=today_str,
            stored_in_wallet=True,
            wallet_added_at=now_iso,
            document_data_json=json.dumps({
                "studentName": student.name,
                "regNo": student.registration_number,
                "course": student.course,
                "branch": student.branch,
                "academicYear": "2025-2026",
                "validUntil": (now + timedelta(days=365)).strftime('%Y-%m-%d')
            })
        )
        db.session.add(doc)

        fee_tuition = FeeRecord(
            student_id=student.id,
            title="Spring 2026 Semester Tuition & Laboratory Fee",
            category="TUITION",
            amount=65000.0,
            amount_paid=65000.0,
            due_date=(now - timedelta(days=15)).strftime('%Y-%m-%d'),
            status="PAID",
            receipt_number="RCP-2026-TUI-0189",
            paid_at=(now - timedelta(days=20)).isoformat(),
            academic_year="2025-2026",
            semester=6
        )
        db.session.add(fee_tuition)

        fee_hostel = FeeRecord(
            student_id=student.id,
            title="Spring 2026 Hostel Maintenance & Utility Dues",
            category="HOSTEL",
            amount=18500.0,
            amount_paid=0.0,
            due_date=(now + timedelta(days=15)).strftime('%Y-%m-%d'),
            status="DUE",
            academic_year="2025-2026",
            semester=6
        )
        db.session.add(fee_hostel)

        visitor = VisitorRequest(
            student_id=student.id,
            visitor_name="Sanjay Sharma",
            visitor_phone="+91 98765 43210",
            relation="Father",
            purpose="Delivering seasonal clothing & family visit",
            visit_date=today_str,
            expected_entry_time="10:00",
            expected_exit_time="18:00",
            status="APPROVED",
            approved_by=warden.id,
            pass_code="VIS-PASS-2026-081"
        )
        db.session.add(visitor)

        db.session.commit()
        print("\n========================================================")
        print("  CAMPUSOS PHYSICAL MULTI-DEVICE TEST SEED COMPLETE!    ")
        print("========================================================")
        print("  Institutional Accounts Ready For Mobile / Web Testing:")
        print("  1. ADMIN:      admin@campusos.edu    / Admin@1234")
        print("  2. TEACHER:    teacher@campusos.edu  / Teacher@1234")
        print("  3. STUDENT:    student@campusos.edu  / Student@1234")
        print("  4. WARDEN:     warden@campusos.edu   / Warden@1234")
        print("  5. MESS STAFF: mess@campusos.edu     / Mess@1234")
        print("  6. SECURITY:   security@campusos.edu / Security@1234")
        print("========================================================\n")


if __name__ == '__main__':
    seed_test_system()
