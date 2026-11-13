# pyrefly: ignore [missing-import]
"""
CampusOS Backend Application Root & Composition Module.

This module acts as the application factory and composition root for the modular
Flask monolith. All business logic, routes, models, cryptography, and middleware
have been decomposed into clean modular packages:
- config.py: Centralized configuration and environment loading
- extensions.py: Shared SQLAlchemy instance and Firebase notification utilities
- models/: Domain models (User, Attendance, GatePass, Mess, Passport, etc.)
- routes/: Flask blueprints for each domain
- services/: Business logic, notifications, auditing, and recurrence clustering
- middleware/: Role authorization and caller identity extraction
- utils/: Cryptographic primitives and data payload validators

Full backward compatibility is preserved for existing tests and scripts.
"""

import os
import sys

# Ensure UTF-8 output on Windows consoles to prevent charmap UnicodeEncodeErrors
if sys.platform == 'win32':
    try:
        if sys.stdout and hasattr(sys.stdout, 'reconfigure'):
            sys.stdout.reconfigure(encoding='utf-8')
        if sys.stderr and hasattr(sys.stderr, 'reconfigure'):
            sys.stderr.reconfigure(encoding='utf-8')
    except Exception:
        pass

from flask import Flask
from flask_cors import CORS

from config import Config
GATE_PASS_SECRET = Config.GATE_PASS_SECRET
from extensions import (
    db,
    init_firebase,
    send_fcm_message,
    firebase_initialized,
    fcm_sender_override,
    FIREBASE_AVAILABLE
)
from models import (
    User,
    Session,
    Attendance,
    Coupon,
    SavedClass,
    LeaveRequest,
    GatePass,
    RequestAudit,
    Complaint,
    ComplaintStatusHistory,
    Notice,
    NotificationDelivery,
    DeviceToken,
    MessMenu,
    MessMeal,
    MessFeedback,
    MealEntry,
    DeviceIdentityKey,
    DeviceCertificate,
    SUPPORTED_FEEDBACK_CATEGORIES,
    init_db
)
from routes import register_routes

# Backward compatibility re-exports for role authorization & middleware
from middleware.roles import is_security_guard, is_warden, is_mess_manager
from middleware.auth import (
    get_authenticated_security_guard,
    get_authenticated_warden,
    verify_admin_access,
    get_authenticated_requester
)

# Backward compatibility re-exports for crypto & validation utilities
from utils.crypto import (
    get_gate_pass_secret,
    generate_signed_credential,
    verify_signed_credential
)
from utils.validators import (
    SUPPORTED_MEAL_TYPES,
    SUPPORTED_MEAL_AVAILABILITIES,
    SUPPORTED_MENU_STATUSES,
    MEAL_ORDER_MAP,
    parse_and_validate_menu_date,
    validate_meals_payload
)

# Backward compatibility re-exports for domain services
from services.notice_service import (
    SUPPORTED_NOTICE_PRIORITIES,
    SUPPORTED_NOTICE_CATEGORIES,
    SUPPORTED_NOTICE_TARGET_TYPES,
    SUPPORTED_NOTICE_STATUSES,
    resolve_notice_recipients,
    is_notice_targeted_to_student,
    dispatch_notice_push_notifications,
    sync_notice_deliveries,
    is_notice_expired
)
from services.complaint_service import (
    COMPLAINT_AGEING_HOURS,
    RECURRENCE_WINDOW_DAYS,
    MIN_COMPLAINTS_FOR_RECURRENCE,
    ESCALATION_ELEVATED_THRESHOLD,
    ESCALATION_HIGH_THRESHOLD,
    COMPLAINT_TRANSITIONS,
    _format_admin_complaint,
    generate_recurrence_id,
    compute_recurring_complaint_clusters
)
from services.passport_service import (
    PassportService,
    get_institution_key_id,
    get_institution_public_key_b64,
    validate_public_key,
    set_institution_key_override,
    clear_institution_key_override
)


def create_app(config_class=Config):
    """
    Application factory that initializes configuration, shared extensions,
    database schema, and registers all blueprints.
    """
    app = Flask(__name__)
    CORS(app)

    # Configure application
    app.config.from_object(config_class)

    # Initialize shared extensions
    db.init_app(app)

    # SQLite Concurrency & Integrity Hardening (WAL mode, busy timeout, foreign keys)
    from sqlalchemy import event
    from sqlalchemy.engine import Engine

    @event.listens_for(Engine, "connect")
    def set_sqlite_pragma(dbapi_connection, connection_record):
        if type(dbapi_connection).__module__ == 'sqlite3':
            cursor = dbapi_connection.cursor()
            cursor.execute("PRAGMA journal_mode=WAL")
            cursor.execute("PRAGMA busy_timeout=10000")
            cursor.execute("PRAGMA synchronous=NORMAL")
            cursor.execute("PRAGMA foreign_keys=ON")
            cursor.close()

    init_firebase()

    # Non-destructive additive database initialization
    init_db(app)

    # Register modular blueprints
    register_routes(app)

    @app.route('/health', methods=['GET'])
    def health_check():
        return {
            "status": "healthy",
            "service": "CampusOS Backend",
            "version": "1.0.0"
        }, 200

    @app.errorhandler(400)
    def handle_400(e):
        import sys
        print(f"DEBUG 400 ERROR: {e}, desc={getattr(e, 'description', '')}", file=sys.stderr)
        return {"error": str(e), "description": getattr(e, 'description', '')}, 400

    # Transparently handle optional /api prefix for direct backend callers
    class ApiPrefixMiddleware:
        def __init__(self, wsgi_app):
            self.wsgi_app = wsgi_app

        def __call__(self, environ, start_response):
            path_info = environ.get('PATH_INFO', '')
            if path_info.startswith('/api/'):
                environ['PATH_INFO'] = path_info[4:]
            elif path_info == '/api':
                environ['PATH_INFO'] = '/'
            return self.wsgi_app(environ, start_response)

    app.wsgi_app = ApiPrefixMiddleware(app.wsgi_app)

    return app


# Module-level app instance for WSGI servers and backwards-compatible imports
app = create_app()


if __name__ == '__main__':
    try:
        key_id = get_institution_key_id()
        pub_b64 = get_institution_public_key_b64()
        print(f"[OK] [PASSPORT] Institutional signing key configured: keyId={key_id}, pubKey={pub_b64[:12]}...")
    except Exception as e:
        print(f"[WARN] [PASSPORT] Institutional signing key not configured: {e}")
    debug_mode = os.environ.get('FLASK_DEBUG', 'false').lower() in ('true', '1', 'yes')
    app.run(debug=debug_mode, host='0.0.0.0', port=5000)