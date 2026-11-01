import os

def _load_env_file():
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

class Config:
    """CampusOS Backend Configuration."""
    SQLALCHEMY_DATABASE_URI = os.environ.get(
        'DATABASE_URL',
        'mysql+pymysql://root:nandasourav766@localhost/attentify'
    )
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    
    # Gate Pass Secret MUST come from environment (never hardcoded, no default fallback)
    GATE_PASS_SECRET = os.environ.get('GATE_PASS_SECRET')

    # Passport Configuration
    PASSPORT_INSTITUTION_KEY_ID = os.environ.get('PASSPORT_INSTITUTION_KEY_ID', 'campusos-root-2026-v1')
    PASSPORT_INSTITUTION_PRIVATE_KEY = os.environ.get('PASSPORT_INSTITUTION_PRIVATE_KEY')

    # Admin Complaints Configuration
    COMPLAINT_AGEING_HOURS = 48
    RECURRING_WINDOW_DAYS = 14
    RECURRING_MIN_SIMILARITY = 0.55
    RECURRING_MIN_COMPLAINTS = 2

    # JWT Session Configuration
    JWT_SECRET = os.environ.get('JWT_SECRET', 'campusos_jwt_sec_8f9c2d1b4e053a6f1d2e4c8b7a9f0e3d')
    JWT_EXPIRATION_HOURS = int(os.environ.get('JWT_EXPIRATION_HOURS', '168'))  # 7 days
    JWT_ALGORITHM = 'HS256'
