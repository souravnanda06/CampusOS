import os
from app import app, get_institution_key_id, get_institution_public_key_b64

if __name__ == '__main__':
    try:
        key_id = get_institution_key_id()
        pub_b64 = get_institution_public_key_b64()
        print(f"🔒 [PASSPORT] Institutional signing key configured: keyId={key_id}, pubKey={pub_b64[:12]}...")
    except Exception as e:
        print(f"⚠️ [PASSPORT] Institutional signing key not configured: {e}")
    port = int(os.environ.get('PORT', 5000))
    debug_mode = os.environ.get('FLASK_DEBUG', 'false').lower() in ('true', '1', 'yes')
    app.run(debug=debug_mode, host='0.0.0.0', port=port)
