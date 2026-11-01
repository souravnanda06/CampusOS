import sys
import os
import json
import datetime
import uuid

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from app import (
    app, db, User, Session, Attendance, LeaveRequest, GatePass,
    RequestAudit, Complaint, ComplaintStatusHistory, Notice, NotificationDelivery,
    resolve_notice_recipients, sync_notice_deliveries, is_notice_targeted_to_student
)
import extensions
extensions.fcm_sender_override = lambda msg: print("[MOCK] FCM message sent:", getattr(msg, 'token', 'None'))

def run_tests():
    print("==================================================")
    print("CAMPUSOS STEP 21B — NOTICE CRUD + TARGETING TEST SUITE")
    print("==================================================")

    client = app.test_client()
    created_notice_ids = []
    created_user_ids = []

    with app.app_context():
        # Setup test fixtures
        admin = User.query.filter_by(role='admin').first()
        if not admin:
            # Create a temporary admin if none exists
            admin = User(
                id=str(uuid.uuid4()),
                email=f"temp_admin_{uuid.uuid4().hex[:6]}@campusos.test",
                password="testpassword",
                name="Temporary Admin",
                role="admin"
            )
            db.session.add(admin)
            db.session.commit()
            created_user_ids.append(admin.id)
            
        teacher = User.query.filter_by(role='teacher').first()
        student_cse = User.query.filter_by(role='student', branch='CSE').first()
        assert teacher is not None, "Teacher user must exist in attentify DB"
        assert student_cse is not None, "Student with CSE branch must exist in attentify DB"

        # Create temporary second student (ECE, 2nd year)
        temp_student_ece = User(
            id=str(uuid.uuid4()),
            email=f"temp_ece_{uuid.uuid4().hex[:6]}@campusos.test",
            password="testpassword",
            name="Temporary ECE Student",
            role="student",
            registration_number="REG_ECE_001",
            course="B.Tech",
            branch="ECE",
            year="2nd"
        )
        db.session.add(temp_student_ece)
        db.session.commit()
        created_user_ids.append(temp_student_ece.id)

        print(f"Test Fixtures Ready:")
        print(f"  - Admin: {admin.name} ({admin.id})")
        print(f"  - Teacher (Staff/Admin): {teacher.name} ({teacher.id})")
        print(f"  - Student 1 (CSE, 3rd): {student_cse.name} ({student_cse.id})")
        print(f"  - Student 2 (ECE, 2nd): {temp_student_ece.name} ({temp_student_ece.id})\n")

        test_passed_count = 0

        try:
            # ----------------------------------------------------
            # Test 1: Create ALL notice
            # ----------------------------------------------------
            print("[Test 1] Create ALL notice...")
            res = client.post('/notices', json={
                "title": "Campus Wide Annual Fest 2026",
                "body": "All students are invited to the campus festival.",
                "category": "EVENT",
                "priority": "NORMAL",
                "target_type": "ALL",
                "status": "PUBLISHED"
            }, headers={"X-User-Id": admin.id})
            assert res.status_code == 201, f"Expected 201, got {res.status_code}: {res.data}"
            data = res.get_json()
            assert data['title'] == "Campus Wide Annual Fest 2026"
            assert data['targetType'] == "ALL"
            assert data['status'] == "PUBLISHED"
            assert data['recipientCount'] >= 2
            notice_all_id = data['id']
            created_notice_ids.append(notice_all_id)
            print("  -> PASSED: ALL notice created with correct deliveries.")
            test_passed_count += 1

            # ----------------------------------------------------
            # Test 2: Create BRANCH notice
            # ----------------------------------------------------
            print("[Test 2] Create BRANCH notice (CSE)...")
            res = client.post('/notices', json={
                "title": "CSE Department Lab Schedule",
                "body": "Special lab sessions for CSE department students.",
                "category": "ACADEMIC",
                "priority": "HIGH",
                "target_type": "BRANCH",
                "target_value": "CSE",
                "status": "PUBLISHED"
            }, headers={"X-User-Id": teacher.id})
            assert res.status_code == 201, f"Expected 201, got {res.status_code}: {res.data}"
            data = res.get_json()
            assert data['targetType'] == "BRANCH"
            assert data['targetValue'] == "CSE"
            notice_branch_id = data['id']
            created_notice_ids.append(notice_branch_id)
            # Verify deliveries only for CSE students
            deliveries = NotificationDelivery.query.filter_by(notice_id=notice_branch_id).all()
            recipient_ids = {d.user_id for d in deliveries}
            assert student_cse.id in recipient_ids
            assert temp_student_ece.id not in recipient_ids
            print("  -> PASSED: BRANCH notice created and targeted strictly to CSE.")
            test_passed_count += 1

            # ----------------------------------------------------
            # Test 3: Create YEAR notice
            # ----------------------------------------------------
            print("[Test 3] Create YEAR notice (3rd Year)...")
            res = client.post('/notices', json={
                "title": "3rd Year Internship Drive",
                "body": "Internship opportunities for 3rd year students.",
                "category": "ACADEMIC",
                "priority": "URGENT",
                "target_type": "YEAR",
                "target_value": "3rd",
                "status": "PUBLISHED"
            }, headers={"X-User-Id": teacher.id})
            assert res.status_code == 201, f"Expected 201, got {res.status_code}: {res.data}"
            data = res.get_json()
            notice_year_id = data['id']
            created_notice_ids.append(notice_year_id)
            deliveries = NotificationDelivery.query.filter_by(notice_id=notice_year_id).all()
            recipient_ids = {d.user_id for d in deliveries}
            assert student_cse.id in recipient_ids
            assert temp_student_ece.id not in recipient_ids
            print("  -> PASSED: YEAR notice created and targeted strictly to 3rd year.")
            test_passed_count += 1

            # ----------------------------------------------------
            # Test 4: Create STUDENT notice
            # ----------------------------------------------------
            print("[Test 4] Create STUDENT notice...")
            res = client.post('/notices', json={
                "title": "Document Verification Reminder",
                "body": "Please submit your missing admission certificate.",
                "category": "GENERAL",
                "priority": "HIGH",
                "target_type": "STUDENT",
                "target_value": student_cse.id,
                "status": "PUBLISHED"
            }, headers={"X-User-Id": teacher.id})
            assert res.status_code == 201, f"Expected 201, got {res.status_code}: {res.data}"
            data = res.get_json()
            notice_student_id = data['id']
            created_notice_ids.append(notice_student_id)
            deliveries = NotificationDelivery.query.filter_by(notice_id=notice_student_id).all()
            assert len(deliveries) == 1
            assert deliveries[0].user_id == student_cse.id
            print("  -> PASSED: Direct STUDENT notice created and targeted to single student.")
            test_passed_count += 1

            # ----------------------------------------------------
            # Test 5: HOSTEL targeting behavior
            # ----------------------------------------------------
            print("[Test 5] HOSTEL targeting rejection...")
            res = client.post('/notices', json={
                "title": "Hostel Water Maintenance",
                "body": "Water supply maintenance in Block A.",
                "category": "HOSTEL",
                "target_type": "HOSTEL",
                "target_value": "Block-A"
            }, headers={"X-User-Id": teacher.id})
            assert res.status_code == 400, f"Expected 400, got {res.status_code}"
            assert "hostel metadata is not configured" in res.get_json()['message']
            print("  -> PASSED: HOSTEL targeting returned expected rejection response.")
            test_passed_count += 1

            # ----------------------------------------------------
            # Test 6: Invalid target type
            # ----------------------------------------------------
            print("[Test 6] Invalid target_type rejection...")
            res = client.post('/notices', json={
                "title": "Invalid Target Test",
                "body": "Body text",
                "target_type": "SPACE_COLONY"
            }, headers={"X-User-Id": teacher.id})
            assert res.status_code == 400
            assert "Invalid target_type" in res.get_json()['message']
            print("  -> PASSED: Invalid target_type rejected with 400.")
            test_passed_count += 1

            # ----------------------------------------------------
            # Test 7: Missing target value
            # ----------------------------------------------------
            print("[Test 7] Missing target_value for BRANCH...")
            res = client.post('/notices', json={
                "title": "Branch Test Without Value",
                "body": "Body text",
                "target_type": "BRANCH"
            }, headers={"X-User-Id": teacher.id})
            assert res.status_code == 400
            assert "target_value is required" in res.get_json()['message']
            print("  -> PASSED: Missing target_value rejected with 400.")
            test_passed_count += 1

            # ----------------------------------------------------
            # Test 8: Unauthorized student creation
            # ----------------------------------------------------
            print("[Test 8] Unauthorized student creation attempt...")
            res = client.post('/notices', json={
                "title": "Student Notice Attempt",
                "body": "I am a student trying to post official notice.",
                "target_type": "ALL"
            }, headers={"X-User-Id": student_cse.id})
            assert res.status_code == 403
            assert "Forbidden" in res.get_json()['message']
            print("  -> PASSED: Student blocked from creating notice with 403.")
            test_passed_count += 1

            # ----------------------------------------------------
            # Test 9: Authorized staff/admin creation
            # ----------------------------------------------------
            print("[Test 9] Authorized staff creation with draft status...")
            res = client.post('/notices', json={
                "title": "Draft Staff Policy",
                "body": "Pending review staff policy.",
                "category": "ACADEMIC",
                "priority": "NORMAL",
                "target_type": "ALL",
                "status": "DRAFT"
            }, headers={"X-User-Id": admin.id})
            assert res.status_code == 201
            data = res.get_json()
            assert data['status'] == "DRAFT"
            assert data['recipientCount'] == 0  # DRAFT does not create deliveries yet
            notice_draft_id = data['id']
            created_notice_ids.append(notice_draft_id)
            print("  -> PASSED: Staff created DRAFT notice without premature deliveries.")
            test_passed_count += 1

            # ----------------------------------------------------
            # Test 10: List notices (Staff view)
            # ----------------------------------------------------
            print("[Test 10] List notices (Staff view)...")
            res = client.get('/notices', headers={"X-User-Id": admin.id})
            assert res.status_code == 200
            staff_list = res.get_json()
            assert len(staff_list) >= 5
            # Confirm newest first order
            for i in range(len(staff_list) - 1):
                assert staff_list[i]['createdAt'] >= staff_list[i + 1]['createdAt']
            print(f"  -> PASSED: Staff retrieved all {len(staff_list)} notices in newest-first order.")
            test_passed_count += 1

            # ----------------------------------------------------
            # Test 11: Student only sees notices targeted to them
            # ----------------------------------------------------
            print("[Test 11] Student targeted notice listing...")
            # Create a notice strictly for ECE student
            res_ece = client.post('/notices', json={
                "title": "ECE Special Workshop",
                "body": "Strictly for ECE students.",
                "category": "EVENT",
                "target_type": "BRANCH",
                "target_value": "ECE",
                "status": "PUBLISHED"
            }, headers={"X-User-Id": teacher.id})
            notice_ece_id = res_ece.get_json()['id']
            created_notice_ids.append(notice_ece_id)

            # Query notices as CSE Student
            res_student_cse = client.get('/notices', headers={"X-User-Id": student_cse.id})
            assert res_student_cse.status_code == 200
            cse_notices = res_student_cse.get_json()
            cse_notice_ids = {n['id'] for n in cse_notices}

            # CSE student MUST see ALL, CSE branch, 3rd year, and direct notices
            assert notice_all_id in cse_notice_ids
            assert notice_branch_id in cse_notice_ids
            assert notice_year_id in cse_notice_ids
            assert notice_student_id in cse_notice_ids
            # CSE student MUST NOT see ECE notice or DRAFT notice
            assert notice_ece_id not in cse_notice_ids
            assert notice_draft_id not in cse_notice_ids

            # Query notices as ECE Student
            res_student_ece = client.get('/notices', headers={"X-User-Id": temp_student_ece.id})
            assert res_student_ece.status_code == 200
            ece_notices = res_student_ece.get_json()
            ece_notice_ids = {n['id'] for n in ece_notices}

            # ECE student MUST see ALL and ECE notice
            assert notice_all_id in ece_notice_ids
            assert notice_ece_id in ece_notice_ids
            # ECE student MUST NOT see CSE branch, 3rd year, direct CSE notice, or DRAFT
            assert notice_branch_id not in ece_notice_ids
            assert notice_year_id not in ece_notice_ids
            assert notice_student_id not in ece_notice_ids
            assert notice_draft_id not in ece_notice_ids
            print("  -> PASSED: Targeting isolation verified across different branches/years/drafts.")
            test_passed_count += 1

            # ----------------------------------------------------
            # Test 12: Notice detail authorization
            # ----------------------------------------------------
            print("[Test 12] Notice detail authorization...")
            # CSE student viewing their own notice -> 200
            res_ok = client.get(f'/notices/{notice_branch_id}', headers={"X-User-Id": student_cse.id})
            assert res_ok.status_code == 200
            # CSE student viewing ECE notice -> 403
            res_denied = client.get(f'/notices/{notice_ece_id}', headers={"X-User-Id": student_cse.id})
            assert res_denied.status_code == 403
            # Staff viewing any notice -> 200
            res_staff = client.get(f'/notices/{notice_ece_id}', headers={"X-User-Id": teacher.id})
            assert res_staff.status_code == 200
            assert 'totalDeliveries' in res_staff.get_json()
            print("  -> PASSED: Notice detail access control verified.")
            test_passed_count += 1

            # ----------------------------------------------------
            # Test 13: Nonexistent notice
            # ----------------------------------------------------
            print("[Test 13] Nonexistent notice lookup...")
            res_404 = client.get(f'/notices/{uuid.uuid4()}', headers={"X-User-Id": teacher.id})
            assert res_404.status_code == 404
            print("  -> PASSED: Nonexistent notice returns 404.")
            test_passed_count += 1

            # ----------------------------------------------------
            # Test 14: Update notice
            # ----------------------------------------------------
            print("[Test 14] Update notice (PATCH)...")
            res_patch = client.patch(f'/notices/{notice_all_id}', json={
                "title": "Campus Wide Annual Fest 2026 (UPDATED)",
                "priority": "HIGH"
            }, headers={"X-User-Id": admin.id})
            assert res_patch.status_code == 200
            patched_data = res_patch.get_json()
            assert patched_data['title'] == "Campus Wide Annual Fest 2026 (UPDATED)"
            assert patched_data['priority'] == "HIGH"
            print("  -> PASSED: Notice fields updated successfully.")
            test_passed_count += 1

            # ----------------------------------------------------
            # Test 15: Archive notice
            # ----------------------------------------------------
            print("[Test 15] Archive notice...")
            res_arch = client.post(f'/notices/{notice_student_id}/archive', headers={"X-User-Id": teacher.id})
            assert res_arch.status_code == 200
            assert res_arch.get_json()['status'] == "ARCHIVED"
            # Student should no longer see archived notice in default list
            res_student_after_arch = client.get('/notices', headers={"X-User-Id": student_cse.id})
            cse_ids_after = {n['id'] for n in res_student_after_arch.get_json()}
            assert notice_student_id not in cse_ids_after
            print("  -> PASSED: Notice archived and hidden from student feed.")
            test_passed_count += 1

            # ----------------------------------------------------
            # Test 16: Expired notice filtering
            # ----------------------------------------------------
            print("[Test 16] Expired notice filtering...")
            past_time = (datetime.datetime.now() - datetime.timedelta(days=2)).isoformat()
            res_exp = client.post('/notices', json={
                "title": "Past Registration Deadline",
                "body": "This registration is already closed.",
                "target_type": "ALL",
                "expires_at": past_time,
                "status": "PUBLISHED"
            }, headers={"X-User-Id": admin.id})
            notice_exp_id = res_exp.get_json()['id']
            created_notice_ids.append(notice_exp_id)

            # Default list should exclude it
            res_list_normal = client.get('/notices', headers={"X-User-Id": admin.id})
            assert notice_exp_id not in {n['id'] for n in res_list_normal.get_json()}

            # includeExpired=true should include it
            res_list_expired = client.get('/notices?includeExpired=true', headers={"X-User-Id": admin.id})
            assert notice_exp_id in {n['id'] for n in res_list_expired.get_json()}
            print("  -> PASSED: Expired notice excluded by default and included with ?includeExpired=true.")
            test_passed_count += 1

            # ----------------------------------------------------
            # Test 17: Duplicate publish/retry does not duplicate deliveries
            # ----------------------------------------------------
            print("[Test 17] Delivery idempotency check...")
            notice_obj = Notice.query.get(notice_branch_id)
            initial_count = NotificationDelivery.query.filter_by(notice_id=notice_branch_id).count()
            # Call sync_notice_deliveries again (simulate retry)
            added_deliveries = sync_notice_deliveries(notice_obj)
            after_count = NotificationDelivery.query.filter_by(notice_id=notice_branch_id).count()
            assert added_deliveries == 0, f"Expected 0 new deliveries on duplicate sync, got {added_deliveries}"
            assert after_count == initial_count
            print("  -> PASSED: Publish retry maintains idempotent delivery records.")
            test_passed_count += 1

            # ----------------------------------------------------
            # Test 18: Targeting resolves correct users helper
            # ----------------------------------------------------
            print("[Test 18] resolve_notice_recipients helper...")
            n_branch_cse = Notice.query.get(notice_branch_id)
            recipients = resolve_notice_recipients(n_branch_cse)
            assert len(recipients) >= 1
            assert all(r.branch == 'CSE' for r in recipients)
            print("  -> PASSED: Helper returned verified branch recipients.")
            test_passed_count += 1

            # ----------------------------------------------------
            # Test 19: Delivery records contain correct notice/user IDs
            # ----------------------------------------------------
            print("[Test 19] NotificationDelivery record verification...")
            deliv = NotificationDelivery.query.filter_by(notice_id=notice_all_id).first()
            assert deliv is not None
            assert deliv.notice_id == notice_all_id
            assert deliv.user_id is not None
            assert deliv.notification_type == 'NOTICE'
            assert deliv.status in ['PENDING', 'DELIVERED']
            assert deliv.title == "Campus Wide Annual Fest 2026 (UPDATED)"
            deliv_dict = deliv.to_dict()
            assert deliv_dict['noticeId'] == notice_all_id
            assert deliv_dict['status'] in ['PENDING', 'DELIVERED']
            print("  -> PASSED: NotificationDelivery fields and to_dict() verified.")
            test_passed_count += 1

            # ----------------------------------------------------
            # Test 20: Existing domain functionality regression check
            # ----------------------------------------------------
            print("[Test 20] Existing domain regression check...")
            from utils.crypto import create_access_token
            admin_jwt = create_access_token(admin)
            res_admin_dash = client.get('/admin/dashboard/summary', headers={"Authorization": f"Bearer {admin_jwt}", "X-User-Id": admin.id})
            assert res_admin_dash.status_code == 200
            assert 'totalComplaints' in res_admin_dash.get_json()

            res_leave = client.get(f'/requests/leave/{student_cse.id}')
            assert res_leave.status_code == 200

            res_gatepass = client.get(f'/requests/gate-pass/{student_cse.id}')
            assert res_gatepass.status_code == 200

            res_complaints = client.get(f'/complaints/student/{student_cse.id}')
            assert res_complaints.status_code == 200

            print("  -> PASSED: Attendance, Leave, Gate Pass, Complaints, Admin Dashboard operational.")
            test_passed_count += 1

        finally:
            print("\nCleaning up test records from attentify DB...")
            # Clean up notification deliveries
            if created_notice_ids:
                NotificationDelivery.query.filter(NotificationDelivery.notice_id.in_(created_notice_ids)).delete(synchronize_session=False)
                Notice.query.filter(Notice.id.in_(created_notice_ids)).delete(synchronize_session=False)
            if created_user_ids:
                NotificationDelivery.query.filter(NotificationDelivery.user_id.in_(created_user_ids)).delete(synchronize_session=False)
                User.query.filter(User.id.in_(created_user_ids)).delete(synchronize_session=False)
            db.session.commit()
            print("Cleanup complete. Zero leftover test notices or delivery records.")

    print(f"\n==================================================")
    print(f"RESULTS: {test_passed_count}/20 TESTS PASSED (100% SUCCESS)")
    print(f"==================================================")

if __name__ == '__main__':
    run_tests()
