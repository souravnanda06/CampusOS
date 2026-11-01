import re
from flask import Blueprint, request, jsonify
from extensions import db
from models.user import User
from models.passport import DeviceIdentityKey, DeviceCertificate
from middleware.auth import get_authenticated_requester
from services.passport_service import (
    PassportService,
    get_institution_key_id,
    get_institution_public_key_b64
)

passport_bp = Blueprint('passport_bp', __name__)

@passport_bp.route('/passport/institution/public-key', methods=['GET'])
def get_passport_institution_public_key():
    """
    Exposes the trusted public institutional certificate-signing key.
    Used by clients and verifiers to authenticate CampusOS certificates.
    Never exposes private key material.
    """
    try:
        return jsonify({
            "issuer": "CampusOS",
            "issuerKeyId": get_institution_key_id(),
            "publicKey": get_institution_public_key_b64(),
            "algorithm": "Ed25519"
        }), 200
    except Exception as e:
        return jsonify({"message": f"Institutional signing key is not configured: {e}"}), 500


@passport_bp.route('/passport/keys/register', methods=['POST'])
def register_passport_key():
    """
    Registers a device's public Ed25519 key and issues an institutional certificate.
    Security:
    - Requester must authenticate via header (X-User-Id / X-Requester-Id).
    - Students can ONLY register a key for themselves (requester.id == target user).
    - Rejects malformed / wrong-length keys with 400.
    - Rejects duplicate keys with 409.
    - Rejects attempts to register when active key already exists with 409.
    - The server NEVER receives or stores private keys.
    """
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required"}), 401

    # Require explicit authentication header (do not treat client-supplied body userId as authorization)
    auth_header = request.headers.get('Authorization') or request.headers.get('X-User-Id') or request.headers.get('X-Requester-Id')
    if not auth_header:
        return jsonify({"message": "Authentication required: Missing authentication header"}), 401

    data = request.json or {}
    target_user_id = data.get('userId') or requester.id

    # Self-registration only for students
    if target_user_id != requester.id and requester.role not in ['admin', 'staff']:
        return jsonify({"message": "Forbidden: You are not authorized to register a key for another user"}), 403

    public_key_b64 = data.get('publicKey')
    if not public_key_b64:
        return jsonify({"message": "publicKey is required"}), 400

    key_type = (data.get('keyType') or 'ED25519').upper().strip()
    if key_type != 'ED25519':
        return jsonify({"message": f"Unsupported keyType '{key_type}'. Only 'ED25519' is supported."}), 400

    try:
        identity_key, cert = PassportService.register_public_key(
            db=db,
            user_model=User,
            device_identity_key_model=DeviceIdentityKey,
            device_certificate_model=DeviceCertificate,
            user_id=target_user_id,
            public_key_b64=public_key_b64,
            key_type=key_type
        )

        return jsonify({
            "keyId": identity_key.id,
            "status": identity_key.status,
            "publicKey": identity_key.public_key_b64,
            "keyType": identity_key.key_type,
            "certificate": cert.to_dict()
        }), 201

    except ValueError as ve:
        return jsonify({"message": f"Invalid public key: {ve}"}), 400
    except RuntimeError as re:
        msg = str(re)
        if "DUPLICATE_KEY" in msg:
            return jsonify({"message": "Conflict: This public key is already registered in the system"}), 409
        elif "ACTIVE_KEY_EXISTS" in msg:
            return jsonify({"message": "Conflict: User already has an active Passport identity key"}), 409
        elif "Institutional signing key is not configured" in msg:
            return jsonify({"message": "Configuration error: Institutional signing key is not configured"}), 500
        return jsonify({"message": f"Key registration error: {msg}"}), 400
    except Exception as e:
        return jsonify({"message": "Internal server error during key registration"}), 500


@passport_bp.route('/passport/keys/<student_id>', methods=['GET'])
def get_passport_keys_for_student(student_id):
    """
    Retrieves public key and institutional certificate metadata for a student.
    Authorization:
    - Students can ONLY view their own Passport identity.
    - Staff / admin / warden can view any student's Passport identity.
    - Returns only public cryptographic information, never secrets.
    """
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required"}), 401

    is_staff = requester.role and requester.role.lower() in ['admin', 'staff', 'warden']
    if requester.id != student_id and not is_staff:
        return jsonify({"message": "Forbidden: You are not authorized to view another student's identity"}), 403

    student = User.query.get(student_id)
    if not student:
        return jsonify({"message": "Student not found"}), 404

    active_key = PassportService.get_active_key(DeviceIdentityKey, student_id)
    if not active_key:
        all_keys = PassportService.get_all_keys(DeviceIdentityKey, student_id)
        if not all_keys:
            return jsonify({"message": "No Passport identity found for this student"}), 404
        key_to_show = all_keys[0]
    else:
        key_to_show = active_key

    cert = key_to_show.get_active_certificate() or (key_to_show.certificates.first() if key_to_show.certificates else None)

    return jsonify({
        "keyId": key_to_show.id,
        "userId": key_to_show.user_id,
        "publicKey": key_to_show.public_key_b64,
        "keyType": key_to_show.key_type,
        "status": key_to_show.status,
        "certificate": cert.to_dict() if cert else None,
        "certificateStatus": cert.status if cert else None,
        "validFrom": cert.valid_from if cert else None,
        "validTo": cert.valid_to if cert else None
    }), 200


