import sys
import os
import json
import base64
import datetime
import uuid
from cryptography.hazmat.primitives.asymmetric import ed25519

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from app import (
    app, db, User, Session, Attendance, LeaveRequest, GatePass,
    RequestAudit, Complaint, ComplaintStatusHistory, Notice, NotificationDelivery,
    DeviceToken, MessMenu, MessMeal, MessFeedback, DeviceIdentityKey, DeviceCertificate
)
import passport_service
from passport_service import (
    PassportService,
    set_institution_key_override,
    clear_institution_key_override,
    get_institution_key_id,
    canonicalize_payload
)


def generate_ed25519_keypair():
    """Generates an Ed25519 keypair and returns (private_key, public_key_b64)."""
    priv = ed25519.Ed25519PrivateKey.generate()
    pub = priv.public_key()
    pub_b64 = base64.b64encode(pub.public_bytes_raw()).decode('ascii')
    return priv, pub_b64


def build_and_sign_presentation(priv_key, key_id, user_id, cert_id, issuer_key_id, issued_at=None, expires_at=None, nonce=None):
    """Builds a canonical presentation dictionary and signs it with the client private key."""
    now_ts = int(datetime.datetime.now(datetime.timezone.utc).timestamp())
    i_at = issued_at if issued_at is not None else now_ts
    e_at = expires_at if expires_at is not None else (i_at + 30)
    n = nonce or uuid.uuid4().hex

    payload = {
        "version": 1,
        "type": "PASSPORT_PRESENTATION",
        "keyId": key_id,
        "userId": user_id,
        "certificateId": cert_id,
        "issuerKeyId": issuer_key_id,
        "issuedAt": i_at,
        "expiresAt": e_at,
        "nonce": n
    }

    # Canonicalize and sign
    canonical_dict = {
        "certificateId": cert_id,
        "expiresAt": e_at,
        "issuedAt": i_at,
        "issuerKeyId": issuer_key_id,
        "keyId": key_id,
        "nonce": n,
        "type": "PASSPORT_PRESENTATION",
        "userId": user_id,
        "version": 1
    }
    canonical_bytes = canonicalize_payload(canonical_dict)
    sig_bytes = priv_key.sign(canonical_bytes)
    sig_b64 = base64.b64encode(sig_bytes).decode('ascii')

    return payload, sig_b64


