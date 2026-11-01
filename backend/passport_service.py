import os
import json
import base64
import datetime
from typing import Optional, Tuple, Dict, Any, List
from cryptography.hazmat.primitives.asymmetric import ed25519
from cryptography.exceptions import InvalidSignature

# Configuration environment variables
ENV_INSTITUTION_PRIVATE_KEY = "PASSPORT_INSTITUTION_PRIVATE_KEY"
ENV_INSTITUTION_KEY_ID = "PASSPORT_INSTITUTION_KEY_ID"
DEFAULT_ISSUER_NAME = "CampusOS"
DEFAULT_KEY_ID = "campusos-root-2026-v1"


def _load_env_file() -> None:
    """
    Loads local environment variables from .env if present and not already set in os.environ.
    Uses pure standard library to avoid external dependencies.
    """
    base_dir = os.path.dirname(os.path.abspath(__file__))
    candidates = [
        os.path.join(base_dir, '.env'),
        os.path.join(os.path.dirname(base_dir), '.env'),
    ]
    for env_path in candidates:
        if os.path.isfile(env_path):
            try:
                with open(env_path, 'r', encoding='utf-8') as f:
                    for line in f:
                        line = line.strip()
                        if not line or line.startswith('#') or '=' not in line:
                            continue
                        k, v = line.split('=', 1)
                        k = k.strip()
                        v = v.strip().strip("'\"")
                        if k and k not in os.environ:
                            os.environ[k] = v
            except Exception:
                pass


_load_env_file()

# In-memory test override for test isolation
_test_institution_private_key_b64: Optional[str] = None
_test_institution_key_id: Optional[str] = None


def set_institution_key_override(private_key_b64: Optional[str] = None, key_id: Optional[str] = None) -> None:
    """
    Sets an ephemeral in-memory institution private key and key ID.
    Strictly for automated test suites to avoid committing or hardcoding secrets.
    """
    global _test_institution_private_key_b64, _test_institution_key_id
    _test_institution_private_key_b64 = private_key_b64
    _test_institution_key_id = key_id


def clear_institution_key_override() -> None:
    """Clears the test override."""
    global _test_institution_private_key_b64, _test_institution_key_id
    _test_institution_private_key_b64 = None
    _test_institution_key_id = None


def get_institution_key_id() -> str:
    """Returns the current institution key ID."""
    if _test_institution_key_id:
        return _test_institution_key_id
    return os.environ.get(ENV_INSTITUTION_KEY_ID, DEFAULT_KEY_ID)


def get_institution_private_key() -> ed25519.Ed25519PrivateKey:
    """
    Loads and returns the institution Ed25519 private key.
    Raises RuntimeError if neither override nor environment variable is configured.
    Never silently generates a new production key or commits a secret.
    """
    raw_key_b64 = _test_institution_private_key_b64 or os.environ.get(ENV_INSTITUTION_PRIVATE_KEY)
    if not raw_key_b64:
        raise RuntimeError(
            f"Institutional signing key is not configured. "
            f"Set the '{ENV_INSTITUTION_PRIVATE_KEY}' environment variable."
        )

    clean_key_b64 = raw_key_b64.strip()
    try:
        raw_bytes = base64.b64decode(clean_key_b64)
    except Exception as e:
        raise ValueError(f"Invalid Base64 format for institution private key: {e}")

    if len(raw_bytes) != 32:
        raise ValueError(
            f"Invalid institution private key length: expected 32 raw bytes (seed), got {len(raw_bytes)} bytes."
        )

    return ed25519.Ed25519PrivateKey.from_private_bytes(raw_bytes)


def get_institution_public_key() -> ed25519.Ed25519PublicKey:
    """Derives and returns the institution Ed25519 public key."""
    priv = get_institution_private_key()
    return priv.public_key()


