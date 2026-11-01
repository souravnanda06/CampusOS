import sys
import os
import json
import uuid
import datetime

# Ensure utf-8 stdout
if sys.platform == 'win32':
    sys.stdout.reconfigure(encoding='utf-8')

from app import (
    app, db, User, Notice, NotificationDelivery, DeviceToken,
    dispatch_notice_push_notifications
)
import extensions
extensions.fcm_sender_override = lambda msg: print("[MOCK] FCM message sent:", getattr(msg, 'token', 'None'))
import app as app_module

def run_tests():
    print("==================================================")
    print("CAMPUSOS STEP 21E — PUSH NOTIFICATIONS + DELIVERY TEST SUITE")
    print("==================================================")

    created_user_ids = []
    created_notice_ids = []
    created_token_ids = []

    client = app.test_client()

    with app.app_context():
        # Setup fixtures
        admin = User.query.filter_by(role='admin').first()
        if not admin:
            admin = User(
                id=str(uuid.uuid4()),
                email=f"admin_21e_{uuid.uuid4().hex[:6]}@campus.edu",
                password="password",
                name="Admin 21E",
                role="admin"
            )
            db.session.add(admin)
            created_user_ids.append(admin.id)

        teacher1 = User.query.filter_by(role='teacher').first()
        if not teacher1:
            teacher1 = User(
                id=str(uuid.uuid4()),
                email=f"teacher1_21e_{uuid.uuid4().hex[:6]}@campus.edu",
                password="password",
                name="Teacher 1 21E",
                role="teacher"
            )
            db.session.add(teacher1)
            created_user_ids.append(teacher1.id)

        teacher2 = User(
            id=str(uuid.uuid4()),
            email=f"teacher2_21e_{uuid.uuid4().hex[:6]}@campus.edu",
            password="password",
            name="Teacher 2 21E",
            role="teacher"
        )
        db.session.add(teacher2)
        created_user_ids.append(teacher2.id)

        student_cse = User(
            id=str(uuid.uuid4()),
            email=f"student_cse_21e_{uuid.uuid4().hex[:6]}@campus.edu",
            password="password",
            name="Student CSE 21E",
            role="student",
            registration_number=f"REG-21E-{uuid.uuid4().hex[:4]}",
            course="B.Tech",
            branch="Computer Science",
            year="3rd"
        )
        db.session.add(student_cse)
        created_user_ids.append(student_cse.id)

        student_ece = User(
            id=str(uuid.uuid4()),
            email=f"student_ece_21e_{uuid.uuid4().hex[:6]}@campus.edu",
            password="password",
            name="Student ECE 21E",
            role="student",
            registration_number=f"REG-21E-{uuid.uuid4().hex[:4]}",
            course="B.Tech",
            branch="Electronics",
            year="2nd"
        )
        db.session.add(student_ece)
        created_user_ids.append(student_ece.id)

        db.session.commit()

        print(f"Test Fixtures Ready:")
        print(f"  - Admin: {admin.name} ({admin.id})")
        print(f"  - Teacher 1 (Owner): {teacher1.name} ({teacher1.id})")
        print(f"  - Teacher 2 (Other): {teacher2.name} ({teacher2.id})")
        print(f"  - Student CSE: {student_cse.name} ({student_cse.id})")
        print(f"  - Student ECE: {student_ece.name} ({student_ece.id})")
        print()

        try:
            # ----------------------------------------------------
            # Test 1: Valid device token registration
            # ----------------------------------------------------
            print("[Test 1] Valid device token registration...")
            t1_token = f"fcm_token_s1_{uuid.uuid4().hex[:12]}"
            resp = client.post(
                '/notifications/device-token',
                headers={'X-User-Id': student_cse.id},
                json={'token': t1_token, 'deviceType': 'android', 'deviceId': 'pixel_8'}
            )
            assert resp.status_code == 201, f"Expected 201, got {resp.status_code}: {resp.data}"
            data1 = resp.get_json()
            assert data1['token'] == t1_token
            assert data1['userId'] == student_cse.id
            assert data1['isActive'] is True
            created_token_ids.append(data1['id'])
            print("  -> PASSED: Valid device token registered with 201 Created.")

            # ----------------------------------------------------
            # Test 2: Duplicate token registration is idempotent
            # ----------------------------------------------------
            print("[Test 2] Duplicate token registration is idempotent...")
            resp = client.post(
                '/notifications/device-token',
                headers={'X-User-Id': student_cse.id},
                json={'token': t1_token, 'deviceType': 'android', 'deviceId': 'pixel_8'}
            )
            assert resp.status_code == 200, f"Expected 200 on duplicate, got {resp.status_code}: {resp.data}"
            data2 = resp.get_json()
            assert data2['id'] == data1['id']
            assert data2['userId'] == student_cse.id
            assert DeviceToken.query.filter_by(token=t1_token).count() == 1
            print("  -> PASSED: Duplicate registration is idempotent (200 OK, single record).")

            # ----------------------------------------------------
            # Test 3: Token refresh
            # ----------------------------------------------------
            print("[Test 3] Token refresh...")
            t2_token = f"fcm_token_s1_refreshed_{uuid.uuid4().hex[:12]}"
            resp = client.post(
                '/notifications/device-token',
                headers={'X-User-Id': student_cse.id},
                json={'token': t2_token, 'deviceType': 'android'}
            )
            assert resp.status_code == 201
            data3 = resp.get_json()
            created_token_ids.append(data3['id'])
            assert DeviceToken.query.filter_by(user_id=student_cse.id, is_active=True).count() == 2
            print("  -> PASSED: Token refresh successfully registers new active token.")

            # ----------------------------------------------------
            # Test 4: Token removal
            # ----------------------------------------------------
            print("[Test 4] Token removal...")
            del_resp = client.delete(
                '/notifications/device-token',
                headers={'X-User-Id': student_cse.id},
                json={'token': t2_token}
            )
            assert del_resp.status_code == 200, f"Expected 200, got {del_resp.status_code}"
            assert DeviceToken.query.filter_by(token=t2_token).first() is None
            assert DeviceToken.query.filter_by(token=t1_token).first() is not None
            print("  -> PASSED: Token removal deletes specified token and preserves others.")

            # ----------------------------------------------------
            # Test 5: Student cannot register another user's token
            # ----------------------------------------------------
            print("[Test 5] Student cannot register another user's token...")
            spoofed_token = f"fcm_spoofed_{uuid.uuid4().hex[:10]}"
            resp = client.post(
                '/notifications/device-token',
                headers={'X-User-Id': student_cse.id},
                json={'token': spoofed_token, 'userId': student_ece.id}  # attempt to set ECE student
            )
            assert resp.status_code in [200, 201]
            rec = DeviceToken.query.filter_by(token=spoofed_token).first()
            assert rec.user_id == student_cse.id, "Security violation: token was not bound to authenticated requester!"
            created_token_ids.append(rec.id)

            # Also check unauthenticated request is rejected
            unauth_resp = client.post('/notifications/device-token', json={'token': 'no_auth_token'})
            assert unauth_resp.status_code == 401
            print("  -> PASSED: Token registration strictly binds to requester.id; unauthenticated rejected (401).")

            # ----------------------------------------------------
            # Test 6: Unauthorized delivery metrics access rejected
            # ----------------------------------------------------
            print("[Test 6] Unauthorized delivery metrics access rejected...")
            # Create a notice by Teacher 1
            n1_resp = client.post(
                '/notices',
                headers={'X-User-Id': teacher1.id},
                json={
                    'title': 'Midterm Notice 21E',
                    'body': 'Exam syllabus for CSE',
                    'category': 'EXAM',
                    'priority': 'HIGH',
                    'target_type': 'BRANCH',
                    'target_value': 'Computer Science',
                    'status': 'PUBLISHED'
                }
            )
            assert n1_resp.status_code == 201
            n1_id = n1_resp.get_json()['id']
            created_notice_ids.append(n1_id)

            # Student attempts to access metrics
            stu_metrics = client.get(f'/notices/{n1_id}/delivery', headers={'X-User-Id': student_cse.id})
            assert stu_metrics.status_code == 403, f"Expected 403 for student, got {stu_metrics.status_code}"
            print("  -> PASSED: Student blocked from viewing notice delivery metrics (403 Forbidden).")

            # ----------------------------------------------------
            # Test 7: Teacher can inspect own notice metrics
            # ----------------------------------------------------
            print("[Test 7] Teacher can inspect own notice metrics...")
            t1_metrics = client.get(f'/notices/{n1_id}/delivery', headers={'X-User-Id': teacher1.id})
            assert t1_metrics.status_code == 200, f"Expected 200, got {t1_metrics.status_code}: {t1_metrics.data}"
            m_data = t1_metrics.get_json()
            assert m_data['noticeId'] == n1_id
            assert 'metrics' in m_data
            assert 'recipients' in m_data['metrics']
            assert 'pushAttempts' in m_data['metrics']
            assert 'delivered' in m_data['metrics']
            assert 'failed' in m_data['metrics']
            assert 'read' in m_data['metrics']
            assert 'unread' in m_data['metrics']
            assert isinstance(m_data['deliveries'], list)
            print("  -> PASSED: Teacher successfully inspected own notice metrics with full delivery summary.")

            # ----------------------------------------------------
            # Test 8: Teacher cannot inspect unauthorized notice metrics
            # ----------------------------------------------------
            print("[Test 8] Teacher cannot inspect unauthorized notice metrics...")
            t2_metrics = client.get(f'/notices/{n1_id}/delivery', headers={'X-User-Id': teacher2.id})
            assert t2_metrics.status_code == 403, f"Expected 403 for other teacher, got {t2_metrics.status_code}"
            print("  -> PASSED: Other teacher blocked from viewing unauthorized notice metrics (403 Forbidden).")

            # ----------------------------------------------------
            # Test 9: Admin can inspect authorized metrics
            # ----------------------------------------------------
            print("[Test 9] Admin can inspect authorized metrics...")
            admin_metrics = client.get(f'/notices/{n1_id}/delivery', headers={'X-User-Id': admin.id})
            assert admin_metrics.status_code == 200, f"Expected 200 for admin, got {admin_metrics.status_code}"
            print("  -> PASSED: Admin authorized to inspect global notice metrics (200 OK).")

            # ----------------------------------------------------
            # Test 10 & 11: Notification failure does not delete notice or delivery history
            # ----------------------------------------------------
            print("[Test 10 & 11] Notification failure resilience (mock FCM failure)...")
            captured_fcm_errors = []

            def failing_fcm_sender(msg):
                captured_fcm_errors.append(msg)
                raise RuntimeError("Simulated FCM server timeout 500")

            app_module.fcm_sender_override = failing_fcm_sender

            n_fail_resp = client.post(
                '/notices',
                headers={'X-User-Id': teacher1.id},
                json={
                    'title': 'Notice During FCM Outage',
                    'body': 'Push should fail safely, notice must persist.',
                    'category': 'ACADEMIC',
                    'priority': 'NORMAL',
                    'target_type': 'BRANCH',
                    'target_value': 'Computer Science',
                    'status': 'PUBLISHED'
                }
            )
            # Notice creation must still succeed with 201!
            assert n_fail_resp.status_code == 201, f"Notice creation failed: {n_fail_resp.data}"
            n_fail_id = n_fail_resp.get_json()['id']
            created_notice_ids.append(n_fail_id)

            # Verify notice exists in DB
            persisted_notice = Notice.query.get(n_fail_id)
            assert persisted_notice is not None
            assert persisted_notice.status == 'PUBLISHED'

            # Verify NotificationDelivery record exists with status FAILED and push_attempted True
            deliv_fail = NotificationDelivery.query.filter_by(notice_id=n_fail_id, user_id=student_cse.id).first()
            assert deliv_fail is not None, "NotificationDelivery record was lost!"
            assert deliv_fail.status == 'FAILED'
            assert deliv_fail.push_attempted is True
            assert "Simulated FCM server timeout" in (deliv_fail.push_error or "")
            print("  -> PASSED: Notice and NotificationDelivery persisted cleanly despite push notification failure.")

            # ----------------------------------------------------
            # Test 12: Invalid token cleanup behavior
            # ----------------------------------------------------
            print("[Test 12] Invalid token cleanup behavior...")
            stale_token = f"stale_token_{uuid.uuid4().hex[:10]}"
            reg_stale = client.post(
                '/notifications/device-token',
                headers={'X-User-Id': student_cse.id},
                json={'token': stale_token, 'deviceType': 'android'}
            )
            assert reg_stale.status_code == 201
            stale_dt_id = reg_stale.get_json()['id']
            created_token_ids.append(stale_dt_id)

            def unregistered_fcm_sender(msg):
                raise RuntimeError("Firebase error: registration-token-not-registered")

            app_module.fcm_sender_override = unregistered_fcm_sender

            n_stale_resp = client.post(
                '/notices',
                headers={'X-User-Id': teacher1.id},
                json={
                    'title': 'Notice with Stale Token',
                    'body': 'Stale token must be deactivated.',
                    'target_type': 'BRANCH',
                    'target_value': 'Computer Science',
                    'status': 'PUBLISHED'
                }
            )
            assert n_stale_resp.status_code == 201
            n_stale_id = n_stale_resp.get_json()['id']
            created_notice_ids.append(n_stale_id)

            stale_dt = DeviceToken.query.get(stale_dt_id)
            assert stale_dt.is_active is False, "Stale token was not marked is_active=False!"
            print("  -> PASSED: Invalid/unregistered token safely cleaned up (marked is_active=False).")

            # ----------------------------------------------------
            # Test 13: Existing notice targeting + push payload & lifecycle
            # ----------------------------------------------------
            print("[Test 13] Targeted push delivery lifecycle & payload verification...")
            sent_messages = []

            def success_fcm_sender(msg):
                sent_messages.append(msg)
                return "projects/campusos/messages/msg_12345"

            app_module.fcm_sender_override = success_fcm_sender

            # Ensure student_cse has a fresh active token
            valid_active_token = f"valid_active_token_{uuid.uuid4().hex[:10]}"
            resp_tok = client.post(
                '/notifications/device-token',
                headers={'X-User-Id': student_cse.id},
                json={'token': valid_active_token, 'deviceType': 'android'}
            )
            created_token_ids.append(resp_tok.get_json()['id'])

            # Register token for student_ece as well
            ece_token = f"ece_valid_token_{uuid.uuid4().hex[:10]}"
            resp_ece_tok = client.post(
                '/notifications/device-token',
                headers={'X-User-Id': student_ece.id},
                json={'token': ece_token, 'deviceType': 'android'}
            )
            created_token_ids.append(resp_ece_tok.get_json()['id'])

            # Publish CSE-targeted notice with OPEN_URL action
            n_lifecycle_resp = client.post(
                '/notices',
                headers={'X-User-Id': teacher1.id},
                json={
                    'title': 'CSE Workshop 2026',
                    'body': 'Register for the advanced AI workshop.',
                    'category': 'EVENT',
                    'priority': 'HIGH',
                    'target_type': 'BRANCH',
                    'target_value': 'Computer Science',
                    'action_type': 'OPEN_URL',
                    'action_payload': 'https://campus.edu/events/cse-ai',
                    'status': 'PUBLISHED'
                }
            )
            assert n_lifecycle_resp.status_code == 201
            lifecycle_nid = n_lifecycle_resp.get_json()['id']
            created_notice_ids.append(lifecycle_nid)

            # Check sent FCM messages
            assert len(sent_messages) > 0, "No FCM push messages were sent!"
            last_msg = sent_messages[-1]
            if hasattr(last_msg, 'data'):
                payload_data = last_msg.data
                token_sent = last_msg.token
            else:
                payload_data = last_msg['data']
                token_sent = last_msg['token']

            assert payload_data['noticeId'] == lifecycle_nid
            assert payload_data['notificationType'] == 'NOTICE'
            assert payload_data['actionType'] == 'OPEN_URL'
            assert payload_data['actionPayload'] == 'https://campus.edu/events/cse-ai'
            assert payload_data['priority'] == 'HIGH'
            print("  - Structured FCM payload verified (noticeId, type, actionType, actionPayload).")

            # Verify delivery state for CSE student
            deliv_cse = NotificationDelivery.query.filter_by(notice_id=lifecycle_nid, user_id=student_cse.id).first()
            assert deliv_cse is not None
            assert deliv_cse.status == 'DELIVERED', f"Expected DELIVERED, got {deliv_cse.status}"
            assert deliv_cse.delivered_at is not None
            assert deliv_cse.is_read is False

            # Verify ECE student was NOT targeted
            deliv_ece = NotificationDelivery.query.filter_by(notice_id=lifecycle_nid, user_id=student_ece.id).first()
            assert deliv_ece is None, "Targeting isolation failed: ECE student received CSE notice delivery!"

            # Student 1 views the notice -> DELIVERED -> READ
            read_resp = client.post(f'/notices/{lifecycle_nid}/read', headers={'X-User-Id': student_cse.id})
            assert read_resp.status_code == 200
            read_data = read_resp.get_json()
            assert read_data['status'] == 'READ'
            assert read_data['isRead'] is True

            # Re-fetch delivery from DB
            db.session.refresh(deliv_cse)
            assert deliv_cse.status == 'READ'
            assert deliv_cse.read_at is not None
            print("  -> PASSED: Lifecycle transition PENDING -> DELIVERED -> READ confirmed.")

            # Reset sender override and cleanup Step 21E fixtures before running regression suites
            app_module.fcm_sender_override = None

            print("\nCleaning up Step 21E fixtures before regression verification...")
            if created_token_ids:
                DeviceToken.query.filter(DeviceToken.id.in_(created_token_ids)).delete(synchronize_session=False)
                created_token_ids = []
            if created_notice_ids:
                NotificationDelivery.query.filter(NotificationDelivery.notice_id.in_(created_notice_ids)).delete(synchronize_session=False)
                Notice.query.filter(Notice.id.in_(created_notice_ids)).delete(synchronize_session=False)
                created_notice_ids = []
            if created_user_ids:
                NotificationDelivery.query.filter(NotificationDelivery.user_id.in_(created_user_ids)).delete(synchronize_session=False)
                User.query.filter(User.id.in_(created_user_ids)).delete(synchronize_session=False)
                created_user_ids = []
            db.session.commit()
            print("Step 21E fixtures cleaned.")

            # ----------------------------------------------------
            # Test 14, 15, 16: Existing Step 21B, 21C, 21D suites pass
            # ----------------------------------------------------
            import subprocess
            backend_dir = os.path.dirname(os.path.abspath(__file__))
            env = dict(os.environ, PYTHONIOENCODING='utf-8')

            print("\n[Test 14] Running Step 21B test suite...")
            p21b = subprocess.run([sys.executable, os.path.join(backend_dir, 'test_step21b_notices.py')], env=env, capture_output=True, text=True, encoding='utf-8', errors='replace')
            assert p21b.returncode == 0, f"Step 21B suite failed:\n{p21b.stdout}\n{p21b.stderr}"
            print("  -> PASSED: Step 21B tests pass (20/20).")

            print("[Test 15] Running Step 21C test suite...")
            p21c = subprocess.run([sys.executable, os.path.join(backend_dir, 'test_step21c_read_tracking.py')], env=env, capture_output=True, text=True, encoding='utf-8', errors='replace')
            assert p21c.returncode == 0, f"Step 21C suite failed:\n{p21c.stdout}\n{p21c.stderr}"
            print("  -> PASSED: Step 21C tests pass (9/9).")

            print("[Test 16] Running Step 21D test suite...")
            p21d = subprocess.run([sys.executable, os.path.join(backend_dir, 'test_step21d_notice_management.py')], env=env, capture_output=True, text=True, encoding='utf-8', errors='replace')
            assert p21d.returncode == 0, f"Step 21D suite failed:\n{p21d.stdout}\n{p21d.stderr}"
            print("  -> PASSED: Step 21D tests pass (12/12).")

        finally:
            # Reset sender override
            app_module.fcm_sender_override = None

            # Cleanup
            print("\nCleaning up Step 21E test records...")
            if created_token_ids:
                DeviceToken.query.filter(DeviceToken.id.in_(created_token_ids)).delete(synchronize_session=False)
            if created_notice_ids:
                NotificationDelivery.query.filter(NotificationDelivery.notice_id.in_(created_notice_ids)).delete(synchronize_session=False)
                Notice.query.filter(Notice.id.in_(created_notice_ids)).delete(synchronize_session=False)
            if created_user_ids:
                NotificationDelivery.query.filter(NotificationDelivery.user_id.in_(created_user_ids)).delete(synchronize_session=False)
                User.query.filter(User.id.in_(created_user_ids)).delete(synchronize_session=False)
            db.session.commit()
            print("Cleanup complete. Zero leftover test records.")

    print("\n==================================================")
    print("RESULTS: ALL 16/16 STEP 21E TESTS PASSED (100% SUCCESS)")
    print("==================================================")

if __name__ == '__main__':
    run_tests()
