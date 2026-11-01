# CampusOS Passport Phase 1D: Dynamic Presentation & Rotating QR

## 1. Architectural Principle: Identity vs Presentation Separation

CampusOS separates long-lived identity credentials from short-lived presentation credentials:

### Identity (Long-Lived, Foundational)
- **Ed25519 Device Keypair**: Stored strictly in local secure hardware-backed keystore (`PassportKeyStorage`).
- **Registered Public Key**: Certified in `device_identity_keys` on the backend.
- **Institutional Certificate**: Issued by the institution in `device_certificates`, proving the key belongs to an authenticated student.
- **Purpose**: Establishes *who* the device/student is over months/years.

### Presentation (Short-Lived, Dynamic)
- **Presentation Payload**: Ephemeral JSON payload referencing `keyId`, `userId`, `certificateId`, `issuerKeyId`, `issuedAt`, `expiresAt`, and a cryptographically secure random `nonce`.
- **Presentation Signature**: Signed locally on-device using the student's Ed25519 private key.
- **Rotating QR**: Displays the compact envelope (`{"p": <payload>, "s": "<signature>"}`).
- **Purpose**: Proves that the presenter currently controls the certified identity key at this precise moment without ever transmitting private keys or static credentials.

> [!IMPORTANT]
> Passport 1D provides short-lived signed identity presentation with expiration-based replay resistance. It does not yet provide verifier-challenge anti-replay.

---

## 2. Presentation Payload Specification

The presentation payload contains only minimal, non-sensitive metadata required for cryptographic verification:

```json
{
  "version": 1,
  "type": "PASSPORT_PRESENTATION",
  "keyId": "<device_identity_key_uuid>",
  "userId": "<student_user_uuid>",
  "certificateId": "<active_certificate_uuid>",
  "issuerKeyId": "<institution_key_identifier>",
  "issuedAt": 1774483200,
  "expiresAt": 1774483230,
  "nonce": "4a7b2c9e1f3d8a5b6c0e2f4a8b1d3e5c"
}
```

### Invariants:
1. **No Private Key**: The device private key never appears in the payload, QR, network logs, or database.
2. **No Permanent Public Key in QR**: The public key is already registered on the backend under `keyId`. The verifier retrieves and verifies the key from the backend key registry.
3. **No Unnecessary PII**: Student name, email, roll number, and phone number are omitted to protect privacy during visual inspection.

---

## 3. Canonical Serialization

To guarantee byte-for-byte identical signatures between Flutter (Dart) and Flask (Python), both platforms enforce deterministic canonical JSON serialization:

- **Sorting**: Keys sorted strictly in alphabetical ASCII order:
  1. `certificateId`
  2. `expiresAt`
  3. `issuedAt`
  4. `issuerKeyId`
  5. `keyId`
  6. `nonce`
  7. `type`
  8. `userId`
  9. `version`
- **Delimiters**: Compact separators without whitespace (`','` and `':'`).
- **Encoding**: UTF-8 bytes.

Python implementation:
```python
json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
```

Flutter implementation:
```dart
model.toCanonicalJson(); // Alphabetically sorts keys, encodes with compact delimiters
```

---

## 4. Signing & Verification Flow

```
STUDENT DEVICE (Flutter)
   PassportKeyStorage (Secure Keystore)
             ↓ [Private Key stays local]
   PassportCryptoService.signPresentation()
             ↓ [Ed25519 Signature]
   Compact Envelope: {"p": payload, "s": signature}
             ↓
   QrImageView (Dynamic Rotating QR)
             ↓
VERIFIER / SCANNER (Future 1E)
             ↓ POST /passport/verify
BACKEND (Flask / MySQL)
   1. Payload schema & type verification
   2. Certificate status check (ACTIVE, not expired, trusted issuer)
   3. Device key status check (ACTIVE, registered)
   4. Certificate-to-Key & Certificate-to-User bindings
   5. Timestamp freshness & clock skew tolerance (MAX_CLOCK_SKEW_SECONDS = 30)
   6. Ed25519 signature verification using registered public key
             ↓
   Result: {"valid": true, "reason": "VALID"} or {"valid": false, "reason": "..."}
```

