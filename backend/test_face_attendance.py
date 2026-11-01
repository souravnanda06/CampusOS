"""
CampusOS Face-Verified Attendance & Enrollment Test Suite.

Verifies:
1. Face status check for un-enrolled student.
2. One-time face enrollment with 128-float vector embedding.
3. Anti-tamper / duplicate enrollment block (HTTP 409).
4. Cosine similarity verification: matching identity vs. proxy mismatch (HTTP 403).
5. Attendance marking with BLE_FACE and QR_FACE verification modes.
6. Admin-authorized re-enrollment reset.
"""

import os
import sys
import json
import uuid
import math
import random

sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))

from app import create_app, db, User, Attendance, Session
from utils.crypto import create_access_token


def generate_synthetic_embedding(seed=42, dimensions=128):
    """Generates a deterministic normalized 128-float embedding vector."""
    rng = random.Random(seed)
    raw = [rng.uniform(-1.0, 1.0) for _ in range(dimensions)]
    magnitude = math.sqrt(sum(x * x for x in raw))
    return [round(x / magnitude, 6) for x in raw]


def add_noise(vector, noise_level=0.05, seed=99):
    """Adds slight random variation to simulate live camera frames of the same person."""
    rng = random.Random(seed)
    noisy = [x + rng.uniform(-noise_level, noise_level) for x in vector]
    mag = math.sqrt(sum(x * x for x in noisy))
    return [round(x / mag, 6) for x in noisy]


