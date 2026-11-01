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


def build_and_sign_presentation(
    priv_key, key_id, user_id, cert_id, issuer_key_id,
    issued_at=None, expires_at=None, nonce=None, challenge=None
):
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

    if challenge is not None:
        payload["challenge"] = challenge
        canonical_dict["challenge"] = challenge

    canonical_bytes = canonicalize_payload(canonical_dict)
    sig_bytes = priv_key.sign(canonical_bytes)
    sig_b64 = base64.b64encode(sig_bytes).decode('ascii')

    return payload, sig_b64


def run_step1g_challenge_tests():
    print("==================================================")
    print("CAMPUSOS PASSPORT 1G — BLE CHALLENGE-BOUND PRESENTATION TEST SUITE")
    print("==================================================")

    client = app.test_client()

    # Generate ephemeral test institutional signing key
    test_inst_priv = ed25519.Ed25519PrivateKey.generate()
    test_inst_priv_b64 = base64.b64encode(test_inst_priv.private_bytes_raw()).decode('ascii')
    test_inst_key_id = f"test-inst-1g-{uuid.uuid4().hex[:8]}"
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
            'device_certificates': DeviceCertificate.query.count()
        }
    print(f"[OK] Baseline database table counts recorded: {baseline_counts}")

    try:
        # Create a test student user
        student_id = f"test-student-1g-{uuid.uuid4().hex[:8]}"
        with app.app_context():
            u = User(
                id=student_id,
                name="Test Student 1G",
                email=f"{student_id}@test.campusos.internal",
                password="password",
                role="STUDENT",
                branch="Computer Science",
                year="3rd",
                course="B.Tech",
                registration_number="REG-1G-001"
            )
            db.session.add(u)
            db.session.commit()
            created_user_ids.append(student_id)

        # Register key and certificate via PassportService
        priv_key, pub_key_b64 = generate_ed25519_keypair()
        with app.app_context():
            key_record, cert_record = PassportService.register_public_key(
                db=db,
                user_model=User,
                device_identity_key_model=DeviceIdentityKey,
                device_certificate_model=DeviceCertificate,
                user_id=student_id,
                public_key_b64=pub_key_b64,
                validity_days=30
            )
            db.session.commit()
            key_id = key_record.id
            cert_id = cert_record.id
            created_key_ids.append(key_id)
            created_cert_ids.append(cert_id)

        now_ts = int(datetime.datetime.now(datetime.timezone.utc).timestamp())

        # ==============================================================
        # Test 1: Valid presentation with challenge succeeds
        # ==============================================================
        print("\n--- Test 1: Valid challenge-bound presentation succeeds ---")
        challenge_1 = {
            "nonce": "a1b2c3d4e5f60718",
            "verifierId": "gate-verifier-north",
            "issuedAt": now_ts - 5,
            "expiresAt": now_ts + 55
        }
        payload, sig = build_and_sign_presentation(
            priv_key, key_id, student_id, cert_id, test_inst_key_id,
            challenge=challenge_1
        )
        resp = client.post('/passport/verify', json={"payload": payload, "signature": sig})
        assert resp.status_code == 200, f"Expected 200, got {resp.status_code}"
        data = resp.get_json()
        assert data.get("valid") is True, f"Expected valid=True, got {data}"
        assert data.get("reason") == "VALID"
        assert data.get("challengeNonce") == "a1b2c3d4e5f60718"
        assert data.get("challengeVerifierId") == "gate-verifier-north"
        assert data.get("user", {}).get("name") == "Test Student 1G"
        print("[PASS] Challenge-bound presentation verified with challenge metadata returned.")

        # ==============================================================
        # Test 2: Valid presentation without challenge succeeds (backward compat)
        # ==============================================================
        print("\n--- Test 2: Valid non-challenge presentation succeeds (backward compatibility) ---")
        payload_no_c, sig_no_c = build_and_sign_presentation(
            priv_key, key_id, student_id, cert_id, test_inst_key_id
        )
        resp = client.post('/passport/verify', json={"payload": payload_no_c, "signature": sig_no_c})
        assert resp.status_code == 200
        data = resp.get_json()
        assert data.get("valid") is True
        assert "challengeNonce" not in data
        assert "challengeVerifierId" not in data
        print("[PASS] Unbound presentation succeeds with backward compatibility.")

        # ==============================================================
        # Test 3: Challenge with missing nonce rejected (INVALID_CHALLENGE)
        # ==============================================================
        print("\n--- Test 3: Malformed challenge missing nonce rejected ---")
        bad_challenge = {
            "verifierId": "gate-verifier-north",
            "issuedAt": now_ts,
            "expiresAt": now_ts + 60
        }
        payload_bad, sig_bad = build_and_sign_presentation(
            priv_key, key_id, student_id, cert_id, test_inst_key_id,
            challenge=bad_challenge
        )
        resp = client.post('/passport/verify', json={"payload": payload_bad, "signature": sig_bad})
        assert resp.status_code == 200
        data = resp.get_json()
        assert data.get("valid") is False
        assert data.get("reason") == "INVALID_CHALLENGE"
        print("[PASS] Missing nonce in challenge rejected with INVALID_CHALLENGE.")

        # ==============================================================
        # Test 4: Challenge with missing verifierId rejected (INVALID_CHALLENGE)
        # ==============================================================
        print("\n--- Test 4: Malformed challenge missing verifierId rejected ---")
        bad_challenge_v = {
            "nonce": "1234567812345678",
            "issuedAt": now_ts,
            "expiresAt": now_ts + 60
        }
        payload_bad_v, sig_bad_v = build_and_sign_presentation(
            priv_key, key_id, student_id, cert_id, test_inst_key_id,
            challenge=bad_challenge_v
        )
        resp = client.post('/passport/verify', json={"payload": payload_bad_v, "signature": sig_bad_v})
        assert resp.status_code == 200
        data = resp.get_json()
        assert data.get("valid") is False
        assert data.get("reason") == "INVALID_CHALLENGE"
        print("[PASS] Missing verifierId rejected with INVALID_CHALLENGE.")

        # ==============================================================
        # Test 5: Expired challenge rejected (CHALLENGE_EXPIRED)
        # ==============================================================
        print("\n--- Test 5: Expired challenge rejected ---")
        expired_challenge = {
            "nonce": "1234567812345678",
            "verifierId": "gate-verifier-north",
            "issuedAt": now_ts - 120,
            "expiresAt": now_ts - 60  # Expired 60s ago, well outside 30s skew
        }
        payload_exp, sig_exp = build_and_sign_presentation(
            priv_key, key_id, student_id, cert_id, test_inst_key_id,
            challenge=expired_challenge
        )
        resp = client.post('/passport/verify', json={"payload": payload_exp, "signature": sig_exp})
        assert resp.status_code == 200
        data = resp.get_json()
        assert data.get("valid") is False
        assert data.get("reason") == "CHALLENGE_EXPIRED"
        print("[PASS] Expired challenge rejected with CHALLENGE_EXPIRED.")

        # ==============================================================
        # Test 6: Inverted challenge timestamps (issuedAt > expiresAt) rejected
        # ==============================================================
        print("\n--- Test 6: Inverted challenge timestamps rejected ---")
        inv_challenge = {
            "nonce": "1234567812345678",
            "verifierId": "gate-verifier-north",
            "issuedAt": now_ts + 60,
            "expiresAt": now_ts
        }
        payload_inv, sig_inv = build_and_sign_presentation(
            priv_key, key_id, student_id, cert_id, test_inst_key_id,
            challenge=inv_challenge
        )
        resp = client.post('/passport/verify', json={"payload": payload_inv, "signature": sig_inv})
        assert resp.status_code == 200
        data = resp.get_json()
        assert data.get("valid") is False
        assert data.get("reason") == "INVALID_CHALLENGE"
        print("[PASS] Inverted challenge timestamps rejected with INVALID_CHALLENGE.")

        # ==============================================================
        # Test 7: Tampered nonce after signing rejected (INVALID_SIGNATURE)
        # ==============================================================
        print("\n--- Test 7: Tampered challenge nonce rejected with INVALID_SIGNATURE ---")
        c_orig = {
            "nonce": "original-nonce-12",
            "verifierId": "gate-verifier-north",
            "issuedAt": now_ts,
            "expiresAt": now_ts + 60
        }
        payload_tamper, sig_tamper = build_and_sign_presentation(
            priv_key, key_id, student_id, cert_id, test_inst_key_id,
            challenge=c_orig
        )
        # Attacker swaps nonce to match a different verifier challenge
        payload_tamper["challenge"]["nonce"] = "tampered-nonce-99"
        resp = client.post('/passport/verify', json={"payload": payload_tamper, "signature": sig_tamper})
        assert resp.status_code == 200
        data = resp.get_json()
        assert data.get("valid") is False
        assert data.get("reason") == "INVALID_SIGNATURE"
        print("[PASS] Tampered challenge nonce detected cryptographically.")

        # ==============================================================
        # Test 8: Tampered verifierId after signing rejected (INVALID_SIGNATURE)
        # ==============================================================
        print("\n--- Test 8: Tampered challenge verifierId rejected with INVALID_SIGNATURE ---")
        c_orig_v = {
            "nonce": "original-nonce-12",
            "verifierId": "gate-verifier-north",
            "issuedAt": now_ts,
            "expiresAt": now_ts + 60
        }
        payload_tamper_v, sig_tamper_v = build_and_sign_presentation(
            priv_key, key_id, student_id, cert_id, test_inst_key_id,
            challenge=c_orig_v
        )
        payload_tamper_v["challenge"]["verifierId"] = "gate-verifier-south"
        resp = client.post('/passport/verify', json={"payload": payload_tamper_v, "signature": sig_tamper_v})
        assert resp.status_code == 200
        data = resp.get_json()
        assert data.get("valid") is False
        assert data.get("reason") == "INVALID_SIGNATURE"
        print("[PASS] Tampered verifierId detected cryptographically.")

        # ==============================================================
        # Test 9: Non-challenge presentation replayed with challenge appended
        # ==============================================================
        print("\n--- Test 9: Unbound QR replayed into challenge mode rejected ---")
        payload_clean, sig_clean = build_and_sign_presentation(
            priv_key, key_id, student_id, cert_id, test_inst_key_id
        )
        # Attacker takes valid unbound QR and attaches a challenge dict
        payload_clean["challenge"] = {
            "nonce": "intercepted-nonc",
            "verifierId": "gate-verifier-north",
            "issuedAt": now_ts,
            "expiresAt": now_ts + 60
        }
        resp = client.post('/passport/verify', json={"payload": payload_clean, "signature": sig_clean})
        assert resp.status_code == 200
        data = resp.get_json()
        assert data.get("valid") is False
        assert data.get("reason") == "INVALID_SIGNATURE"
        print("[PASS] Replay attack: appending challenge to unbound presentation fails signature.")

        # ==============================================================
        # Test 10: Stripping challenge from challenge-bound presentation fails
        # ==============================================================
        print("\n--- Test 10: Stripping challenge from bound presentation rejected ---")
        c_bound = {
            "nonce": "bound-nonce-1234",
            "verifierId": "gate-verifier-north",
            "issuedAt": now_ts,
            "expiresAt": now_ts + 60
        }
        payload_bound, sig_bound = build_and_sign_presentation(
            priv_key, key_id, student_id, cert_id, test_inst_key_id,
            challenge=c_bound
        )
        del payload_bound["challenge"]
        resp = client.post('/passport/verify', json={"payload": payload_bound, "signature": sig_bound})
        assert resp.status_code == 200
        data = resp.get_json()
        assert data.get("valid") is False
        assert data.get("reason") == "INVALID_SIGNATURE"
        print("[PASS] Stripping challenge from bound presentation fails signature.")

        # ==============================================================
        # Test 11: Compact envelope format (p & s) with challenge
        # ==============================================================
        print("\n--- Test 11: Compact QR envelope (p & s) with challenge succeeds ---")
        c_compact = {
            "nonce": "compact-nonce-56",
            "verifierId": "gate-verifier-north",
            "issuedAt": now_ts,
            "expiresAt": now_ts + 60
        }
        payload_cp, sig_cp = build_and_sign_presentation(
            priv_key, key_id, student_id, cert_id, test_inst_key_id,
            challenge=c_compact
        )
        resp = client.post('/passport/verify', json={"p": payload_cp, "s": sig_cp})
        assert resp.status_code == 200
        data = resp.get_json()
        assert data.get("valid") is True
        assert data.get("challengeNonce") == "compact-nonce-56"
        print("[PASS] Compact QR envelope format with challenge succeeds.")

        # ==============================================================
        # Test 12: Invariant: Statelessness and zero database changes
        # ==============================================================
        print("\n--- Test 12: Statelessness & Database non-mutation invariant ---")
        with app.app_context():
            from sqlalchemy import inspect
            inspector = inspect(db.engine)
            table_names = [t.lower() for t in inspector.get_table_names()]
            assert "passport_challenge" not in table_names
            assert "challenges" not in table_names
        print("[PASS] Invariant verified: zero challenge tables in database.")

    finally:
        # Cleanup
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

            after_counts = {
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
                'device_certificates': DeviceCertificate.query.count()
            }
            assert baseline_counts == after_counts, (
                f"Database leaked! Baseline: {baseline_counts}, After: {after_counts}"
            )
            print(f"[OK] Database baseline perfectly restored: {after_counts}")
            clear_institution_key_override()

    print("\n==================================================")
    print("ALL PASSPORT 1G CHALLENGE TESTS PASSED SUCCESSFULLY!")
    print("==================================================")


if __name__ == '__main__':
    run_step1g_challenge_tests()
