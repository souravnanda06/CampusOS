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
    get_institution_public_key_b64,
    validate_public_key,
    canonicalize_payload
)


def generate_ed25519_keypair():
    """Generates an Ed25519 keypair and returns (private_key, public_key_b64)."""
    priv = ed25519.Ed25519PrivateKey.generate()
    pub = priv.public_key()
    pub_b64 = base64.b64encode(pub.public_bytes_raw()).decode('ascii')
    return priv, pub_b64


def run_step1c_passport_tests():
    print("==================================================")
    print("CAMPUSOS PASSPORT PHASE 1C: BACKEND KEY REGISTRY & INSTITUTION CERTIFICATION")
    print("==================================================")

    client = app.test_client()

    # Generate ephemeral test institutional signing key for test isolation
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
        student_a = User(
            id=str(uuid.uuid4()),
            email=f"passport_student_a_{uuid.uuid4().hex[:6]}@campusos.test",
            password="password",
            name="Passport Student A",
            role="student"
        )
        db.session.add(student_a)

        student_b = User(
            id=str(uuid.uuid4()),
            email=f"passport_student_b_{uuid.uuid4().hex[:6]}@campusos.test",
            password="password",
            name="Passport Student B",
            role="student"
        )
        db.session.add(student_b)

        admin = User(
            id=str(uuid.uuid4()),
            email=f"passport_admin_{uuid.uuid4().hex[:6]}@campusos.test",
            password="password",
            name="Passport Admin",
            role="admin"
        )
        db.session.add(admin)

        teacher = User(
            id=str(uuid.uuid4()),
            email=f"passport_teacher_{uuid.uuid4().hex[:6]}@campusos.test",
            password="password",
            name="Passport Teacher",
            role="teacher"
        )
        db.session.add(teacher)

        db.session.commit()
        created_user_ids.extend([student_a.id, student_b.id, admin.id, teacher.id])

        student_a_id = student_a.id
        student_b_id = student_b.id
        admin_id = admin.id
        teacher_id = teacher.id

    try:
        # Generate client keypairs for students
        _, student_a_pub_b64 = generate_ed25519_keypair()
        _, student_b_pub_b64 = generate_ed25519_keypair()

        print("\n--- Test 1: GET /passport/identity returns enrolled=false before enrollment ---")
        res = client.get('/passport/identity', headers={'X-User-Id': student_a_id})
        assert res.status_code == 200, f"Expected 200, got {res.status_code}: {res.data}"
        data = json.loads(res.data)
        assert data.get('enrolled') is False, f"Expected enrolled=False, got {data}"
        print("[PASS] Enrolled=false verified before key registration.")

        print("\n--- Test 2: Unauthenticated registration request rejected (401) ---")
        res = client.post('/passport/keys/register', json={
            'userId': student_a_id,
            'publicKey': student_a_pub_b64,
            'keyType': 'ED25519'
        })
        assert res.status_code == 401, f"Expected 401, got {res.status_code}: {res.data}"
        print("[PASS] Unauthenticated request correctly rejected with 401.")

        print("\n--- Test 3: Student A cannot register a key for Student B (403) ---")
        res = client.post('/passport/keys/register', headers={'X-User-Id': student_a_id}, json={
            'userId': student_b_id,
            'publicKey': student_a_pub_b64,
            'keyType': 'ED25519'
        })
        assert res.status_code == 403, f"Expected 403, got {res.status_code}: {res.data}"
        print("[PASS] Student A cannot register key for Student B (403).")

        print("\n--- Test 4: Malformed public key returns 400 ---")
        res = client.post('/passport/keys/register', headers={'X-User-Id': student_a_id}, json={
            'userId': student_a_id,
            'publicKey': 'not-a-valid-base64-key!!!',
            'keyType': 'ED25519'
        })
        assert res.status_code == 400, f"Expected 400, got {res.status_code}: {res.data}"
        print("[PASS] Malformed base64 public key rejected with 400.")

        print("\n--- Test 5: 64-byte payload (private key or signature) is explicitly rejected (400) ---")
        bogus_64_byte = base64.b64encode(b"A" * 64).decode('ascii')
        res = client.post('/passport/keys/register', headers={'X-User-Id': student_a_id}, json={
            'userId': student_a_id,
            'publicKey': bogus_64_byte,
            'keyType': 'ED25519'
        })
        assert res.status_code == 400, f"Expected 400, got {res.status_code}: {res.data}"
        assert "64-byte" in json.loads(res.data).get('message', ''), "Expected 64-byte error message"
        print("[PASS] 64-byte private key/signature payload explicitly rejected with 400.")

        print("\n--- Test 6: Unsupported keyType returns 400 ---")
        res = client.post('/passport/keys/register', headers={'X-User-Id': student_a_id}, json={
            'userId': student_a_id,
            'publicKey': student_a_pub_b64,
            'keyType': 'RSA-4096'
        })
        assert res.status_code == 400, f"Expected 400, got {res.status_code}: {res.data}"
        print("[PASS] Unsupported keyType correctly rejected with 400.")

        print("\n--- Test 7: Valid Ed25519 registration creates DeviceIdentityKey & DeviceCertificate ---")
        reg_payload = {
            'userId': student_a_id,
            'publicKey': student_a_pub_b64,
            'keyType': 'ED25519'
        }
        res = client.post('/passport/keys/register', headers={'X-User-Id': student_a_id}, json=reg_payload)
        assert res.status_code == 201, f"Expected 201, got {res.status_code}: {res.data}"
        reg_data = json.loads(res.data)
        key_id = reg_data['keyId']
        cert_data = reg_data['certificate']
        cert_id = cert_data['id']
        created_key_ids.append(key_id)
        created_cert_ids.append(cert_id)

        assert reg_data['status'] == 'ACTIVE'
        assert reg_data['publicKey'] == student_a_pub_b64
        assert cert_data['userId'] == student_a_id
        assert cert_data['publicKey'] == student_a_pub_b64
        assert cert_data['issuer'] == 'CampusOS'
        assert cert_data['issuerKeyId'] == test_inst_key_id
        assert cert_data['signature'] is not None and len(cert_data['signature']) > 0
        assert 'privateKey' not in reg_data
        assert 'private_key' not in reg_data
        print(f"[PASS] Key registered and certified: keyId={key_id}, certId={cert_id}")

        print("\n--- Test 8: Verify database records and invariants ---")
        with app.app_context():
            db_key = DeviceIdentityKey.query.get(key_id)
            assert db_key is not None, "DeviceIdentityKey not found in database"
            assert db_key.user_id == student_a_id
            assert db_key.public_key_b64 == student_a_pub_b64
            assert db_key.status == 'ACTIVE'
            assert db_key.key_type == 'ED25519'
            assert not hasattr(db_key, 'private_key'), "SECURITY VIOLATION: DeviceIdentityKey has private_key field!"

            db_cert = DeviceCertificate.query.get(cert_id)
            assert db_cert is not None, "DeviceCertificate not found in database"
            assert db_cert.key_id == key_id
            assert db_cert.subject_user_id == student_a_id
            assert db_cert.subject_public_key_b64 == student_a_pub_b64
            assert db_cert.status == 'ACTIVE'
            assert not hasattr(db_cert, 'private_key'), "SECURITY VIOLATION: DeviceCertificate has private_key field!"
        print("[PASS] Database models and invariants verified; zero private key columns.")

        print("\n--- Test 9: Verify Certificate signature cryptographically ---")
        canonical_payload = cert_data['payload']
        canonical_bytes = canonicalize_payload(canonical_payload)
        sig_bytes = base64.b64decode(cert_data['signature'])
        inst_pub = test_inst_priv.public_key()
        inst_pub.verify(sig_bytes, canonical_bytes)
        print("[PASS] Certificate signature cryptographically verified with institution public key.")

        print("\n--- Test 10: Duplicate public key registration fails with 409 ---")
        # Student B attempts to register Student A's public key
        res = client.post('/passport/keys/register', headers={'X-User-Id': student_b_id}, json={
            'userId': student_b_id,
            'publicKey': student_a_pub_b64,
            'keyType': 'ED25519'
        })
        assert res.status_code == 409, f"Expected 409, got {res.status_code}: {res.data}"
        print("[PASS] Duplicate public key across users rejected with 409.")

        print("\n--- Test 11: Policy of single active key: user cannot register 2nd active key (409) ---")
        _, student_a_new_pub = generate_ed25519_keypair()
        res = client.post('/passport/keys/register', headers={'X-User-Id': student_a_id}, json={
            'userId': student_a_id,
            'publicKey': student_a_new_pub,
            'keyType': 'ED25519'
        })
        assert res.status_code == 409, f"Expected 409, got {res.status_code}: {res.data}"
        print("[PASS] User with existing active key cannot register another active key (409).")

        print("\n--- Test 12: GET /passport/identity returns enrolled=true with active key & certificate ---")
        res = client.get('/passport/identity', headers={'X-User-Id': student_a_id})
        assert res.status_code == 200, f"Expected 200, got {res.status_code}: {res.data}"
        data = json.loads(res.data)
        assert data.get('enrolled') is True
        assert data['key']['id'] == key_id
        assert data['certificate']['id'] == cert_id
        print("[PASS] Current identity endpoint returns enrolled=true with key and certificate.")

        print("\n--- Test 13: Student A cannot retrieve Student B's identity endpoint (403) ---")
        res = client.get(f'/passport/keys/{student_b_id}', headers={'X-User-Id': student_a_id})
        assert res.status_code == 403, f"Expected 403, got {res.status_code}: {res.data}"
        print("[PASS] Student A cannot retrieve Student B's identity endpoint (403).")

        print("\n--- Test 14: Student A can retrieve their own identity endpoint (200) ---")
        res = client.get(f'/passport/keys/{student_a_id}', headers={'X-User-Id': student_a_id})
        assert res.status_code == 200, f"Expected 200, got {res.status_code}: {res.data}"
        data = json.loads(res.data)
        assert data['keyId'] == key_id
        assert data['userId'] == student_a_id
        assert data['publicKey'] == student_a_pub_b64
        print("[PASS] Student A can retrieve their own public identity information.")

        print("\n--- Test 15: Admin can retrieve Student A's identity endpoint (200) ---")
        res = client.get(f'/passport/keys/{student_a_id}', headers={'X-User-Id': admin_id})
        assert res.status_code == 200, f"Expected 200, got {res.status_code}: {res.data}"
        data = json.loads(res.data)
        assert data['keyId'] == key_id
        print("[PASS] Admin authorized to inspect student identity.")

        print("\n--- Test 16: Certificate verification: valid certificate passes all 10 checks ---")
        verify_payload = {"certificate": cert_data}
        res = client.post('/passport/verify-certificate', json=verify_payload)
        assert res.status_code == 200, f"Expected 200, got {res.status_code}: {res.data}"
        result = json.loads(res.data)
        assert result['valid'] is True, f"Expected valid=True, got {result}"
        assert result['reason'] is None
        print("[PASS] Valid active certificate passes 10-point verification.")

        print("\n--- Test 17: Certificate verification with certificateId succeeds ---")
        res = client.post('/passport/verify-certificate', json={"certificateId": cert_id})
        assert res.status_code == 200, f"Expected 200, got {res.status_code}: {res.data}"
        result = json.loads(res.data)
        assert result['valid'] is True
        print("[PASS] Certificate verification via certificateId succeeds.")

        print("\n--- Test 18: Tampered payload fails verification ---")
        tampered_cert = json.loads(json.dumps(cert_data))
        tampered_cert['payload']['userId'] = student_b_id  # Alter subject user ID
        res = client.post('/passport/verify-certificate', json={"certificate": tampered_cert})
        assert res.status_code == 200
        result = json.loads(res.data)
        assert result['valid'] is False
        assert "signature verification failed" in result['reason'].lower() or "not match" in result['reason'].lower()
        print(f"[PASS] Tampered payload rejected: {result['reason']}")

        print("\n--- Test 19: Tampered signature fails verification ---")
        tampered_sig_cert = json.loads(json.dumps(cert_data))
        # Corrupt signature by flipping chars
        tampered_sig_cert['signature'] = "A" * len(cert_data['signature'])
        res = client.post('/passport/verify-certificate', json={"certificate": tampered_sig_cert})
        assert res.status_code == 200
        result = json.loads(res.data)
        assert result['valid'] is False
        assert "signature verification failed" in result['reason'].lower()
        print(f"[PASS] Tampered signature rejected: {result['reason']}")

        print("\n--- Test 20: Expired certificate fails verification ---")
        expired_payload = dict(cert_data['payload'])
        expired_payload['validFrom'] = (datetime.datetime.now() - datetime.timedelta(days=400)).isoformat()
        expired_payload['validTo'] = (datetime.datetime.now() - datetime.timedelta(days=35)).isoformat()
        exp_canonical = canonicalize_payload(expired_payload)
        exp_sig = base64.b64encode(test_inst_priv.sign(exp_canonical)).decode('ascii')
        expired_cert = {
            "payload": expired_payload,
            "signature": exp_sig,
            "issuerKeyId": test_inst_key_id,
            "status": "ACTIVE"
        }
        res = client.post('/passport/verify-certificate', json={"certificate": expired_cert})
        assert res.status_code == 200
        result = json.loads(res.data)
        assert result['valid'] is False
        assert "expired" in result['reason'].lower()
        print(f"[PASS] Expired certificate rejected: {result['reason']}")

        print("\n--- Test 21: Mismatched public key inside certificate fails verification ---")
        _, other_pub_b64 = generate_ed25519_keypair()
        mismatch_payload = dict(cert_data['payload'])
        mismatch_payload['publicKey'] = other_pub_b64
        mismatch_canonical = canonicalize_payload(mismatch_payload)
        mismatch_sig = base64.b64encode(test_inst_priv.sign(mismatch_canonical)).decode('ascii')
        mismatch_cert = {
            "payload": mismatch_payload,
            "signature": mismatch_sig,
            "issuerKeyId": test_inst_key_id,
            "status": "ACTIVE"
        }
        res = client.post('/passport/verify-certificate', json={"certificate": mismatch_cert})
        assert res.status_code == 200
        result = json.loads(res.data)
        assert result['valid'] is False
        assert "does not match" in result['reason'].lower()
        print(f"[PASS] Mismatched public key rejected: {result['reason']}")

        print("\n--- Test 22: Student B cannot revoke Student A's key (403) ---")
        res = client.post(f'/passport/keys/{key_id}/revoke', headers={'X-User-Id': student_b_id})
        assert res.status_code == 403, f"Expected 403, got {res.status_code}: {res.data}"
        print("[PASS] Student B cannot revoke Student A's key (403).")

        print("\n--- Test 23: Student A can revoke their own key ---")
        res = client.post(f'/passport/keys/{key_id}/revoke', headers={'X-User-Id': student_a_id})
        assert res.status_code == 200, f"Expected 200, got {res.status_code}: {res.data}"
        rev_data = json.loads(res.data)
        assert rev_data['key']['status'] == 'REVOKED'
        assert rev_data['key']['revokedAt'] is not None

        with app.app_context():
            db_key = DeviceIdentityKey.query.get(key_id)
            assert db_key.status == 'REVOKED'
            db_cert = DeviceCertificate.query.get(cert_id)
            assert db_cert.status == 'REVOKED'
        print("[PASS] Key and associated certificate marked REVOKED in database.")

        print("\n--- Test 24: Revoked key fails certificate verification ---")
        res = client.post('/passport/verify-certificate', json={"certificateId": cert_id})
        assert res.status_code == 200
        result = json.loads(res.data)
        assert result['valid'] is False
        assert "revoked" in result['reason'].lower()
        print(f"[PASS] Revoked key certificate fails verification: {result['reason']}")

        print("\n--- Test 25: Now that Student A's key is revoked, Student A can enroll a new key ---")
        _, student_a_key2_pub = generate_ed25519_keypair()
        res = client.post('/passport/keys/register', headers={'X-User-Id': student_a_id}, json={
            'userId': student_a_id,
            'publicKey': student_a_key2_pub,
            'keyType': 'ED25519'
        })
        assert res.status_code == 201, f"Expected 201, got {res.status_code}: {res.data}"
        key2_data = json.loads(res.data)
        key2_id = key2_data['keyId']
        cert2_id = key2_data['certificate']['id']
        created_key_ids.append(key2_id)
        created_cert_ids.append(cert2_id)
        assert key2_data['status'] == 'ACTIVE'

        # Student A now has 2 keys in history: 1 REVOKED, 1 ACTIVE
        with app.app_context():
            all_keys = DeviceIdentityKey.query.filter_by(user_id=student_a_id).all()
            assert len(all_keys) == 2, f"Expected 2 historical keys, got {len(all_keys)}"
            statuses = {k.status for k in all_keys}
            assert statuses == {'REVOKED', 'ACTIVE'}
        print("[PASS] Multiple historical keys supported (1 REVOKED, 1 ACTIVE).")

        print("\n--- Test 26: Expose public key endpoint GET /passport/institution/public-key ---")
        res = client.get('/passport/institution/public-key')
        assert res.status_code == 200, f"Expected 200, got {res.status_code}: {res.data}"
        pub_info = json.loads(res.data)
        assert pub_info['issuer'] == 'CampusOS'
        assert pub_info['issuerKeyId'] == test_inst_key_id
        assert pub_info['algorithm'] == 'Ed25519'
        assert pub_info['publicKey'] == base64.b64encode(test_inst_priv.public_key().public_bytes_raw()).decode('ascii')
        assert 'private' not in json.dumps(pub_info).lower()
        print("[PASS] Institutional public key endpoint returns correct trusted parameters without secrets.")

        print("\n--- Test 27: Configuration error handling when institution key is missing ---")
        clear_institution_key_override()
        # Ensure env var is also cleared for this test
        old_env_priv = os.environ.pop(passport_service.ENV_INSTITUTION_PRIVATE_KEY, None)
        try:
            _, unconfigured_pub = generate_ed25519_keypair()
            res = client.post('/passport/keys/register', headers={'X-User-Id': student_b_id}, json={
                'userId': student_b_id,
                'publicKey': unconfigured_pub,
                'keyType': 'ED25519'
            })
            assert res.status_code == 500, f"Expected 500 when unconfigured, got {res.status_code}: {res.data}"
            assert "Institutional signing key is not configured" in json.loads(res.data).get('message', '')
            print("[PASS] Clear 500 error returned when institution key is unconfigured.")
        finally:
            if old_env_priv:
                os.environ[passport_service.ENV_INSTITUTION_PRIVATE_KEY] = old_env_priv
            # Restore test override
            set_institution_key_override(test_inst_priv_b64, test_inst_key_id)

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
    print("ALL 27 PASSPORT PHASE 1C TESTS PASSED SUCCESSFULLY!")
    print("==================================================")


if __name__ == '__main__':
    run_step1c_passport_tests()