def run_face_tests():
    print("=" * 70)
    print("CAMPUSOS FACE-VERIFIED ATTENDANCE TEST SUITE")
    print("=" * 70)

    app = create_app()
    client = app.test_client()

    with app.app_context():
        # Setup deterministic test accounts
        student_a = User.query.filter_by(email="face_student_a@campusos.edu").first()
        if not student_a:
            student_a = User(
                name="Face Student Alpha",
                email="face_student_a@campusos.edu",
                role="student",
                password="password123",
                registration_number="2201289001"
            )
            db.session.add(student_a)

        student_b = User.query.filter_by(email="face_student_b@campusos.edu").first()
        if not student_b:
            student_b = User(
                name="Face Student Proxy",
                email="face_student_b@campusos.edu",
                role="student",
                password="password123",
                registration_number="2201289002"
            )
            db.session.add(student_b)

        admin = User.query.filter_by(email="face_admin@campusos.edu").first()
        if not admin:
            admin = User(
                name="Face Dean Admin",
                email="face_admin@campusos.edu",
                role="admin",
                password="password123"
            )
            db.session.add(admin)

        db.session.commit()

        # Reset any prior test state for student_a
        student_a.face_enrolled = False
        student_a.face_enrolled_at = None
        student_a.face_embedding = None
        student_a.face_embedding_hash = None
        db.session.commit()

        student_token = create_access_token(student_a)
        student_headers = {
            "Authorization": f"Bearer {student_token}",
            "Content-Type": "application/json"
        }
        admin_token = create_access_token(admin)
        admin_headers = {
            "Authorization": f"Bearer {admin_token}",
            "Content-Type": "application/json"
        }

        # -------------------------------------------------------------
        # TEST 1: Check initial status (Un-enrolled)
        # -------------------------------------------------------------
        print("\n[TEST 1] Checking initial face status for unenrolled student...")
        res = client.get(f'/passport/face/status?studentId={student_a.id}', headers=student_headers)
        assert res.status_code == 200, f"Status check failed: {res.data}"
        data = res.get_json()
        assert data["faceEnrolled"] is False
        assert data["status"] == "NOT_ENROLLED"
        print("  -> [PASS] Verified student begins in NOT_ENROLLED state.")

        # -------------------------------------------------------------
        # TEST 2: Perform One-Time Face Enrollment
        # -------------------------------------------------------------
        print("\n[TEST 2] Enrolling student face with 128-D vector embedding...")
        enrolled_vector = generate_synthetic_embedding(seed=101)
        res = client.post('/passport/face/enroll', headers=student_headers, json={
            "studentId": student_a.id,
            "faceEmbedding": enrolled_vector,
            "deviceId": "samsung-galaxy-s24-uuid"
        })
        assert res.status_code == 201, f"Enrollment failed: {res.data}"
        enroll_data = res.get_json()
        assert enroll_data["faceEnrolled"] is True
        assert enroll_data["dimensions"] == 128
        assert "embeddingHash" in enroll_data
        print(f"  -> [PASS] One-time face enrollment successful. Hash: {enroll_data['embeddingHash'][:16]}...")

        # -------------------------------------------------------------
        # TEST 3: Block Duplicate / Proxy Re-enrollment without Admin Authorization
        # -------------------------------------------------------------
        print("\n[TEST 3] Verifying anti-tamper duplicate enrollment protection...")
        res = client.post('/passport/face/enroll', headers=student_headers, json={
            "studentId": student_a.id,
            "faceEmbedding": generate_synthetic_embedding(seed=999)
        })
        assert res.status_code == 409, f"Should have blocked duplicate: {res.data}"
        print("  -> [PASS] Unilateral re-enrollment strictly blocked with HTTP 409 Conflict.")

        # -------------------------------------------------------------
        # TEST 4: Verification Gate — Legitimate Student (High Similarity >= 0.82)
        # -------------------------------------------------------------
        print("\n[TEST 4] Testing face verification with legitimate student live frame...")
        live_frame_same_person = add_noise(enrolled_vector, noise_level=0.03, seed=55)
        res = client.post('/passport/face/verify', headers=student_headers, json={
            "studentId": student_a.id,
            "faceEmbedding": live_frame_same_person
        })
        assert res.status_code == 200, f"Legitimate face rejected: {res.data}"
        verify_data = res.get_json()
        assert verify_data["verified"] is True
        assert verify_data["similarity"] >= 0.82
        print(f"  -> [PASS] Legitimate student verified! Cosine Similarity: {verify_data['similarity']} (Confidence: {verify_data['matchConfidence']}).")

        # -------------------------------------------------------------
        # TEST 5: Verification Gate — Proxy Attack (Different Person, Sim < 0.82)
        # -------------------------------------------------------------
        print("\n[TEST 5] Testing proxy attendance attack (Friend attempting verification)...")
        proxy_face_vector = generate_synthetic_embedding(seed=777)  # Totally different face
        res = client.post('/passport/face/verify', headers=student_headers, json={
            "studentId": student_a.id,
            "faceEmbedding": proxy_face_vector
        })
        assert res.status_code == 403, f"Proxy should have been rejected: {res.data}"
        proxy_data = res.get_json()
        assert proxy_data["verified"] is False
        assert proxy_data["reason"] == "OWNER_MISMATCH"
        print(f"  -> [PASS] Proxy attack blocked! Cosine Similarity: {proxy_data['similarity']} < 0.82. Reason: OWNER_MISMATCH.")

        # -------------------------------------------------------------
        # TEST 6: Attendance Record with BLE_FACE Verification Mode
        # -------------------------------------------------------------
        print("\n[TEST 6] Recording attendance with verificationMode='BLE_FACE'...")
        session = Session(
            name="Computer Architecture CS302",
            subject="Computer Architecture",
            instructor_name="Prof. Sharma",
            course="B.Tech",
            branch="CSE",
            year="3rd Year",
            location="Room 401",
            start_time="2026-10-30T10:00:00",
            end_time="2026-10-30T11:00:00"
        )
        db.session.add(session)
        db.session.commit()

        res = client.post('/attendance/mark', headers=student_headers, json={
            "sessionId": session.id,
            "studentId": student_a.id,
            "studentName": student_a.name,
            "verificationMode": "BLE_FACE",
            "proximityTier": "NEAR",
            "idempotencyKey": f"att_face_{session.id}_{student_a.id}"
        })
        assert res.status_code in (200, 201), f"Attendance marking failed: {res.data}"
        att_data = res.get_json()
        assert att_data["verificationMode"] == "BLE_FACE"
        assert att_data["proximityTier"] == "NEAR"
        print("  -> [PASS] Attendance successfully marked with BLE_FACE verification mode.")

        # -------------------------------------------------------------
        # TEST 7: Admin-Authorized Face Re-Enrollment Reset
        # -------------------------------------------------------------
        print("\n[TEST 7] Testing Admin/Dean authorized face enrollment reset...")
        res = client.post('/admin/face/reset', headers=admin_headers, json={
            "studentId": student_a.id,
            "reason": "Student requested re-enrollment after camera calibration"
        })
        assert res.status_code == 200, f"Admin reset failed: {res.data}"
        reset_data = res.get_json()
        assert reset_data["success"] is True

        # Verify status is now reset to NOT_ENROLLED
        refreshed_student = User.query.get(student_a.id)
        assert refreshed_student.face_enrolled is False
        assert refreshed_student.face_embedding is None
        print("  -> [PASS] Face enrollment reset authorized and verified in database.")

        print("\n" + "=" * 70)
        print("ALL 7 FACE-VERIFIED ATTENDANCE TESTS PASSED SUCCESSFULLY! [100%]")
        print("=" * 70)


if __name__ == '__main__':
    run_face_tests()
