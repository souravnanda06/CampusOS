import os
import sys
import json
import base64
import uuid
import datetime
from cryptography.hazmat.primitives.asymmetric import ed25519

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from app import app, db, User, DeviceIdentityKey, DeviceCertificate
import passport_service
from passport_service import (
    PassportService,
    get_institution_key_id,
    get_institution_private_key,
    get_institution_public_key,
    get_institution_public_key_b64,
    set_institution_key_override,
    clear_institution_key_override,
    canonicalize_payload,
    ENV_INSTITUTION_PRIVATE_KEY,
    ENV_INSTITUTION_KEY_ID
)


def run_tests():
    print("==================================================")
    print("CAMPUSOS PASSPORT: INSTITUTIONAL SIGNING KEY CONFIGURATION TESTS")
    print("==================================================")

    # Save initial environment state
    saved_env_key = os.environ.get(ENV_INSTITUTION_PRIVATE_KEY)
    saved_env_id = os.environ.get(ENV_INSTITUTION_KEY_ID)

    try:
        # 1. Missing PASSPORT_INSTITUTION_PRIVATE_KEY produces existing configuration error
        print("\n--- Test 1: Missing PASSPORT_INSTITUTION_PRIVATE_KEY raises RuntimeError ---")
        clear_institution_key_override()
        if ENV_INSTITUTION_PRIVATE_KEY in os.environ:
            del os.environ[ENV_INSTITUTION_PRIVATE_KEY]

        try:
            get_institution_private_key()
            assert False, "Expected RuntimeError for missing key"
        except RuntimeError as e:
            assert "Institutional signing key is not configured" in str(e)
            print(f"[PASS] Missing key raises expected RuntimeError: {e}")

        # Also verify backend endpoint returns 500 when unconfigured
        client = app.test_client()
        student_test_id = f"test-student-cfg-{uuid.uuid4().hex[:8]}"
        with app.app_context():
            test_user = User(
                id=student_test_id,
                email=f"{student_test_id}@campusos.edu",
                name="Config Test Student",
                role="student",
                password="password123"
            )
            db.session.add(test_user)
            db.session.commit()

        try:
            device_priv = ed25519.Ed25519PrivateKey.generate()
            device_pub_b64 = base64.b64encode(device_priv.public_key().public_bytes_raw()).decode('ascii')
            res = client.post(
                '/passport/keys/register',
                headers={'X-User-Id': student_test_id},
                json={'userId': student_test_id, 'publicKey': device_pub_b64, 'keyType': 'ED25519'}
            )
            assert res.status_code == 500, f"Expected 500, got {res.status_code}: {res.data}"
            err_data = json.loads(res.data)
            assert "Institutional signing key is not configured" in err_data.get('message', '')
            print("[PASS] Endpoint returns 500 'Institutional signing key is not configured'")

            # 2. Valid Base64 32-byte seed loads successfully
            print("\n--- Test 2: Valid Base64 32-byte seed loads successfully ---")
            sample_priv = ed25519.Ed25519PrivateKey.generate()
            sample_seed = sample_priv.private_bytes_raw()
            assert len(sample_seed) == 32
            sample_seed_b64 = base64.b64encode(sample_seed).decode('ascii')

            os.environ[ENV_INSTITUTION_PRIVATE_KEY] = sample_seed_b64
            os.environ[ENV_INSTITUTION_KEY_ID] = "test-root-key-v1"

            loaded_priv = get_institution_private_key()
            assert isinstance(loaded_priv, ed25519.Ed25519PrivateKey)
            assert get_institution_key_id() == "test-root-key-v1"
            print("[PASS] Valid 32-byte seed successfully loaded from environment.")

            # 3. Invalid Base64 is rejected
            print("\n--- Test 3: Invalid Base64 is rejected ---")
            os.environ[ENV_INSTITUTION_PRIVATE_KEY] = "not-a-valid-base64-string!@#$%"
            try:
                get_institution_private_key()
                assert False, "Expected ValueError for invalid base64"
            except ValueError as ve:
                assert "Invalid Base64 format" in str(ve)
                print(f"[PASS] Malformed Base64 correctly rejected: {ve}")

            # 4. Wrong byte length is rejected
            print("\n--- Test 4: Wrong byte length is rejected ---")
            # 16 bytes
            short_b64 = base64.b64encode(b"X" * 16).decode('ascii')
            os.environ[ENV_INSTITUTION_PRIVATE_KEY] = short_b64
            try:
                get_institution_private_key()
                assert False, "Expected ValueError for short byte length"
            except ValueError as ve:
                assert "expected 32 raw bytes" in str(ve)
                print(f"[PASS] Short byte length correctly rejected: {ve}")

            # 64 bytes (attempting full private key format instead of 32-byte seed)
            long_b64 = base64.b64encode(b"X" * 64).decode('ascii')
            os.environ[ENV_INSTITUTION_PRIVATE_KEY] = long_b64
            try:
                get_institution_private_key()
                assert False, "Expected ValueError for 64-byte key"
            except ValueError as ve:
                assert "expected 32 raw bytes" in str(ve)
                print(f"[PASS] 64-byte payload correctly rejected: {ve}")

            # 5. Institution public key can be derived
            print("\n--- Test 5: Institution public key can be derived ---")
            os.environ[ENV_INSTITUTION_PRIVATE_KEY] = sample_seed_b64
            derived_pub = get_institution_public_key()
            assert isinstance(derived_pub, ed25519.Ed25519PublicKey)
            derived_pub_b64 = get_institution_public_key_b64()
            expected_pub_b64 = base64.b64encode(sample_priv.public_key().public_bytes_raw()).decode('ascii')
            assert derived_pub_b64 == expected_pub_b64
            print(f"[PASS] Derived institution public key correctly: {derived_pub_b64}")

            # 6. Certificate issuance succeeds
            print("\n--- Test 6: Certificate issuance succeeds ---")
            res_enroll = client.post(
                '/passport/keys/register',
                headers={'X-User-Id': student_test_id},
                json={'userId': student_test_id, 'publicKey': device_pub_b64, 'keyType': 'ED25519'}
            )
            assert res_enroll.status_code == 201, f"Expected 201, got {res_enroll.status_code}: {res_enroll.data}"
            enroll_data = json.loads(res_enroll.data)
            assert enroll_data['status'] == 'ACTIVE'
            cert_data = enroll_data['certificate']
            assert cert_data['status'] == 'ACTIVE'
            assert cert_data['userId'] == student_test_id
            print(f"[PASS] Key registered and certificate issued: keyId={enroll_data['keyId']}")

            # 7. Issued certificate verifies against the institution public key
            print("\n--- Test 7: Issued certificate cryptographically verifies with institution public key ---")
            canonical_bytes = canonicalize_payload(cert_data['payload'])
            sig_bytes = base64.b64decode(cert_data['signature'])
            derived_pub.verify(sig_bytes, canonical_bytes)
            print("[PASS] Certificate signature cryptographically verified against institution public key.")

            # 8. Private key is never included in API responses
            print("\n--- Test 8: Private key is never exposed in API responses ---")
            res_pub = client.get('/passport/institution/public-key')
            assert res_pub.status_code == 200
            pub_data = json.loads(res_pub.data)
            assert pub_data['issuer'] == 'CampusOS'
            assert pub_data['publicKey'] == expected_pub_b64
            assert 'private' not in json.dumps(pub_data).lower()
            assert 'private' not in json.dumps(enroll_data).lower()
            print("[PASS] Zero private key material in public key endpoint or enrollment responses.")

        finally:
            with app.app_context():
                DeviceCertificate.query.filter_by(subject_user_id=student_test_id).delete()
                DeviceIdentityKey.query.filter_by(user_id=student_test_id).delete()
                User.query.filter_by(id=student_test_id).delete()
                db.session.commit()

    finally:
        # Restore initial environment
        if saved_env_key is not None:
            os.environ[ENV_INSTITUTION_PRIVATE_KEY] = saved_env_key
        elif ENV_INSTITUTION_PRIVATE_KEY in os.environ:
            del os.environ[ENV_INSTITUTION_PRIVATE_KEY]

        if saved_env_id is not None:
            os.environ[ENV_INSTITUTION_KEY_ID] = saved_env_id
        elif ENV_INSTITUTION_KEY_ID in os.environ:
            del os.environ[ENV_INSTITUTION_KEY_ID]
        clear_institution_key_override()

    print("\n==================================================")
    print("ALL 8 INSTITUTIONAL SIGNING KEY CONFIGURATION TESTS PASSED!")
    print("==================================================")


if __name__ == '__main__':
    run_tests()
