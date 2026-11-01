"""
CampusOS Feature 2: Proof-of-Fix 2-Way OTP Ticket Closure & Escalation Slingshot Tests.

Verifies:
1. Complaint creation automatically generates a 4-digit student closure OTP.
2. Student can retrieve their own closure OTP.
3. Assigned staff cannot see closure OTP before resolution.
4. Staff attempting RESOLVE without OTP fails with 400.
5. Staff attempting RESOLVE with wrong OTP fails with 403.
6. Staff attempting RESOLVE with correct OTP succeeds with 200 and records otp_verified_at.
7. Student post-resolution rating & feedback (1-5 stars).
8. SLA Slingshot Evaluation (>24h -> Tier 2 Warden Alert, >48h -> Tier 3 Dean Slingshot + Vendor Penalty).
9. Slingshot Dashboard API metrics.
"""

import os
import sys
import datetime
import uuid

sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))

from app import app, db, User, Complaint, RequestAudit, ComplaintStatusHistory


def run_feature2_tests():
    print("=" * 75)
    print("CAMPUSOS FEATURE 2 — PROOF-OF-FIX OTP & SLA SLINGSHOT TESTS")
    print("=" * 75)

    with app.app_context():
        # 1. Setup deterministic accounts
        student = User.query.filter_by(email="f2_student@campusos.edu").first()
        if not student:
            student = User(name="F2 Student", email="f2_student@campusos.edu", role="student", password="password123")
            db.session.add(student)

        staff = User.query.filter_by(email="f2_staff@campusos.edu").first()
        if not staff:
            staff = User(name="F2 Electrician", email="f2_staff@campusos.edu", role="staff", password="password123")
            db.session.add(staff)

        warden = User.query.filter_by(email="f2_warden@campusos.edu").first()
        if not warden:
            warden = User(name="F2 Warden", email="f2_warden@campusos.edu", role="warden", password="password123")
            db.session.add(warden)

        db.session.commit()

        student_id = student.id
        staff_id = staff.id
        warden_id = warden.id

        client = app.test_client()

        # ----------------------------------------------------------------------
        # Test 1: Complaint creation creates 4-digit closure OTP
        # ----------------------------------------------------------------------
        print("\n[TEST 1] Creating complaint and verifying 4-digit closure OTP...")
        create_res = client.post('/complaints', json={
            'studentId': student_id,
            'category': 'Hostel/Room',
            'title': 'Broken geyser in Room 204',
            'description': 'Geyser tripping main MCB continuously',
            'location': 'Hostel C, Room 204',
            'priority': 'HIGH'
        })
        assert create_res.status_code == 201, f"Expected 201, got {create_res.status_code}: {create_res.data}"
        c_data = create_res.get_json()['complaint']
        complaint_id = c_data['id']
        closure_otp = c_data.get('closureOtp')
        assert closure_otp is not None, "closureOtp must be present for student creator"
        assert len(str(closure_otp)) == 4, f"Closure OTP must be 4 digits, got: {closure_otp}"
        print(f"  -> [PASS] Complaint created (ID: {complaint_id}) with Student Closure PIN: {closure_otp}")

        # ----------------------------------------------------------------------
        # Test 2: Role-based OTP privacy: Staff cannot see OTP while in progress
        # ----------------------------------------------------------------------
        print("\n[TEST 2] Testing Role-based privacy (Staff cannot spy on Closure OTP)...")
        # Assign to staff
        assign_res = client.post(f'/complaints/{complaint_id}/assign', json={
            'actorId': warden_id,
            'assignedTo': staff_id,
            'remarks': 'Assigned to senior electrician'
        })
        assert assign_res.status_code == 200

        # Start work
        start_res = client.post(f'/complaints/{complaint_id}/action', json={
            'actorId': staff_id,
            'action': 'START',
            'remarks': 'Inspecting thermostat heating element'
        })
        assert start_res.status_code == 200

        # Staff queries complaint
        staff_view = client.get(f'/complaints/{complaint_id}?requesterId={staff_id}')
        assert staff_view.status_code == 200
        staff_view_data = staff_view.get_json()
        assert staff_view_data.get('closureOtp') is None, "Caretaker/Staff must NOT see student's closure OTP"
        assert staff_view_data.get('hasClosureOtp') is True, "hasClosureOtp flag should indicate OTP exists"
        print("  -> [PASS] Staff view correctly hides closureOtp (prevents unauthorized remote closing).")

        # Student queries complaint
        student_view = client.get(f'/complaints/{complaint_id}?requesterId={student_id}')
        assert student_view.status_code == 200
        student_view_data = student_view.get_json()
        assert student_view_data.get('closureOtp') == closure_otp, "Student owner must see their closure OTP"
        print("  -> [PASS] Student owner can securely view closureOtp.")

        # ----------------------------------------------------------------------
        # Test 3: Attempting resolution without OTP fails with 400
        # ----------------------------------------------------------------------
        print("\n[TEST 3] Attempting RESOLVE without OTP (Unilateral closure attempt)...")
        resolve_no_otp = client.post(f'/complaints/{complaint_id}/action', json={
            'actorId': staff_id,
            'action': 'RESOLVE',
            'remarks': 'Replaced heating coil'
        })
        assert resolve_no_otp.status_code == 400, f"Expected 400, got {resolve_no_otp.status_code}"
        assert "closure OTP is required" in resolve_no_otp.get_json()['message']
        print("  -> [PASS] Blocked unilateral resolution without OTP (HTTP 400).")

        # ----------------------------------------------------------------------
        # Test 4: Attempting resolution with WRONG OTP fails with 403
        # ----------------------------------------------------------------------
        print("\n[TEST 4] Attempting RESOLVE with invalid OTP...")
        resolve_bad_otp = client.post(f'/complaints/{complaint_id}/action', json={
            'actorId': staff_id,
            'action': 'RESOLVE',
            'otp': '9999',  # Invalid OTP
            'remarks': 'Replaced heating coil'
        })
        assert resolve_bad_otp.status_code == 403, f"Expected 403, got {resolve_bad_otp.status_code}"
        assert "Invalid Closure OTP" in resolve_bad_otp.get_json()['message']
        print("  -> [PASS] Blocked fraudulent OTP resolution (HTTP 403).")

        # ----------------------------------------------------------------------
        # Test 5: Resolution with valid OTP succeeds via dedicated verify-resolve
        # ----------------------------------------------------------------------
        print("\n[TEST 5] Resolving complaint via 2-Way OTP handshake (/verify-resolve)...")
        resolve_ok = client.post(f'/complaints/{complaint_id}/verify-resolve', json={
            'actorId': staff_id,
            'otp': closure_otp,
            'remarks': 'Replaced heating element and thermostat. Verified temperature cut-off with student.'
        })
        assert resolve_ok.status_code == 200, f"Expected 200, got {resolve_ok.status_code}: {resolve_ok.data}"
        resolved_c = resolve_ok.get_json()['complaint']
        assert resolved_c['status'] == 'RESOLVED'
        assert resolved_c['otpVerifiedAt'] is not None
        print("  -> [PASS] Handshake verified! Status changed to RESOLVED with verified timestamp.")

        # ----------------------------------------------------------------------
        # Test 6: Student post-resolution rating & feedback (5 Stars)
        # ----------------------------------------------------------------------
        print("\n[TEST 6] Student submitting 5-star rating & feedback...")
        fb_res = client.post(f'/complaints/{complaint_id}/feedback', json={
            'studentId': student_id,
            'rating': 5,
            'feedback': 'Geyser is working properly now and heating fast. Great work!'
        })
        assert fb_res.status_code == 200, f"Expected 200, got {fb_res.status_code}"
        fb_data = fb_res.get_json()['complaint']
        assert fb_data['studentRating'] == 5
        assert fb_data['studentFeedback'] == 'Geyser is working properly now and heating fast. Great work!'
        print("  -> [PASS] Student feedback & rating persisted successfully.")

        # ----------------------------------------------------------------------
        # Test 7: SLA Escalation Slingshot Evaluation (>24h Tier 2, >48h Tier 3)
        # ----------------------------------------------------------------------
        print("\n[TEST 7] Testing SLA Escalation Slingshot Engine...")
        # Create a 30-hour old ticket (Tier 2) and a 55-hour old ticket (Tier 3)
        now = datetime.datetime.now()
        dt_30h = (now - datetime.timedelta(hours=30)).isoformat()
        dt_55h = (now - datetime.timedelta(hours=55)).isoformat()

        c_tier2 = Complaint(
            student_id=student_id,
            category='Plumbing',
            title='Leaking flush tank',
            description='Water overflowing from cistern',
            location='Hostel C, Room 102',
            priority='HIGH',
            status='PENDING',
            created_at=dt_30h
        )
        c_tier3 = Complaint(
            student_id=student_id,
            category='Electrical',
            title='Ceiling fan making screeching noise',
            description='Bearing worn out, fan vibrating violently',
            location='Hostel C, Room 305',
            priority='URGENT',
            status='PENDING',
            created_at=dt_55h
        )
        db.session.add(c_tier2)
        db.session.add(c_tier3)
        db.session.commit()

        # Trigger Slingshot evaluation
        slingshot_eval = client.post('/complaints/slingshot/evaluate')
        assert slingshot_eval.status_code == 200
        eval_data = slingshot_eval.get_json()
        assert eval_data['escalatedToTier2Count'] >= 1
        assert eval_data['escalatedToTier3Count'] >= 1
        print(f"  -> [PASS] Slingshot evaluated: {eval_data['escalatedToTier2Count']} escalated to Tier 2 (Warden Alert), {eval_data['escalatedToTier3Count']} escalated to Tier 3 (Dean Slingshot).")

        # Verify DB records
        c_tier2_refreshed = Complaint.query.get(c_tier2.id)
        assert c_tier2_refreshed.escalation_level == 2, f"Expected tier 2, got {c_tier2_refreshed.escalation_level}"

        c_tier3_refreshed = Complaint.query.get(c_tier3.id)
        assert c_tier3_refreshed.escalation_level == 3, f"Expected tier 3, got {c_tier3_refreshed.escalation_level}"
        assert c_tier3_refreshed.vendor_penalty_flag is True, "Tier 3 must trigger vendor penalty flag"
        assert c_tier3_refreshed.vendor_penalty_amount == 500.0, "Tier 3 penalty should be ₹500"
        print("  -> [PASS] Tier 3 SLA breach applied ₹500 vendor contractual deduction penalty.")

        # ----------------------------------------------------------------------
        # Test 8: Slingshot Dashboard API
        # ----------------------------------------------------------------------
        print("\n[TEST 8] Querying Slingshot Executive Dashboard API...")
        dash_res = client.get('/complaints/slingshot/dashboard')
        assert dash_res.status_code == 200
        dash_data = dash_res.get_json()
        assert dash_data['tier2WardenAlert'] >= 1
        assert dash_data['tier3DeanSlingshot'] >= 1
        assert dash_data['vendorPenaltiesTriggered'] >= 1
        assert dash_data['totalVendorPenaltyAmount'] >= 500.0
        assert len(dash_data['slingshotTickets']) >= 2
        print(f"  -> [PASS] Dashboard verified: Total Penalty: ₹{dash_data['totalVendorPenaltyAmount']}, Active Breaches: {len(dash_data['slingshotTickets'])}")

        print("\n" + "=" * 75)
        print("FEATURE 2 BACKEND TEST VERIFICATION: ALL 8 TEST SUITES PASSED! [100%]")
        print("=" * 75)


if __name__ == '__main__':
    run_feature2_tests()
