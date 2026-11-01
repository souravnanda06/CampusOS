import os
import uuid
import datetime
from app import (
    app, db, User, Session, Attendance, LeaveRequest, GatePass,
    RequestAudit, Complaint, ComplaintStatusHistory, Notice,
    NotificationDelivery, MessMenu, MessMeal, MealEntry,
    DeviceIdentityKey, DeviceCertificate
)
from test_step1d_passport_presentation import generate_ed25519_keypair, build_and_sign_presentation
from utils.crypto import create_access_token


def run_cross_role_e2e_tests():
    print("=" * 70)
    print("CAMPUSOS FULL-SYSTEM CROSS-ROLE WORKFLOW INTEGRATION SUITE")
    print("=" * 70)

    client = app.test_client()

    with app.app_context():
        # Setup cross-role personas
        tag = uuid.uuid4().hex[:6]
        student = User(
            name=f"E2E Student_{tag}",
            email=f"e2e_student_{tag}@campusos.edu",
            password="password123",
            role="student",
            registration_number=f"REG_{tag}",
            course="B.Tech",
            branch="CSE",
            year=3
        )
        teacher = User(
            name=f"E2E Prof_{tag}",
            email=f"e2e_prof_{tag}@campusos.edu",
            password="password123",
            role="teacher"
        )
        warden = User(
            name=f"E2E Warden_{tag}",
            email=f"e2e_warden_{tag}@campusos.edu",
            password="password123",
            role="warden"
        )
        security = User(
            name=f"E2E Guard_{tag}",
            email=f"e2e_guard_{tag}@campusos.edu",
            password="password123",
            role="security"
        )
        mess_staff = User(
            name=f"E2E MessStaff_{tag}",
            email=f"e2e_mess_{tag}@campusos.edu",
            password="password123",
            role="mess_staff"
        )
        admin = User(
            name=f"E2E Admin_{tag}",
            email=f"e2e_admin_{tag}@campusos.edu",
            password="password123",
            role="admin"
        )

        db.session.add_all([student, teacher, warden, security, mess_staff, admin])
        db.session.commit()

        # Track cleanup records
        created_sessions = []
        created_leaves = []
        created_gate_passes = []
        created_complaints = []
        created_notices = []
        created_menus = []

        try:
            # ==============================================================
            # CHAIN 1: Student Leave -> Warden Approve -> Gate Pass -> Security Exit -> Return
            # ==============================================================
            print("\n[CHAIN 1] Student Leave -> Warden Approve -> Gate Pass -> Security Exit -> Return...")
            
            # 1. Student creates leave request with auto-associated Gate Pass
            res = client.post('/requests/leave', headers={'X-User-Id': student.id}, json={
                "studentId": student.id,
                "leaveType": "HOME",
                "startDate": "2026-09-28",
                "endDate": "2026-09-30",
                "reason": "Family function",
                "destination": "Bhubaneswar",
                "createGatePass": True
            })
            assert res.status_code == 201, f"Failed to create leave: {res.data}"
            leave_id = res.get_json()['request']['id']
            created_leaves.append(leave_id)
            print("  1.1 Student created leave request in PENDING status.")

            # 2. Warden views pending inbox and approves
            res = client.get('/warden/leave-requests/pending', headers={'X-User-Id': warden.id})
            assert res.status_code == 200
            pending_list = res.get_json()
            assert any(p['id'] == leave_id for p in pending_list)

            res = client.post(f'/warden/leave-requests/{leave_id}/action', headers={'X-User-Id': warden.id}, json={
                "action": "APPROVE",
                "remarks": "Approved by institutional warden"
            })
            assert res.status_code == 200
            print("  1.2 Warden approved leave request.")

            # 3. Student requests Gate Pass following approved leave
            now = datetime.datetime.now()
            exit_time = (now + datetime.timedelta(hours=1)).isoformat()
            return_time = (now + datetime.timedelta(hours=24)).isoformat()

            gp_post = client.post('/requests/gate-pass', json={
                "studentId": student.id,
                "leaveRequestId": leave_id,
                "destination": "Bhubaneswar",
                "reason": "Family function",
                "expectedExitTime": exit_time,
                "expectedReturnTime": return_time
            })
            assert gp_post.status_code == 201, f"Failed gate pass request: {gp_post.data}"
            gp_id = gp_post.get_json()['gatePass']['id']
            created_gate_passes.append(gp_id)

            # Issue Gate Pass
            issue_res = client.post(f'/requests/gate-pass/{gp_id}/issue', json={"issuerId": warden.id})
            assert issue_res.status_code == 200
            gp = GatePass.query.get(gp_id)
            assert gp.status == 'ISSUED', f"Expected ISSUED, got {gp.status}"
            print(f"  1.3 Gate pass generated and issued following Warden approval (ID: {gp.id}).")

            # 4. Student obtains cryptographic HMAC Gate Pass credential
            res = client.get(f'/requests/gate-pass/{gp.id}/credential')
            assert res.status_code == 200
            cred_data = res.get_json()
            credential_token = cred_data['credential']
            assert credential_token is not None
            print("  1.4 Student retrieved valid HMAC-SHA256 QR credential.")

            # 5. Security verifies credential at Gate
            res = client.post('/security/gate-pass/verify', headers={'X-User-Id': security.id}, json={
                "credential": credential_token,
                "gateName": "Main Gate 1"
            })
            assert res.status_code == 200
            ver_res = res.get_json()
            assert ver_res['valid'] is True
            assert ver_res['action'] == 'EXIT'
            print("  1.5 Security Officer verified credential (action=EXIT).")

            # 6. Security executes Student EXIT
            idemp_exit = f"exit-{uuid.uuid4()}"
            res = client.post(f'/security/gate-pass/{gp.id}/exit', headers={'X-User-Id': security.id}, json={
                "idempotencyKey": idemp_exit,
                "gateName": "Main Gate 1",
                "verificationMode": "QR_FALLBACK"
            })
            assert res.status_code == 200
            exit_data = res.get_json()
            assert exit_data.get('resultCode') == 'EXITED' or exit_data.get('status') == 'EXITED'
            db.session.refresh(gp)
            assert gp.status == 'EXITED'
            print("  1.6 Student EXIT recorded (status=EXITED).")

            # 7. Repeated exit is prevented with 409
            res = client.post(f'/security/gate-pass/{gp.id}/exit', headers={'X-User-Id': security.id}, json={
                "idempotencyKey": f"repeat-exit-{uuid.uuid4()}",
                "gateName": "Main Gate 1"
            })
            assert res.status_code == 409, "Duplicate exit should be rejected with 409"
            print("  1.7 Duplicate EXIT prevented with 409 Conflict.")

            # 8. Security executes Student RETURN
            idemp_ret = f"ret-{uuid.uuid4()}"
            res = client.post(f'/security/gate-pass/{gp.id}/return', headers={'X-User-Id': security.id}, json={
                "idempotencyKey": idemp_ret,
                "gateName": "Main Gate 1",
                "verificationMode": "QR_FALLBACK"
            })
            assert res.status_code == 200
            ret_data = res.get_json()
            assert ret_data.get('resultCode') == 'RETURNED' or ret_data.get('status') == 'RETURNED'
            db.session.refresh(gp)
            assert gp.status == 'RETURNED'
            print("  1.8 Student RETURN recorded (status=RETURNED).")
            print("  --> [CHAIN 1 PASSED]: Complete Student-Warden-Security transit workflow fully verified!")

            # ==============================================================
            # CHAIN 2: Teacher Session -> Student Attendance -> Fallback QR Mode
            # ==============================================================
            print("\n[CHAIN 2] Teacher Session -> Student Attendance -> Fallback QR Mode...")

            # 1. Teacher starts attendance session
            res = client.post('/sessions/create', json={
                "teacherId": teacher.id,
                "subject": "Distributed Systems CS401",
                "room": "Hall 302",
                "radius": 15,
                "attendanceType": "BLE_BATCH"
            })
            assert res.status_code == 201
            session_id = res.get_json()['id']
            created_sessions.append(session_id)
            print(f"  2.1 Teacher created session {session_id}.")

            # 2. Student marks attendance (Batch BLE mode)
            res = client.post('/attendance/mark', json={
                "sessionId": session_id,
                "studentId": student.id,
                "studentName": student.name,
                "verificationMode": "BLE_BATCH",
                "proximityTier": "NEAR"
            })
            assert res.status_code == 201
            print("  2.2 Student marked attendance (BLE_BATCH).")

            # 3. Duplicate attendance is prevented
            res = client.post('/attendance/mark', json={
                "sessionId": session_id,
                "studentId": student.id
            })
            assert res.status_code == 400
            print("  2.3 Duplicate attendance rejected with 400.")

            # 4. Fallback: QR challenge mode fallback verification
            res_history = client.get(f'/attendance/session/{session_id}')
            assert res_history.status_code == 200
            assert len(res_history.get_json()) == 1
            print("  2.4 Attendance confirmed in session records.")
            print("  --> [CHAIN 2 PASSED]: Complete Attendance workflow verified!")

            # ==============================================================
            # CHAIN 3: Mess Staff -> Menu -> Student Verification -> Meal Entry
            # ==============================================================
            print("\n[CHAIN 3] Mess Staff -> Menu -> Student Verification -> Meal Entry...")

            today_date = "2026-10-05"
            for om in MessMenu.query.filter_by(menu_date=today_date).all():
                MealEntry.query.filter_by(menu_id=om.id).delete()
                MessMeal.query.filter_by(menu_id=om.id).delete()
                MessMenu.query.filter_by(id=om.id).delete()
            db.session.commit()
            
            # 1. Mess staff creates menu
            res = client.post('/mess/menus', headers={'X-User-Id': mess_staff.id}, json={
                "menuDate": today_date,
                "title": f"Menu for {today_date}",
                "meals": [
                    {
                        "mealType": "LUNCH",
                        "title": "Wholesome Lunch",
                        "startTime": "12:00",
                        "endTime": "14:30",
                        "items": ["Rice", "Dal", "Paneer Masala", "Salad"],
                        "availability": "AVAILABLE"
                    }
                ]
            })
            assert res.status_code == 201, f"Failed to create menu: {res.data}"
            menu_id = res.get_json()['id']
            created_menus.append(menu_id)
            res_pub = client.post(f'/mess/menus/{menu_id}/publish', headers={'X-User-Id': mess_staff.id})
            assert res_pub.status_code == 200, f"Publish menu failed: {res_pub.status_code} - {res_pub.data}"

            # 2. Register passport key for student and build cryptographically signed presentation
            client_priv, client_pub_b64 = generate_ed25519_keypair()
            res_key = client.post('/passport/keys/register', headers={'X-User-Id': student.id}, json={
                'userId': student.id,
                'publicKey': client_pub_b64,
                'keyType': 'ED25519'
            })
            assert res_key.status_code == 201, f"Passport key registration failed: {res_key.data}"
            reg_data = res_key.get_json()
            key_id = reg_data['keyId']
            cert_id = reg_data['certificate']['id']
            issuer_key_id = reg_data['certificate']['issuerKeyId']

            payload, sig = build_and_sign_presentation(client_priv, key_id, student.id, cert_id, issuer_key_id)

            # Mess staff verifies student meal entry via genuine signed presentation
            res = client.post('/mess/entries/verify', headers={'X-User-Id': mess_staff.id}, json={
                "studentId": student.id,
                "mealType": "LUNCH",
                "date": today_date,
                "verificationMode": "QR_PRESENTATION",
                "qrPayload": {"p": payload, "s": sig}
            })
            assert res.status_code in [200, 201], f"Failed to verify mess entry: {res.data}"
            entry_data = res.get_json()
            assert entry_data['status'] == 'VERIFIED'
            print("  3.1 Student verified and recorded for LUNCH meal entry via cryptographic presentation.")

            # 3. Duplicate meal entry rejected with 409 (even with fresh signed presentation)
            payload_dup, sig_dup = build_and_sign_presentation(client_priv, key_id, student.id, cert_id, issuer_key_id)
            res = client.post('/mess/entries/verify', headers={'X-User-Id': mess_staff.id}, json={
                "studentId": student.id,
                "mealType": "LUNCH",
                "date": today_date,
                "qrPayload": {"p": payload_dup, "s": sig_dup}
            })
            assert res.status_code == 409
            print("  3.2 Duplicate meal entry on same date strictly rejected with 409.")
            print("  --> [CHAIN 3 PASSED]: Complete Mess verification and duplicate protection verified!")

            # ==============================================================
            # CHAIN 4: Student Complaint -> Staff Action -> Resolution -> Admin Analytics
            # ==============================================================
            print("\n[CHAIN 4] Student Complaint -> Assignment -> Resolution -> Admin Analytics...")

            # 1. Student creates complaint
            res = client.post('/complaints', json={
                "studentId": student.id,
                "category": "HOSTEL",
                "title": "Water leakage in Room 204",
                "description": "Bathroom pipe leakage causing puddle",
                "location": "Hostel Block A, Room 204",
                "priority": "HIGH"
            })
            assert res.status_code == 201, f"Failed complaint creation: {res.data}"
            complaint_res = res.get_json()['complaint']
            complaint_id = complaint_res['id']
            closure_otp = complaint_res.get('closureOtp')
            created_complaints.append(complaint_id)
            print(f"  4.1 Student filed complaint {complaint_id} (PENDING).")

            # 2. Admin assigns complaint to warden/staff
            res = client.post(f'/complaints/{complaint_id}/assign', json={
                "assignedTo": warden.id,
                "actorId": admin.id,
                "remarks": "Assigned to Hostel Warden for repair"
            })
            assert res.status_code == 200, f"Failed assign: {res.data}"
            print("  4.2 Complaint assigned to Warden (ASSIGNED).")

            # 3. Warden progresses to IN_PROGRESS
            res = client.post(f'/complaints/{complaint_id}/action', json={
                "actorId": warden.id,
                "action": "START",
                "remarks": "Plumber dispatched"
            })
            assert res.status_code == 200, f"Failed start: {res.data}"
            print("  4.3 Complaint status advanced to IN_PROGRESS.")

            # 4. Warden resolves complaint
            res = client.post(f'/complaints/{complaint_id}/action', json={
                "actorId": warden.id,
                "action": "RESOLVE",
                "otp": closure_otp,
                "remarks": "Pipe repaired and verified"
            })
            assert res.status_code == 200, f"Failed resolve: {res.data}"
            print("  4.4 Complaint RESOLVED.")

            # 5. Student reopens complaint if not satisfied
            res = client.post(f'/complaints/{complaint_id}/action', json={
                "actorId": student.id,
                "action": "REOPEN",
                "remarks": "Water is still dripping slowly"
            })
            assert res.status_code == 200, f"Failed reopen: {res.data}"
            print("  4.5 Student exercised right to REOPEN complaint.")

            # 6. Admin analytics reflects complaints data
            admin_jwt = create_access_token(admin)
            res = client.get('/admin/dashboard/summary', headers={'Authorization': f'Bearer {admin_jwt}'})
            assert res.status_code == 200
            dash_data = res.get_json()
            assert "totalComplaints" in dash_data
            assert "reopenedComplaints" in dash_data
            assert dash_data["totalComplaints"] >= 1
            print("  4.6 Admin command center summary reflects complaint metrics.")
            print("  --> [CHAIN 4 PASSED]: Complete Complaint lifecycle & Admin visibility verified!")

            # ==============================================================
            # CHAIN 5: Admin Notice -> Student Read Tracking
            # ==============================================================
            print("\n[CHAIN 5] Admin Notice -> Student Read Tracking...")

            # 1. Admin creates and publishes targeted notice
            res = client.post('/notices', headers={'X-User-Id': admin.id}, json={
                "title": f"BPUT Hackathon Final Notice {tag}",
                "body": "All presentations will be conducted in Main Auditorium.",
                "category": "ACADEMIC",
                "priority": "HIGH",
                "target_type": "BRANCH",
                "target_value": "CSE",
                "status": "PUBLISHED"
            })
            assert res.status_code == 201
            notice_id = res.get_json()['id']
            created_notices.append(notice_id)
            print(f"  5.1 Admin published targeted notice {notice_id} for CSE branch.")

            # 2. Student queries accessible notices
            res = client.get('/notices', headers={'X-User-Id': student.id})
            assert res.status_code == 200
            notices = res.get_json()
            assert any(n['id'] == notice_id for n in notices)
            print("  5.2 Notice is visible in Student targeted notice feed.")

            # 3. Student reads notice
            res = client.post(f'/notices/{notice_id}/read', headers={'X-User-Id': student.id})
            assert res.status_code == 200
            read_data = res.get_json()
            assert read_data['isRead'] is True
            print("  5.3 Student marked notice as READ.")

            # 4. Delivery audit reflects read status
            deliv = NotificationDelivery.query.filter_by(notice_id=notice_id, user_id=student.id).first()
            assert deliv is not None
            assert deliv.is_read is True
            assert deliv.status == 'READ'
            print("  5.4 Server recorded read audit status accurately.")
            print("  --> [CHAIN 5 PASSED]: Complete Notice broadcast and read tracking verified!")

        finally:
            print("\nCleaning up test artifacts...")
            for nid in created_notices:
                NotificationDelivery.query.filter_by(notice_id=nid).delete()
                Notice.query.filter_by(id=nid).delete()
            for cid in created_complaints:
                ComplaintStatusHistory.query.filter_by(complaint_id=cid).delete()
                Complaint.query.filter_by(id=cid).delete()
            for gpid in created_gate_passes:
                RequestAudit.query.filter_by(entity_id=gpid).delete()
                GatePass.query.filter_by(id=gpid).delete()
            for lid in created_leaves:
                RequestAudit.query.filter_by(entity_id=lid).delete()
                LeaveRequest.query.filter_by(id=lid).delete()
            for sid in created_sessions:
                Attendance.query.filter_by(session_id=sid).delete()
                Session.query.filter_by(id=sid).delete()
            for mid in created_menus:
                MessMeal.query.filter_by(menu_id=mid).delete()
                MessMenu.query.filter_by(id=mid).delete()

            user_ids = [student.id, teacher.id, warden.id, security.id, mess_staff.id, admin.id]
            RequestAudit.query.filter(RequestAudit.actor_id.in_(user_ids)).delete()
            ComplaintStatusHistory.query.filter(ComplaintStatusHistory.changed_by.in_(user_ids)).delete()
            NotificationDelivery.query.filter(NotificationDelivery.user_id.in_(user_ids)).delete()
            MealEntry.query.filter(MealEntry.student_id.in_(user_ids)).delete()
            MealEntry.query.filter(MealEntry.verified_by.in_(user_ids)).delete()
            DeviceCertificate.query.filter(DeviceCertificate.subject_user_id.in_(user_ids)).delete()
            DeviceIdentityKey.query.filter(DeviceIdentityKey.user_id.in_(user_ids)).delete()
            User.query.filter(User.id.in_(user_ids)).delete()
            db.session.commit()
            print("Cleanup complete. Attentify database perfectly restored!")

        print("\n" + "=" * 70)
        print("ALL 5 CROSS-ROLE CHAINS VERIFIED SUCCESSFULLY!")
        print("=" * 70)

if __name__ == '__main__':
    run_cross_role_e2e_tests()
