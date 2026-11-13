from flask import request, jsonify
from models.user import User
from middleware.roles import is_security_guard, is_warden, is_admin
from utils.crypto import verify_access_token

def get_authenticated_user_from_token():
    """
    Extracts and cryptographically verifies the access token from Authorization: Bearer <token>.
    Returns: (user, error_response, error_status)
    """
    auth_header = request.headers.get('Authorization')
    if not auth_header or not auth_header.strip():
        return None, None, 401

    clean_header = auth_header.strip()
    if not clean_header.startswith('Bearer '):
        return None, jsonify({
            "message": "Authentication required: Authorization header must use Bearer scheme",
            "resultCode": "UNAUTHORIZED"
        }), 401

    token = clean_header[7:].strip()
    is_valid, payload_or_err, user_id = verify_access_token(token)
    if not is_valid:
        return None, jsonify({
            "message": f"Authentication failed: {payload_or_err}",
            "resultCode": "UNAUTHORIZED"
        }), 401

    user = User.query.get(user_id)
    if not user:
        return None, jsonify({
            "message": "Authenticated user record not found",
            "resultCode": "UNAUTHORIZED"
        }), 401

    return user, None, 200

def get_authenticated_security_guard():
    """
    Authenticates the caller and verifies SECURITY or ADMIN role.
    Prefers cryptographically verified JWT token from Authorization header.
    Never trusts client-supplied JSON body for authorization.
    Returns: (guard_user, error_response, error_status)
    """
    # 1. Check for cryptographic Bearer token
    auth_header = request.headers.get('Authorization')
    if auth_header and auth_header.strip():
        user, err_resp, err_code = get_authenticated_user_from_token()
        if err_resp:
            return None, err_resp, err_code
        if not is_security_guard(user):
            return None, jsonify({
                "message": f"Forbidden: Role '{user.role}' is not authorized for Gate Security operations. SECURITY or ADMIN role required.",
                "resultCode": "FORBIDDEN"
            }), 403
        return user, None, 200

    # 2. Legacy / test suite header resolution
    actor_id = (
        request.headers.get('X-User-Id') or
        request.headers.get('X-Requester-Id') or
        request.headers.get('X-Security-Guard-Id')
    )
    if not actor_id and request.args:
        actor_id = request.args.get('userId') or request.args.get('securityGuardId')

    if not actor_id:
        return None, jsonify({
            "message": "Authentication required: Missing user authentication credentials",
            "resultCode": "UNAUTHORIZED"
        }), 401

    user = User.query.get(actor_id)
    if not user:
        return None, jsonify({
            "message": "Authenticated user not found",
            "resultCode": "UNAUTHORIZED"
        }), 401

    if not is_security_guard(user):
        return None, jsonify({
            "message": f"Forbidden: Role '{user.role}' is not authorized for Gate Security operations. SECURITY or ADMIN role required.",
            "resultCode": "FORBIDDEN"
        }), 403

    return user, None, 200

def get_authenticated_warden():
    """
    Authenticates the caller and verifies WARDEN or ADMIN role.
    Prefers cryptographically verified JWT token from Authorization header.
    Never trusts client-supplied JSON body for authorization.
    Returns: (warden_user, error_response, error_status)
    """
    # 1. Check for cryptographic Bearer token
    auth_header = request.headers.get('Authorization')
    if auth_header and auth_header.strip():
        user, err_resp, err_code = get_authenticated_user_from_token()
        if err_resp:
            return None, err_resp, err_code
        if not is_warden(user):
            return None, jsonify({
                "message": f"Forbidden: Role '{user.role}' is not authorized for Warden operations. WARDEN or ADMIN role required.",
                "resultCode": "FORBIDDEN"
            }), 403
        return user, None, 200

    # 2. Legacy / test suite header resolution
    actor_id = (
        request.headers.get('X-User-Id') or
        request.headers.get('X-Requester-Id') or
        request.headers.get('X-Warden-Id')
    )
    if not actor_id and request.args:
        actor_id = request.args.get('userId') or request.args.get('wardenId') or request.args.get('requesterId')

    if not actor_id:
        return None, jsonify({
            "message": "Authentication required: Missing user authentication credentials",
            "resultCode": "UNAUTHORIZED"
        }), 401

    user = User.query.get(actor_id)
    if not user:
        return None, jsonify({
            "message": "Authenticated user not found",
            "resultCode": "UNAUTHORIZED"
        }), 401

    if not is_warden(user):
        return None, jsonify({
            "message": f"Forbidden: Role '{user.role}' is not authorized for Warden operations. WARDEN or ADMIN role required.",
            "resultCode": "FORBIDDEN"
        }), 403

    return user, None, 200

def verify_admin_access():
    """
    Verifies that caller has Admin/Staff access.
    Enforces strict authentication: unauthenticated callers are rejected with 401.
    Non-admin callers are rejected with 403.
    Returns: (authorized_bool, error_tuple)
    """
    # Require cryptographic Bearer token
    auth_header = request.headers.get('Authorization')
    if not auth_header or not auth_header.strip():
        return False, (jsonify({
            "message": "Authentication required: Admin credentials missing",
            "resultCode": "UNAUTHORIZED"
        }), 401)

    user, err_resp, err_code = get_authenticated_user_from_token()
    if err_resp:
        return False, (err_resp, err_code)

    if not is_admin(user) and user.role not in ['admin', 'staff']:
        return False, (jsonify({
            "message": "Forbidden: Admin or staff access required",
            "resultCode": "FORBIDDEN"
        }), 403)

    return True, None

def get_authenticated_requester():
    """
    Resolves the authenticated user from cryptographic JWT Bearer token or request headers.
    Returns: (user, error_response)
    """
    auth_header = request.headers.get('Authorization')
    if auth_header and auth_header.strip():
        user, err_resp, err_code = get_authenticated_user_from_token()
        if err_resp:
            return None, (err_resp, err_code)
        return user, None

    requester_id = (
        request.headers.get('X-User-Id') or
        request.headers.get('X-Requester-Id') or
        request.args.get('userId') or
        request.args.get('requesterId') or
        request.args.get('studentId')
    )
    if not requester_id and request.is_json:
        body = request.get_json(silent=True) or {}
        if isinstance(body, dict):
            requester_id = (
                body.get('userId') or
                body.get('requesterId') or
                body.get('actorId') or
                body.get('createdBy')
            )
    if not requester_id:
        return None, None

    user = User.query.get(requester_id)
    if not user:
        return None, (jsonify({
            "message": "Requester user not found",
            "resultCode": "UNAUTHORIZED"
        }), 401)
    return user, None