---

## 5. Expiration & 30-Second Rotation

- **Presentation Lifetime (TTL)**: Approximately 30 seconds (`presentationLifetime = Duration(seconds: 30)`).
- **Client Rotation**: The Flutter client locally ticks down remaining validity. When `remainingSeconds <= 0`, a new presentation with a fresh 16-byte random `nonce` is generated and signed locally.
- **Zero Network Cost for Rotation**: Generating a new QR does **not** call the backend. It signs locally using the cached enrollment status. Only key activation and initial status query require network access.
- **Safe Lifecycle Management**: Flutter's `_rotationTimer` is safely paused/resumed via `WidgetsBindingObserver` and cleanly cancelled on widget `dispose()` to prevent memory or timer leaks.

---

## 6. Server-Side Verification Rules (POST /passport/verify)

The backend implements 20 deterministic validation checks:

| Check # | Rule | Error Code on Failure |
|---|---|---|
| 1-4 | Payload presence, version == 1, type == 'PASSPORT_PRESENTATION', required fields present | `INVALID_FORMAT` |
| 5-6 | `keyId` and `userId` present | `INVALID_FORMAT` |
| 7-8 | `certificateId` and `issuerKeyId` present | `INVALID_FORMAT` |
| 9-11 | `DeviceCertificate` exists, status == 'ACTIVE', and within validity window | `UNKNOWN_CERTIFICATE` / `REVOKED_CERTIFICATE` / `EXPIRED_CERTIFICATE` |
| 12-13 | `DeviceIdentityKey` exists and status == 'ACTIVE' | `UNKNOWN_KEY` / `REVOKED_KEY` |
| 14 | Certificate subject (`userId`, `keyId`) matches key and user | `CERTIFICATE_MISMATCH` |
| 15 | Issuer key matches institution trust anchor (`PASSPORT_INSTITUTION_KEY_ID`) | `CERTIFICATE_MISMATCH` |
| 16 | `issuedAt` is not in the future beyond `MAX_CLOCK_SKEW_SECONDS` (30s) | `NOT_YET_VALID` |
| 17-18 | `expiresAt` > `issuedAt` and presentation is not expired (`now <= expiresAt + skew`) | `PRESENTATION_EXPIRED` |
| 19 | Server-side clock skew tolerance (30 seconds) applied safely | `PRESENTATION_EXPIRED` |
| 20 | Ed25519 cryptographic signature verifies against registered `publicKey` | `INVALID_SIGNATURE` |

---

## 7. Stateless Architecture: Why No Presentation Table Exists

In Phase 1D:
- **No `passport_presentations` table** is created.
- **No `nonce` replay ledger** is stored in the database.

### Rationale:
1. Students rotate their QR every ~30 seconds. Storing every presentation would generate unnecessary database writes on mobile clients and verification gateways.
2. Short 30-second TTL limits replay exposure window without requiring persistent storage.
3. True zero-replay protection will be implemented in a subsequent phase via **Verifier Challenge-Response** (where the scanner terminal supplies a single-use random server-issued challenge nonce to be signed by the presenting device).

---

## 8. Threat Model & Security Boundaries

### What Passport 1D Protects:
- **Credential Theft**: Extracting the QR from a photo or screenshot only gives the attacker a payload valid for up to 30 seconds.
- **Key Extraction**: The private key is never transmitted or encoded in QR.
- **Identity Spoofing**: An attacker cannot generate a valid presentation for another student because they lack the certified Ed25519 private key.
- **Signature Tampering**: Any alteration of `keyId`, `userId`, `expiresAt`, or `nonce` causes signature verification to fail.

### What Is Deferred (Phase 1E+):
- **Live Verifier Camera / Scanner**: The scanner terminal interface.
- **Offline Gateway Verification**: Verifying presentations locally at gate terminals using cached public keys.
- **Challenge-Response Anti-Replay**: Verifier-issued challenges preventing video replay within the 30-second window.
- **Contextual Gate / Attendance Credentials**: Authorizing gate transit or BLE classroom presence via Passport presentation.
