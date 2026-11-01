import sys
import os
import json
import datetime
import uuid

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from app import (
    app, db, User, Notice, NotificationDelivery
)
import extensions
extensions.fcm_sender_override = lambda msg: print("[MOCK] FCM message sent:", getattr(msg, 'token', 'None'))

def run_tests():
    print("==================================================")
    print("CAMPUSOS STEP 21C — NOTICE READ TRACKING TEST SUITE")
    print("==================================================")

    client = app.test_client()
    created_notice_ids = []
    created_user_ids = []

    with app.app_context():
        # Setup test fixtures
        admin = User.query.filter_by(role='admin').first()
        if not admin:
            admin = User(
                id=str(uuid.uuid4()),
                email=f"temp_admin_c_{uuid.uuid4().hex[:6]}@campusos.test",
                password="testpassword",
                name="Temporary Admin C",
                role="admin"
            )
            db.session.add(admin)
            db.session.commit()
            created_user_ids.append(admin.id)
            
        teacher = User.query.filter_by(role='teacher').first()
        student1 = User.query.filter_by(role='student', branch='CSE').first()
        assert teacher is not None, "Teacher user must exist in attentify DB"
        assert student1 is not None, "Student 1 must exist in attentify DB"

        # Create temporary second student (ECE)
        student2 = User(
            id=str(uuid.uuid4()),
            email=f"temp_s2_{uuid.uuid4().hex[:6]}@campusos.test",
            password="testpassword",
            name="Temporary ECE Student 2",
            role="student",
            registration_number="REG_ECE_002",
            course="B.Tech",
            branch="ECE",
            year="2nd"
        )
        db.session.add(student2)
        db.session.commit()
        created_user_ids.append(student2.id)

        print(f"Test Fixtures Ready:")
        print(f"  - Admin: {admin.name} ({admin.id})")
        print(f"  - Teacher (Staff/Admin): {teacher.name} ({teacher.id})")
        print(f"  - Student 1 (CSE): {student1.name} ({student1.id})")
        print(f"  - Student 2 (ECE): {student2.name} ({student2.id})\n")

        test_passed_count = 0

        try:
            # 1. Create a published notice for Student 1 only (BRANCH=CSE)
            res = client.post('/notices', json={
                "title": "CSE Academic Seminar",
                "body": "Seminar for CSE students only.",
                "category": "ACADEMIC",
                "priority": "HIGH",
                "target_type": "BRANCH",
                "target_value": "CSE",
                "status": "PUBLISHED"
            }, headers={"X-User-Id": teacher.id})
            assert res.status_code == 201
            cse_notice_id = res.get_json()['id']
            created_notice_ids.append(cse_notice_id)

            # 2. Create a published notice for Student 2 only (BRANCH=ECE)
            res = client.post('/notices', json={
                "title": "ECE Circuit Lab Workshop",
                "body": "Lab session for ECE students only.",
                "category": "ACADEMIC",
                "priority": "NORMAL",
                "target_type": "BRANCH",
                "target_value": "ECE",
                "status": "PUBLISHED"
            }, headers={"X-User-Id": teacher.id})
            assert res.status_code == 201
            ece_notice_id = res.get_json()['id']
            created_notice_ids.append(ece_notice_id)

            # 3. Create an ALL notice for both
            res = client.post('/notices', json={
                "title": "Campus Wide Convocation Notice",
                "body": "Convocation registration is now live for all branches.",
                "category": "EVENT",
                "priority": "URGENT",
                "target_type": "ALL",
                "status": "PUBLISHED"
            }, headers={"X-User-Id": admin.id})
            assert res.status_code == 201
            all_notice_id = res.get_json()['id']
            created_notice_ids.append(all_notice_id)

            # ----------------------------------------------------
            # Test 1: Read accessible notice (Student 1 reads CSE notice)
            # ----------------------------------------------------
            print("[Test 1] Read accessible notice...")
            res_read1 = client.post(f'/notices/{cse_notice_id}/read', headers={"X-User-Id": student1.id})
            assert res_read1.status_code == 200, f"Expected 200, got {res_read1.status_code}: {res_read1.data}"
            data_read1 = res_read1.get_json()
            assert data_read1['noticeId'] == cse_notice_id
            assert data_read1['userId'] == student1.id
            assert data_read1['isRead'] == True
            assert data_read1['status'] == "READ"
            assert data_read1['readAt'] is not None
            print("  -> PASSED: Student 1 successfully marked CSE notice as read.")
            test_passed_count += 1

            # ----------------------------------------------------
            # Test 2: Unauthorized read attempt (Student 1 reads ECE notice)
            # ----------------------------------------------------
            print("[Test 2] Unauthorized read attempt (student reading other branch's notice)...")
            res_unauth = client.post(f'/notices/{ece_notice_id}/read', headers={"X-User-Id": student1.id})
            assert res_unauth.status_code == 403
            assert "Access denied" in res_unauth.get_json()['message']
            print("  -> PASSED: Student 1 blocked from reading ECE notice with 403.")
            test_passed_count += 1

            # ----------------------------------------------------
            # Test 3: Nonexistent notice
            # ----------------------------------------------------
            print("[Test 3] Nonexistent notice read attempt...")
            res_404 = client.post(f'/notices/{uuid.uuid4()}/read', headers={"X-User-Id": student1.id})
            assert res_404.status_code == 404
            assert "Notice not found" in res_404.get_json()['message']
            print("  -> PASSED: Nonexistent notice returned 404.")
            test_passed_count += 1

            # ----------------------------------------------------
            # Test 4: Repeated read request is idempotent
            # ----------------------------------------------------
            print("[Test 4] Repeated read request idempotency...")
            first_read_at = data_read1['readAt']
            res_repeat = client.post(f'/notices/{cse_notice_id}/read', headers={"X-User-Id": student1.id})
            assert res_repeat.status_code == 200
            data_repeat = res_repeat.get_json()
            assert data_repeat['isRead'] == True
            assert data_repeat['status'] == "READ"
            # Verify no duplicate deliveries exist
            deliv_count = NotificationDelivery.query.filter_by(notice_id=cse_notice_id, user_id=student1.id).count()
            assert deliv_count == 1, f"Expected exactly 1 delivery record, found {deliv_count}"
            print("  -> PASSED: Repeated read request is completely idempotent.")
            test_passed_count += 1

            # ----------------------------------------------------
            # Test 5: Already ACTIONED delivery remains ACTIONED
            # ----------------------------------------------------
            print("[Test 5] Already ACTIONED delivery remains ACTIONED on read...")
            deliv_cse = NotificationDelivery.query.filter_by(notice_id=cse_notice_id, user_id=student1.id).first()
            deliv_cse.status = 'ACTIONED'
            deliv_cse.action_at = datetime.datetime.now().isoformat()
            db.session.commit()

            res_read_actioned = client.post(f'/notices/{cse_notice_id}/read', headers={"X-User-Id": student1.id})
            assert res_read_actioned.status_code == 200
            data_actioned = res_read_actioned.get_json()
            assert data_actioned['status'] == "ACTIONED", f"Expected ACTIONED, got {data_actioned['status']}"
            assert data_actioned['isRead'] == True
            print("  -> PASSED: ACTIONED delivery status was preserved.")
            test_passed_count += 1

            # ----------------------------------------------------
            # Test 6: read_at is populated
            # ----------------------------------------------------
            print("[Test 6] Verification of read_at field...")
            res_all_s2 = client.post(f'/notices/{all_notice_id}/read', headers={"X-User-Id": student2.id})
            assert res_all_s2.status_code == 200
            data_all_s2 = res_all_s2.get_json()
            assert data_all_s2['readAt'] is not None
            # Validate ISO timestamp
            datetime.datetime.fromisoformat(data_all_s2['readAt'])
            print("  -> PASSED: readAt is populated with valid ISO timestamp.")
            test_passed_count += 1

            # ----------------------------------------------------
            # Test 7: is_read is true
            # ----------------------------------------------------
            print("[Test 7] Verification of is_read == True...")
            assert data_all_s2['isRead'] == True
            db_deliv = NotificationDelivery.query.filter_by(notice_id=all_notice_id, user_id=student2.id).first()
            assert db_deliv.is_read == True
            print("  -> PASSED: is_read confirmed true in API response and database.")
            test_passed_count += 1

            # ----------------------------------------------------
            # Test 8 & 9: Correct student delivery updated & another student untouched
            # ----------------------------------------------------
            print("[Test 8 & 9] Multi-user delivery isolation on shared notice...")
            # Student 2 read all_notice_id, but Student 1 has NOT read all_notice_id yet
            deliv_s1_all = NotificationDelivery.query.filter_by(notice_id=all_notice_id, user_id=student1.id).first()
            assert deliv_s1_all is not None
            assert deliv_s1_all.is_read == False or deliv_s1_all.is_read is None
            assert deliv_s1_all.status in ["PENDING", "DELIVERED", "FAILED"]
            assert deliv_s1_all.status != "READ"
            assert deliv_s1_all.read_at is None

            # Student 2 delivery is READ
            deliv_s2_all = NotificationDelivery.query.filter_by(notice_id=all_notice_id, user_id=student2.id).first()
            assert deliv_s2_all is not None
            assert deliv_s2_all.is_read == True
            assert deliv_s2_all.status == "READ"
            assert deliv_s2_all.read_at is not None
            print("  -> PASSED: Student 2 marked read while Student 1 remained PENDING (zero cross-contamination).")
            test_passed_count += 2

        finally:
            print("\nCleaning up test records from attentify DB...")
            if created_notice_ids:
                NotificationDelivery.query.filter(NotificationDelivery.notice_id.in_(created_notice_ids)).delete(synchronize_session=False)
                Notice.query.filter(Notice.id.in_(created_notice_ids)).delete(synchronize_session=False)
            if created_user_ids:
                NotificationDelivery.query.filter(NotificationDelivery.user_id.in_(created_user_ids)).delete(synchronize_session=False)
                User.query.filter(User.id.in_(created_user_ids)).delete(synchronize_session=False)
            db.session.commit()
            print("Cleanup complete. Zero leftover test notices or delivery records.")

    print(f"\n==================================================")
    print(f"RESULTS: {test_passed_count}/9 TESTS PASSED (100% SUCCESS)")
    print(f"==================================================")

if __name__ == '__main__':
    run_tests()