def get_institution_public_key_b64() -> str:
    """Returns the Base64-encoded raw 32-byte public key of the institution."""
    pub = get_institution_public_key()
    return base64.b64encode(pub.public_bytes_raw()).decode('ascii')


def validate_public_key(public_key_b64: Any) -> Tuple[bool, Optional[str], Optional[bytes]]:
    """
    Validates an Ed25519 public key.
    Must be a non-empty string, valid Base64, and decode to exactly 32 raw bytes.
    Specifically rejects non-32-byte payloads (such as 64-byte private keys or signatures).
    """
    if not public_key_b64 or not isinstance(public_key_b64, str):
        return False, "Public key must be a non-empty string", None

    clean_b64 = public_key_b64.strip()
    try:
        raw_bytes = base64.b64decode(clean_b64, validate=True)
    except Exception as e:
        return False, f"Malformed Base64 public key: {e}", None

    if len(raw_bytes) != 32:
        if len(raw_bytes) == 64:
            return False, "Invalid public key length: 64-byte payload detected (private key or signature payload rejected)", None
        return False, f"Invalid Ed25519 public key length: expected 32 bytes, got {len(raw_bytes)}", None

    try:
        # Verify it loads as a valid Ed25519 public key
        ed25519.Ed25519PublicKey.from_public_bytes(raw_bytes)
    except Exception as e:
        return False, f"Invalid Ed25519 public key point: {e}", None

    return True, None, raw_bytes


def canonicalize_payload(payload_dict: Dict[str, Any]) -> bytes:
    """
    Canonicalizes a certificate dictionary into deterministic UTF-8 bytes.
    Rules:
    - Sorted keys (alphabetical)
    - Compact separators (',' and ':') with no whitespace
    - UTF-8 encoded
    - ensure_ascii=False for standard UTF-8 preservation
    """
    return json.dumps(
        payload_dict,
        sort_keys=True,
        separators=(',', ':'),
        ensure_ascii=False
    ).encode('utf-8')


def sign_canonical_payload(canonical_bytes: bytes) -> str:
    """
    Signs canonical certificate bytes using the institution Ed25519 private key.
    Returns the resulting 64-byte Ed25519 signature encoded as Base64.
    """
    priv_key = get_institution_private_key()
    sig_bytes = priv_key.sign(canonical_bytes)
    return base64.b64encode(sig_bytes).decode('ascii')


def verify_institution_signature(canonical_bytes: bytes, signature_b64: str) -> bool:
    """
    Verifies a Base64-encoded signature over canonical bytes using the institution public key.
    """
    try:
        pub_key = get_institution_public_key()
        sig_bytes = base64.b64decode(signature_b64.strip(), validate=True)
        if len(sig_bytes) != 64:
            return False
        pub_key.verify(sig_bytes, canonical_bytes)
        return True
    except (InvalidSignature, Exception):
        return False


def verify_device_signature(canonical_bytes: bytes, signature_b64: str, public_key_b64: str) -> bool:
    """
    Verifies an Ed25519 signature generated by a student device using the registered public key.
    """
    try:
        pub_bytes = base64.b64decode(public_key_b64.strip(), validate=True)
        if len(pub_bytes) != 32:
            return False
        sig_bytes = base64.b64decode(signature_b64.strip(), validate=True)
        if len(sig_bytes) != 64:
            return False
        pub_key = ed25519.Ed25519PublicKey.from_public_bytes(pub_bytes)
        pub_key.verify(sig_bytes, canonical_bytes)
        return True
    except (InvalidSignature, Exception):
        return False


def canonicalize_presentation_payload(payload_dict: Dict[str, Any]) -> bytes:
    """Canonicalizes a presentation payload dictionary into deterministic UTF-8 bytes."""
    return canonicalize_payload(payload_dict)


