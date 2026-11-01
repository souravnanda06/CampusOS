# CampusOS Passport Phase 1F: Offline Verification & Local Trust Bundle Architecture

## Overview & Scope Boundary
CampusOS Passport Phase 1F enables authorized verifier devices (Hostel Wardens, Gate Staff, Teachers, and Campus Administrators) to perform **100% offline cryptographic verification** of rotating dynamic Passport QR presentations without any internet or backend connectivity.

Verification is driven by an authenticated, locally cached **Trust Bundle** containing certified device public keys, institutional certificates, and active identity records signed by the CampusOS Root Authority keypair (`campusos-root-2026-v1`).

### Explicit Security Boundary & Revocation Limitation Statement
> **CRITICAL SECURITY BOUNDARY**:
> "Offline Passport verification establishes cryptographic validity against the verifier's last trusted CampusOS trust snapshot. It cannot observe revocations or certificate changes that occurred after that snapshot."

Offline verification proves:
1. The presentation was created and signed by an Ed25519 identity key certified by CampusOS.
2. The presentation payload has not been tampered with or modified.
3. The presentation timestamps adhere to the 30-second presentation validity window and clock-skew bounds.
4. The identity key and institutional certificate were marked `ACTIVE` at the time the verifier device synchronized its trust snapshot.

Offline verification does **NOT** prove:
- The identity has not been revoked on the server *after* the trust bundle snapshot was generated.
- The presentation has never been scanned elsewhere on campus (anti-replay requires online state or interactive challenge).
- The student is authorized for specific physical gate passage, leave approval, mess access, or attendance marking (business authorizations remain domain-specific).

---

## 1. Trust Bundle Architecture

The trust bundle is a compact, cryptographically authentic data container holding only public cryptographic artifacts and identity records. Private keys, student passwords, contact details, and unnecessary PII are strictly excluded.

### Data Schema
```json
{
  "version": 1,
  "issuerKeyId": "campusos-root-2026-v1",
  "generatedAt": 1727318400,
  "expiresAt": 1727340000,
  "institution": {
    "keyId": "campusos-root-2026-v1",
    "publicKey": "base64_ed25519_root_public_key..."
  },
  "identities": [
    {
      "keyId": "dev_key_01...",
      "userId": "usr_student_...",
      "publicKey": "base64_ed25519_device_pubkey...",
      "certificateId": "cert_inst_...",
      "issuerKeyId": "campusos-root-2026-v1",
      "validFrom": 1727310000,
      "validTo": 1758846000,
      "status": "ACTIVE"
    }
  ],
  "revokedKeyIds": [
    "dev_key_revoked_..."
  ]
}
```

### Bundle Envelope & Institutional Signature
To prevent man-in-the-middle attacks, rogue cache injection, or bundle tampering, the trust bundle is signed by the backend using the CampusOS Root Authority Ed25519 private key:
```json
{
  "payload": { ...canonical trust bundle payload... },
  "signature": "base64_ed25519_institutional_signature..."
}
```

The verifier device independently validates this signature against the trusted CampusOS Root Authority public key prior to saving or using any cached trust bundle.

---

## 2. Deterministic Canonicalization
To guarantee byte-level consistency between backend Python signing (`passport_service.py`) and Flutter Dart verification (`passport_trust_bundle_model.dart` / `passport_trust_bundle_service.dart`), canonical JSON formatting adheres to strict deterministic rules:
1. **Sorted Keys**: All map keys at all nesting depths are sorted alphabetically.
2. **Compact Separators**: No whitespace after `:` or `,` (e.g. `{"a":1,"b":2}`).
3. **UTF-8 Encoding**: Character data is encoded strictly as UTF-8 bytes.
4. **Number Normalization**: Integer epoch timestamps without trailing decimals.

Both backend and client share identical canonical serialization algorithms.

---

## 3. Server Endpoint: `GET /passport/trust-bundle`
- **Path**: `GET /passport/trust-bundle`
- **Authentication**: Existing CampusOS Bearer session token.
- **Authorization**: Role-gated via `passport_verifier_required`.
  - Allowed: `ADMIN`, `WARDEN`, `STAFF`, `TEACHER`
  - Forbidden: `STUDENT` receives HTTP `403 Forbidden`.
- **Response**: Signed trust bundle containing all `ACTIVE` identity keys and `ACTIVE` institutional certificates. Revoked key IDs are appended to the snapshot's revocation ledger.
- **Database Safety**: Zero database schema mutations or new tables required. Queries existing `DeviceIdentityKey` and `DeviceCertificate` tables directly.

---

## 4. Local Cache & Secure Storage
On the Flutter verifier device:
- The trust bundle is persisted via `PassportKeyStorage` (using hardware-backed `FlutterSecureStorage` with Android Keystore encryption in production).
- Storage key: `campusos_passport_trust_bundle_v1`.
- When loading a cached bundle from local disk, the service performs **cold-load integrity verification**:
  1. Unpacks bundle and institutional signature.
  2. Canonicalizes the payload.
  3. Verifies Ed25519 institutional root signature.
  4. Only if signature verification succeeds is the bundle accepted into memory.
- If storage is tampered with or corrupted, the service rejects the bundle and reports `OFFLINE_INVALID_BUNDLE` or `OFFLINE_TRUST_DATA_MISSING`.

---

## 5. Trust Bundle Expiration & Freshness Lifecycles
Trust bundles are bound to an operational Time-To-Live (TTL):
- Default TTL: 6 hours (`generatedAt` to `expiresAt`).
- **Fresh**: `< 4 hours` old.
- **Expiring Soon**: Within 2 hours of expiration.
- **Expired**: `now > expiresAt`.

