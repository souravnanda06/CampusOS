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
        os.path.join(os.getcwd(), '.env'),
        os.path.join(os.getcwd(), 'backend', '.env'),
        '/home/campusos/backend/.env',
        '/home/campusos/CampusOS-1.0.0/backend/.env',
        '/home/campusos/.env',
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
    _base_dir = os.path.dirname(os.path.abspath(__file__))
    _raw_db_url = os.environ.get(
        'DATABASE_URL',
        'sqlite:///app.db'
    ) or 'sqlite:///app.db'
    if (
        _raw_db_url.startswith('sqlite:///')
        and _raw_db_url[10:] != ':memory:'
        and not _raw_db_url[10:].startswith('file:')
        and not os.path.isabs(_raw_db_url[10:])
    ):
        _db_path = os.path.join(_base_dir, _raw_db_url[10:]).replace('\\', '/')
        SQLALCHEMY_DATABASE_URI = f'sqlite:///{_db_path}'
    else:
        SQLALCHEMY_DATABASE_URI = _raw_db_url
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    
    # Gate Pass Secret with preconfigured development default
    GATE_PASS_SECRET = os.environ.get('GATE_PASS_SECRET', 'campusos_gate_sec_7a9f82d1c4b8e053a6f1d2e4c8b7a9f0')

    # Passport Configuration with preconfigured development defaults
    PASSPORT_INSTITUTION_KEY_ID = os.environ.get('PASSPORT_INSTITUTION_KEY_ID', 'campusos-root-2026-v1')
    PASSPORT_INSTITUTION_PRIVATE_KEY = os.environ.get('PASSPORT_INSTITUTION_PRIVATE_KEY', 't6s2qBfceKH/2cFn7Fy/yD7NdY+650e369ujP4/VD2E=')

    # Admin Complaints Configuration
    COMPLAINT_AGEING_HOURS = 48
    RECURRING_WINDOW_DAYS = 14
    RECURRING_MIN_SIMILARITY = 0.55
    RECURRING_MIN_COMPLAINTS = 2

    # JWT Session Configuration
    JWT_SECRET = os.environ.get('JWT_SECRET', 'campusos_jwt_sec_8f9c2d1b4e053a6f1d2e4c8b7a9f0e3d')
    JWT_EXPIRATION_HOURS = int(os.environ.get('JWT_EXPIRATION_HOURS', '168'))  # 7 days
    JWT_ALGORITHM = 'HS256'

    # Media / Photo Uploads Configuration
    UPLOAD_FOLDER = os.environ.get('UPLOAD_FOLDER', os.path.join(_base_dir, 'uploads'))
    MAX_CONTENT_LENGTH = int(os.environ.get('MAX_CONTENT_LENGTH', str(8 * 1024 * 1024)))  # 8 MB

    # CampusOS AI Copilot (Gemini API)
    GEMINI_API_KEY = os.environ.get('GEMINI_API_KEY', '').strip()
    GEMINI_MODEL = os.environ.get('GEMINI_MODEL', 'gemini-3.8-flash').strip() or 'gemini-3.8-flash'

    # OpenWA WhatsApp Gateway Configuration
    OPENWA_BASE_URL = os.environ.get('OPENWA_BASE_URL', 'http://localhost:2785').rstrip('/')
    OPENWA_API_KEY = os.environ.get('OPENWA_API_KEY', '').strip()
    OPENWA_SESSION_ID = os.environ.get('OPENWA_SESSION_ID', 'default').strip() or 'default'
    OPENWA_ENABLED = os.environ.get('OPENWA_ENABLED', 'true').strip().lower() in ('true', '1', 'yes')