class PassportService:
    """
    Service layer for CampusOS Passport identity key registration,
    institutional certification, lifecycle management, and verification.
    """

    @staticmethod
    def register_public_key(
        db,
        user_model,
        device_identity_key_model,
        device_certificate_model,
        user_id: str,
        public_key_b64: str,
        key_type: str = "ED25519",
        validity_days: int = 365
    ) -> Tuple[Any, Any]:
        """
        Registers a new Ed25519 public key for a user and issues an institutional certificate.
        Enforces:
        - Exactly 32-byte Ed25519 public key format.
        - Public key uniqueness across the entire system.
        - Single ACTIVE key enrollment policy per user.
        - Deterministic canonical institutional certificate generation and signing.
        """
        # 1. Validate public key format
        is_valid, err_msg, raw_bytes = validate_public_key(public_key_b64)
        if not is_valid:
            raise ValueError(err_msg)

        # Standardize clean Base64 representation (32 bytes standard base64)
        clean_pub_b64 = base64.b64encode(raw_bytes).decode('ascii')

        # 2. Validate key_type
        if (key_type or '').strip().upper() != "ED25519":
            raise ValueError(f"Unsupported keyType '{key_type}'. Only 'ED25519' is currently supported.")

        # 3. Validate user exists
        user = user_model.query.get(user_id)
        if not user:
            raise ValueError(f"User with ID '{user_id}' does not exist.")

        # 4. Check for duplicate public key anywhere in the database
        existing_duplicate = device_identity_key_model.query.filter_by(public_key_b64=clean_pub_b64).first()
        if existing_duplicate:
            raise RuntimeError("DUPLICATE_KEY: This public key is already registered in the system.")

        # 5. Check enrollment policy: only 1 ACTIVE key per student
        active_key = device_identity_key_model.query.filter_by(user_id=user_id, status='ACTIVE').first()
        if active_key:
            raise RuntimeError("ACTIVE_KEY_EXISTS: User already has an active Passport identity key.")

        now_dt = datetime.datetime.now()
        now_iso = now_dt.isoformat()
        expiry_dt = now_dt + datetime.timedelta(days=validity_days)
        expiry_iso = expiry_dt.isoformat()

        # 6. Create DeviceIdentityKey
        import uuid
        identity_key = device_identity_key_model(
            id=str(uuid.uuid4()),
            user_id=user_id,
            public_key_b64=clean_pub_b64,
            key_type="ED25519",
            status="ACTIVE",
            created_at=now_iso,
            activated_at=now_iso,
            revoked_at=None,
            last_seen_at=now_iso
        )
        db.session.add(identity_key)
        db.session.flush()

        # 7. Issue Institutional Certificate
        cert = PassportService.issue_certificate(
            db=db,
            device_certificate_model=device_certificate_model,
            identity_key=identity_key,
            valid_from_iso=now_iso,
            valid_to_iso=expiry_iso
        )

        db.session.commit()
        return identity_key, cert

    @staticmethod
    def issue_certificate(
        db,
        device_certificate_model,
        identity_key: Any,
        valid_from_iso: Optional[str] = None,
        valid_to_iso: Optional[str] = None,
        validity_days: int = 365
    ) -> Any:
        """
        Generates and signs an institutional DeviceCertificate for a DeviceIdentityKey.
        """
        import uuid
        now_dt = datetime.datetime.now()
        valid_from = valid_from_iso or now_dt.isoformat()
        valid_to = valid_to_iso or (now_dt + datetime.timedelta(days=validity_days)).isoformat()
        issuer_key_id = get_institution_key_id()

        # Build canonical payload dict
        payload = {
            "algorithm": "Ed25519",
            "certificateVersion": "1.0",
            "issuer": DEFAULT_ISSUER_NAME,
            "keyId": identity_key.id,
            "publicKey": identity_key.public_key_b64,
            "userId": identity_key.user_id,
            "validFrom": valid_from,
            "validTo": valid_to
        }

        canonical_bytes = canonicalize_payload(payload)
        sig_b64 = sign_canonical_payload(canonical_bytes)

        cert = device_certificate_model(
            id=str(uuid.uuid4()),
            key_id=identity_key.id,
            certificate_version="1.0",
            issuer=DEFAULT_ISSUER_NAME,
            issuer_key_id=issuer_key_id,
            subject_user_id=identity_key.user_id,
            subject_public_key_b64=identity_key.public_key_b64,
            algorithm="Ed25519",
            valid_from=valid_from,
            valid_to=valid_to,
            signature=sig_b64,
            status="ACTIVE",
            created_at=now_dt.isoformat(),
            revoked_at=None
        )
        db.session.add(cert)
        return cert

    @staticmethod
    def verify_certificate(
        cert_data: Any,
        user_model=None,
        device_identity_key_model=None,
        device_certificate_model=None,
        check_database: bool = True
    ) -> Dict[str, Any]:
        """
        Comprehensive 10-point certificate verification:
        1. certificate structure
        2. certificate signature
        3. institution issuer & key ID
        4. certificate validity window
        5. certificate status
        6. public key format
        7. certificate user ID
        8. registered DeviceIdentityKey exists
        9. registered key matches certificate public key
        10. key status is ACTIVE
        """
        details: Dict[str, Any] = {}

        # 1. Normalize input dictionary
        if hasattr(cert_data, 'to_dict'):
            d = cert_data.to_dict()
        elif isinstance(cert_data, dict):
            d = cert_data
        else:
            return {"valid": False, "reason": "Invalid certificate input: expected dict or model", "details": details}

        # Extract payload and signature
        payload = d.get('payload') or d
        sig_b64 = d.get('signature') or payload.get('signature')

        # Check required fields
        required_fields = [
            "certificateVersion", "issuer", "keyId", "userId",
            "publicKey", "algorithm", "validFrom", "validTo"
        ]
        for field in required_fields:
            val = payload.get(field)
            if not val:
                return {
                    "valid": False,
                    "reason": f"Missing required certificate field: '{field}'",
                    "details": details
                }

        if not sig_b64:
            return {"valid": False, "reason": "Missing certificate signature", "details": details}

        cert_version = payload.get("certificateVersion")
        issuer = payload.get("issuer")
        issuer_key_id = d.get("issuerKeyId") or payload.get("issuerKeyId") or get_institution_key_id()
        key_id = payload.get("keyId")
        user_id = payload.get("userId")
        public_key_b64 = payload.get("publicKey")
        algorithm = payload.get("algorithm")
        valid_from_str = payload.get("validFrom")
        valid_to_str = payload.get("validTo")
        cert_status = (d.get("status") or "ACTIVE").upper()

        details.update({
            "certificateVersion": cert_version,
            "issuer": issuer,
            "issuerKeyId": issuer_key_id,
            "keyId": key_id,
            "userId": user_id,
            "algorithm": algorithm,
            "status": cert_status
        })

        # 2. Issuer check
        if issuer != DEFAULT_ISSUER_NAME:
            return {
                "valid": False,
                "reason": f"Invalid certificate issuer '{issuer}': expected '{DEFAULT_ISSUER_NAME}'",
                "details": details
            }

        # 3. Algorithm check
        if (algorithm or '').upper() != "ED25519":
            return {
                "valid": False,
                "reason": f"Unsupported certificate algorithm '{algorithm}': expected 'Ed25519'",
                "details": details
            }

        # 4. Public key format check
        is_valid_pk, pk_err, _ = validate_public_key(public_key_b64)
        if not is_valid_pk:
            return {
                "valid": False,
                "reason": f"Malformed subject public key: {pk_err}",
                "details": details
            }

        # 5. Certificate signature check
        canonical_dict = {
            "algorithm": algorithm,
            "certificateVersion": cert_version,
            "issuer": issuer,
            "keyId": key_id,
            "publicKey": public_key_b64,
            "userId": user_id,
            "validFrom": valid_from_str,
            "validTo": valid_to_str
        }
        canonical_bytes = canonicalize_payload(canonical_dict)
        sig_ok = verify_institution_signature(canonical_bytes, sig_b64)
        if not sig_ok:
            return {
                "valid": False,
                "reason": "Institutional certificate signature verification failed",
                "details": details
            }

        # 6. Certificate validity window check
        try:
            # Handle ISO timestamps with or without timezone
            v_from = datetime.datetime.fromisoformat(valid_from_str.replace('Z', '+00:00'))
            v_to = datetime.datetime.fromisoformat(valid_to_str.replace('Z', '+00:00'))
            now = datetime.datetime.now(v_from.tzinfo) if v_from.tzinfo else datetime.datetime.now()

            if now < v_from:
                return {
                    "valid": False,
                    "reason": f"Certificate is not yet valid (validFrom: {valid_from_str})",
                    "details": details
                }
            if now > v_to:
                return {
                    "valid": False,
                    "reason": f"Certificate has expired (validTo: {valid_to_str})",
                    "details": details
                }
        except Exception as e:
            return {
                "valid": False,
                "reason": f"Malformed validity dates in certificate: {e}",
                "details": details
            }

        # 7. Certificate status check
        if cert_status != "ACTIVE":
            return {
                "valid": False,
                "reason": f"Certificate status is '{cert_status}', not 'ACTIVE'",
                "details": details
            }

        # Database correlation checks (steps 8-10)
        if check_database and device_identity_key_model and user_model:
            # 8. Registered DeviceIdentityKey exists
            db_key = device_identity_key_model.query.get(key_id)
            if not db_key:
                return {
                    "valid": False,
                    "reason": f"Registered device identity key '{key_id}' not found in database",
                    "details": details
                }

            # 9. Registered key matches certificate public key and user ID
            if db_key.public_key_b64 != public_key_b64:
                return {
                    "valid": False,
                    "reason": "Certificate public key does not match registered device identity key",
                    "details": details
                }
            if db_key.user_id != user_id:
                return {
                    "valid": False,
                    "reason": "Certificate userId does not match registered device identity key owner",
                    "details": details
                }

            # 10. Key status is ACTIVE
            if db_key.status != "ACTIVE":
                return {
                    "valid": False,
                    "reason": f"Registered device identity key status is '{db_key.status}', not 'ACTIVE'",
                    "details": details
                }

            # Verify user exists in database
            user = user_model.query.get(user_id)
            if not user:
                return {
                    "valid": False,
                    "reason": f"Subject user '{user_id}' not found in database",
                    "details": details
                }

        return {
            "valid": True,
            "reason": None,
            "details": details
        }

    @staticmethod
    def revoke_key(db, device_identity_key_model, key_id: str) -> Any:
        """
        Revokes a DeviceIdentityKey and all its active certificates.
        """
        key = device_identity_key_model.query.get(key_id)
        if not key:
            raise ValueError(f"DeviceIdentityKey with ID '{key_id}' not found.")

        now_iso = datetime.datetime.now().isoformat()
        key.status = "REVOKED"
        key.revoked_at = now_iso

        # Revoke all associated certificates
        for cert in key.certificates:
            if cert.status == "ACTIVE":
                cert.status = "REVOKED"
                cert.revoked_at = now_iso

        db.session.commit()
        return key

    @staticmethod
    def get_active_key(device_identity_key_model, user_id: str) -> Optional[Any]:
        """Returns the current ACTIVE DeviceIdentityKey for a user, or None."""
        return device_identity_key_model.query.filter_by(user_id=user_id, status='ACTIVE').first()

    @staticmethod
    def get_all_keys(device_identity_key_model, user_id: str) -> List[Any]:
        """Returns all historical and current keys for a user."""
        return device_identity_key_model.query.filter_by(user_id=user_id).order_by(
            device_identity_key_model.created_at.desc()
        ).all()

    @staticmethod
    def generate_trust_bundle(
        db,
        device_identity_key_model,
        device_certificate_model,
        user_model=None,
        ttl_seconds: int = 86400
    ) -> Dict[str, Any]:
        """
        Generates and cryptographically signs a versioned institutional trust bundle (Phase 1F).
        Contains:
        - institution public key and keyId
        - active certified identities
        - revoked key IDs (for fast revocation tracking)
        - deterministic generation and expiration timestamps
        - Ed25519 signature over canonical payload
        Zero secrets or private keys are included.
        """
        now_dt = datetime.datetime.now(datetime.timezone.utc)
        now_ts = int(now_dt.timestamp())
        expires_ts = now_ts + ttl_seconds

        issuer_key_id = get_institution_key_id()
        inst_pub_b64 = get_institution_public_key_b64()

        # Query all active keys
        active_keys = device_identity_key_model.query.filter_by(status='ACTIVE').all()
        active_identities = []

        for key in active_keys:
            cert = key.get_active_certificate()
            if not cert or cert.status != 'ACTIVE':
                continue

            # Verify certificate expiration
            try:
                cert_to = datetime.datetime.fromisoformat(cert.valid_to.replace('Z', '+00:00'))
                if cert_to.tzinfo is None:
                    cert_to = cert_to.replace(tzinfo=datetime.timezone.utc)
                if now_dt > cert_to:
                    continue
            except Exception:
                continue

            # Resolve user name if available
            user_name = None
            if user_model:
                u = user_model.query.get(key.user_id)
                if u:
                    user_name = u.name

            identity_entry = {
                "certificateId": cert.id,
                "issuerKeyId": cert.issuer_key_id,
                "keyId": key.id,
                "publicKey": key.public_key_b64,
                "status": "ACTIVE",
                "userId": key.user_id,
                "validFrom": cert.valid_from,
                "validTo": cert.valid_to,
            }
            if user_name:
                identity_entry["userName"] = user_name

            active_identities.append(identity_entry)

        # Stable sort by keyId for determinism
        active_identities.sort(key=lambda x: x["keyId"])

        # Query revoked keys
        revoked_keys = device_identity_key_model.query.filter_by(status='REVOKED').all()
        revoked_key_ids = sorted([k.id for k in revoked_keys])

        payload = {
            "expiresAt": expires_ts,
            "generatedAt": now_ts,
            "identities": active_identities,
            "institution": {
                "keyId": issuer_key_id,
                "publicKey": inst_pub_b64
            },
            "issuerKeyId": issuer_key_id,
            "revokedKeyIds": revoked_key_ids,
            "version": 1
        }

        canonical_bytes = canonicalize_payload(payload)
        sig_b64 = sign_canonical_payload(canonical_bytes)

        return {
            "payload": payload,
            "signature": sig_b64
        }

    @staticmethod
    def verify_trust_bundle(bundle_dict: Dict[str, Any]) -> Tuple[bool, Optional[str]]:
        """
        Validates the structure and cryptographic signature of a trust bundle.
        """
        if not bundle_dict or not isinstance(bundle_dict, dict):
            return False, "Bundle must be a non-empty dictionary"

        payload = bundle_dict.get("payload")
        signature_b64 = bundle_dict.get("signature")

        if not payload or not isinstance(payload, dict):
            return False, "Bundle missing valid payload dictionary"
        if not signature_b64 or not isinstance(signature_b64, str):
            return False, "Bundle missing valid signature string"

        required_payload_keys = ["version", "issuerKeyId", "generatedAt", "expiresAt", "institution", "identities"]
        for k in required_payload_keys:
            if k not in payload:
                return False, f"Payload missing required field '{k}'"

        canonical_bytes = canonicalize_payload(payload)
        if not verify_institution_signature(canonical_bytes, signature_b64):
            return False, "Institution signature verification failed over canonical payload"

        return True, None

    @staticmethod
    def verify_presentation(
        payload: Dict[str, Any],
        signature_b64: str,
        device_identity_key_model,
        device_certificate_model,
        user_model=None,
        max_clock_skew_seconds: int = 30
    ) -> Dict[str, Any]:
        """
        Verifies a dynamic Passport presentation (Phase 1D):
        1. payload format, version, type
        2. required fields: keyId, userId, certificateId, issuerKeyId, issuedAt, expiresAt, nonce
        3. keyId exists and is ACTIVE
        4. userId matches key owner
        5. certificateId exists, matches keyId, userId, issuerKeyId, and is ACTIVE
        6. certificate validity window
        7. timestamps validity and expiration window (with clock skew)
        8. cryptographic Ed25519 signature verification against registered public key
        """
        if not payload or not isinstance(payload, dict):
            return {"valid": False, "reason": "INVALID_FORMAT"}

        # Version and Type checks
        if payload.get("version") != 1:
            return {"valid": False, "reason": "INVALID_FORMAT"}
        if payload.get("type") != "PASSPORT_PRESENTATION":
            return {"valid": False, "reason": "INVALID_FORMAT"}

        # Required fields check
        required_fields = ["keyId", "userId", "certificateId", "issuerKeyId", "issuedAt", "expiresAt", "nonce"]
        for rf in required_fields:
            if payload.get(rf) is None:
                return {"valid": False, "reason": "INVALID_FORMAT"}

        key_id = str(payload.get("keyId"))
        user_id = str(payload.get("userId"))
        certificate_id = str(payload.get("certificateId"))
        issuer_key_id = str(payload.get("issuerKeyId"))
        nonce = str(payload.get("nonce"))

        if not signature_b64 or not isinstance(signature_b64, str):
            return {"valid": False, "reason": "INVALID_SIGNATURE"}

        # Key validation
        db_key = device_identity_key_model.query.get(key_id)
        if not db_key:
            return {"valid": False, "reason": "UNKNOWN_KEY"}

        if db_key.user_id != user_id:
            return {"valid": False, "reason": "CERTIFICATE_MISMATCH"}

        if db_key.status == "REVOKED":
            return {"valid": False, "reason": "REVOKED_KEY"}
        if db_key.status != "ACTIVE":
            return {"valid": False, "reason": f"{db_key.status}_KEY"}

        # Certificate validation
        db_cert = device_certificate_model.query.get(certificate_id)
        if not db_cert:
            return {"valid": False, "reason": "UNKNOWN_CERTIFICATE"}

        if db_cert.key_id != key_id or db_cert.subject_user_id != user_id or db_cert.issuer_key_id != issuer_key_id:
            return {"valid": False, "reason": "CERTIFICATE_MISMATCH"}

        if db_cert.status == "REVOKED":
            return {"valid": False, "reason": "REVOKED_CERTIFICATE"}
        if db_cert.status != "ACTIVE":
            return {"valid": False, "reason": "EXPIRED_CERTIFICATE" if db_cert.status == "EXPIRED" else f"{db_cert.status}_CERTIFICATE"}

        # Certificate validity window
        try:
            cert_from = datetime.datetime.fromisoformat(db_cert.valid_from.replace('Z', '+00:00'))
            cert_to = datetime.datetime.fromisoformat(db_cert.valid_to.replace('Z', '+00:00'))
            now_dt = datetime.datetime.now(cert_from.tzinfo) if cert_from.tzinfo else datetime.datetime.now()
            if now_dt < cert_from:
                return {"valid": False, "reason": "NOT_YET_VALID"}
            if now_dt > cert_to:
                return {"valid": False, "reason": "EXPIRED_CERTIFICATE"}
        except Exception:
            return {"valid": False, "reason": "EXPIRED_CERTIFICATE"}

        # Presentation timestamp & skew checks
        try:
            issued_at = int(payload.get("issuedAt"))
            expires_at = int(payload.get("expiresAt"))
        except (ValueError, TypeError):
            return {"valid": False, "reason": "INVALID_FORMAT"}

        if issued_at > expires_at:
            return {"valid": False, "reason": "INVALID_FORMAT"}

        now_ts = int(datetime.datetime.now(datetime.timezone.utc).timestamp())

        # Check future skew (cannot be issued unreasonably far in the future)
        if issued_at > now_ts + max_clock_skew_seconds:
            return {"valid": False, "reason": "NOT_YET_VALID"}

        # Check expiration (with allowed tolerance)
        if expires_at < now_ts - max_clock_skew_seconds:
            return {"valid": False, "reason": "PRESENTATION_EXPIRED"}

        # Phase 1G: Extract and validate optional challenge binding
        challenge_data = payload.get("challenge")
        challenge_info = None

        if challenge_data and isinstance(challenge_data, dict):
            # Validate challenge structure
            challenge_nonce = challenge_data.get("nonce")
            challenge_verifier_id = challenge_data.get("verifierId")
            challenge_issued_at = challenge_data.get("issuedAt")
            challenge_expires_at = challenge_data.get("expiresAt")

            if not challenge_nonce or not isinstance(challenge_nonce, str):
                return {"valid": False, "reason": "INVALID_CHALLENGE"}

            if not challenge_verifier_id or not isinstance(challenge_verifier_id, str):
                return {"valid": False, "reason": "INVALID_CHALLENGE"}

            if challenge_issued_at is None or challenge_expires_at is None:
                return {"valid": False, "reason": "INVALID_CHALLENGE"}

            try:
                c_issued = int(challenge_issued_at)
                c_expires = int(challenge_expires_at)
            except (ValueError, TypeError):
                return {"valid": False, "reason": "INVALID_CHALLENGE"}

            if c_issued > c_expires:
                return {"valid": False, "reason": "INVALID_CHALLENGE"}

            # Challenge expiration check (with clock skew tolerance)
            if c_expires < now_ts - max_clock_skew_seconds:
                return {"valid": False, "reason": "CHALLENGE_EXPIRED"}

            challenge_info = {
                "nonce": str(challenge_nonce),
                "verifierId": str(challenge_verifier_id),
                "issuedAt": c_issued,
                "expiresAt": c_expires,
            }

        # Cryptographic signature verification over canonical payload
        canonical_dict = {
            "certificateId": certificate_id,
            "expiresAt": expires_at,
            "issuedAt": issued_at,
            "issuerKeyId": issuer_key_id,
            "keyId": key_id,
            "nonce": nonce,
            "type": "PASSPORT_PRESENTATION",
            "userId": user_id,
            "version": 1
        }

        # Phase 1G: Include challenge in canonical dict if present
        # The challenge key is alphabetically between 'certificateId' and 'expiresAt',
        # and canonical serialization sorts keys, so just include it in the dict.
        if challenge_info is not None:
            canonical_dict["challenge"] = challenge_info

        canonical_bytes = canonicalize_payload(canonical_dict)
        sig_ok = verify_device_signature(canonical_bytes, signature_b64, db_key.public_key_b64)
        if not sig_ok:
            return {"valid": False, "reason": "INVALID_SIGNATURE"}

        user_info = None
        if user_model:
            db_user = user_model.query.get(user_id)
            if db_user:
                user_info = {
                    "name": db_user.name,
                    "branch": db_user.branch,
                    "year": db_user.year,
                    "course": db_user.course,
                    "registrationNumber": db_user.registration_number
                }

        res = {
            "valid": True,
            "reason": "VALID",
            "userId": user_id,
            "keyId": key_id,
            "certificateId": certificate_id,
            "expiresAt": expires_at
        }
        if user_info:
            res["user"] = user_info

        # Phase 1G: Include challenge metadata in response
        if challenge_info is not None:
            res["challengeNonce"] = challenge_info["nonce"]
            res["challengeVerifierId"] = challenge_info["verifierId"]

        return res