### Handling Stale Trust Data
If the trust bundle has expired:
1. Offline verification is halted immediately.
2. The UI displays: **"Trust Data Expired"** and *"Offline verification data has expired. Connect to CampusOS to refresh."*
3. The verifier cannot issue false positive claims of identity trust on outdated snapshots.

---

## 6. Offline Verification Flow & The 18 Cryptographic Rules
When the verifier is in **OFFLINE** mode, camera scans execute through `PassportOfflineVerifierService.verifyOffline(...)` with zero HTTP or `ApiClient` calls:

```
Scanned QR String
      ↓
[ Rule 1 ] Local envelope parsed (must be valid JSON with 'p' and 's')
      ↓
[ Rule 2 ] Type matches 'PASSPORT_PRESENTATION' & version == 1
      ↓
[ Rule 3 ] Required presentation fields present (userId, keyId, certId, issuedAt, expiresAt, nonce)
      ↓
[ Rule 4 ] Load local trust bundle from cache & verify institutional signature
      ↓
[ Rule 5 ] Check trust bundle expiration (generatedAt <= now <= expiresAt)
      ↓
[ Rule 6 ] Find keyId in cached bundle (reject with OFFLINE_UNKNOWN_KEY if absent)
      ↓
[ Rule 7 ] Check key status (must be ACTIVE; reject with OFFLINE_REVOKED_KEY if in revoked list)
      ↓
[ Rule 8 ] Check certificateId matches certified record in bundle
      ↓
[ Rule 9 ] Check userId matches certified record in bundle
      ↓
[ Rule 10 ] Check certificate issuerKeyId matches trusted institution root keyId
      ↓
[ Rule 11 ] Verify certificate validity window (validFrom <= now <= validTo)
      ↓
[ Rule 12 ] Check presentation issuedAt not in future beyond clock-skew tolerance (30s)
      ↓
[ Rule 13 ] Check presentation expiresAt not in past (now <= expiresAt + skew)
      ↓
[ Rule 14 ] Check presentation duration within 30-second bounds
      ↓
[ Rule 15 ] Extract device public key from certified identity record
      ↓
[ Rule 16 ] Deterministically canonicalize presentation payload
      ↓
[ Rule 17 ] Locally verify Ed25519 signature over canonical presentation bytes
      ↓
[ Rule 18 ] Return OFFLINE_VALID with verified user details and trust snapshot age
```

---

## 7. Verifier Screen UI Experience (`PassportVerifierScreen`)
The verification terminal provides a refined operator interface:
1. **ONLINE / OFFLINE Segmented Selector**:
   - `ONLINE`: Authoritative server verification via `POST /passport/verify`.
   - `OFFLINE`: 100% offline verification using local trust bundle.
2. **Passport Trust Data Management Sheet**:
   - Accessed via the AppBar shield icon.
   - Displays Status (Fresh / Expiring / Expired), Last Updated, Expires, Active Identities count, and Institution Key ID.
   - Provides `[ Refresh Trust Data ]` (downloads latest bundle when online) and `[ Verify Bundle ]` (validates local bundle signature on demand).
3. **Authoritative Offline Result Cards**:
   - **Valid Card**: Displays `PASSPORT VALID` + `OFFLINE` badge, Student Name, Roll/Reg No, Branch, Semester, Snapshot Age (e.g. *"updated 18 mins ago"*), the 3 cryptographic guarantees (`✓ Cryptographic signature valid`, `✓ Institution certificate valid`, `✓ Identity key trusted`), and the explicit revocation limitation notice.
   - **Invalid Cards**: Clear diagnostic error states for invalid signatures, unknown identity keys, expired certificates, expired presentations, and expired trust snapshots.

---

## 8. Threat Model & Mitigation Matrix

| Threat | Attack Vector | Mitigation in Passport 1F |
| :--- | :--- | :--- |
| **Fake QR Code** | Attacker generates arbitrary QR with student ID | Device public key is certified by CampusOS; signature verification fails locally without private key. |
| **Tampered QR** | Attacker intercepts legitimate QR and modifies student roll or timestamp | Ed25519 presentation signature is verified over canonical bytes; any modification invalidates signature. |
| **Tampered Trust Bundle** | Attacker edits local JSON cache to inject rogue public key | Trust bundle has institutional Ed25519 signature verified on import and cold load against hardcoded trust anchor. |
| **Stale Revocation Replay** | Revoked student presents valid-looking QR to offline verifier | Trust bundle enforces 6-hour operational TTL; verifier UI explicitly discloses snapshot time and revocation limitation. |
| **Privilege Escalation** | Student attempts to download bundle or run verifier | Role gating prevents student role from fetching `/passport/trust-bundle` (403) and blocks Verifier UI. |
| **Network Leaks** | Device in offline mode accidentally phones home | `PassportOfflineVerifierService` contains zero references or calls to `ApiClient` or network sockets. |

---

## 9. Features Explicitly Deferred to Phase 1G+
The following capabilities were intentionally excluded from Phase 1F to maintain clean architectural boundaries:
- **Interactive Challenge-Response**: Nonce generation, verifier-student BLE challenge, or one-time counter challenges.
- **Biometric Attestation**: Face / gait matching during presentation.
- **Incremental Delta Bundles**: Merkle-tree or delta-sync updates for campuses exceeding 50,000 students.
- **Decentralized Replay Ledger**: Offline mesh replay detection between multiple roaming verifiers.
- **Physical Gate Automation**: Automatic gate barrier triggers or relay activation.
