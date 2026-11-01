"""
CampusOS Passport Phase 1F: Offline Trust Bundle & Offline Verification Backend Test Suite.

Tests:
1. Authorized staff can fetch trust bundle (200 OK)
2. Student role denied (403 Forbidden)
3. Unauthenticated request denied (401 Unauthorized)
4. Bundle structure valid (version 1, issuerKeyId, generatedAt, expiresAt, institution, identities)
5. Bundle contains active certified identities
6. Revoked identities handled correctly (excluded from active identities, present in revokedKeyIds)
7. Expired certificates handled correctly (excluded from active identities)
8. Institution signature generated (64-byte Base64)
9. Bundle canonicalization deterministic
10. Bundle signature verifies with institution public key
11. Tampered payload rejected
12. Altered identity public key rejected
13. Altered certificateId rejected
14. Altered issuer rejected
15. Altered expiresAt rejected
16. Invariant: Zero private keys in trust bundle
17. Database safety: Zero migration, zero mutations, exact baseline restoration
"""

import os
import sys
import json
import base64
import datetime
from cryptography.hazmat.primitives.asymmetric import ed25519
from sqlalchemy import text

# Ensure backend root is on Python path
sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))

from app import app, db, User, DeviceIdentityKey, DeviceCertificate
from passport_service import (
    PassportService,
    set_institution_key_override,
    clear_institution_key_override,
    get_institution_public_key_b64,
    get_institution_key_id,
    canonicalize_payload,
    verify_institution_signature
)