@passport_bp.route('/passport/identity', methods=['GET'])
def get_current_passport_identity():
    """
    Convenience endpoint for client device to query its current user's Passport enrollment status.
    Returns:
    - enrolled: false if no active key exists (HTTP 200)
    - enrolled: true with key and certificate if active key exists (HTTP 200)
    """
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required"}), 401

    active_key = PassportService.get_active_key(DeviceIdentityKey, requester.id)
    if not active_key:
        return jsonify({"enrolled": False}), 200

    cert = active_key.get_active_certificate()
    return jsonify({
        "enrolled": True,
        "key": active_key.to_dict(),
        "certificate": cert.to_dict() if cert else None
    }), 200


@passport_bp.route('/passport/keys/<key_id>/revoke', methods=['POST'])
def revoke_passport_key(key_id):
    """
    Revokes a DeviceIdentityKey and its associated certificates.
    Authorization:
    - Key owner can revoke their own key.
    - Staff / admin / warden can revoke any key.
    - Other students are forbidden.
    """
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required"}), 401

    key = DeviceIdentityKey.query.get(key_id)
    if not key:
        return jsonify({"message": "DeviceIdentityKey not found"}), 404

    is_staff = requester.role and requester.role.lower() in ['admin', 'staff', 'warden']
    if requester.id != key.user_id and not is_staff:
        return jsonify({"message": "Forbidden: You are not authorized to revoke this key"}), 403

    revoked_key = PassportService.revoke_key(db, DeviceIdentityKey, key_id)
    return jsonify({
        "message": "Key and associated certificates revoked successfully",
        "key": revoked_key.to_dict()
    }), 200


@passport_bp.route('/passport/verify-certificate', methods=['POST'])
def verify_passport_certificate():
    """
    Verifies an institutional DeviceCertificate against the 10 verification rules:
    1. Structure
    2. Signature
    3. Issuer & Key ID
    4. Validity window
    5. Certificate status
    6. Public key format
    7. Certificate user ID
    8. Registered key exists
    9. Registered key matches certificate public key
    10. Key status is ACTIVE
    """
    data = request.json or {}
    cert_input = data.get('certificate') or data

    if 'certificateId' in data and not cert_input.get('signature'):
        db_cert = DeviceCertificate.query.get(data['certificateId'])
        if not db_cert:
            return jsonify({
                "valid": False,
                "reason": f"Certificate with ID '{data['certificateId']}' not found in database",
                "details": {}
            }), 404
        cert_input = db_cert.to_dict()

    result = PassportService.verify_certificate(
        cert_data=cert_input,
        user_model=User,
        device_identity_key_model=DeviceIdentityKey,
        device_certificate_model=DeviceCertificate,
        check_database=True
    )
    return jsonify(result), 200


@passport_bp.route('/passport/verify', methods=['POST'])
def verify_passport_presentation():
    """
    Verifies a dynamic Passport presentation (Phase 1D).
    Validates:
    - Payload format, version, type
    - Student's certified public key
    - Institutional certificate status and validity window
    - Expiration window (~30s) and clock skew tolerance
    - Ed25519 signature over canonical presentation JSON
    """
    data = request.json or {}
    payload = data.get('payload') or data.get('p')
    signature = data.get('signature') or data.get('s')

    if not payload or not isinstance(payload, dict):
        return jsonify({"valid": False, "reason": "INVALID_FORMAT"}), 200

    if not signature or not isinstance(signature, str):
        return jsonify({"valid": False, "reason": "INVALID_SIGNATURE"}), 200

    max_skew = 30
    if 'maxClockSkewSeconds' in data and isinstance(data['maxClockSkewSeconds'], int):
        max_skew = data['maxClockSkewSeconds']

    result = PassportService.verify_presentation(
        payload=payload,
        signature_b64=signature,
        device_identity_key_model=DeviceIdentityKey,
        device_certificate_model=DeviceCertificate,
        user_model=User,
        max_clock_skew_seconds=max_skew
    )
    return jsonify(result), 200


@passport_bp.route('/passport/trust-bundle', methods=['GET'])
def get_passport_trust_bundle():
    """
    Returns the signed institutional trust bundle for offline verifiers (Phase 1F).
    Authorization:
    - Strictly restricted to ADMIN, WARDEN, STAFF, TEACHER roles.
    - Students receive 403 Forbidden.
    - Unauthenticated requests receive 401 Unauthorized.
    Contains only public keys, active certificates, and non-sensitive validity metadata.
    Signed with the institution Ed25519 root private key.
    """
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required"}), 401

    allowed_roles = ['admin', 'warden', 'staff', 'teacher']
    if not requester.role or requester.role.lower() not in allowed_roles:
        return jsonify({"message": "Forbidden: Only authorized verifiers can download the trust bundle"}), 403

    ttl_seconds = request.args.get('ttlSeconds', default=86400, type=int)

    try:
        bundle = PassportService.generate_trust_bundle(
            db=db,
            device_identity_key_model=DeviceIdentityKey,
            device_certificate_model=DeviceCertificate,
            user_model=User,
            ttl_seconds=ttl_seconds
        )
        return jsonify(bundle), 200
    except Exception as e:
        return jsonify({"message": f"Failed to generate trust bundle: {e}"}), 500

