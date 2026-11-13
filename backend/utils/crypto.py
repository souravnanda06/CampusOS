import os
import hmac
import hashlib
import base64
import json
import datetime
import uuid
import jwt
from config import Config

def get_gate_pass_secret():
    """
    Retrieves the HMAC-SHA256 signing secret from environment configuration.
    Falls back to the standard institutional development secret if missing.
    """
    secret = os.environ.get('GATE_PASS_SECRET')
    if not secret or not secret.strip():
        secret = getattr(Config, 'GATE_PASS_SECRET', None) or 'campusos_gate_sec_7a9f82d1c4b8e053a6f1d2e4c8b7a9f0'
    return secret.strip()

def generate_signed_credential(payload_dict):
    """
    Generates a cryptographically signed HMAC-SHA256 compact token.
    Token format: <b64_header>.<b64_payload>.<b64_signature>
    """
    secret = get_gate_pass_secret()
    header = {"alg": "HS256", "typ": "GATEPASS"}
    h_bytes = base64.urlsafe_b64encode(json.dumps(header, separators=(',', ':')).encode('utf-8')).decode('utf-8').rstrip('=')
    p_bytes = base64.urlsafe_b64encode(json.dumps(payload_dict, separators=(',', ':')).encode('utf-8')).decode('utf-8').rstrip('=')
    data_to_sign = f"{h_bytes}.{p_bytes}"
    sig = hmac.new(secret.encode('utf-8'), data_to_sign.encode('utf-8'), hashlib.sha256).digest()
    sig_b64 = base64.urlsafe_b64encode(sig).decode('utf-8').rstrip('=')
    return f"{data_to_sign}.{sig_b64}"

def verify_signed_credential(token_str):
    """
    Verifies the HMAC-SHA256 signature and decodes the payload.
    Returns (is_valid, payload_dict, message)
    """
    try:
        secret = get_gate_pass_secret()
        parts = token_str.split('.')
        if len(parts) != 3:
            return False, None, "Invalid token structure"
        h_bytes, p_bytes, sig_b64 = parts
        data_to_sign = f"{h_bytes}.{p_bytes}"
        expected_sig = hmac.new(secret.encode('utf-8'), data_to_sign.encode('utf-8'), hashlib.sha256).digest()
        expected_sig_b64 = base64.urlsafe_b64encode(expected_sig).decode('utf-8').rstrip('=')
        
        if not hmac.compare_digest(sig_b64, expected_sig_b64):
            return False, None, "Signature mismatch / tampering detected"
            
        padding = '=' * (-len(p_bytes) % 4)
        payload_json = base64.urlsafe_b64decode((p_bytes + padding).encode('utf-8')).decode('utf-8')
        payload = json.loads(payload_json)
        return True, payload, "Valid"
    except RuntimeError:
        raise
    except Exception as e:
        return False, None, f"Malformed token: {str(e)}"


# ==============================================================================
# --- AUTHENTICATION JWT SESSION TOKENS ---
# ==============================================================================

def get_jwt_secret():
    """
    Retrieves the JWT signing secret from server environment or config.
    Never uses a hardcoded fallback in production environments.
    """
    secret = os.environ.get('JWT_SECRET') or getattr(Config, 'JWT_SECRET', None)
    if not secret or not str(secret).strip():
        raise RuntimeError(
            "CRITICAL CONFIGURATION ERROR: 'JWT_SECRET' is not configured. "
            "Session authentication requires an explicitly configured signing secret."
        )
    return str(secret).strip()


def create_access_token(user, expires_in_hours=None):
    """
    Generates a cryptographically signed HMAC-SHA256 JWT access token for an authenticated user.
    Claims included:
      - sub: User ID
      - userId: User ID
      - role: Institutional role
      - email: User email
      - name: User display name
      - iat: Issued at (UTC datetime)
      - exp: Expiration (UTC datetime)
      - jti: Unique token UUID
    """
    secret = get_jwt_secret()
    now = datetime.datetime.now(datetime.timezone.utc)
    if expires_in_hours is None:
        expires_in_hours = getattr(Config, 'JWT_EXPIRATION_HOURS', 168)
    exp = now + datetime.timedelta(hours=expires_in_hours)

    payload = {
        'sub': str(user.id),
        'userId': str(user.id),
        'role': str(user.role),
        'email': str(user.email),
        'name': str(user.name or ''),
        'iat': now,
        'exp': exp,
        'jti': str(uuid.uuid4())
    }
    return jwt.encode(payload, secret, algorithm='HS256')


def verify_access_token(token_str, secret_override=None):
    """
    Cryptographically verifies the JWT signature, algorithm, expiration, and required claims.
    Returns: (is_valid: bool, payload_or_reason: Any, user_id: Optional[str])
    """
    if not token_str or not isinstance(token_str, str) or not token_str.strip():
        return False, "Missing or empty authentication token", None

    clean_token = token_str.strip()
    try:
        secret = secret_override if secret_override is not None else get_jwt_secret()
        payload = jwt.decode(
            clean_token,
            secret,
            algorithms=['HS256'],
            options={
                'require': ['sub', 'role', 'exp', 'iat']
            }
        )
        user_id = str(payload.get('sub') or payload.get('userId'))
        return True, payload, user_id
    except jwt.ExpiredSignatureError:
        return False, "Token has expired", None
    except jwt.InvalidAlgorithmError:
        return False, "Invalid token signing algorithm", None
    except jwt.InvalidSignatureError:
        return False, "Invalid token signature or tampered token", None
    except jwt.DecodeError:
        return False, "Malformed token string", None
    except Exception as e:
        return False, f"Token verification error: {str(e)}", None

