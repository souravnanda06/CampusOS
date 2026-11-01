import sys
import os
backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

import passport_service as _ps

PassportService = _ps.PassportService
get_institution_key_id = _ps.get_institution_key_id
get_institution_public_key_b64 = _ps.get_institution_public_key_b64
validate_public_key = _ps.validate_public_key
set_institution_key_override = _ps.set_institution_key_override
clear_institution_key_override = _ps.clear_institution_key_override

__all__ = [
    'PassportService',
    'get_institution_key_id',
    'get_institution_public_key_b64',
    'validate_public_key',
    'set_institution_key_override',
    'clear_institution_key_override'
]
