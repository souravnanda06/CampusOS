import os
from flask_sqlalchemy import SQLAlchemy

# pyrefly: ignore [missing-import]
try:
    import firebase_admin
    from firebase_admin import credentials, messaging
    FIREBASE_AVAILABLE = True
except ImportError:
    FIREBASE_AVAILABLE = False

# Shared SQLAlchemy instance across all models and services
db = SQLAlchemy()

# Firebase notification infrastructure
firebase_initialized = False
fcm_sender_override = None

def send_fcm_message(message):
    """
    Send an FCM message using the active Firebase instance or test override.
    """
    global fcm_sender_override, firebase_initialized
    sender = None
    try:
        import sys
        if 'app' in sys.modules:
            sender = getattr(sys.modules['app'], 'fcm_sender_override', None)
    except Exception:
        pass

    if sender is None:
        sender = fcm_sender_override

    if sender is not None:
        return sender(message)

    if not firebase_initialized:
        raise RuntimeError("Firebase Admin is not initialized")
    return messaging.send(message)

def init_firebase(base_dir=None):
    """
    Initialize Firebase Admin SDK if credentials exist.
    """
    global firebase_initialized
    if not FIREBASE_AVAILABLE:
        print("[INFO] Running in local mode: firebase_admin not installed (notifications disabled).")
        return False

    if base_dir is None:
        base_dir = os.path.abspath(os.path.dirname(__file__))

    firebase_path = os.path.join(base_dir, "firebase_credentials.json")
    if os.path.exists(firebase_path):
        try:
            if not firebase_admin._apps:
                cred = credentials.Certificate(firebase_path)
                firebase_admin.initialize_app(cred)
            firebase_initialized = True
            print("[OK] Firebase Admin initialized successfully.")
            return True
        except Exception as e:
            print(f"[WARN] Failed to initialize Firebase: {e}")
            return False
    else:
        print("[INFO] Running in local mode: firebase_credentials.json not found (notifications disabled).")
        return False
