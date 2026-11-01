"""
CampusOS Passport Phase 1I: Batch Attendance & Offline Idempotency Backend Test Suite.
"""

import os
import sys
import json
import uuid
import datetime

# Ensure backend root is on Python path
sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))

from app import app, db, User, Session, Attendance


def run_tests():
    print("=" * 60)
    print("CAMPUSOS PASSPORT 1I — BATCH ATTENDANCE & IDEMPOTENCY TESTS")
    print("=" * 60)

    client = app.test_client()

    with app.app_context():
        # Setup temporary test session and students
        test_teacher = User.query.filter_by(role='teacher').first()
        if not test_teacher:
            test_teacher = User(name="Test Teacher", email="teacher.test@campusos.edu", role="teacher")
            db.session.add(test_teacher)
            db.session.commit()

        test_student = User.query.filter_by(role='student').first()
        if not test_student:
            test_student = User(name="Test Student", email="student.test@campusos.edu", role="student")
            db.session.add(test_student)
            db.session.commit()

        session_id = str(uuid.uuid4())
        session_nonce = "a" * 32
        teacher_key_id = "test-teacher-key-01"

        new_session = Session(
            id=session_id,
            name="CS101 Distributed Systems",
            subject="CS101",
            instructor_name=test_teacher.name,
            course="B.Tech",
            branch="CSE",
            year="4th Year",
            start_time=datetime.datetime.now().isoformat(),
            end_time=(datetime.datetime.now() + datetime.timedelta(hours=1)).isoformat(),
            location="Room 401",
            session_nonce=session_nonce,
            teacher_key_id=teacher_key_id,
            teacher_id=test_teacher.id
        )
        db.session.add(new_session)
        db.session.commit()

        try:
            # Test 1: Beacon endpoint GET
            print("\n[TEST 1] Query session beacon info...")
            res = client.get(f'/sessions/{session_id}/beacon')
            assert res.status_code == 200, f"Expected 200, got {res.status_code}: {res.get_json()}"
            beacon_data = res.get_json()
            assert beacon_data['sessionId'] == session_id
            assert beacon_data['sessionNonce'] == session_nonce
            assert beacon_data['teacherKeyId'] == teacher_key_id
            assert beacon_data['teacherId'] == test_teacher.id
            print("[PASS] [TEST 1] Beacon info retrieved correctly.")

            # Test 2: Beacon endpoint POST update
            print("\n[TEST 2] Update session beacon nonce...")
            new_nonce = "b" * 32
            res = client.post(f'/sessions/{session_id}/beacon', json={'sessionNonce': new_nonce})
            assert res.status_code == 200
            assert res.get_json()['sessionNonce'] == new_nonce
            print("[PASS] [TEST 2] Session beacon updated successfully.")

            # Test 3: Idempotent mark attendance with idempotency key
            print("\n[TEST 3] Mark attendance with idempotency key...")
            idempotency_key_1 = f"idem-{uuid.uuid4()}"
            res = client.post('/attendance/mark', json={
                'sessionId': session_id,
                'studentId': test_student.id,
                'studentName': test_student.name,
                'idempotencyKey': idempotency_key_1,
                'deviceKeyId': 'student-device-key-1',
                'responseNonce': 'resp-nonce-1',
                'verificationMode': 'BLE_BATCH',
                'proximityTier': 'NEAR'
            })
            assert res.status_code == 201, f"Expected 201, got {res.status_code}: {res.get_json()}"
            record_1 = res.get_json()
            assert record_1['idempotencyKey'] == idempotency_key_1
            assert record_1['verificationMode'] == 'BLE_BATCH'
            assert record_1['proximityTier'] == 'NEAR'
            print("[PASS] [TEST 3] Attendance marked with Passport 1I metadata.")

            # Test 4: Duplicate mark attendance with same idempotency key is idempotent (returns 200, no duplicate)
            print("\n[TEST 4] Replaying exact same mark request (idempotency check)...")
            res_dup = client.post('/attendance/mark', json={
                'sessionId': session_id,
                'studentId': test_student.id,
                'studentName': test_student.name,
                'idempotencyKey': idempotency_key_1,
                'deviceKeyId': 'student-device-key-1',
                'responseNonce': 'resp-nonce-1',
                'verificationMode': 'BLE_BATCH',
                'proximityTier': 'NEAR'
            })
            assert res_dup.status_code == 200, f"Expected 200 on idempotent replay, got {res_dup.status_code}"
            assert res_dup.get_json()['id'] == record_1['id']
            print("[PASS] [TEST 4] Replay request correctly returned 200 with existing record.")

            # Test 5: Batch sync attendance with multiple records
            print("\n[TEST 5] Batch sync attendance endpoint...")
            student_2_id = str(uuid.uuid4())
            student_3_id = str(uuid.uuid4())
            idem_2 = f"idem-{uuid.uuid4()}"
            idem_3 = f"idem-{uuid.uuid4()}"

            batch_payload = {
                'sessionId': session_id,
                'records': [
                    {
                        'studentId': student_2_id,
                        'studentName': 'Batch Student 2',
                        'deviceKeyId': 'dev-key-2',
                        'responseNonce': 'resp-2',
                        'idempotencyKey': idem_2,
                        'verificationMode': 'BLE_BATCH',
                        'proximityTier': 'NEAR'
                    },
                    {
                        'studentId': student_3_id,
                        'studentName': 'Batch Student 3',
                        'deviceKeyId': 'dev-key-3',
                        'responseNonce': 'resp-3',
                        'idempotencyKey': idem_3,
                        'verificationMode': 'QR_FALLBACK',
                        'proximityTier': 'FALLBACK_VERIFIED'
                    },
                    # Duplicate of student 1
                    {
                        'studentId': test_student.id,
                        'studentName': test_student.name,
                        'deviceKeyId': 'student-device-key-1',
                        'responseNonce': 'resp-nonce-1',
                        'idempotencyKey': idempotency_key_1,
                        'verificationMode': 'BLE_BATCH',
                        'proximityTier': 'NEAR'
                    }
                ]
            }

            res_batch = client.post('/attendance/batch-sync', json=batch_payload)
            assert res_batch.status_code == 200, f"Expected 200, got {res_batch.status_code}: {res_batch.get_json()}"
            batch_result = res_batch.get_json()
            assert batch_result['newSynced'] == 2, f"Expected 2 new, got {batch_result['newSynced']}"
            assert batch_result['duplicates'] == 1, f"Expected 1 duplicate, got {batch_result['duplicates']}"
            assert batch_result['totalRecords'] == 3
            print("[PASS] [TEST 5] Batch sync successfully synced 2 new records and skipped 1 duplicate.")

            # Test 6: Re-syncing the entire batch produces 0 new and 3 duplicates
            print("\n[TEST 6] Re-sync entire batch (all duplicates)...")
            res_resync = client.post('/attendance/batch-sync', json=batch_payload)
            assert res_resync.status_code == 200
            resync_data = res_resync.get_json()
            assert resync_data['newSynced'] == 0, f"Expected 0 new, got {resync_data['newSynced']}"
            assert resync_data['duplicates'] == 3, f"Expected 3 duplicates, got {resync_data['duplicates']}"
            print("[PASS] [TEST 6] Batch re-sync completely idempotent.")

            # Test 7: Duplicate mark without idempotency key rejected
            print("\n[TEST 7] Duplicate check-in without idempotency key...")
            res_no_idem = client.post('/attendance/mark', json={
                'sessionId': session_id,
                'studentId': test_student.id,
                'studentName': test_student.name
            })
            assert res_no_idem.status_code in [400, 409], f"Expected 400/409, got {res_no_idem.status_code}"
            print("[PASS] [TEST 7] Duplicate attendance correctly rejected.")

            # Test 8: Database-level UniqueConstraint uq_attendance_session_user enforcement
            print("\n[TEST 8] Database UniqueConstraint uq_attendance_session_user enforcement...")
            from sqlalchemy.exc import IntegrityError
            duplicate_direct_att = Attendance(
                session_id=session_id,
                user_id=test_student.id,
                student_name=test_student.name,
                check_in_time=datetime.datetime.now().isoformat(),
                status='present'
            )
            db.session.add(duplicate_direct_att)
            try:
                db.session.commit()
                assert False, "Database should have thrown IntegrityError on duplicate (session_id, user_id)!"
            except IntegrityError:
                db.session.rollback()
                print("[PASS] [TEST 8] Database UniqueConstraint strictly blocked duplicate (session_id, user_id) insertion.")

        finally:
            # Clean up test rows
            Attendance.query.filter_by(session_id=session_id).delete()
            Session.query.filter_by(id=session_id).delete()
            db.session.commit()
            print("\n[CLEANUP] Test data cleaned up successfully.")

    print("\n" + "=" * 60)
    print("ALL 8 PASSPORT 1I BACKEND TESTS PASSED!")
    print("=" * 60)


if __name__ == '__main__':
    run_tests()
