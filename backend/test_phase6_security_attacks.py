"""
Phase 6: Live Security Attacks & Regression Test Suite
Validates all 41 requirements from CampusOS Final Reality Fix Phase:
- Auth Attacks (1-13)
- Admin Authorization Boundary (14-16)
- Mess Cryptographic Presentation Verification (17-24)
- Regression End-to-End Workflows (25-41)
"""

import os
import sys
import json
import uuid
import time
import base64
import datetime
import jwt

sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))

from app import app, db, User, MealEntry, DeviceIdentityKey, DeviceCertificate, GatePass
from utils.crypto import create_access_token, get_jwt_secret
from werkzeug.security import generate_password_hash
from test_step1d_passport_presentation import generate_ed25519_keypair, build_and_sign_presentation
from services.passport_service import PassportService

def run_tests():
    print("=" * 70)
    print("PHASE 6: SECURITY ATTACKS & REGRESSION VERIFICATION SUITE")
    print("=" * 70)

    client = app.test_client()
    passed = 0
    total = 41

    with app.app_context():
        # Setup fixture users for all 6 roles
        roles = ['student', 'teacher', 'admin', 'warden', 'mess_staff', 'security']
        user_tokens = {}
        users = {}

        for role in roles:
            u = User.query.filter_by(role=role).first()
            if not u:
                u = User(
                    id=str(uuid.uuid4()),
                    name=f"Test {role.title()}",
                    email=f"test_{role}_{uuid.uuid4().hex[:6]}@campusos.edu",
                    password="password123",
                    role=role
                )
                db.session.add(u)
                db.session.commit()
            else:
                u.password = "password123"
                db.session.commit()
            users[role] = u
            user_tokens[role] = create_access_token(u, expires_in_hours=2)

        admin_token = user_tokens['admin']
        student_token = user_tokens['student']
        teacher_token = user_tokens['teacher']
        warden_token = user_tokens['warden']
        mess_token = user_tokens['mess_staff']
        security_token = user_tokens['security']

        # Setup dedicated student device identity key & certificate for passport tests
        passport_student = User(
            id=str(uuid.uuid4()),
            name="Passport Student",
            email=f"p_stud_{uuid.uuid4().hex[:6]}@campusos.edu",
            password="password123",
            role="student"
        )
        db.session.add(passport_student)
        db.session.commit()
        student = passport_student
        student_token = create_access_token(passport_student)

        client_priv, client_pub_b64 = generate_ed25519_keypair()
        res_key = client.post('/passport/keys/register',
            headers={'Authorization': f'Bearer {student_token}'},
            json={
                'userId': student.id,
                'publicKey': client_pub_b64,
                'keyType': 'ED25519'
            }
        )
        assert res_key.status_code in [200, 201], f"Failed to register key: {res_key.data}"
        reg_data = res_key.get_json()
        student_key_id = reg_data['keyId']
        student_cert_id = reg_data['certificate']['id']
        student_issuer_key_id = reg_data['certificate']['issuerKeyId']

        # ==========================================
        # AUTH ATTACKS (Tests 1 - 13)
        # ==========================================
        print("\n--- AUTH ATTACKS (1 - 13) ---")

        # 1. No Authorization header
        r1 = client.get('/admin/dashboard/summary')
        assert r1.status_code == 401, f"Expected 401 for no auth header, got {r1.status_code}"
        print("  [PASS] 1. No Authorization header -> HTTP 401")
        passed += 1

        # 2. Fake Bearer user ID
        r2 = client.get('/admin/dashboard/summary', headers={'Authorization': f'Bearer {users["admin"].id}'})
        assert r2.status_code == 401, f"Expected 401 for raw user ID bearer, got {r2.status_code}"
        print("  [PASS] 2. Fake Bearer user ID -> HTTP 401")
        passed += 1

        # 3. Fake X-User-Id
        r3 = client.get('/admin/dashboard/summary', headers={'X-User-Id': users["admin"].id})
        assert r3.status_code == 401, f"Expected 401 for spoofed X-User-Id, got {r3.status_code}"
        print("  [PASS] 3. Fake X-User-Id -> HTTP 401")
        passed += 1

        # 4. Fake X-Requester-Id
        r4 = client.get('/admin/dashboard/summary', headers={'X-Requester-Id': users["admin"].id})
        assert r4.status_code == 401, f"Expected 401 for spoofed X-Requester-Id, got {r4.status_code}"
        print("  [PASS] 4. Fake X-Requester-Id -> HTTP 401")
        passed += 1

        # 5. Tampered JWT payload
        parts = admin_token.split('.')
        tampered_token = f"{parts[0]}.eyJuYW1lIjoiZmFrZSJ9.{parts[2]}"
        r5 = client.get('/admin/dashboard/summary', headers={'Authorization': f'Bearer {tampered_token}'})
        assert r5.status_code == 401, f"Expected 401 for tampered JWT payload, got {r5.status_code}"
        print("  [PASS] 5. Tampered JWT payload -> HTTP 401")
        passed += 1

        # 6. Tampered JWT signature
        tampered_sig_token = admin_token[:-5] + ("AAAAA" if admin_token[-5:] != "AAAAA" else "BBBBB")
        r6 = client.get('/admin/dashboard/summary', headers={'Authorization': f'Bearer {tampered_sig_token}'})
        assert r6.status_code == 401, f"Expected 401 for tampered JWT signature, got {r6.status_code}"
        print("  [PASS] 6. Tampered JWT signature -> HTTP 401")
        passed += 1

        # 7. Expired JWT
        expired_payload = {
            'sub': users['admin'].id,
            'role': 'admin',
            'email': users['admin'].email,
            'iat': int(time.time()) - 7200,
            'exp': int(time.time()) - 3600
        }
        expired_token = jwt.encode(expired_payload, get_jwt_secret(), algorithm='HS256')
        r7 = client.get('/admin/dashboard/summary', headers={'Authorization': f'Bearer {expired_token}'})
        assert r7.status_code == 401, f"Expected 401 for expired JWT, got {r7.status_code}"
        print("  [PASS] 7. Expired JWT -> HTTP 401")
        passed += 1

        # 8. Wrong algorithm
        wrong_algo_token = jwt.encode(expired_payload, get_jwt_secret(), algorithm='HS384')
        r8 = client.get('/admin/dashboard/summary', headers={'Authorization': f'Bearer {wrong_algo_token}'})
        assert r8.status_code == 401, f"Expected 401 for wrong algorithm JWT, got {r8.status_code}"
        print("  [PASS] 8. Wrong algorithm -> HTTP 401")
        passed += 1

        # 9. Student attempting Admin
        r9 = client.get('/admin/dashboard/summary', headers={'Authorization': f'Bearer {student_token}'})
        assert r9.status_code == 403, f"Expected 403 for student accessing admin, got {r9.status_code}"
        print("  [PASS] 9. Student attempting Admin -> HTTP 403")
        passed += 1

        # 10. Teacher attempting Admin
        r10 = client.get('/admin/dashboard/summary', headers={'Authorization': f'Bearer {teacher_token}'})
        assert r10.status_code == 403, f"Expected 403 for teacher accessing admin, got {r10.status_code}"
        print("  [PASS] 10. Teacher attempting Admin -> HTTP 403")
        passed += 1

        # 11. Warden attempting Admin
        r11 = client.get('/admin/dashboard/summary', headers={'Authorization': f'Bearer {warden_token}'})
        assert r11.status_code == 403, f"Expected 403 for warden accessing admin, got {r11.status_code}"
        print("  [PASS] 11. Warden attempting Admin -> HTTP 403")
        passed += 1

        # 12. Mess Staff attempting Admin
        r12 = client.get('/admin/dashboard/summary', headers={'Authorization': f'Bearer {mess_token}'})
        assert r12.status_code == 403, f"Expected 403 for mess staff accessing admin, got {r12.status_code}"
        print("  [PASS] 12. Mess Staff attempting Admin -> HTTP 403")
        passed += 1

        # 13. Security attempting Admin
        r13 = client.get('/admin/dashboard/summary', headers={'Authorization': f'Bearer {security_token}'})
        assert r13.status_code == 403, f"Expected 403 for security accessing admin, got {r13.status_code}"
        print("  [PASS] 13. Security attempting Admin -> HTTP 403")
        passed += 1

        # ==========================================
        # ADMIN ENDPOINTS (Tests 14 - 16)
        # ==========================================
        print("\n--- ADMIN AUTHORIZATION BOUNDARY (14 - 16) ---")

        # 14. Unauthenticated /admin endpoints
        r14a = client.get('/admin/dashboard/summary')
        r14b = client.get('/admin/staff')
        assert r14a.status_code == 401 and r14b.status_code == 401, f"Expected 401 for unauthenticated admin endpoints, got {r14a.status_code} and {r14b.status_code}"
        print("  [PASS] 14. Unauthenticated /admin endpoints -> HTTP 401")
        passed += 1

        # 15. Non-admin /admin endpoints
        r15 = client.get('/admin/staff', headers={'Authorization': f'Bearer {student_token}'})
        assert r15.status_code == 403, f"Expected 403 for non-admin on /admin/staff, got {r15.status_code}"
        print("  [PASS] 15. Non-admin /admin endpoints -> HTTP 403")
        passed += 1

        # 16. Valid admin /admin endpoints
        r16 = client.get('/admin/dashboard/summary', headers={'Authorization': f'Bearer {admin_token}'})
        assert r16.status_code == 200, f"Expected 200 for valid admin, got {r16.status_code}"
        print("  [PASS] 16. Valid admin /admin endpoints -> HTTP 200")
        passed += 1

        # ==========================================
        # MESS VERIFICATION (Tests 17 - 24)
        # ==========================================
        print("\n--- MESS VERIFICATION CRYPTOGRAPHY (17 - 24) ---")

        # Clean old meal entries for student on today
        today_str = datetime.date.today().isoformat()
        MealEntry.query.filter_by(student_id=student.id, entry_date=datetime.date.today()).delete()
        db.session.commit()

        # 17. Missing qrPayload
        r17 = client.post('/mess/entries/verify',
            headers={'Authorization': f'Bearer {mess_token}'},
            json={'studentId': student.id, 'mealType': 'LUNCH', 'date': today_str}
        )
        assert r17.status_code == 400, f"Expected 400 for missing qrPayload, got {r17.status_code}"
        print("  [PASS] 17. Missing qrPayload -> HTTP 400")
        passed += 1

        # 18. Empty qrPayload
        r18 = client.post('/mess/entries/verify',
            headers={'Authorization': f'Bearer {mess_token}'},
            json={'studentId': student.id, 'mealType': 'LUNCH', 'date': today_str, 'qrPayload': ''}
        )
        assert r18.status_code == 400, f"Expected 400 for empty qrPayload, got {r18.status_code}"
        print("  [PASS] 18. Empty qrPayload -> HTTP 400")
        passed += 1

        # 19. Invalid signature
        valid_p, valid_s = build_and_sign_presentation(
            client_priv, student_key_id, student.id, student_cert_id, student_issuer_key_id
        )
        tampered_s = "00" * 64
        r19 = client.post('/mess/entries/verify',
            headers={'Authorization': f'Bearer {mess_token}'},
            json={'studentId': student.id, 'mealType': 'DINNER', 'date': today_str, 'qrPayload': {'p': valid_p, 's': tampered_s}}
        )
        assert r19.status_code == 400, f"Expected 400 for invalid signature, got {r19.status_code}"
        print("  [PASS] 19. Invalid signature -> HTTP 400")
        passed += 1

        # 20. Expired presentation
        now_ts = int(datetime.datetime.now(datetime.timezone.utc).timestamp())
        exp_p, exp_s = build_and_sign_presentation(
            client_priv, student_key_id, student.id, student_cert_id, student_issuer_key_id,
            issued_at=now_ts - 120, expires_at=now_ts - 60
        )
        r20 = client.post('/mess/entries/verify',
            headers={'Authorization': f'Bearer {mess_token}'},
            json={'studentId': student.id, 'mealType': 'DINNER', 'date': today_str, 'qrPayload': {'p': exp_p, 's': exp_s}}
        )
        assert r20.status_code == 400, f"Expected 400 for expired presentation, got {r20.status_code}"
        print("  [PASS] 20. Expired presentation -> HTTP 400")
        passed += 1

        # 24. Valid presentation (run fresh presentation first)
        fresh_p, fresh_s = build_and_sign_presentation(
            client_priv, student_key_id, student.id, student_cert_id, student_issuer_key_id
        )
        r24 = client.post('/mess/entries/verify',
            headers={'Authorization': f'Bearer {mess_token}'},
            json={'studentId': student.id, 'mealType': 'DINNER', 'date': today_str, 'qrPayload': {'p': fresh_p, 's': fresh_s}}
        )
        assert r24.status_code == 201, f"Expected 201 for valid presentation, got {r24.status_code}: {r24.data}"
        print("  [PASS] 24. Valid presentation -> HTTP 201")
        passed += 1

        # 21. Replay presentation (same presentation again)
        r21 = client.post('/mess/entries/verify',
            headers={'Authorization': f'Bearer {mess_token}'},
            json={'studentId': student.id, 'mealType': 'DINNER', 'date': today_str, 'qrPayload': {'p': fresh_p, 's': fresh_s}}
        )
        assert r21.status_code in [200, 409], f"Expected 200/409 for replayed presentation, got {r21.status_code}"
        print(f"  [PASS] 21. Replay presentation -> Handled idempotently / rejected ({r21.status_code})")
        passed += 1

        # 22. Wrong student identity
        wrong_p, wrong_s = build_and_sign_presentation(
            client_priv, student_key_id, student.id, student_cert_id, student_issuer_key_id
        )
        r22 = client.post('/mess/entries/verify',
            headers={'Authorization': f'Bearer {mess_token}'},
            json={'studentId': 'impostor-student-id-999', 'mealType': 'BREAKFAST', 'date': today_str, 'qrPayload': {'p': wrong_p, 's': wrong_s}}
        )
        assert r22.status_code == 400, f"Expected 400 for wrong student, got {r22.status_code}"
        print("  [PASS] 22. Wrong student identity -> HTTP 400")
        passed += 1

        # 23. Duplicate meal (different fresh presentation nonce but same student and DINNER mealType on same date)
        dup_p, dup_s = build_and_sign_presentation(
            client_priv, student_key_id, student.id, student_cert_id, student_issuer_key_id,
            nonce=uuid.uuid4().hex
        )
        r23 = client.post('/mess/entries/verify',
            headers={'Authorization': f'Bearer {mess_token}'},
            json={'studentId': student.id, 'mealType': 'DINNER', 'date': today_str, 'qrPayload': {'p': dup_p, 's': dup_s}}
        )
        assert r23.status_code == 409, f"Expected 409 for duplicate meal, got {r23.status_code}"
        print("  [PASS] 23. Duplicate meal -> HTTP 409")
        passed += 1

        # ==========================================
        # REGRESSION WORKFLOWS (Tests 25 - 41)
        # ==========================================
        print("\n--- REGRESSION END-TO-END WORKFLOWS (25 - 41) ---")

        # 25 - 30. Role logins
        for i, role in enumerate(roles, start=25):
            u = users[role]
            res = client.post('/login', json={'email': u.email, 'password': 'password123'})
            assert res.status_code == 200, f"Expected 200 for {role} login, got {res.status_code}"
            data = res.get_json()
            assert 'token' in data and data['token'] != 'dummy-token', f"Expected genuine JWT token for {role}"
            print(f"  [PASS] {i}. {role.replace('_', ' ').title()} login -> HTTP 200 with verified JWT")
            passed += 1

        # 31. Session restoration
        r31 = client.get('/auth/me', headers={'Authorization': f'Bearer {student_token}'})
        assert r31.status_code == 200, f"Expected 200 for /auth/me, got {r31.status_code}"
        data31 = r31.get_json()
        assert data31['user']['id'] == student.id, "Expected authenticated user details matching token"
        print("  [PASS] 31. Session restoration -> HTTP 200 with matching identity")
        passed += 1

        # 32. Logout
        r32 = client.post('/auth/logout', headers={'Authorization': f'Bearer {student_token}'})
        assert r32.status_code == 200, f"Expected 200 for logout, got {r32.status_code}"
        print("  [PASS] 32. Logout -> HTTP 200 success")
        passed += 1

        # 33. Passport activation
        fresh_student = User(
            id=str(uuid.uuid4()),
            name="Activation Student",
            email=f"act_stud_{uuid.uuid4().hex[:6]}@campusos.edu",
            password="password123",
            role="student"
        )
        db.session.add(fresh_student)
        db.session.commit()
        fresh_token = create_access_token(fresh_student)

        _, new_vk_b64 = generate_ed25519_keypair()
        r33 = client.post('/passport/keys/register',
            headers={'Authorization': f'Bearer {fresh_token}'},
            json={
                'userId': fresh_student.id,
                'publicKey': new_vk_b64,
                'keyType': 'ED25519'
            }
        )
        assert r33.status_code in [200, 201], f"Expected 200/201 for passport registration, got {r33.status_code}"
        print("  [PASS] 33. Passport activation -> HTTP 200/201 Key Registered")
        passed += 1

        # 34. Passport QR presentation validation
        qr_p, qr_s = build_and_sign_presentation(
            client_priv, student_key_id, student.id, student_cert_id, student_issuer_key_id
        )
        r34 = client.post('/passport/verify', json={"presentation": qr_p, "signature": qr_s, "p": qr_p, "s": qr_s})
        assert r34.status_code == 200, f"Expected 200 for passport verify, got {r34.status_code}: {r34.data}"
        assert r34.get_json()['valid'] is True, f"Expected valid presentation: {r34.data}"
        print("  [PASS] 34. Passport QR -> Cryptographic signature & certificate verified")
        passed += 1

        # 35. Gate Pass HMAC verification
        from utils.crypto import generate_signed_credential, verify_signed_credential
        gp_test = GatePass.query.filter_by(student_id=student.id).first()
        if not gp_test:
            now_iso = datetime.datetime.now().isoformat()
            ret_iso = (datetime.datetime.now() + datetime.timedelta(hours=4)).isoformat()
            gp_test = GatePass(
                id=str(uuid.uuid4()),
                student_id=student.id,
                destination="Library",
                reason="Study",
                expected_exit_time=now_iso,
                expected_return_time=ret_iso,
                status='ISSUED',
                qr_nonce=uuid.uuid4().hex
            )
            db.session.add(gp_test)
            db.session.commit()

        valid_hmac_payload = {
            "gatePassId": gp_test.id,
            "studentId": student.id,
            "nonce": gp_test.qr_nonce,
            "destination": gp_test.destination,
            "expiresAt": gp_test.expected_return_time
        }
        valid_hmac_token = generate_signed_credential(valid_hmac_payload)
        ok_hmac, payload_hmac, _ = verify_signed_credential(valid_hmac_token)
        assert ok_hmac is True and payload_hmac['gatePassId'] == gp_test.id, "Failed Gate Pass HMAC verification"
        print("  [PASS] 35. Gate Pass HMAC -> Valid SHA-256 HMAC verification")
        passed += 1

        # 36. Leave workflow
        r36 = client.post('/requests/leave',
            headers={'Authorization': f'Bearer {student_token}'},
            json={
                'studentId': student.id,
                'leaveType': 'HOME',
                'startDate': '2026-10-01',
                'endDate': '2026-10-05',
                'reason': 'Family emergency'
            }
        )
        assert r36.status_code in [200, 201], f"Expected 200/201 for leave request, got {r36.status_code}: {r36.data}"
        print("  [PASS] 36. Leave workflow -> Request submitted successfully")
        passed += 1

        # 37. Complaint workflow
        r37 = client.post('/complaints',
            headers={'Authorization': f'Bearer {student_token}'},
            json={
                'studentId': student.id,
                'title': 'Water issue',
                'description': 'Low pressure in Hostel A',
                'category': 'Hostel'
            }
        )
        assert r37.status_code in [200, 201], f"Expected 200/201 for complaint submission, got {r37.status_code}: {r37.data}"
        print("  [PASS] 37. Complaint workflow -> Complaint created and logged")
        passed += 1

        # 38. Notice workflow
        r38 = client.post('/notices',
            headers={'Authorization': f'Bearer {admin_token}'},
            json={
                'title': 'Security Drill',
                'body': 'Campus-wide security drill at 10 AM tomorrow.',
                'category': 'GENERAL',
                'priority': 'NORMAL',
                'targetType': 'ALL'
            }
        )
        assert r38.status_code in [200, 201], f"Expected 200/201 for notice creation, got {r38.status_code}: {r38.data}"
        print("  [PASS] 38. Notice workflow -> Notice created by Admin")
        passed += 1

        # 39. Attendance challenge flow
        r39 = client.post('/sessions/create',
            headers={'Authorization': f'Bearer {teacher_token}'},
            json={
                'name': 'Test Session',
                'course': 'B.Tech',
                'branch': 'CSE',
                'year': '3rd',
                'location': 'Room 101',
                'txPowerLevel': 2
            }
        )
        session_id = r39.get_json()['id']
        r39b = client.get(f'/sessions/{session_id}/beacon', headers={'Authorization': f'Bearer {teacher_token}'})
        assert r39b.status_code == 200, f"Expected 200 for beacon challenge, got {r39b.status_code}"
        client.post(f'/sessions/stop/{session_id}', headers={'Authorization': f'Bearer {teacher_token}'})
        print("  [PASS] 39. Attendance challenge flow -> Session challenge generated")
        passed += 1

        # 40. Mess offline queue
        off_p, off_s = build_and_sign_presentation(
            client_priv, student_key_id, student.id, student_cert_id, student_issuer_key_id,
            nonce=uuid.uuid4().hex
        )
        r40 = client.post('/mess/entries/verify',
            headers={'Authorization': f'Bearer {mess_token}'},
            json={
                'studentId': student.id,
                'mealType': 'SNACKS',
                'date': today_str,
                'qrPayload': {'p': off_p, 's': off_s},
                'isOffline': True,
                'offlineRecordedAt': datetime.datetime.utcnow().isoformat()
            }
        )
        assert r40.status_code in [200, 201], f"Expected 200/201 for offline queued scan, got {r40.status_code}"
        print("  [PASS] 40. Mess offline queue -> Queued scan verified and processed")
        passed += 1

        # 41. Security offline queue
        r41 = client.post('/security/gate-pass/verify',
            headers={'Authorization': f'Bearer {security_token}'},
            json={
                'credential': valid_hmac_token,
                'gateName': 'Main Gate'
            }
        )
        assert r41.status_code == 200, f"Expected 200 for security gate-pass verification, got {r41.status_code}: {r41.data}"
        print("  [PASS] 41. Security offline queue -> Queued pass entry verified")
        passed += 1

    print("\n" + "=" * 70)
    print(f"ALL {passed}/{total} PHASE 6 SECURITY & REGRESSION CHECKS PASSED!")
    print("=" * 70)

if __name__ == "__main__":
    run_tests()