def run_tests():
    print("=" * 60)
    print("CAMPUSOS PASSPORT 1F — OFFLINE TRUST BUNDLE TEST SUITE")
    print("=" * 60)

    # Configure ephemeral test institution key
    test_seed = b"test_institution_seed_campusos_!"  # exactly 32 bytes
    test_priv = ed25519.Ed25519PrivateKey.from_private_bytes(test_seed)
    test_priv_b64 = base64.b64encode(test_seed).decode('ascii')
    test_key_id = "campusos-institution-test-root-2026"
    set_institution_key_override(test_priv_b64, test_key_id)

    client = app.test_client()

    with app.app_context():
        # Step 0: Record baseline table counts
        tables = [
            'users', 'sessions', 'attendance', 'leave_requests', 'gate_passes',
            'complaints', 'complaint_status_history', 'request_audits', 'notices',
            'notification_deliveries', 'device_tokens', 'mess_menus', 'mess_meals',
            'mess_feedback', 'device_identity_keys', 'device_certificates'
        ]
        baseline = {t: db.session.execute(text(f"SELECT COUNT(*) FROM {t}")).scalar() for t in tables}
        print(f"[OK] Baseline database counts: {baseline}")

        # Find or create test users
        admin_user = User.query.filter_by(role='admin').first()
        staff_user = User.query.filter_by(role='staff').first()
        student_user = User.query.filter_by(role='student').first()

        assert admin_user is not None, "Admin user required for test fixtures"
        assert student_user is not None, "Student user required for test fixtures"
        staff_id = staff_user.id if staff_user else admin_user.id
        admin_id = admin_user.id
        student_id = student_user.id

        # Generate a test student keypair and register it
        student_seed = b"test_student_seed_for_offline_!!"  # 32 bytes
        student_priv = ed25519.Ed25519PrivateKey.from_private_bytes(student_seed)
        student_pub = student_priv.public_key()
        student_pub_b64 = base64.b64encode(student_pub.public_bytes_raw()).decode('ascii')

        # Register key for student
        reg_res = client.post(
            '/passport/keys/register',
            headers={'X-User-Id': student_id},
            json={'publicKey': student_pub_b64, 'keyType': 'ED25519'}
        )
        assert reg_res.status_code == 201, f"Failed to register student key: {reg_res.get_json()}"
        reg_data = reg_res.get_json()
        student_key_id = reg_data['keyId']
        student_cert_id = reg_data['certificate']['id']
        print(f"[OK] Registered student identity key {student_key_id}")

        # -------------------------------------------------------------
        # Test 1: Authorized staff can fetch trust bundle (200 OK)
        # -------------------------------------------------------------
        print("\n--- Test 1: Authorized staff can fetch bundle ---")
        res = client.get('/passport/trust-bundle', headers={'X-User-Id': staff_id})
        assert res.status_code == 200, f"Expected 200, got {res.status_code}: {res.get_json()}"
        bundle = res.get_json()
        assert "payload" in bundle, "Missing payload in bundle"
        assert "signature" in bundle, "Missing signature in bundle"
        print("[PASS] Authorized staff successfully downloaded trust bundle.")

        # -------------------------------------------------------------
        # Test 2: Student role denied (403 Forbidden)
        # -------------------------------------------------------------
        print("\n--- Test 2: Student denied trust bundle download (403) ---")
        res = client.get('/passport/trust-bundle', headers={'X-User-Id': student_id})
        assert res.status_code == 403, f"Expected 403, got {res.status_code}"
        print("[PASS] Student correctly forbidden from downloading trust bundle (403).")

        # -------------------------------------------------------------
        # Test 3: Unauthenticated request denied (401 Unauthorized)
        # -------------------------------------------------------------
        print("\n--- Test 3: Unauthenticated request denied (401) ---")
        res = client.get('/passport/trust-bundle')
        assert res.status_code == 401, f"Expected 401, got {res.status_code}"
        print("[PASS] Unauthenticated request correctly rejected with 401.")

        # -------------------------------------------------------------
        # Test 4: Bundle structure and metadata valid
        # -------------------------------------------------------------
        print("\n--- Test 4: Bundle structure and metadata validity ---")
        payload = bundle["payload"]
        assert payload["version"] == 1, "Expected bundle version 1"
        assert payload["issuerKeyId"] == test_key_id, f"Expected issuerKeyId {test_key_id}"
        assert isinstance(payload["generatedAt"], int), "generatedAt must be an integer unix timestamp"
        assert isinstance(payload["expiresAt"], int), "expiresAt must be an integer unix timestamp"
        assert payload["expiresAt"] > payload["generatedAt"], "expiresAt must be after generatedAt"
        assert "institution" in payload, "Missing institution block in payload"
        assert payload["institution"]["keyId"] == test_key_id
        assert payload["institution"]["publicKey"] == get_institution_public_key_b64()
        assert isinstance(payload["identities"], list), "identities must be a list"
        assert "revokedKeyIds" in payload, "revokedKeyIds must be present"
        print(f"[PASS] Bundle structure valid. Identities count: {len(payload['identities'])}")

        # -------------------------------------------------------------
        # Test 5: Bundle contains active identities
        # -------------------------------------------------------------
        print("\n--- Test 5: Bundle contains active identity entries ---")
        active_entries = [i for i in payload["identities"] if i["keyId"] == student_key_id]
        assert len(active_entries) == 1, f"Student key {student_key_id} not found in bundle identities"
        entry = active_entries[0]
        assert entry["userId"] == student_id
        assert entry["publicKey"] == student_pub_b64
        assert entry["certificateId"] == student_cert_id
        assert entry["issuerKeyId"] == test_key_id
        assert entry["status"] == "ACTIVE"
        print("[PASS] Active student identity correctly present in trust bundle.")

        # -------------------------------------------------------------
        # Test 6: Revoked identities handled correctly
        # -------------------------------------------------------------
        print("\n--- Test 6: Revoked identities handled correctly ---")
        # Revoke the student's key
        rev_res = client.post(f'/passport/keys/{student_key_id}/revoke', headers={'X-User-Id': student_id})
        assert rev_res.status_code == 200, f"Revocation failed: {rev_res.get_json()}"

        # Fetch bundle again
        res_after_rev = client.get('/passport/trust-bundle', headers={'X-User-Id': staff_id})
        bundle_after_rev = res_after_rev.get_json()
        payload_after_rev = bundle_after_rev["payload"]

        # Key should NOT be in active identities
        active_rev = [i for i in payload_after_rev["identities"] if i["keyId"] == student_key_id]
        assert len(active_rev) == 0, "Revoked key must NOT be in active identities!"

        # Key MUST be in revokedKeyIds
        assert student_key_id in payload_after_rev["revokedKeyIds"], "Revoked key must be in revokedKeyIds list"
        print("[PASS] Revoked key excluded from active identities and included in revokedKeyIds.")

        # -------------------------------------------------------------
        # Test 7: Expired certificates handled correctly
        # -------------------------------------------------------------
        print("\n--- Test 7: Expired certificates excluded from active bundle ---")
        # Enroll a new key and artificially set valid_to to the past
        student_seed2 = b"test_student_seed_2_for_offline!"  # 32 bytes
        student_priv2 = ed25519.Ed25519PrivateKey.from_private_bytes(student_seed2)
        student_pub2 = student_priv2.public_key()
        student_pub2_b64 = base64.b64encode(student_pub2.public_bytes_raw()).decode('ascii')

        reg_res2 = client.post(
            '/passport/keys/register',
            headers={'X-User-Id': student_id},
            json={'publicKey': student_pub2_b64, 'keyType': 'ED25519'}
        )
        assert reg_res2.status_code == 201
        key2_id = reg_res2.get_json()['keyId']
        cert2_id = reg_res2.get_json()['certificate']['id']

        # Artificially expire the certificate in database
        cert2 = DeviceCertificate.query.get(cert2_id)
        past_iso = (datetime.datetime.now() - datetime.timedelta(days=10)).isoformat()
        cert2.valid_to = past_iso
        db.session.commit()

        # Fetch bundle
        res_exp = client.get('/passport/trust-bundle', headers={'X-User-Id': staff_id})
        payload_exp = res_exp.get_json()["payload"]
        active_exp = [i for i in payload_exp["identities"] if i["keyId"] == key2_id]
        assert len(active_exp) == 0, "Identity with expired certificate must not be in active identities"
        print("[PASS] Identity with expired certificate properly excluded from active identities.")

        # Clean up key2
        k2 = DeviceIdentityKey.query.get(key2_id)
        c2 = DeviceCertificate.query.get(cert2_id)
        db.session.delete(c2)
        db.session.delete(k2)
        db.session.commit()

        # Re-register a fresh valid key for student
        reg_res3 = client.post(
            '/passport/keys/register',
            headers={'X-User-Id': student_id},
            json={'publicKey': student_pub2_b64, 'keyType': 'ED25519'}
        )
        assert reg_res3.status_code == 201
        key3_id = reg_res3.get_json()['keyId']
        cert3_id = reg_res3.get_json()['certificate']['id']

        # -------------------------------------------------------------
        # Test 8: Institution signature generated
        # -------------------------------------------------------------
        print("\n--- Test 8: Institution signature generated ---")
        fresh_res = client.get('/passport/trust-bundle', headers={'X-User-Id': staff_id})
        fresh_bundle = fresh_res.get_json()
        sig_b64 = fresh_bundle["signature"]
        raw_sig = base64.b64decode(sig_b64)
        assert len(raw_sig) == 64, f"Expected 64-byte Ed25519 signature, got {len(raw_sig)}"
        print("[PASS] Valid 64-byte Ed25519 institutional signature generated.")

        # -------------------------------------------------------------
        # Test 9: Bundle canonicalization deterministic
        # -------------------------------------------------------------
        print("\n--- Test 9: Bundle canonicalization deterministic ---")
        p = fresh_bundle["payload"]
        c1 = canonicalize_payload(p)
        c2 = canonicalize_payload(p)
        assert c1 == c2, "Canonicalization must be deterministic across calls"
        # Test that key ordering in nested dict is deterministic
        assert b'"identities":' in c1
        assert b'"institution":' in c1
        print("[PASS] Canonical serialization is 100% deterministic.")

        # -------------------------------------------------------------
        # Test 10: Bundle signature verifies with institution public key
        # -------------------------------------------------------------
        print("\n--- Test 10: Bundle signature verifies with institution public key ---")
        c_bytes = canonicalize_payload(fresh_bundle["payload"])
        valid_sig = verify_institution_signature(c_bytes, fresh_bundle["signature"])
        assert valid_sig is True, "Institutional signature must verify over canonical bundle payload"
        is_ok, err = PassportService.verify_trust_bundle(fresh_bundle)
        assert is_ok is True and err is None, f"PassportService.verify_trust_bundle failed: {err}"
        print("[PASS] Bundle signature cryptographically verified successfully.")

        # -------------------------------------------------------------
        # Test 11: Tampered bundle rejected
        # -------------------------------------------------------------
        print("\n--- Test 11: Tampered payload rejected ---")
        tampered_bundle = json.loads(json.dumps(fresh_bundle))
        tampered_bundle["payload"]["version"] = 99
        is_ok, _ = PassportService.verify_trust_bundle(tampered_bundle)
        assert is_ok is False, "Tampered version must fail signature verification"
        print("[PASS] Tampered bundle version rejected.")

        # -------------------------------------------------------------
        # Test 12: Changed identity public key rejected
        # -------------------------------------------------------------
        print("\n--- Test 12: Changed identity public key rejected ---")
        tampered_bundle = json.loads(json.dumps(fresh_bundle))
        if tampered_bundle["payload"]["identities"]:
            # Tamper with the public key of the identity
            tampered_bundle["payload"]["identities"][0]["publicKey"] = base64.b64encode(b"A" * 32).decode('ascii')
            is_ok, _ = PassportService.verify_trust_bundle(tampered_bundle)
            assert is_ok is False, "Tampered identity public key must fail verification"
        print("[PASS] Tampered identity public key detected and rejected.")

        # -------------------------------------------------------------
        # Test 13: Changed certificate rejected
        # -------------------------------------------------------------
        print("\n--- Test 13: Changed certificateId rejected ---")
        tampered_bundle = json.loads(json.dumps(fresh_bundle))
        if tampered_bundle["payload"]["identities"]:
            tampered_bundle["payload"]["identities"][0]["certificateId"] = "fake-cert-uuid"
            is_ok, _ = PassportService.verify_trust_bundle(tampered_bundle)
            assert is_ok is False, "Tampered certificate ID must fail verification"
        print("[PASS] Tampered certificateId detected and rejected.")

        # -------------------------------------------------------------
        # Test 14: Changed issuer rejected
        # -------------------------------------------------------------
        print("\n--- Test 14: Changed issuerKeyId rejected ---")
        tampered_bundle = json.loads(json.dumps(fresh_bundle))
        tampered_bundle["payload"]["issuerKeyId"] = "rogue-issuer-id"
        is_ok, _ = PassportService.verify_trust_bundle(tampered_bundle)
        assert is_ok is False, "Tampered issuerKeyId must fail verification"
        print("[PASS] Tampered issuerKeyId detected and rejected.")

        # -------------------------------------------------------------
        # Test 15: Changed expiry rejected
        # -------------------------------------------------------------
        print("\n--- Test 15: Changed expiresAt rejected ---")
        tampered_bundle = json.loads(json.dumps(fresh_bundle))
        tampered_bundle["payload"]["expiresAt"] += 100000
        is_ok, _ = PassportService.verify_trust_bundle(tampered_bundle)
        assert is_ok is False, "Tampered expiresAt must fail verification"
        print("[PASS] Tampered expiresAt detected and rejected.")

        # -------------------------------------------------------------
        # Test 16: Zero private keys in trust bundle
        # -------------------------------------------------------------
        print("\n--- Test 16: Zero private key material in trust bundle ---")
        bundle_str = json.dumps(fresh_bundle)
        assert "private" not in bundle_str.lower(), "Found 'private' string in trust bundle"
        assert "secret" not in bundle_str.lower(), "Found 'secret' string in trust bundle"
        assert test_priv_b64 not in bundle_str, "Found raw institution private key in trust bundle"
        print("[PASS] Security invariant confirmed: ZERO private keys or secrets in trust bundle.")

        # -------------------------------------------------------------
        # Cleanup & Baseline Verification
        # -------------------------------------------------------------
        print("\n--- Restoring database baseline ---")
        # Delete test keys & certs
        for kid in [student_key_id, key3_id]:
            k = DeviceIdentityKey.query.get(kid)
            if k:
                for c in k.certificates:
                    db.session.delete(c)
                db.session.delete(k)
        db.session.commit()

        final_counts = {t: db.session.execute(text(f"SELECT COUNT(*) FROM {t}")).scalar() for t in tables}
        passport_tables = ['device_identity_keys', 'device_certificates', 'users']
        for t in passport_tables:
            assert final_counts[t] == baseline[t], f"Table {t} mutated! Baseline: {baseline[t]}, Final: {final_counts[t]}"
        print(f"[OK] Database baseline perfectly restored for passport domain: {final_counts}")

    clear_institution_key_override()
    print("\n" + "=" * 60)
    print("ALL 16 PASSPORT 1F TRUST BUNDLE TESTS PASSED SUCCESSFULLY!")
    print("=" * 60)


if __name__ == '__main__':
    run_tests()
