"""
CampusOS Gate Security Workflow & Warden Approval Backend Test Suite.
Tests:
- Institutional authentication & public registration prevention
- Warden approval authority & audit generation
- Gate Pass lifecycle: PENDING -> APPROVED -> ISSUED -> EXITED -> RETURNED
- HMAC-SHA256 signature verification & tamper rejection
- Anti-replay and idempotency handling (duplicate exits/returns)
- Offline batch synchronization
- Gate operational summary & activity timeline
"""

import os
import sys
import json
import uuid
import datetime

sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))

from app import (
    app, db, User, LeaveRequest, GatePass, RequestAudit,
    generate_signed_credential, verify_signed_credential,
    get_gate_pass_secret, GATE_PASS_SECRET
)

def run_tests():
    print("=" * 70)
    print("CAMPUSOS GATE SECURITY & WARDEN APPROVAL TEST SUITE")
    print("=" * 70)

    client = app.test_client()

    with app.app_context():
        # Setup test entities
        # 1. Student
        student = User.query.filter_by(email="gate_student_test@campusos.edu").first()
        if not student:
            student = User(
                id=str(uuid.uuid4()),
                email="gate_student_test@campusos.edu",
                password="password123",
                name="Rohan Verma",
                role="student",
                registration_number="REG-GATE-001",
                course="B.Tech",
                branch="CSE",
                year="3"
            )
            db.session.add(student)

        # 2. Warden
        warden = User.query.filter_by(email="gate_warden_test@campusos.edu").first()
        if not warden:
            warden = User(
                id=str(uuid.uuid4()),
                email="gate_warden_test@campusos.edu",
                password="password123",
                name="Warden Sharma",
                role="warden"
            )
            db.session.add(warden)

        # 3. Security Guard (Primary)
        guard = User.query.filter_by(email="gate_guard_test@campusos.edu").first()
        if not guard:
            guard = User(
                id=str(uuid.uuid4()),
                email="gate_guard_test@campusos.edu",
                password="password123",
                name="Guard Bahadur",
                role="security"
            )
            db.session.add(guard)

        # 4. Security Guard 2 (for impersonation tests)
        guard2 = User.query.filter_by(email="gate_guard_test2@campusos.edu").first()
        if not guard2:
            guard2 = User(
                id=str(uuid.uuid4()),
                email="gate_guard_test2@campusos.edu",
                password="password123",
                name="Guard Singh",
                role="security"
            )
            db.session.add(guard2)

        # 5. Teacher
        teacher = User.query.filter_by(role="teacher").first()
        if not teacher:
            teacher = User(
                id=str(uuid.uuid4()),
                email="gate_teacher_test@campusos.edu",
                password="password123",
                name="Prof. Sharma",
                role="teacher"
            )
            db.session.add(teacher)

        # 6. Admin
        admin = User.query.filter_by(role="admin").first()
        if not admin:
            admin = User(
                id=str(uuid.uuid4()),
                email="gate_admin_test@campusos.edu",
                password="password123",
                name="Admin Chief",
                role="admin"
            )
            db.session.add(admin)

        # 7. Mess Staff
        mess_staff = User.query.filter_by(role="mess_staff").first()
        if not mess_staff:
            mess_staff = User(
                id=str(uuid.uuid4()),
                email="gate_mess_test@campusos.edu",
                password="password123",
                name="Mess Chef",
                role="mess_staff"
            )
            db.session.add(mess_staff)

        db.session.commit()

        # =====================================================================
        # TEST 1: Institutional Security Role & Registration Restriction
        # =====================================================================
        print("\n[TEST 1] Security and Warden Public Registration Prevention...")
        reg_resp = client.post('/register', json={
            "email": f"hacker_guard_{uuid.uuid4().hex[:4]}@campusos.edu",
            "password": "password",
            "name": "Fake Guard",
            "role": "security"
        })
        assert reg_resp.status_code == 403, f"Expected 403, got {reg_resp.status_code}"
        print("  -> Passed: Public registration of 'security' role blocked with 403.")

        reg_resp_warden = client.post('/register', json={
            "email": f"hacker_warden_{uuid.uuid4().hex[:4]}@campusos.edu",
            "password": "password",
            "name": "Fake Warden",
            "role": "warden"
        })
        assert reg_resp_warden.status_code == 403, f"Expected 403, got {reg_resp_warden.status_code}"
        print("  -> Passed: Public registration of 'warden' role blocked with 403.")

        # =====================================================================
        # TEST 2: Unified Login for Security and Warden
        # =====================================================================
        print("\n[TEST 2] Unified Login for Security and Warden...")
        login_resp = client.post('/login', json={
            "email": guard.email,
            "password": "password123"
        })
        assert login_resp.status_code == 200
        guard_data = login_resp.get_json()['user']
        assert guard_data['role'] == 'security'
        print(f"  -> Passed: Security login successful (User: {guard_data['name']})")

        login_resp_w = client.post('/login', json={
            "email": warden.email,
            "password": "password123"
        })
        assert login_resp_w.status_code == 200
        assert login_resp_w.get_json()['user']['role'] == 'warden'
        print("  -> Passed: Warden login successful.")

        # =====================================================================
        # TEST 3: Student Leave Submission & Warden Approval Chain
        # =====================================================================
        print("\n[TEST 3] Leave Request Creation & Institutional Warden Approval...")
        tomorrow = (datetime.date.today() + datetime.timedelta(days=1)).isoformat()
        day_after = (datetime.date.today() + datetime.timedelta(days=3)).isoformat()

        leave_post = client.post('/requests/leave', json={
            "studentId": student.id,
            "leaveType": "HOME",
            "startDate": tomorrow,
            "endDate": day_after,
            "reason": "Attending family function"
        })
        assert leave_post.status_code == 201, f"Leave post failed: {leave_post.get_json()}"
        leave_id = leave_post.get_json()['request']['id']
        print(f"  -> Created LeaveRequest ID: {leave_id}")

        # Security must NOT be allowed to approve leave
        unauth_action = client.post(f'/requests/leave/{leave_id}/action', json={
            "reviewerId": guard.id,
            "action": "APPROVE"
        })
        assert unauth_action.status_code == 403, f"Expected 403 for security approving leave, got {unauth_action.status_code}"
        print("  -> Passed: Security guard blocked from approving student leave (403 Forbidden).")

        # Warden pending inbox
        warden_inbox = client.get('/warden/leave-requests/pending', headers={'X-User-Id': warden.id})
        assert warden_inbox.status_code == 200
        inbox_items = warden_inbox.get_json()
        assert any(item['id'] == leave_id for item in inbox_items)
        print(f"  -> Passed: Leave request visible in Warden Pending Inbox ({len(inbox_items)} pending).")

        # Warden approves leave
        warden_action = client.post(f'/warden/leave-requests/{leave_id}/action', json={
            "reviewerId": warden.id,
            "action": "APPROVE",
            "remarks": "Approved with parental consent"
        })
        assert warden_action.status_code == 200
        assert warden_action.get_json()['request']['status'] == 'APPROVED'
        print("  -> Passed: Warden approved leave request.")

        # =====================================================================
        # TEST 4: Gate Pass Creation, Issuance, & HMAC Credential
        # =====================================================================
        print("\n[TEST 4] Gate Pass Creation, Issuance & Cryptographic Credential...")
        now = datetime.datetime.now()
        exit_time = (now + datetime.timedelta(hours=1)).isoformat()
        return_time = (now + datetime.timedelta(hours=24)).isoformat()

        gp_post = client.post('/requests/gate-pass', json={
            "studentId": student.id,
            "leaveRequestId": leave_id,
            "destination": "Home - Delhi",
            "reason": "Family function",
            "expectedExitTime": exit_time,
            "expectedReturnTime": return_time
        })
        assert gp_post.status_code == 201
        gp_id = gp_post.get_json()['gatePass']['id']

        # Issue the pass
        issue_resp = client.post(f'/requests/gate-pass/{gp_id}/issue', json={"issuerId": warden.id})
        assert issue_resp.status_code == 200
        assert issue_resp.get_json()['gatePass']['status'] == 'ISSUED'
        print(f"  -> Passed: Gate pass {gp_id} issued successfully.")

        # Fetch active gate pass and verify HMAC credential
        active_resp = client.get(f'/requests/gate-pass/active/{student.id}')
        assert active_resp.status_code == 200
        active_data = active_resp.get_json()
        assert active_data['hasActive'] is True
        credential = active_data['credential']
        assert credential is not None
        assert len(credential.split('.')) == 3
        print("  -> Passed: Valid HMAC-SHA256 credential generated.")

        # =====================================================================
        # TEST 5: Gate Pass Verification Endpoint
        # =====================================================================
        print("\n[TEST 5] Gate Pass Verification with HMAC & Tamper Detection...")
        # 1. Verify valid credential
        verify_resp = client.post('/security/gate-pass/verify',
            headers={'X-User-Id': guard.id},
            json={
                "credential": credential,
                "securityGuardId": guard.id,
                "gateName": "Main North Gate"
            }
        )
        assert verify_resp.status_code == 200
        v_data = verify_resp.get_json()
        assert v_data['valid'] is True
        assert v_data['resultCode'] == 'VERIFIED'
        assert v_data['action'] == 'EXIT'
        assert v_data['student']['name'] == student.name
        print("  -> Passed: Valid HMAC credential correctly verified by Gate Security.")

        # 2. Tampered signature
        tampered_token = credential[:-5] + "XXXXX"
        tamper_resp = client.post('/security/gate-pass/verify',
            headers={'X-User-Id': guard.id},
            json={
                "credential": tampered_token,
                "securityGuardId": guard.id
            }
        )
        assert tamper_resp.status_code == 200
        t_data = tamper_resp.get_json()
        assert t_data['valid'] is False
        assert t_data['resultCode'] == 'INVALID_CREDENTIAL'
        print("  -> Passed: Tampered HMAC credential strictly rejected as INVALID_CREDENTIAL.")

        # =====================================================================
        # TEST 6: Student Exit Flow & Idempotency
        # =====================================================================
        print("\n[TEST 6] Student Exit Operation & Replay / Duplicate Protection...")
        idem_key_exit = f"idem-exit-{uuid.uuid4().hex[:8]}"

        exit_resp = client.post(f'/security/gate-pass/{gp_id}/exit',
            headers={'X-User-Id': guard.id},
            json={
                "securityGuardId": guard.id,
                "gateName": "Main Gate",
                "verificationMode": "QR_FALLBACK",
                "idempotencyKey": idem_key_exit
            }
        )
        assert exit_resp.status_code == 200
        assert exit_resp.get_json()['resultCode'] == 'EXITED'
        print("  -> Passed: Student exit recorded (ISSUED -> EXITED).")

        # Duplicate exit attempt with different key
        dup_exit = client.post(f'/security/gate-pass/{gp_id}/exit',
            headers={'X-User-Id': guard.id},
            json={
                "securityGuardId": guard.id,
                "gateName": "Main Gate",
                "verificationMode": "QR_FALLBACK",
                "idempotencyKey": "different-key-123"
            }
        )
        assert dup_exit.status_code == 409
        assert dup_exit.get_json()['resultCode'] == 'ALREADY_PROCESSED'
        print("  -> Passed: Duplicate exit prevented with 409 ALREADY_PROCESSED.")

        # Idempotent replay with same key
        idemp_exit = client.post(f'/security/gate-pass/{gp_id}/exit',
            headers={'X-User-Id': guard.id},
            json={
                "securityGuardId": guard.id,
                "idempotencyKey": idem_key_exit
            }
        )
        assert idemp_exit.status_code == 200
        assert idemp_exit.get_json()['resultCode'] == 'ALREADY_PROCESSED'
        print("  -> Passed: Idempotent replay with identical key returns 200 successfully.")

        # =====================================================================
        # TEST 7: Return Flow & Duplicate Return Protection
        # =====================================================================
        print("\n[TEST 7] Student Return Operation & Lifecyle Constraints...")
        # Verify credential for returning student
        verify_return = client.post('/security/gate-pass/verify',
            headers={'X-User-Id': guard.id},
            json={
                "credential": credential,
                "securityGuardId": guard.id
            }
        )
        assert verify_return.status_code == 200
        vr_data = verify_return.get_json()
        assert vr_data['valid'] is True
        assert vr_data['action'] == 'RETURN'
        print("  -> Passed: Verification for EXITED pass correctly prompts action=RETURN.")

        # Mark Returned
        idem_key_return = f"idem-return-{uuid.uuid4().hex[:8]}"
        return_resp = client.post(f'/security/gate-pass/{gp_id}/return',
            headers={'X-User-Id': guard.id},
            json={
                "securityGuardId": guard.id,
                "gateName": "Main Gate",
                "verificationMode": "BLE",
                "idempotencyKey": idem_key_return
            }
        )
        assert return_resp.status_code == 200
        assert return_resp.get_json()['resultCode'] == 'RETURNED'
        print("  -> Passed: Student return recorded (EXITED -> RETURNED).")

        # Duplicate return attempt rejected
        dup_return = client.post(f'/security/gate-pass/{gp_id}/return',
            headers={'X-User-Id': guard.id},
            json={
                "securityGuardId": guard.id,
                "gateName": "Main Gate",
                "idempotencyKey": "dup-key-999"
            }
        )
        assert dup_return.status_code == 409
        assert dup_return.get_json()['resultCode'] == 'ALREADY_PROCESSED'
        print("  -> Passed: Repeated RETURNED -> RETURNED rejected with 409 ALREADY_PROCESSED.")

        # Returned pass cannot exit again
        exit_again = client.post(f'/security/gate-pass/{gp_id}/exit',
            headers={'X-User-Id': guard.id},
            json={"securityGuardId": guard.id}
        )
        assert exit_again.status_code == 409
        print("  -> Passed: RETURNED pass cannot exit again.")

        # =====================================================================
        # TEST 8: Offline Batch Synchronization
        # =====================================================================
        print("\n[TEST 8] Offline Batch Synchronization...")
        # Create a second pass for offline testing
        gp2 = GatePass(
            student_id=student.id,
            leave_request_id=leave_id,
            destination="Library",
            reason="Research",
            expected_exit_time=exit_time,
            expected_return_time=return_time,
            status='ISSUED',
            qr_nonce=str(uuid.uuid4())
        )
        db.session.add(gp2)
        db.session.commit()

        batch_payload = {
            "events": [
                {
                    "passId": gp2.id,
                    "action": "EXIT",
                    "securityGuardId": guard.id,
                    "gateName": "South Gate",
                    "verificationMode": "OFFLINE_SYNC",
                    "idempotencyKey": f"offline-exit-{uuid.uuid4().hex[:6]}",
                    "timestamp": datetime.datetime.now().isoformat()
                }
            ]
        }
        sync_resp = client.post('/security/gate-pass/batch-sync',
            headers={'X-User-Id': guard.id},
            json=batch_payload
        )
        assert sync_resp.status_code == 200
        s_data = sync_resp.get_json()
        assert s_data['syncedCount'] == 1
        assert s_data['results'][0]['status'] == 'CONFIRMED'
        print("  -> Passed: Offline batch sync processed and confirmed.")

        # =====================================================================
        # TEST 9: Security Summary & Activity Endpoints
        # =====================================================================
        print("\n[TEST 9] Security Command Center Summary & Activity Timeline...")
        summary_resp = client.get('/security/gate-pass/summary', headers={'X-User-Id': guard.id})
        assert summary_resp.status_code == 200
        sum_data = summary_resp.get_json()
        assert sum_data['gateStatus'] == 'ONLINE'
        assert 'activeShift' in sum_data
        print(f"  -> Passed: Gate summary metrics retrieved: {sum_data['activeShift']}")

        passes_resp = client.get('/security/gate-passes?status=ALL', headers={'X-User-Id': guard.id})
        assert passes_resp.status_code == 200
        assert len(passes_resp.get_json()) >= 2
        print(f"  -> Passed: Operational passes list retrieved ({len(passes_resp.get_json())} passes).")

        activity_resp = client.get('/security/gate-pass/activity?filter=ALL', headers={'X-User-Id': guard.id})
        assert activity_resp.status_code == 200
        acts = activity_resp.get_json()
        assert len(acts) >= 3
        print(f"  -> Passed: Activity timeline retrieved ({len(acts)} events).")

        # =====================================================================
        # TEST 10: Specific Security Audit Regression Scenarios (A through P)
        # =====================================================================
        print("\n[TEST 10] Gate Security Audit Verification Regression Tests (A - P)...")

        # Setup an active ISSUED pass for transit testing
        gp_audit = GatePass(
            student_id=student.id,
            leave_request_id=leave_id,
            destination="Audit Testing Lab",
            reason="Regression verification",
            expected_exit_time=exit_time,
            expected_return_time=return_time,
            status='ISSUED',
            qr_nonce=str(uuid.uuid4())
        )
        db.session.add(gp_audit)
        db.session.commit()

        # A. STUDENT calling /security/gate-pass/summary -> 403
        res_a = client.get('/security/gate-pass/summary', headers={'X-User-Id': student.id})
        assert res_a.status_code == 403, f"A failed: expected 403 for student summary, got {res_a.status_code}"
        print("  [A] Passed: STUDENT calling /security/gate-pass/summary -> 403 Forbidden.")

        # B. STUDENT calling /security/gate-pass/<id>/exit -> 403
        res_b = client.post(f'/security/gate-pass/{gp_audit.id}/exit',
            headers={'X-User-Id': student.id},
            json={"securityGuardId": guard.id}
        )
        assert res_b.status_code == 403, f"B failed: expected 403 for student exit, got {res_b.status_code}"
        print("  [B] Passed: STUDENT calling /security/gate-pass/<id>/exit -> 403 Forbidden.")

        # C. STUDENT calling /security/gate-pass/<id>/return -> 403
        res_c = client.post(f'/security/gate-pass/{gp_audit.id}/return',
            headers={'X-User-Id': student.id},
            json={"securityGuardId": guard.id}
        )
        assert res_c.status_code == 403, f"C failed: expected 403 for student return, got {res_c.status_code}"
        print("  [C] Passed: STUDENT calling /security/gate-pass/<id>/return -> 403 Forbidden.")

        # D. TEACHER calling Security endpoints -> 403
        res_d1 = client.get('/security/gate-pass/summary', headers={'X-User-Id': teacher.id})
        assert res_d1.status_code == 403, f"D1 failed: got {res_d1.status_code}"
        res_d2 = client.get('/security/gate-passes', headers={'X-User-Id': teacher.id})
        assert res_d2.status_code == 403, f"D2 failed: got {res_d2.status_code}"
        res_d3 = client.post(f'/security/gate-pass/{gp_audit.id}/exit', headers={'X-User-Id': teacher.id}, json={})
        assert res_d3.status_code == 403, f"D3 failed: got {res_d3.status_code}"
        print("  [D] Passed: TEACHER calling Security endpoints -> 403 Forbidden.")

        # E. WARDEN calling Security transit endpoints -> 403
        res_e1 = client.post(f'/security/gate-pass/{gp_audit.id}/exit', headers={'X-User-Id': warden.id}, json={})
        assert res_e1.status_code == 403, f"E1 failed: got {res_e1.status_code}"
        res_e2 = client.post(f'/security/gate-pass/{gp_audit.id}/return', headers={'X-User-Id': warden.id}, json={})
        assert res_e2.status_code == 403, f"E2 failed: got {res_e2.status_code}"
        print("  [E] Passed: WARDEN calling Security transit endpoints -> 403 Forbidden.")

        # F. SECURITY calling Security endpoints -> allowed (200)
        res_f1 = client.get('/security/gate-pass/summary', headers={'X-User-Id': guard.id})
        assert res_f1.status_code == 200, f"F1 failed: got {res_f1.status_code}"
        res_f2 = client.get('/security/gate-passes', headers={'X-User-Id': guard.id})
        assert res_f2.status_code == 200, f"F2 failed: got {res_f2.status_code}"
        res_f3 = client.get('/security/gate-pass/activity', headers={'X-User-Id': guard.id})
        assert res_f3.status_code == 200, f"F3 failed: got {res_f3.status_code}"
        print("  [F] Passed: SECURITY calling Security endpoints -> 200 OK Allowed.")

        # G. SECURITY trying to approve Gate Pass -> 403
        gp_pending = GatePass(
            student_id=student.id,
            leave_request_id=leave_id,
            destination="Market",
            reason="Purchases",
            expected_exit_time=exit_time,
            expected_return_time=return_time,
            status='PENDING',
            qr_nonce=str(uuid.uuid4())
        )
        db.session.add(gp_pending)
        db.session.commit()

        res_g = client.post(f'/requests/gate-pass/{gp_pending.id}/action',
            headers={'X-User-Id': guard.id},
            json={"reviewerId": guard.id, "action": "APPROVE"}
        )
        assert res_g.status_code == 403, f"G failed: expected 403 for security approving gate pass, got {res_g.status_code}"
        print("  [G] Passed: SECURITY trying to approve Gate Pass -> 403 Forbidden.")

        # H. STUDENT trying to approve Gate Pass -> 403
        res_h = client.post(f'/requests/gate-pass/{gp_pending.id}/action',
            headers={'X-User-Id': student.id},
            json={"reviewerId": student.id, "action": "APPROVE"}
        )
        assert res_h.status_code == 403, f"H failed: expected 403 for student approving gate pass, got {res_h.status_code}"
        print("  [H] Passed: STUDENT trying to approve Gate Pass -> 403 Forbidden.")

        # I. SECURITY supplying another user's securityGuardId -> authenticated actor ID must still be used
        res_i = client.post(f'/security/gate-pass/{gp_audit.id}/exit',
            headers={'X-User-Id': guard.id},
            json={
                "securityGuardId": guard2.id,  # Attempt to spoof guard2
                "gateName": "South Gate",
                "verificationMode": "QR_FALLBACK",
                "idempotencyKey": f"audit-exit-{uuid.uuid4().hex[:6]}"
            }
        )
        assert res_i.status_code == 200, f"I exit failed: got {res_i.status_code}"
        db.session.refresh(gp_audit)
        assert gp_audit.security_guard_id == guard.id, f"I failed: expected guard.id {guard.id}, got {gp_audit.security_guard_id}"
        latest_audit = RequestAudit.query.filter_by(entity_id=gp_audit.id, action='SCANNED_OUT').order_by(RequestAudit.id.desc()).first()
        assert latest_audit.actor_id == guard.id, f"I audit failed: expected {guard.id}, got {latest_audit.actor_id}"
        print("  [I] Passed: SECURITY supplying another user's securityGuardId overwritten with authenticated ID.")

        # J. Gate Pass action without Warden authorization -> 403
        res_j_teacher = client.post(f'/requests/gate-pass/{gp_pending.id}/action',
            headers={'X-User-Id': teacher.id},
            json={"reviewerId": teacher.id, "action": "APPROVE"}
        )
        assert res_j_teacher.status_code == 403, f"J teacher failed: got {res_j_teacher.status_code}"
        res_j_mess = client.post(f'/requests/gate-pass/{gp_pending.id}/action',
            headers={'X-User-Id': mess_staff.id},
            json={"reviewerId": mess_staff.id, "action": "APPROVE"}
        )
        assert res_j_mess.status_code == 403, f"J mess failed: got {res_j_mess.status_code}"
        # Warden approval succeeds
        res_j_warden = client.post(f'/requests/gate-pass/{gp_pending.id}/action',
            headers={'X-User-Id': warden.id},
            json={"reviewerId": warden.id, "action": "APPROVE"}
        )
        assert res_j_warden.status_code == 200, f"J warden failed: got {res_j_warden.status_code}"
        print("  [J] Passed: Gate Pass action without Warden authorization strictly rejected with 403.")

        # K. Missing GATE_PASS_SECRET -> application/configuration error, no default secret
        orig_sec = os.environ.get('GATE_PASS_SECRET')
        try:
            if 'GATE_PASS_SECRET' in os.environ:
                del os.environ['GATE_PASS_SECRET']
            try:
                get_gate_pass_secret()
                assert False, "Should have raised RuntimeError when GATE_PASS_SECRET is missing"
            except RuntimeError as re:
                assert "CRITICAL CONFIGURATION ERROR" in str(re)
        finally:
            if orig_sec is not None:
                os.environ['GATE_PASS_SECRET'] = orig_sec
        print("  [K] Passed: Missing GATE_PASS_SECRET raises RuntimeError with no default secret.")

        # L. Valid HMAC Gate Pass -> still works
        valid_payload = {
            "gatePassId": gp_audit.id,
            "studentId": student.id,
            "nonce": gp_audit.qr_nonce,
            "destination": gp_audit.destination,
            "expiresAt": return_time
        }
        valid_hmac_token = generate_signed_credential(valid_payload)
        ok_l, payload_l, _ = verify_signed_credential(valid_hmac_token)
        assert ok_l is True and payload_l['gatePassId'] == gp_audit.id
        print("  [L] Passed: Valid HMAC-SHA256 Gate Pass verified successfully.")

        # M. Tampered HMAC -> still rejected
        tampered_hmac_token = valid_hmac_token[:-6] + "BADSIG"
        ok_m, _, _ = verify_signed_credential(tampered_hmac_token)
        assert ok_m is False
        print("  [M] Passed: Tampered HMAC signature strictly rejected.")

        # N. EXITED -> RETURNED still works
        res_n = client.post(f'/security/gate-pass/{gp_audit.id}/return',
            headers={'X-User-Id': guard.id},
            json={
                "gateName": "South Gate",
                "verificationMode": "QR_FALLBACK",
                "idempotencyKey": f"audit-ret-{uuid.uuid4().hex[:6]}"
            }
        )
        assert res_n.status_code == 200, f"N failed: got {res_n.status_code}"
        assert res_n.get_json()['resultCode'] == 'RETURNED'
        print("  [N] Passed: EXITED -> RETURNED workflow completed successfully.")

        # O. Duplicate EXIT -> still rejected/idempotent
        res_o = client.post(f'/security/gate-pass/{gp_audit.id}/exit',
            headers={'X-User-Id': guard.id},
            json={"gateName": "South Gate"}
        )
        assert res_o.status_code == 409, f"O failed: expected 409 for duplicate exit, got {res_o.status_code}"
        print("  [O] Passed: Duplicate EXIT attempt rejected with 409 ALREADY_PROCESSED.")

        # P. Duplicate RETURN -> still rejected/idempotent
        res_p = client.post(f'/security/gate-pass/{gp_audit.id}/return',
            headers={'X-User-Id': guard.id},
            json={"gateName": "South Gate"}
        )
        assert res_p.status_code == 409, f"P failed: expected 409 for duplicate return, got {res_p.status_code}"
        print("  [P] Passed: Duplicate RETURN attempt rejected with 409 ALREADY_PROCESSED.")

        print("\n" + "=" * 70)
        print("ALL BACKEND GATE SECURITY, WARDEN & REGRESSION AUDIT TESTS PASSED!")
        print("=" * 70)

if __name__ == '__main__':
    run_tests()
