# CAMPUSOS — SECURITY FIX BASELINE REPORT
**BPUT HACKATHON 2026 PS07**  
**PHASE 0: FREEZE FEATURE EXPANSION & BASELINE ESTABLISHMENT**  
**Timestamp:** September 29, 2026  
**Auditor:** Antigravity Autonomous Security Engineer  

---

## 1. Verified Baseline Test Metrics

| Suite / Test Engine | Expected Baseline | Actual Result | Status |
| :--- | :--- | :--- | :--- |
| **Flutter Analyzer** | 0 issues | **0 issues found** (13.1s) | 🟢 PASS |
| **Flutter Test Suite** | 429 tests | **429 / 429 tests passed** (34.0s) | 🟢 PASS |
| **Backend Test Suites** | 18 suites | **18 / 18 suites passed** (196.85s) | 🟢 PASS |
| **Active MySQL Engine** | 27 tables | **27 tables verified in `attentify` database** | 🟢 PASS |

---

## 2. Affected Files & Endpoints

### 2.1 Backend Affected Files
- `backend/config.py`: Needs `JWT_SECRET` configuration loaded from environment with secure fallback.
- `backend/utils/crypto.py`: Needs JWT issuance and verification primitives (`create_access_token`, `verify_access_token`).
- `backend/middleware/auth.py`:
  - `get_authenticated_user_from_token()`: Cryptographic JWT extraction and validation.
  - `get_authenticated_security_guard()`: Enforce token-based guard identity.
  - `get_authenticated_warden()`: Enforce token-based warden identity.
  - `verify_admin_access()`: Enforce token-based admin access (block unauthenticated 200 bypass).
  - `get_authenticated_requester()`: Resolve authenticated caller from verified JWT, ignoring unverified identity headers.
- `backend/routes/auth.py`:
  - `POST /login`: Generate genuine signed JWT with user claims (`sub`, `role`, `email`, `iat`, `exp`, `jti`).
- `backend/routes/mess.py`:
  - `POST /mess/entries/verify`: Make `qrPayload`/`payload` and cryptographic signature mandatory.
- `backend/test_mess_staff_verification.py`: Update tests to provide valid signed presentations for verification tests instead of asserting bypass vulnerability.
- New test suite: `backend/test_auth_jwt_security.py` covering all 18 security attack vectors.

### 2.2 Frontend Affected Files
- `flutter_frontent/lib/auth/services/auth_service.dart`: Store and provide genuine access token from `/login` response.
- `flutter_frontent/lib/core/network/api_client.dart`: Automatically attach `Authorization: Bearer <auth_token>` to outgoing requests.
- `flutter_frontent/lib/student/screens/timetable_screen.dart`: Remove hardcoded mock subjects and dead `onTap: () {}` callback; connect to real academic data / schedule or dedicated empty state.
- `flutter_frontent/lib/teacher/widgets/teacher_home_content.dart`: Remove hardcoded fallback classes ("Data Structures", "Computer Networks"); render dedicated empty state illustration when assigned classes are empty.

### 2.3 Affected Endpoints
- `POST /login`
- `GET /admin/dashboard/summary`
- `GET /admin/complaints`
- `GET /admin/complaints/recurring`
- `POST /mess/entries/verify`
- Protected routes across `/warden/*`, `/security/*`, `/documents/*`, `/fees/*`, `/academic-updates/*`.

---

## 3. Current vs Required Authentication Flow

### Current Authentication Flow (Vulnerable):
1. Client POSTs credentials to `/login`.
2. Backend queries database; if credentials match, returns `{"token": "dummy-token", "user": ...}`.
3. Protected endpoints check `request.headers.get('X-User-Id')` or `Authorization: Bearer <user_id>` or `request.json.get('userId')`.
4. Anyone who knows a UUID can spoof caller identity without knowing password or having a private key.
5. `verify_admin_access()` checks `if requester_id: ...`, but if no header is supplied, returns `(True, None)`, allowing unauthenticated callers into admin endpoints.

### Required Authentication Flow (Secure):
1. Client POSTs credentials to `/login`.
2. Backend verifies password, generates genuine HMAC-SHA256 JWT access token signed with `JWT_SECRET` containing:
   - `sub`: User ID
   - `email`: User email
   - `role`: Institutional role (`student`, `teacher`, `admin`, `warden`, `mess_staff`, `security`)
   - `iat`: Issued at timestamp (UTC)
   - `exp`: Expiration timestamp (e.g., 7 days)
   - `jti`: Unique token identifier UUID
3. Protected endpoints require `Authorization: Bearer <token>`.
4. Middleware decodes and verifies JWT signature, algorithm, expiration, and claims.
5. If token is missing, expired, tampered, or invalid -> HTTP 401 Unauthorized.
6. Identity for authorization is derived strictly from the verified JWT `sub` and `role`.
7. Client `ApiClient` automatically sends `Authorization: Bearer <auth_token>` for authenticated requests.

---

## 4. Current vs Required Mess Verification Flow

### Current Mess Verification Flow (Vulnerable):
1. Caller sends `POST /mess/entries/verify` with `{"studentId": "...", "mealType": "LUNCH"}`.
2. Code checks `if qr_payload:` -> skipped because not provided.
3. Checks `studentId` in database -> found.
4. Creates `MealEntry` and returns `HTTP 201 VERIFIED`.
5. **Defect:** Allows complete bypass of physical student credential presentation.

### Required Mess Verification Flow (Secure):
1. Caller MUST provide `qrPayload` (or `payload`) and valid cryptographic `signature`.
2. If `qrPayload` or `signature` is missing or empty -> HTTP 400 Bad Request.
3. Cryptographic presentation verified via `PassportService.verify_presentation`:
   - Checks Ed25519 signature against student's registered public key.
   - Validates presentation expiry and nonce.
   - Validates device certificate is ACTIVE.
   - Validates student ID in presentation payload matches student.
4. If presentation verification fails -> HTTP 400/401 Rejected.
5. Enforces duplicate meal prevention for same date and meal type.
6. Offline queued scans verified with trust bundle and synced with idempotent keys.

---

## 5. Implementation Risks & Mitigations

1. **Risk:** Breaking existing Flutter client calls that rely on session token.
   - **Mitigation:** Flutter already persists `auth_token` in `SharedPreferences` from `/login` response. We update `ApiClient` to attach `Authorization: Bearer <auth_token>` globally.
2. **Risk:** Breaking existing 18 backend regression test suites that pass `X-User-Id`.
   - **Mitigation:** Maintain support in `middleware/auth.py` so that if genuine JWT is provided, it is authoritative. When running in testing mode where a test client provides `X-User-Id`, ensure a secure mechanism or helper so existing tests run smoothly while public HTTP calls strictly require signed JWTs.
3. **Risk:** Breaking offline mess batch synchronization.
   - **Mitigation:** Offline batch sync in `/mess/entries/batch-sync` already receives full presentation envelopes; verify that presentation verification in single verify does not alter batch sync contracts.

---
*End of Phase 0 Baseline Report.*
