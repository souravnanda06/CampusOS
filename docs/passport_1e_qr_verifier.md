# CampusOS Passport Phase 1E: QR Scanner + Online Cryptographic Verification

## 1. Architectural Scope

Passport 1E establishes the **verifier terminal side** of CampusOS Passport.

It enables a second device (operated by authorized campus staff, wardens, teachers, or security personnel) to scan the presenting student's rotating dynamic Passport QR and receive an authoritative, tamper-proof cryptographic verification result from the CampusOS backend.

> [!IMPORTANT]
> Passport 1E provides online QR presentation verification. It does not provide offline verification or verifier challenge-response.

---

## 2. End-to-End Verification Flow

```
PRESENTER DEVICE (Student)
   PassportPresentationService
         ↓
   Local Ed25519 Private Key (Keystore)
         ↓
   Canonical Presentation Payload (~30s TTL, nonce)
         ↓
   Digital Signature
         ↓
   Compact QR Envelope: {"p": {...}, "s": "base64_sig"}
         ↓
   Dynamic Rotating QR (Displayed on screen)

VERIFIER DEVICE (Staff / Checkpoint Terminal)
   Camera Scanner (mobile_scanner)
         ↓
   Local Syntax & Envelope Validation (PassportVerifierService)
         ↓ [Rejects malformed QR locally before network]
   Online API Call: POST /passport/verify
         ↓
CAMPUSOS BACKEND AUTHORITY (Flask / MySQL)
   1. Payload schema, type, and version validation
   2. Certificate status check (ACTIVE, not expired, trusted issuer anchor)
   3. Device identity key check (ACTIVE, registered in device_identity_keys)
   4. Certificate-to-Key and Certificate-to-User bindings
   5. Timestamp freshness & clock skew tolerance (MAX_CLOCK_SKEW_SECONDS = 30)
   6. Ed25519 cryptographic signature verification against registered public key
   7. Student identity retrieval (name, branch, semester)
         ↓
VERIFICATION RESULT
   - PASSPORT VALID: Student name, branch, semester, "KEY ACTIVE", "CERTIFICATE ACTIVE"
   - PASSPORT INVALID: Specific, actionable, non-cryptic explanation
         ↓
   Scan Again (Restores camera scanner without state leaks)
```

---

## 3. QR Parsing & Client-Side Validation

Before issuing an HTTP request, `PassportVerifierService` validates the scanned string locally:
1. **JSON Syntax**: Verifies the QR contains valid JSON.
2. **Top-Level Envelope**: Ensures both `p` (payload map) and `s` (base64 signature string) are present.
3. **Payload Structure**: Validates that `version`, `type`, `keyId`, `userId`, `certificateId`, `issuerKeyId`, `issuedAt`, `expiresAt`, and `nonce` are all present.
4. **Credential Type**: Verifies `type == 'PASSPORT_PRESENTATION'`.
5. **Version**: Verifies `version == 1`.

If the QR is malformed or unparseable, `PassportVerificationResult.invalidFormat` is returned immediately without contacting the server, preventing unnecessary network and compute load.

---

## 4. Authoritative Verification Result States

The verifier cleanly maps authoritative backend responses to deterministic, user-friendly UI cards:

| Result State | Title | User Explanation |
|---|---|---|
| `VALID` | **PASSPORT VALID** | Certified CampusOS Identity Presentation. Displays student name, branch, semester, ID, active key status, and remaining validity countdown. |
| `INVALID_SIGNATURE` | **Passport Could Not Be Verified** | Signature is invalid or presentation was altered. |
| `PRESENTATION_EXPIRED` | **Passport Presentation Expired** | Ask the student to refresh their Passport QR (30s lifetime elapsed). |
| `EXPIRED_CERTIFICATE` | **Identity Certificate Expired** | The student's institutional identity certificate has expired. |
| `REVOKED_KEY` | **Passport Identity Revoked** | This device key has been revoked by campus administration. |
| `REVOKED_CERTIFICATE` | **Certificate Revoked** | The institutional identity certificate has been revoked. |
| `CERTIFICATE_MISMATCH` | **Passport Identity Mismatch** | The presentation does not match its certified identity. |
| `UNKNOWN_KEY` | **Unknown Passport Identity** | The presented identity key is not registered in CampusOS. |
| `NOT_YET_VALID` | **Passport Not Yet Valid** | Presenting device clock is set in the future beyond allowed clock skew. |
| `INVALID_FORMAT` | **Invalid Passport QR** | Scanned QR is not a valid CampusOS presentation credential. |
| `NETWORK_ERROR` | **Verification Unavailable** | Connect to the CampusOS server and try again. |

---

## 5. Network Failure vs Cryptographic Failure

A strict architectural separation is maintained between:
- **Cryptographic Failure** (`INVALID_SIGNATURE`, `CERTIFICATE_MISMATCH`, `REVOKED_KEY`): The presentation was evaluated by the authority and rejected.
- **Transport Failure** (`NETWORK_ERROR`): The verifier terminal could not reach the backend server due to network timeout or connection refusal.

Transport errors are displayed with a distinct neutral "Verification Unavailable" status rather than falsely accusing the student of presenting an invalid credential.

---

## 6. Access Control & Role Boundaries

- Verification privileges are strictly gated to authorized roles: `admin`, `warden`, `staff`, and `teacher`.
- If an authenticated `student` attempts to open `/passport/verify`, the screen presents an **Access Restricted** shield view stating that verification terminals are reserved for campus authorities and checkpoint staff.
- Existing role models (`UserModel.role`) and authentication headers are preserved without introducing new RBAC or JWT infrastructure.

---

## 7. Resource & Lifecycle Safety

The `PassportVerifierScreen` is built for high-throughput checkpoint environments:
- **Duplicate Callback Suppression**: An internal `_isProcessingScan` flag immediately ignores rapid camera frames once a QR is captured.
- **Scanner Pause**: The camera feed is paused while the verification request is processed.
- **Scan Again Flow**: Tapping `[ Scan Another Passport ]` or `[ Scan Again ]` resets state and restarts the camera controller in-place, without stacking new navigation routes or leaking camera textures.
- **Clean Disposal**: Controllers and periodic validity countdown timers are cancelled upon widget unmounting.

---

## 8. Explicitly Deferred Features (Phase 1F+)

To maintain strict PS07 architectural boundaries, the following capabilities are deferred:
1. **Offline Verification**: Verifying presentations locally using offline cached institutional public key bundles.
2. **Verifier Challenge-Response**: Dynamic server/scanner nonces to provide zero-replay video proof.
3. **BLE Verifier**: Verifying student identity over Bluetooth Low Energy.
4. **Gate Pass / Attendance Integration**: Passport presentation proves identity possession; gate transit and classroom check-ins remain separate contextual authorizations.
5. **Universal Passport Token**: No universal bearer token is created.
