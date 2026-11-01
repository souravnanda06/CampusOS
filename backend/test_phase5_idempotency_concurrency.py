"""
CampusOS Phase 5: Backend Idempotency & Concurrency Hardening Test Suite.

Tests concurrent duplicate requests, atomic counters, and idempotency recovery
under race conditions for session creation and attendance marking.
"""

import os
import sys
import uuid
import datetime
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed

# Ensure backend root is on Python path
sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))

from app import app, db, User, Session, Attendance


def run_tests():
    print("=" * 70)
    print("CAMPUSOS PHASE 5 — IDEMPOTENCY & CONCURRENCY HARDENING TESTS")
    print("=" * 70)

    passed = 0
    failed = 0

    with app.app_context():
        # ------------------------------------------------------------------
        # Setup: Ensure a teacher and student exist
        # ------------------------------------------------------------------
        teacher = User.query.filter_by(role='teacher').first()
        if not teacher:
            teacher = User(name="P5 Teacher", email="p5teacher@campusos.edu", role="teacher")
            db.session.add(teacher)
            db.session.commit()

        student = User.query.filter_by(role='student').first()
        if not student:
            student = User(name="P5 Student", email="p5student@campusos.edu", role="student")
            db.session.add(student)
            db.session.commit()

        teacher_id = teacher.id
        teacher_name = teacher.name
        student_id = student.id
        student_name = student.name

        cleanup_session_ids = []
        cleanup_idempotency_keys = []

        try:
            # ==============================================================
            # TEST 1: Concurrent session creation with same idempotency key
            # ==============================================================
            print("\n[TEST 1] Concurrent session creation with same idempotency key...")
            idem_key_sess = f"p5-sess-{uuid.uuid4()}"
            cleanup_idempotency_keys.append(idem_key_sess)
            results = []
            errors = []

            def create_session_request():
                with app.app_context():
                    c = app.test_client()
                    try:
                        res = c.post('/sessions/create', json={
                            "idempotencyKey": idem_key_sess,
                            "name": "Concurrent Session",
                            "instructorName": teacher_name,
                            "course": "B.Tech",
                            "branch": "CSE",
                            "year": "3rd Year",
                            "location": "Room P5"
                        })
                        results.append((res.status_code, res.get_json()))
                    except Exception as e:
                        errors.append(str(e))

            threads = [threading.Thread(target=create_session_request) for _ in range(5)]
            for t in threads:
                t.start()
            for t in threads:
                t.join(timeout=10)

            assert len(errors) == 0, f"Thread errors: {errors}"
            status_codes = [r[0] for r in results]
            server_ids = set(r[1]["id"] for r in results)

            assert all(sc in (200, 201) for sc in status_codes), \
                f"Expected all 200/201, got {status_codes}"
            assert len(server_ids) == 1, \
                f"Expected 1 unique server ID, got {len(server_ids)}: {server_ids}"
            assert status_codes.count(201) == 1, \
                f"Expected exactly one 201, got {status_codes.count(201)} in {status_codes}"

            cleanup_session_ids.append(list(server_ids)[0])
            passed += 1
            print(f"[PASS] [TEST 1] 5 concurrent creates -> 1x201 + 4x200, single server ID.")

            # ==============================================================
            # TEST 2: Concurrent attendance marking with same idempotency key
            # ==============================================================
            print("\n[TEST 2] Concurrent attendance marking with same idempotency key...")
            att_sess_id = str(uuid.uuid4())
            att_session = Session(
                id=att_sess_id,
                name="P5 Attendance Session",
                subject="P5 Subject",
                instructor_name=teacher_name,
                course="B.Tech", branch="CSE", year="3rd Year",
                start_time=datetime.datetime.now().isoformat(),
                end_time=(datetime.datetime.now() + datetime.timedelta(hours=1)).isoformat(),
                location="Room P5",
                attendance_count=0
            )
            db.session.add(att_session)
            db.session.commit()
            cleanup_session_ids.append(att_sess_id)

            idem_key_att = f"p5-att-{uuid.uuid4()}"
            att_results = []
            att_errors = []

            def mark_attendance_request():
                with app.app_context():
                    c = app.test_client()
                    try:
                        res = c.post('/attendance/mark', json={
                            "sessionId": att_sess_id,
                            "studentId": student_id,
                            "studentName": student_name,
                            "idempotencyKey": idem_key_att,
                            "verificationMode": "BLE_BATCH",
                            "proximityTier": "NEAR"
                        })
                        att_results.append((res.status_code, res.get_json()))
                    except Exception as e:
                        att_errors.append(str(e))

            threads = [threading.Thread(target=mark_attendance_request) for _ in range(5)]
            for t in threads:
                t.start()
            for t in threads:
                t.join(timeout=10)

            assert len(att_errors) == 0, f"Thread errors: {att_errors}"
            att_codes = [r[0] for r in att_results]
            att_ids = set(r[1].get("id") for r in att_results if r[1].get("id"))

            assert all(sc in (200, 201, 400, 409) for sc in att_codes), \
                f"Expected 200/201/400/409, got {att_codes}"
            assert len(att_ids) == 1, \
                f"Expected 1 attendance record, got {len(att_ids)}: {att_ids}"

            passed += 1
            print(f"[PASS] [TEST 2] 5 concurrent marks -> single attendance record, no 500s.")

            # ==============================================================
            # TEST 3: Attendance count accuracy under concurrent marking
            # ==============================================================
            print("\n[TEST 3] Attendance count accuracy under concurrent marking...")
            count_sess_id = str(uuid.uuid4())
            count_session = Session(
                id=count_sess_id,
                name="P5 Count Session",
                subject="Counting",
                instructor_name=teacher_name,
                course="B.Tech", branch="CSE", year="3rd Year",
                start_time=datetime.datetime.now().isoformat(),
                end_time=(datetime.datetime.now() + datetime.timedelta(hours=1)).isoformat(),
                location="Room P5",
                attendance_count=0
            )
            db.session.add(count_session)
            db.session.commit()
            cleanup_session_ids.append(count_sess_id)

            num_students = 10
            count_results = []
            count_errors = []

            def mark_unique_student(idx):
                with app.app_context():
                    c = app.test_client()
                    s_id = str(uuid.uuid4())
                    idem = f"p5-count-{uuid.uuid4()}"
                    try:
                        res = c.post('/attendance/mark', json={
                            "sessionId": count_sess_id,
                            "studentId": s_id,
                            "studentName": f"Count Student {idx}",
                            "idempotencyKey": idem,
                            "verificationMode": "BLE_BATCH",
                            "proximityTier": "NEAR"
                        })
                        count_results.append((res.status_code, res.get_json()))
                    except Exception as e:
                        count_errors.append(str(e))

            with ThreadPoolExecutor(max_workers=10) as pool:
                futures = [pool.submit(mark_unique_student, i) for i in range(num_students)]
                for f in as_completed(futures):
                    f.result()

            assert len(count_errors) == 0, f"Thread errors: {count_errors}"
            assert all(r[0] == 201 for r in count_results), \
                f"Expected all 201, got {[r[0] for r in count_results]}"

            # Verify the atomic count
            db.session.expire_all()
            final_session = Session.query.get(count_sess_id)
            actual_count = final_session.attendance_count or 0
            actual_records = Attendance.query.filter_by(session_id=count_sess_id).count()

            assert actual_count == num_students, \
                f"Attendance count mismatch: counter={actual_count}, expected={num_students}"
            assert actual_records == num_students, \
                f"Attendance records mismatch: records={actual_records}, expected={num_students}"

            passed += 1
            print(f"[PASS] [TEST 3] {num_students} concurrent marks -> count={actual_count}, records={actual_records}. Atomic!")

            # ==============================================================
            # TEST 4: Concurrent batch-sync with overlapping records
            # ==============================================================
            print("\n[TEST 4] Concurrent batch-sync with overlapping records...")
            batch_sess_id = str(uuid.uuid4())
            batch_session = Session(
                id=batch_sess_id,
                name="P5 Batch Session",
                subject="Batch Subject",
                instructor_name=teacher_name,
                course="B.Tech", branch="CSE", year="3rd Year",
                start_time=datetime.datetime.now().isoformat(),
                end_time=(datetime.datetime.now() + datetime.timedelta(hours=1)).isoformat(),
                location="Room P5",
                attendance_count=0
            )
            db.session.add(batch_session)
            db.session.commit()
            cleanup_session_ids.append(batch_sess_id)

            shared_records = []
            for i in range(5):
                shared_records.append({
                    "studentId": str(uuid.uuid4()),
                    "studentName": f"Batch Student {i}",
                    "idempotencyKey": f"p5-batch-{uuid.uuid4()}",
                    "verificationMode": "BLE_BATCH",
                    "proximityTier": "NEAR"
                })

            batch_payload = {
                "sessionId": batch_sess_id,
                "records": shared_records
            }

            batch_results = []
            batch_errors = []

            def batch_sync_request():
                with app.app_context():
                    c = app.test_client()
                    try:
                        res = c.post('/attendance/batch-sync', json=batch_payload)
                        batch_results.append((res.status_code, res.get_json()))
                    except Exception as e:
                        batch_errors.append(str(e))

            threads = [threading.Thread(target=batch_sync_request) for _ in range(3)]
            for t in threads:
                t.start()
            for t in threads:
                t.join(timeout=15)

            assert len(batch_errors) == 0, f"Thread errors: {batch_errors}"
            assert all(r[0] == 200 for r in batch_results), \
                f"Expected all 200, got {[r[0] for r in batch_results]}"

            # Verify exactly 5 attendance records exist (not 15)
            batch_att_count = Attendance.query.filter_by(session_id=batch_sess_id).count()
            assert batch_att_count == 5, \
                f"Expected exactly 5 attendance records, got {batch_att_count}"

            # Sum of newSynced across all batches should be 5
            total_new = sum(r[1].get("newSynced", 0) for r in batch_results)
            total_dups = sum(r[1].get("duplicates", 0) for r in batch_results)
            assert total_new == 5, f"Total newSynced should be 5, got {total_new}"
            assert total_dups == 10, f"Total duplicates should be 10, got {total_dups}"

            passed += 1
            print(f"[PASS] [TEST 4] 3 concurrent batch-syncs of 5 records -> exactly 5 persisted, 10 deduped.")

            # ==============================================================
            # TEST 5: Session idempotency key uniqueness stress test
            # ==============================================================
            print("\n[TEST 5] Session idempotency key uniqueness stress test...")
            stress_keys = [f"p5-stress-{uuid.uuid4()}" for _ in range(10)]
            cleanup_idempotency_keys.extend(stress_keys)
            stress_results = []
            stress_errors = []

            def create_unique_session(key):
                with app.app_context():
                    c = app.test_client()
                    try:
                        res = c.post('/sessions/create', json={
                            "idempotencyKey": key,
                            "name": f"Stress {key[:8]}",
                            "instructorName": teacher_name,
                            "course": "B.Tech",
                            "branch": "CSE",
                            "year": "3rd Year",
                            "location": "Room S"
                        })
                        stress_results.append((res.status_code, res.get_json()))
                    except Exception as e:
                        stress_errors.append(str(e))

            with ThreadPoolExecutor(max_workers=10) as pool:
                futures = [pool.submit(create_unique_session, k) for k in stress_keys]
                for f in as_completed(futures):
                    f.result()

            assert len(stress_errors) == 0, f"Thread errors: {stress_errors}"
            assert all(r[0] == 201 for r in stress_results), \
                f"Expected all 201, got {[r[0] for r in stress_results]}"
            stress_ids = set(r[1]["id"] for r in stress_results)
            assert len(stress_ids) == 10, \
                f"Expected 10 unique sessions, got {len(stress_ids)}"

            for sid in stress_ids:
                cleanup_session_ids.append(sid)

            passed += 1
            print(f"[PASS] [TEST 5] 10 concurrent unique sessions -> 10 unique IDs, all 201.")

            # ==============================================================
            # TEST 6: V1 recovery — IntegrityError on session returns 200
            # ==============================================================
            print("\n[TEST 6] Session IntegrityError recovery returns existing (200)...")
            recover_key = f"p5-recover-{uuid.uuid4()}"
            cleanup_idempotency_keys.append(recover_key)

            c1 = app.test_client()
            r1 = c1.post('/sessions/create', json={
                "idempotencyKey": recover_key,
                "name": "Recovery Session",
                "instructorName": teacher_name,
                "course": "B.Tech", "branch": "CSE", "year": "3rd Year",
                "location": "Room R"
            })
            assert r1.status_code == 201
            original_id = r1.get_json()["id"]
            cleanup_session_ids.append(original_id)

            r2 = c1.post('/sessions/create', json={
                "idempotencyKey": recover_key,
                "name": "Recovery Session (retry)",
                "instructorName": teacher_name,
                "course": "B.Tech", "branch": "CSE", "year": "3rd Year",
                "location": "Room R"
            })
            assert r2.status_code == 200, f"Expected 200, got {r2.status_code}"
            assert r2.get_json()["id"] == original_id, "Retry should return original session"

            passed += 1
            print(f"[PASS] [TEST 6] Retry returns 200 with original session ID.")

            # ==============================================================
            # TEST 7: Reconcile endpoint idempotency under concurrent calls
            # ==============================================================
            print("\n[TEST 7] Concurrent /sessions/reconcile with same localId...")
            reconcile_key = f"p5-recon-{uuid.uuid4()}"
            cleanup_idempotency_keys.append(reconcile_key)
            recon_results = []
            recon_errors = []

            def reconcile_request():
                with app.app_context():
                    c = app.test_client()
                    try:
                        res = c.post('/sessions/reconcile', json={
                            "localId": reconcile_key,
                            "idempotencyKey": reconcile_key,
                            "name": "Reconcile Race",
                            "instructorName": teacher_name,
                            "course": "B.Tech", "branch": "CSE", "year": "3rd Year",
                            "location": "Lab 7"
                        })
                        recon_results.append((res.status_code, res.get_json()))
                    except Exception as e:
                        recon_errors.append(str(e))

            threads = [threading.Thread(target=reconcile_request) for _ in range(5)]
            for t in threads:
                t.start()
            for t in threads:
                t.join(timeout=10)

            assert len(recon_errors) == 0, f"Thread errors: {recon_errors}"
            recon_codes = [r[0] for r in recon_results]
            recon_ids = set(r[1]["id"] for r in recon_results)

            assert all(sc in (200, 201) for sc in recon_codes), \
                f"Expected all 200/201, got {recon_codes}"
            assert len(recon_ids) == 1, \
                f"Expected 1 unique reconciled ID, got {len(recon_ids)}: {recon_ids}"

            cleanup_session_ids.append(list(recon_ids)[0])

            passed += 1
            print(f"[PASS] [TEST 7] 5 concurrent reconciliations -> single session, no 500s.")

        finally:
            # ------------------------------------------------------------------
            # Cleanup
            # ------------------------------------------------------------------
            for sid in cleanup_session_ids:
                try:
                    Attendance.query.filter_by(session_id=sid).delete()
                except Exception:
                    db.session.rollback()
            for sid in cleanup_session_ids:
                try:
                    Session.query.filter_by(id=sid).delete()
                except Exception:
                    db.session.rollback()
            for key in cleanup_idempotency_keys:
                try:
                    Session.query.filter_by(idempotency_key=key).delete()
                except Exception:
                    db.session.rollback()
            try:
                db.session.commit()
            except Exception:
                db.session.rollback()
            print("\n[CLEANUP] Phase 5 test data cleaned up.")

    total = passed + failed
    print("\n" + "=" * 70)
    print(f"PHASE 5 RESULTS: {passed}/{total} tests passed.")
    if failed > 0:
        print(f"FAILED: {failed} tests")
        sys.exit(1)
    else:
        print("ALL PHASE 5 IDEMPOTENCY & CONCURRENCY TESTS PASSED!")
    print("=" * 70)


if __name__ == '__main__':
    run_tests()

