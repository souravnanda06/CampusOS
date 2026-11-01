"""
CampusOS Mess Staff Experience, Batch Verification, QR Fallback, and Idempotency Backend Test Suite.
"""

import os
import sys
import json
import uuid
import datetime

# Ensure backend root is on Python path
sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))

from app import (
    app, db, User, MealEntry, MessMenu, is_mess_manager,
    DeviceIdentityKey, DeviceCertificate
)
from test_step1d_passport_presentation import generate_ed25519_keypair, build_and_sign_presentation



def run_tests():
    print("=" * 60)
    print("CAMPUSOS MESS STAFF VERIFICATION & IDEMPOTENCY TEST SUITE")
    print("=" * 60)

    client = app.test_client()

    with app.app_context():
        # Ensure database tables exist
        db.create_all()

        # 1. Setup test users
        mess_staff = User.query.filter_by(role='mess_staff').first()
        if not mess_staff:
            mess_staff = User(
                id=str(uuid.uuid4()),
                name="Chef Gordon",
                email=f"chef_{uuid.uuid4().hex[:6]}@campusos.edu",
                password="password123",
                role="mess_staff"
            )
            db.session.add(mess_staff)
            db.session.commit()

        test_student = User.query.filter_by(email="mess_test_student@campusos.edu").first()
        if not test_student:
            test_student = User(
                id=str(uuid.uuid4()),
                name="Alice Student",
                email="mess_test_student@campusos.edu",
                password="password123",
                role="student",
                registration_number="REG2026MESS"
            )
            db.session.add(test_student)
            db.session.commit()

        # Clean any prior keys/certs/entries for this test student
        MealEntry.query.filter_by(student_id=test_student.id).delete()
        DeviceCertificate.query.filter_by(subject_user_id=test_student.id).delete()
        DeviceIdentityKey.query.filter_by(user_id=test_student.id).delete()
        db.session.commit()

        test_teacher = User.query.filter_by(role='teacher').first()
        if not test_teacher:
            test_teacher = User(
                id=str(uuid.uuid4()),
                name="Prof Smith",
                email=f"prof_{uuid.uuid4().hex[:6]}@campusos.edu",
                password="password123",
                role="teacher"
            )
            db.session.add(test_teacher)
            db.session.commit()

        test_date = "2026-10-15"
        test_meal_type = "LUNCH"

        try:
            # -------------------------------------------------------------
            # TEST 1: Role check & Public Registration Protection
            # -------------------------------------------------------------
            print("\n[TEST 1] Testing institutional role check and public registration block...")
            assert is_mess_manager(mess_staff) is True, "mess_staff should be recognized as mess manager"
            assert is_mess_manager(test_student) is False, "student must NOT be mess manager"
            assert is_mess_manager(test_teacher) is False, "teacher must NOT be mess manager"

            # Attempt public registration for mess_staff -> must be blocked with 403
            res_reg = client.post('/register', json={
                'name': 'Hacker Staff',
                'email': f'fake_{uuid.uuid4().hex[:6]}@campusos.edu',
                'password': 'password123',
                'role': 'mess_staff'
            })
            assert res_reg.status_code == 403, f"Expected 403 on public mess_staff signup, got {res_reg.status_code}"
            print("[PASS] [TEST 1] Role verification and public registration protection verified.")

            # -------------------------------------------------------------
            # PASSPORT SETUP: Enroll student key & certificate
            # -------------------------------------------------------------
            client_priv, client_pub_b64 = generate_ed25519_keypair()
            res_key = client.post('/passport/keys/register', headers={'X-User-Id': test_student.id}, json={
                'userId': test_student.id,
                'publicKey': client_pub_b64,
                'keyType': 'ED25519'
            })
            assert res_key.status_code == 201, f"Failed to register key: {res_key.data}"
            reg_data = res_key.get_json()
            student_key_id = reg_data['keyId']
            student_cert_id = reg_data['certificate']['id']
            student_issuer_key_id = reg_data['certificate']['issuerKeyId']

            # -------------------------------------------------------------
            # TEST 2A: Missing qrPayload Rejected (Security Fix P0-03)
            # -------------------------------------------------------------
            print("\n[TEST 2A] Testing rejection when qrPayload is missing (P0-03 fix)...")
            res_missing = client.post(
                '/mess/entries/verify',
                headers={'X-User-Id': mess_staff.id},
                json={
                    'studentId': test_student.id,
                    'mealType': test_meal_type,
                    'date': test_date
                }
            )
            assert res_missing.status_code == 400, f"Expected 400, got {res_missing.status_code}"
            assert "Cryptographic presentation required" in res_missing.get_json()['message']
            print("[PASS] [TEST 2A] Missing qrPayload strictly rejected with 400.")

            # -------------------------------------------------------------
            # TEST 2B: Empty / Malformed qrPayload Rejected
            # -------------------------------------------------------------
            print("\n[TEST 2B] Testing rejection of empty or malformed qrPayload...")
            res_empty = client.post(
                '/mess/entries/verify',
                headers={'X-User-Id': mess_staff.id},
                json={
                    'studentId': test_student.id,
                    'mealType': test_meal_type,
                    'date': test_date,
                    'qrPayload': ''
                }
            )
            assert res_empty.status_code == 400
            res_bad_json = client.post(
                '/mess/entries/verify',
                headers={'X-User-Id': mess_staff.id},
                json={
                    'studentId': test_student.id,
                    'mealType': test_meal_type,
                    'date': test_date,
                    'qrPayload': '{{not-valid-json'
                }
            )
            assert res_bad_json.status_code == 400
            print("[PASS] [TEST 2B] Empty and malformed qrPayload rejected with 400.")

            # -------------------------------------------------------------
            # TEST 2C: Expired Presentation Rejected
            # -------------------------------------------------------------
            print("\n[TEST 2C] Testing rejection of expired passport presentation...")
            now_ts = int(datetime.datetime.now(datetime.timezone.utc).timestamp())
            exp_p, exp_s = build_and_sign_presentation(
                client_priv, student_key_id, test_student.id, student_cert_id, student_issuer_key_id,
                issued_at=now_ts - 120, expires_at=now_ts - 60
            )
            res_exp = client.post(
                '/mess/entries/verify',
                headers={'X-User-Id': mess_staff.id},
                json={
                    'studentId': test_student.id,
                    'mealType': test_meal_type,
                    'date': test_date,
                    'qrPayload': {"p": exp_p, "s": exp_s}
                }
            )
            assert res_exp.status_code == 400
            assert "verification failed" in res_exp.get_json()['message'].lower()
            print("[PASS] [TEST 2C] Expired presentation strictly rejected with 400.")

            # -------------------------------------------------------------
            # TEST 2D: Student ID Mismatch Rejected
            # -------------------------------------------------------------
            print("\n[TEST 2D] Testing rejection of student ID mismatch...")
            valid_p0, valid_s0 = build_and_sign_presentation(
                client_priv, student_key_id, test_student.id, student_cert_id, student_issuer_key_id
            )
            res_mismatch = client.post(
                '/mess/entries/verify',
                headers={'X-User-Id': mess_staff.id},
                json={
                    'studentId': 'impostor-student-id-999',
                    'mealType': test_meal_type,
                    'date': test_date,
                    'qrPayload': {"p": valid_p0, "s": valid_s0}
                }
            )
            assert res_mismatch.status_code == 400
            print("[PASS] [TEST 2D] Student ID mismatch strictly rejected with 400.")

            # -------------------------------------------------------------
            # TEST 2E: Valid Cryptographic Presentation Verification (Success)
            # -------------------------------------------------------------
            print("\n[TEST 2E] Testing valid cryptographic meal verification...")
            idempotency_key_1 = f"mess-idem-{uuid.uuid4()}"
            valid_payload_1, valid_sig_1 = build_and_sign_presentation(
                client_priv, student_key_id, test_student.id, student_cert_id, student_issuer_key_id
            )
            res_verify = client.post(
                '/mess/entries/verify',
                headers={'X-User-Id': mess_staff.id},
                json={
                    'studentId': test_student.id,
                    'mealType': test_meal_type,
                    'date': test_date,
                    'verificationMode': 'QR_PRESENTATION',
                    'idempotencyKey': idempotency_key_1,
                    'qrPayload': {"p": valid_payload_1, "s": valid_sig_1}
                }
            )
            assert res_verify.status_code == 201, f"Expected 201, got {res_verify.status_code}: {res_verify.get_json()}"
            entry_data = res_verify.get_json()
            assert entry_data['status'] == 'VERIFIED'
            assert entry_data['entry']['studentId'] == test_student.id
            assert entry_data['entry']['verificationMode'] == 'QR_PRESENTATION'
            assert entry_data['entry']['idempotencyKey'] == idempotency_key_1
            print("[PASS] [TEST 2E] Valid cryptographic meal verification recorded successfully.")

            # -------------------------------------------------------------
            # TEST 3: Idempotent Replay of Exact Same Request
            # -------------------------------------------------------------
            print("\n[TEST 3] Testing idempotent replay with same idempotency key...")
            res_replay = client.post(
                '/mess/entries/verify',
                headers={'X-User-Id': mess_staff.id},
                json={
                    'studentId': test_student.id,
                    'mealType': test_meal_type,
                    'date': test_date,
                    'verificationMode': 'QR_PRESENTATION',
                    'idempotencyKey': idempotency_key_1,
                    'qrPayload': {"p": valid_payload_1, "s": valid_sig_1}
                }
            )
            assert res_replay.status_code == 200, f"Expected 200 on replay, got {res_replay.status_code}"
            replay_data = res_replay.get_json()
            assert replay_data['status'] == 'VERIFIED'
            assert replay_data['isReplay'] is True
            assert replay_data['entry']['id'] == entry_data['entry']['id']
            print("[PASS] [TEST 3] Replay request correctly returned 200 with original record.")

            # -------------------------------------------------------------
            # TEST 4: Duplicate Check-In Protection (Different Idempotency Key)
            # -------------------------------------------------------------
            print("\n[TEST 4] Testing duplicate check-in prevention for same meal & date...")
            valid_payload_2, valid_sig_2 = build_and_sign_presentation(
                client_priv, student_key_id, test_student.id, student_cert_id, student_issuer_key_id
            )
            res_dup = client.post(
                '/mess/entries/verify',
                headers={'X-User-Id': mess_staff.id},
                json={
                    'studentId': test_student.id,
                    'mealType': test_meal_type,
                    'date': test_date,
                    'verificationMode': 'QR_PRESENTATION',
                    'idempotencyKey': f"mess-idem-{uuid.uuid4()}",
                    'qrPayload': {"p": valid_payload_2, "s": valid_sig_2}
                }
            )
            assert res_dup.status_code == 409, f"Expected 409 Conflict, got {res_dup.status_code}"
            dup_data = res_dup.get_json()
            assert dup_data['status'] == 'ALREADY_USED'
            assert "already checked in" in dup_data['message']
            print("[PASS] [TEST 4] Duplicate check-in correctly rejected with 409 ALREADY_USED.")

            # -------------------------------------------------------------
            # TEST 4B: Replay of Used Nonce Rejected
            # -------------------------------------------------------------
            print("\n[TEST 4B] Testing presentation nonce replay rejection...")
            res_nonce_replay = client.post(
                '/mess/entries/verify',
                headers={'X-User-Id': mess_staff.id},
                json={
                    'studentId': test_student.id,
                    'mealType': 'DINNER',
                    'date': test_date,
                    'idempotencyKey': f"mess-new-key-{uuid.uuid4()}",
                    'qrPayload': {"p": valid_payload_1, "s": valid_sig_1}
                }
            )
            assert res_nonce_replay.status_code == 409, f"Expected 409 on nonce replay, got {res_nonce_replay.status_code}"
            assert "replay detected" in res_nonce_replay.get_json()['message'].lower()
            print("[PASS] [TEST 4B] Replayed nonce presentation strictly rejected with 409.")

            # -------------------------------------------------------------
            # TEST 5: Unauthorized Verifier Rejection & Unauthenticated
            # -------------------------------------------------------------
            print("\n[TEST 5] Testing permission rejection for unauthorized / unauthenticated callers...")
            res_unauth = client.post(
                '/mess/entries/verify',
                headers={'X-User-Id': test_student.id},
                json={
                    'studentId': test_student.id,
                    'mealType': 'DINNER',
                    'date': test_date,
                    'qrPayload': {"p": valid_payload_2, "s": valid_sig_2}
                }
            )
            assert res_unauth.status_code == 403, f"Expected 403 Forbidden, got {res_unauth.status_code}"

            res_no_auth = client.post(
                '/mess/entries/verify',
                json={
                    'studentId': test_student.id,
                    'mealType': 'DINNER',
                    'date': test_date,
                    'qrPayload': {"p": valid_payload_2, "s": valid_sig_2}
                }
            )
            assert res_no_auth.status_code == 401, f"Expected 401 Unauthorized, got {res_no_auth.status_code}"
            print("[PASS] [TEST 5] Unauthorized role (403) and unauthenticated caller (401) strictly rejected.")

            # -------------------------------------------------------------
            # TEST 6: Batch Synchronization Endpoint
            # -------------------------------------------------------------
            print("\n[TEST 6] Testing batch synchronization with new and duplicate records...")
            student_2 = User(
                id=str(uuid.uuid4()),
                name="Bob Batch",
                email=f"bob_{uuid.uuid4().hex[:6]}@campusos.edu",
                password="pass",
                role="student"
            )
            student_3 = User(
                id=str(uuid.uuid4()),
                name="Charlie Batch",
                email=f"charlie_{uuid.uuid4().hex[:6]}@campusos.edu",
                password="pass",
                role="student"
            )
            db.session.add_all([student_2, student_3])
            db.session.commit()

            idem_b2 = f"idem-b2-{uuid.uuid4()}"
            idem_b3 = f"idem-b3-{uuid.uuid4()}"

            batch_res = client.post(
                '/mess/entries/batch-sync',
                headers={'X-User-Id': mess_staff.id},
                json={
                    'mealType': 'DINNER',
                    'date': test_date,
                    'records': [
                        {
                            'studentId': student_2.id,
                            'studentName': student_2.name,
                            'idempotencyKey': idem_b2,
                            'verificationMode': 'BATCH'
                        },
                        {
                            'studentId': student_3.id,
                            'studentName': student_3.name,
                            'idempotencyKey': idem_b3,
                            'verificationMode': 'BATCH'
                        },
                        # Re-send student_2 in same batch -> duplicate
                        {
                            'studentId': student_2.id,
                            'studentName': student_2.name,
                            'idempotencyKey': idem_b2,
                            'verificationMode': 'BATCH'
                        }
                    ]
                }
            )
            assert batch_res.status_code == 200, f"Expected 200, got {batch_res.status_code}"
            b_data = batch_res.get_json()
            assert b_data['newSynced'] == 2, f"Expected 2 new, got {b_data['newSynced']}"
            assert b_data['duplicates'] == 1, f"Expected 1 duplicate, got {b_data['duplicates']}"
            assert b_data['totalRecords'] == 3
            print("[PASS] [TEST 6] Batch sync correctly ingested 2 new and handled 1 duplicate.")

            # -------------------------------------------------------------
            # TEST 7: Today Stats & Analytics Endpoints
            # -------------------------------------------------------------
            print("\n[TEST 7] Testing Today Stats and Analytics endpoints...")
            today_res = client.get('/mess/entries/today', headers={'X-User-Id': mess_staff.id})
            assert today_res.status_code == 200
            today_data = today_res.get_json()
            assert 'activeMeal' in today_data
            assert 'counts' in today_data
            assert 'mealTiming' in today_data

            analytics_res = client.get('/mess/entries/analytics', headers={'X-User-Id': mess_staff.id})
            assert analytics_res.status_code == 200
            analytics_data = analytics_res.get_json()
            assert 'totalEntries' in analytics_data
            assert 'batchEntries' in analytics_data
            assert 'qrEntries' in analytics_data
            assert 'mealBreakdown' in analytics_data
            # -------------------------------------------------------------
            # TEST 8: Forged Unsigned QR Presentation Rejected
            # -------------------------------------------------------------
            print("\n[TEST 8] Testing rejection of forged unsigned QR payload...")
            forged_qr = json.dumps({
                "sub": test_student.id,
                "type": "PASSPORT_PRESENTATION",
                "issuedAt": int(datetime.datetime.now().timestamp()),
                "expiresAt": int(datetime.datetime.now().timestamp()) + 30
            })
            res_forged = client.post(
                '/mess/entries/verify',
                headers={'X-User-Id': mess_staff.id},
                json={
                    'mealType': 'DINNER',
                    'date': test_date,
                    'qrPayload': forged_qr
                }
            )
            assert res_forged.status_code == 400, f"Expected 400, got {res_forged.status_code}: {res_forged.get_json()}"
            forged_data = res_forged.get_json()
            assert forged_data['valid'] is False
            assert "Cryptographic verification failed" in forged_data['message']
            print("[PASS] [TEST 8] Forged unsigned QR payload strictly rejected with 400.")

            # -------------------------------------------------------------
            # TEST 9: Tampered Signature in QR Presentation Rejected
            # -------------------------------------------------------------
            print("\n[TEST 9] Testing rejection of tampered signature in QR envelope...")
            tampered_qr = json.dumps({
                "p": {
                    "version": 1,
                    "type": "PASSPORT_PRESENTATION",
                    "keyId": "some-key",
                    "userId": test_student.id,
                    "certificateId": "some-cert",
                    "issuerKeyId": "inst-root",
                    "issuedAt": int(datetime.datetime.now().timestamp()),
                    "expiresAt": int(datetime.datetime.now().timestamp()) + 30,
                    "nonce": "test-nonce"
                },
                "s": "dGFtcGVyZWRfc2lnbmF0dXJlX2J5dGVzX2hlcmU="
            })
            res_tampered = client.post(
                '/mess/entries/verify',
                headers={'X-User-Id': mess_staff.id},
                json={
                    'mealType': 'DINNER',
                    'date': test_date,
                    'qrPayload': tampered_qr
                }
            )
            assert res_tampered.status_code == 400, f"Expected 400, got {res_tampered.status_code}"
            assert res_tampered.get_json()['valid'] is False
            assert "Cryptographic verification failed" in res_tampered.get_json()['message']
            print("[PASS] [TEST 9] Tampered signature in QR payload strictly rejected with 400.")

        finally:
            # Cleanup test records
            MealEntry.query.filter_by(student_id=test_student.id).delete()
            MealEntry.query.filter_by(entry_date=test_date).delete()
            DeviceCertificate.query.filter_by(subject_user_id=test_student.id).delete()
            DeviceIdentityKey.query.filter_by(user_id=test_student.id).delete()
            db.session.commit()
            print("\n[CLEANUP] Test meal entries, keys, and certs cleaned up successfully.")

    print("\n" + "=" * 60)
    print("ALL MESS STAFF BACKEND TESTS PASSED SUCCESSFULLY!")
    print("=" * 60)


if __name__ == '__main__':
    run_tests()
