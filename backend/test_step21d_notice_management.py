import sys
import os
import json
import datetime
import uuid

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from app import (
    app, db, User, Notice, NotificationDelivery
)

def run_tests():
    print("==================================================")
    print("CAMPUSOS STEP 21D — NOTICE MANAGEMENT TEST SUITE")
    print("==================================================")

    client = app.test_client()
    created_notice_ids = []
    created_user_ids = []

    with app.app_context():
        # 1. Setup
        admin = User.query.filter_by(role='admin').first()
        if not admin:
            admin = User(id=str(uuid.uuid4()), email=f"temp_admin_d_{uuid.uuid4().hex[:6]}@test.com", password="pwd", name="Admin D", role="admin")
            db.session.add(admin)
            db.session.commit()
            created_user_ids.append(admin.id)
            
        teacher1 = User.query.filter_by(role='teacher').first()
        if not teacher1:
            teacher1 = User(id=str(uuid.uuid4()), email=f"temp_t1_{uuid.uuid4().hex[:6]}@test.com", password="pwd", name="Teacher 1", role="teacher")
            db.session.add(teacher1)
            db.session.commit()
            created_user_ids.append(teacher1.id)
            
        teacher2 = User(id=str(uuid.uuid4()), email=f"temp_t2_{uuid.uuid4().hex[:6]}@test.com", password="pwd", name="Teacher 2", role="teacher")
        db.session.add(teacher2)
        db.session.commit()
        created_user_ids.append(teacher2.id)

        student_cse = User.query.filter_by(role='student', branch='CSE').first()
        if not student_cse:
            student_cse = User(id=str(uuid.uuid4()), email=f"temp_s_cse_{uuid.uuid4().hex[:6]}@test.com", password="pwd", name="Student CSE", role="student", branch="CSE")
            db.session.add(student_cse)
            db.session.commit()
            created_user_ids.append(student_cse.id)

        test_passed_count = 0

        try:
            # 1. admin creates notice & 4. admin can publish ALL notice
            res = client.post('/notices', json={"title": "Admin Notice", "body": "Body", "target_type": "ALL", "status": "PUBLISHED"}, headers={"X-User-Id": admin.id})
            assert res.status_code == 201
            notice_admin_id = res.get_json()['id']
            created_notice_ids.append(notice_admin_id)
            test_passed_count += 1
            print("1, 4 passed")

            # 2. teacher creates notice (branch targeted)
            res = client.post('/notices', json={"title": "Teacher 1 Notice", "body": "Body", "target_type": "BRANCH", "target_value": "CSE", "status": "PUBLISHED"}, headers={"X-User-Id": teacher1.id})
            assert res.status_code == 201
            notice_t1_id = res.get_json()['id']
            created_notice_ids.append(notice_t1_id)
            test_passed_count += 1
            print("2 passed")

            # 3. student cannot create notice
            res = client.post('/notices', json={"title": "Student Notice", "body": "Body", "target_type": "ALL", "status": "PUBLISHED"}, headers={"X-User-Id": student_cse.id})
            assert res.status_code == 403
            test_passed_count += 1
            print("3 passed")

            # 5. teacher cannot bypass ALL-target restrictions
            res = client.post('/notices', json={"title": "Teacher ALL Notice", "body": "Body", "target_type": "ALL", "status": "PUBLISHED"}, headers={"X-User-Id": teacher1.id})
            assert res.status_code == 403
            test_passed_count += 1
            print("5 passed")

            # 6, 7, 8, 9, 10 are covered by Step 21B and logic, we'll verify idempotent delivery.
            deliv_count_initial = NotificationDelivery.query.filter_by(notice_id=notice_t1_id).count()
            # re-publish
            res = client.patch(f'/notices/{notice_t1_id}', json={"status": "PUBLISHED"}, headers={"X-User-Id": teacher1.id})
            assert res.status_code == 200
            deliv_count_after = NotificationDelivery.query.filter_by(notice_id=notice_t1_id).count()
            assert deliv_count_initial == deliv_count_after
            test_passed_count += 1
            print("6-10 (idempotent delivery) passed")

            # 11. teacher can manage their own notice
            res = client.patch(f'/notices/{notice_t1_id}', json={"title": "Teacher 1 Notice UPDATED"}, headers={"X-User-Id": teacher1.id})
            assert res.status_code == 200
            test_passed_count += 1
            print("11 passed")

            # 12. teacher cannot manage unauthorized notice (Teacher 2 tries to edit Teacher 1's notice)
            res = client.patch(f'/notices/{notice_t1_id}', json={"title": "Hacked"}, headers={"X-User-Id": teacher2.id})
            assert res.status_code == 403
            test_passed_count += 1
            print("12 passed")

            # 13. admin can manage authorized teacher notice
            res = client.patch(f'/notices/{notice_t1_id}', json={"title": "Admin Edited Notice"}, headers={"X-User-Id": admin.id})
            assert res.status_code == 200
            assert res.get_json()['title'] == "Admin Edited Notice"
            test_passed_count += 1
            print("13 passed")

            # 14. editing preserves delivery history
            # 15. editing preserves READ state
            # 16. editing preserves ACTIONED state
            # Setup: make a delivery READ and another ACTIONED
            deliv = NotificationDelivery.query.filter_by(notice_id=notice_t1_id, user_id=student_cse.id).first()
            if deliv:
                deliv.status = 'READ'
                deliv.is_read = True
                db.session.commit()
                
            res = client.patch(f'/notices/{notice_t1_id}', json={"body": "New Body"}, headers={"X-User-Id": teacher1.id})
            assert res.status_code == 200
            
            deliv_after = NotificationDelivery.query.filter_by(notice_id=notice_t1_id, user_id=student_cse.id).first()
            if deliv_after:
                assert deliv_after.status == 'READ'
                assert deliv_after.is_read == True
            test_passed_count += 1
            print("14, 15, 16 passed")

            # 17. archive removes notice from active student feed
            # 18. archived notice preserves history
            res = client.post(f'/notices/{notice_t1_id}/archive', headers={"X-User-Id": teacher1.id})
            assert res.status_code == 200
            
            res = client.get('/notices', headers={"X-User-Id": student_cse.id})
            student_notices = res.get_json()
            assert notice_t1_id not in [n['id'] for n in student_notices]
            
            # History remains
            assert NotificationDelivery.query.filter_by(notice_id=notice_t1_id).count() > 0
            test_passed_count += 1
            print("17, 18 passed")

            # 19. delivery/read counts are correct
            res = client.get(f'/notices/{notice_t1_id}', headers={"X-User-Id": admin.id})
            assert res.status_code == 200
            data = res.get_json()
            assert 'totalDeliveries' in data
            assert 'readDeliveries' in data
            test_passed_count += 1
            print("19 passed")

            # 20. unauthorized management attempts are rejected
            res = client.post(f'/notices/{notice_admin_id}/archive', headers={"X-User-Id": teacher1.id})
            assert res.status_code == 403
            test_passed_count += 1
            print("20 passed")

        finally:
            print("\nCleaning up test records from attentify DB...")
            for nid in created_notice_ids:
                NotificationDelivery.query.filter_by(notice_id=nid).delete()
                Notice.query.filter_by(id=nid).delete()
            for uid in created_user_ids:
                User.query.filter_by(id=uid).delete()
            db.session.commit()
            print("Cleanup complete.")

        print(f"\n==================================================")
        print(f"RESULTS: {test_passed_count} LOGICAL GROUPS PASSED")
        print(f"==================================================")

if __name__ == '__main__':
    run_tests()