def run_step1d_presentation_tests():
    print("==================================================")
    print("CAMPUSOS PASSPORT 1D — DYNAMIC PASSPORT + ROTATING QR TEST SUITE")
    print("==================================================")

    client = app.test_client()

    # Generate ephemeral test institutional signing key
    test_inst_priv = ed25519.Ed25519PrivateKey.generate()
    test_inst_priv_b64 = base64.b64encode(test_inst_priv.private_bytes_raw()).decode('ascii')
    test_inst_key_id = f"test-institution-key-{uuid.uuid4().hex[:8]}"
    set_institution_key_override(test_inst_priv_b64, test_inst_key_id)

    created_user_ids = []
    created_key_ids = []
    created_cert_ids = []

    # 1. Record baseline database counts across ALL tables
    baseline_counts = {}
    with app.app_context():
        baseline_counts = {
            'users': User.query.count(),
            'sessions': Session.query.count(),
            'attendance': Attendance.query.count(),
            'leave_requests': LeaveRequest.query.count(),
            'gate_passes': GatePass.query.count(),
            'complaints': Complaint.query.count(),
            'complaint_status_history': ComplaintStatusHistory.query.count(),
            'request_audits': RequestAudit.query.count(),
            'notices': Notice.query.count(),
            'notification_deliveries': NotificationDelivery.query.count(),
            'device_tokens': DeviceToken.query.count(),
            'mess_menus': MessMenu.query.count(),
            'mess_meals': MessMeal.query.count(),
            'mess_feedback': MessFeedback.query.count(),
            'device_identity_keys': DeviceIdentityKey.query.count(),
            'device_certificates': DeviceCertificate.query.count(),
        }
        print(f"[OK] Baseline database table counts recorded: {baseline_counts}")

        # Setup test fixtures
        student = User(
            id=str(uuid.uuid4()),
            email=f"passport_1d_student_{uuid.uuid4().hex[:6]}@campusos.test",
            password="password",
            name="Dynamic Passport Student",
            role="student"
        )
        db.session.add(student)

        other_student = User(
            id=str(uuid.uuid4()),
            email=f"passport_1d_other_{uuid.uuid4().hex[:6]}@campusos.test",
            password="password",
            name="Other Student",
            role="student"
        )
        db.session.add(other_student)

        db.session.commit()
        created_user_ids.extend([student.id, other_student.id])
        student_id = student.id
        other_student_id = other_student.id

    try:
        # Generate client keypair for student
        client_priv, client_pub_b64 = generate_ed25519_keypair()
        other_priv, other_pub_b64 = generate_ed25519_keypair()

        # Enroll student's key and certificate via 1C endpoint
        reg_payload = {
            'userId': student_id,
            'publicKey': client_pub_b64,
            'keyType': 'ED25519'
        }
        res = client.post('/passport/keys/register', headers={'X-User-Id': student_id}, json=reg_payload)
        assert res.status_code == 201, f"Failed to register key: {res.data}"
        reg_data = json.loads(res.data)
        key_id = reg_data['keyId']
        cert_id = reg_data['certificate']['id']
        created_key_ids.append(key_id)
        created_cert_ids.append(cert_id)

        print("\n--- Test 1: Valid presentation succeeds ---")
        payload, sig = build_and_sign_presentation(client_priv, key_id, student_id, cert_id, test_inst_key_id)
        res = client.post('/passport/verify', json={"payload": payload, "signature": sig})
        assert res.status_code == 200
        data = json.loads(res.data)
        assert data['valid'] is True, f"Expected valid=True, got {data}"
        assert data['reason'] == "VALID"
        assert data['userId'] == student_id
        assert data['keyId'] == key_id
        assert data['certificateId'] == cert_id
        assert data['expiresAt'] == payload['expiresAt']
        print("[PASS] Valid dynamic presentation verified successfully.")

        print("\n--- Test 2: Compact QR envelope format (p & s) succeeds ---")
        res = client.post('/passport/verify', json={"p": payload, "s": sig})
        assert res.status_code == 200
        data = json.loads(res.data)
        assert data['valid'] is True
        assert data['reason'] == "VALID"
        print("[PASS] Compact QR envelope format {'p': ..., 's': ...} accepted and verified.")

        print("\n--- Test 3: Malformed payload rejected (INVALID_FORMAT) ---")
        res = client.post('/passport/verify', json={"payload": "not-a-dict", "signature": sig})
        assert res.status_code == 200
        assert json.loads(res.data)['reason'] == "INVALID_FORMAT"

        res = client.post('/passport/verify', json={"payload": {}, "signature": sig})
        assert res.status_code == 200
        assert json.loads(res.data)['reason'] == "INVALID_FORMAT"
        print("[PASS] Malformed and empty payloads rejected with INVALID_FORMAT.")

        print("\n--- Test 4: Wrong presentation type rejected (INVALID_FORMAT) ---")
        bad_type_p = dict(payload)
        bad_type_p['type'] = 'STATIC_QR'
        _, bad_sig = build_and_sign_presentation(client_priv, key_id, student_id, cert_id, test_inst_key_id)
        res = client.post('/passport/verify', json={"payload": bad_type_p, "signature": bad_sig})
        assert res.status_code == 200
        assert json.loads(res.data)['reason'] == "INVALID_FORMAT"
        print("[PASS] Wrong presentation type rejected with INVALID_FORMAT.")

        print("\n--- Test 5: Missing keyId rejected (INVALID_FORMAT) ---")
        missing_key_p = dict(payload)
        del missing_key_p['keyId']
        res = client.post('/passport/verify', json={"payload": missing_key_p, "signature": sig})
        assert res.status_code == 200
        assert json.loads(res.data)['reason'] == "INVALID_FORMAT"
        print("[PASS] Missing keyId rejected with INVALID_FORMAT.")

        print("\n--- Test 6: Unknown keyId rejected (UNKNOWN_KEY) ---")
        unknown_key_id = str(uuid.uuid4())
        unk_p, unk_sig = build_and_sign_presentation(client_priv, unknown_key_id, student_id, cert_id, test_inst_key_id)
        res = client.post('/passport/verify', json={"payload": unk_p, "signature": unk_sig})
        assert res.status_code == 200
        assert json.loads(res.data)['reason'] == "UNKNOWN_KEY"
        print("[PASS] Unknown keyId rejected with UNKNOWN_KEY.")

        print("\n--- Test 7: Unknown certificateId rejected (UNKNOWN_CERTIFICATE) ---")
        unknown_cert_id = str(uuid.uuid4())
        unk_c_p, unk_c_sig = build_and_sign_presentation(client_priv, key_id, student_id, unknown_cert_id, test_inst_key_id)
        res = client.post('/passport/verify', json={"payload": unk_c_p, "signature": unk_c_sig})
        assert res.status_code == 200
        assert json.loads(res.data)['reason'] == "UNKNOWN_CERTIFICATE"
        print("[PASS] Unknown certificateId rejected with UNKNOWN_CERTIFICATE.")

        print("\n--- Test 8: Certificate/key mismatch rejected (CERTIFICATE_MISMATCH) ---")
        # Enroll second student
        res_o = client.post('/passport/keys/register', headers={'X-User-Id': other_student_id}, json={
            'userId': other_student_id,
            'publicKey': other_pub_b64,
            'keyType': 'ED25519'
        })
        assert res_o.status_code == 201
        other_key_id = json.loads(res_o.data)['keyId']
        other_cert_id = json.loads(res_o.data)['certificate']['id']
        created_key_ids.append(other_key_id)
        created_cert_ids.append(other_cert_id)

        # Present student_id with other_student's cert
        mismatch_p, mismatch_sig = build_and_sign_presentation(client_priv, key_id, student_id, other_cert_id, test_inst_key_id)
        res = client.post('/passport/verify', json={"payload": mismatch_p, "signature": mismatch_sig})
        assert res.status_code == 200
        assert json.loads(res.data)['reason'] == "CERTIFICATE_MISMATCH"
        print("[PASS] Certificate/key mismatch rejected with CERTIFICATE_MISMATCH.")

        print("\n--- Test 9: Certificate/user mismatch rejected (CERTIFICATE_MISMATCH) ---")
        user_mismatch_p, user_mismatch_sig = build_and_sign_presentation(client_priv, key_id, other_student_id, cert_id, test_inst_key_id)
        res = client.post('/passport/verify', json={"payload": user_mismatch_p, "signature": user_mismatch_sig})
        assert res.status_code == 200
        assert json.loads(res.data)['reason'] == "CERTIFICATE_MISMATCH"
        print("[PASS] Certificate/user mismatch rejected with CERTIFICATE_MISMATCH.")

        print("\n--- Test 10: Invalid signature rejected (INVALID_SIGNATURE) ---")
        # Signed by other_priv instead of client_priv (wrong keypair)
        wrong_sig_p, wrong_sig = build_and_sign_presentation(other_priv, key_id, student_id, cert_id, test_inst_key_id)
        res = client.post('/passport/verify', json={"payload": wrong_sig_p, "signature": wrong_sig})
        assert res.status_code == 200
        assert json.loads(res.data)['reason'] == "INVALID_SIGNATURE"
        print("[PASS] Signature from unauthorized private key rejected with INVALID_SIGNATURE.")

        print("\n--- Test 11: Altered payload after signing rejected (INVALID_SIGNATURE) ---")
        tampered_p = dict(payload)
        tampered_p['nonce'] = "altered-nonce-value"
        res = client.post('/passport/verify', json={"payload": tampered_p, "signature": sig})
        assert res.status_code == 200
        assert json.loads(res.data)['reason'] == "INVALID_SIGNATURE"
        print("[PASS] Altered payload detected; rejected with INVALID_SIGNATURE.")

        print("\n--- Test 12: Altered signature rejected (INVALID_SIGNATURE) ---")
        corrupt_sig = sig[:-4] + "AAAA"
        res = client.post('/passport/verify', json={"payload": payload, "signature": corrupt_sig})
        assert res.status_code == 200
        assert json.loads(res.data)['reason'] == "INVALID_SIGNATURE"
        print("[PASS] Corrupt signature rejected with INVALID_SIGNATURE.")

        print("\n--- Test 13: Expired presentation rejected (PRESENTATION_EXPIRED) ---")
        now_ts = int(datetime.datetime.now(datetime.timezone.utc).timestamp())
        # Expired 60 seconds ago (well outside 30s skew tolerance)
        exp_p, exp_sig = build_and_sign_presentation(
            client_priv, key_id, student_id, cert_id, test_inst_key_id,
            issued_at=now_ts - 100, expires_at=now_ts - 70
        )
        res = client.post('/passport/verify', json={"payload": exp_p, "signature": exp_sig})
        assert res.status_code == 200
        assert json.loads(res.data)['reason'] == "PRESENTATION_EXPIRED"
        print("[PASS] Expired presentation rejected with PRESENTATION_EXPIRED.")

        print("\n--- Test 14: Presentation not yet valid (future issuedAt outside skew) rejected (NOT_YET_VALID) ---")
        # Issued 120 seconds in the future
        fut_p, fut_sig = build_and_sign_presentation(
            client_priv, key_id, student_id, cert_id, test_inst_key_id,
            issued_at=now_ts + 120, expires_at=now_ts + 150
        )
        res = client.post('/passport/verify', json={"payload": fut_p, "signature": fut_sig})
        assert res.status_code == 200
        assert json.loads(res.data)['reason'] == "NOT_YET_VALID"
        print("[PASS] Future presentation outside clock skew rejected with NOT_YET_VALID.")

        print("\n--- Test 15: Timestamp with allowed clock skew succeeds ---")
        # Issued 15s ago, expires in 15s (within 30s skew)
        skew_p, skew_sig = build_and_sign_presentation(
            client_priv, key_id, student_id, cert_id, test_inst_key_id,
            issued_at=now_ts - 15, expires_at=now_ts + 15
        )
        res = client.post('/passport/verify', json={"payload": skew_p, "signature": skew_sig})
        assert res.status_code == 200
        assert json.loads(res.data)['reason'] == "VALID"
        print("[PASS] Presentation within allowed clock skew verified successfully.")

        print("\n--- Test 16: Revoked key presentation rejected (REVOKED_KEY) ---")
        # Revoke student's key
        res_rev = client.post(f'/passport/keys/{key_id}/revoke', headers={'X-User-Id': student_id})
        assert res_rev.status_code == 200

        rev_p, rev_sig = build_and_sign_presentation(client_priv, key_id, student_id, cert_id, test_inst_key_id)
        res = client.post('/passport/verify', json={"payload": rev_p, "signature": rev_sig})
        assert res.status_code == 200
        assert json.loads(res.data)['reason'] == "REVOKED_KEY"
        print("[PASS] Presentation signed by revoked key rejected with REVOKED_KEY.")

        print("\n--- Test 17: Statelessness invariant: no presentation table created in DB ---")
        with app.app_context():
            from sqlalchemy import inspect
            inspector = inspect(db.engine)
            tables = inspector.get_table_names()
            assert 'passport_presentations' not in tables
            assert 'presentations' not in tables
            assert 'presentation_nonces' not in tables
            assert 'nonces' not in tables
        print("[PASS] Stateless presentation invariant confirmed: zero presentation tables in database.")

        print("\n--- Test 18: Security invariant: verification does not mutate identity state ---")
        with app.app_context():
            key_after = DeviceIdentityKey.query.get(other_key_id)
            assert key_after.status == 'ACTIVE'
            cert_after = DeviceCertificate.query.get(other_cert_id)
            assert cert_after.status == 'ACTIVE'
        print("[PASS] Presentation verification is purely read-only and non-mutating.")

    finally:
        # Cleanup all created test records
        print("\n--- Cleanup: Restoring database baseline ---")
        with app.app_context():
            for cid in created_cert_ids:
                c = DeviceCertificate.query.get(cid)
                if c:
                    db.session.delete(c)
            for kid in created_key_ids:
                k = DeviceIdentityKey.query.get(kid)
                if k:
                    db.session.delete(k)
            for uid in created_user_ids:
                u = User.query.get(uid)
                if u:
                    db.session.delete(u)
            db.session.commit()

            # Verify exact baseline counts
            final_counts = {
                'users': User.query.count(),
                'sessions': Session.query.count(),
                'attendance': Attendance.query.count(),
                'leave_requests': LeaveRequest.query.count(),
                'gate_passes': GatePass.query.count(),
                'complaints': Complaint.query.count(),
                'complaint_status_history': ComplaintStatusHistory.query.count(),
                'request_audits': RequestAudit.query.count(),
                'notices': Notice.query.count(),
                'notification_deliveries': NotificationDelivery.query.count(),
                'device_tokens': DeviceToken.query.count(),
                'mess_menus': MessMenu.query.count(),
                'mess_meals': MessMeal.query.count(),
                'mess_feedback': MessFeedback.query.count(),
                'device_identity_keys': DeviceIdentityKey.query.count(),
                'device_certificates': DeviceCertificate.query.count(),
            }

            for table_name, baseline_val in baseline_counts.items():
                final_val = final_counts[table_name]
                assert final_val == baseline_val, (
                    f"Database count mismatch for table '{table_name}': baseline={baseline_val}, final={final_val}"
                )
            print(f"[OK] Database baseline perfectly restored: {final_counts}")

    print("\n==================================================")
    print("ALL PASSPORT 1D PRESENTATION TESTS PASSED SUCCESSFULLY!")
    print("==================================================")


if __name__ == '__main__':
    run_step1d_presentation_tests()
