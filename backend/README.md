# CampusOS Backend: Modular Flask Monolith & Cryptographic Services

[![Backend Framework](https://img.shields.io/badge/Framework-Flask%203.x-blue?style=flat-square)](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/backend/app.py)
[![Database](https://img.shields.io/badge/Database-MySQL%208.0%20%2F%20SQLAlchemy-orange?style=flat-square)](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/backend/models)
[![Cryptography](https://img.shields.io/badge/Crypto-Ed25519%20%2B%20HMAC--SHA256-green?style=flat-square)](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/backend/utils/crypto.py)
[![Test Suites](https://img.shields.io/badge/Test%20Suites-22%20Passing-success?style=flat-square)](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/backend/run_all_backend_tests.py)

The **CampusOS Backend** is an institutional application server designed for high throughput, strict role-based access control (RBAC), and offline-resilient cryptographic verification. It serves as the authoritative persistence and verification layer for both the Flutter mobile client and the React 19 administrative control plane.

---

## 🏗️ Architecture & Package Layout

The backend is built as a clean, modular monolith structured into distinct domain layers:

```
backend/
├── app.py                      # Central composition root & Flask app factory
├── config.py                   # Environment variable loader & settings
├── extensions.py               # Shared extensions (SQLAlchemy db, FCM Push)
├── run.py                      # Local development runtime server
│
├── models/                     # 27 Relational SQLAlchemy Database Models
│   ├── __init__.py             # Central export & init_db table registration
│   ├── user.py                 # User identity, hashed passwords, roles
│   ├── attendance.py           # Sessions, Attendance records, Coupons, Classes
│   ├── leave.py                # Student leave requests & status lifecycles
│   ├── gate_pass.py            # Cryptographic gate passes & transit logs
│   ├── mess.py                 # Menus, meals, feedback ratings, meal scans
│   ├── complaint.py            # Grievance tickets, categories, ageing flags
│   ├── notice.py               # Scoped circulars (STUDENT, TEACHER, ALL)
│   ├── notification.py         # Push device tokens & delivery tracking
│   ├── passport.py             # Ed25519 device keys & institutional certificates
│   ├── audit.py                # Immutable audit logs & ticket status histories
│   ├── expansion.py            # Documents, Fees, Hostel Assets, Visitor passes
│   └── schema.py               # Auxiliary schemas & legacy support
│
├── routes/                     # 19 Domain-Specific Flask Blueprints
│   ├── auth.py                 # Login, session restore, password verification
│   ├── attendance.py           # BLE check-in, dynamic QR scan, batch sync
│   ├── gate_pass.py            # Student gate pass requests & live QR payload
│   ├── security.py             # Security guard pass scanner & transit recorder
│   ├── warden.py               # Warden leave inbox, approvals, reject remarks
│   ├── leave.py                # Leave request lifecycles & queries
│   ├── mess.py                 # Menu management, QR dining scan, feedback
│   ├── complaints.py           # Grievance submission, triage & status updates
│   ├── notices.py              # Targeted circular publishing & read receipts
│   ├── notifications.py        # FCM token registration & notification queries
│   ├── passport.py             # Ed25519 identity issuance & trust bundle export
│   ├── documents.py            # Document request approvals & certificate registry
│   ├── fees.py                 # Dues overview, receipts & student balances
│   ├── hostel.py               # Room allocation & physical asset defect reports
│   ├── visitors.py             # Visitor entry requests & gate checkout
│   ├── academic_updates.py     # Classroom shift notifications & feed
│   ├── search.py               # Global institutional fuzzy search
│   └── admin.py                # System telemetry, metrics & executive analytics
│
├── services/                   # Core Business Logic & Algorithms
│   ├── notice_service.py       # Scoped recipient resolution & delivery states
│   ├── recurrence_clustering.py# Natural language similarity clustering for complaints
│   └── passport_service.py     # Public key trust bundle generation & cert signer
│
├── middleware/                 # Security & RBAC Enforcement
│   ├── auth.py                 # JWT token extraction & verification decorators
│   └── roles.py                # Role checkers (Student, Teacher, Warden, Admin, etc.)
│
├── utils/                      # Cryptographic & Data Primitives
│   ├── crypto.py               # Ed25519 signature checks, HMAC-SHA256 tokens
│   └── validators.py           # Payload validation & sanitization functions
│
├── seed_test_data.py           # Deterministic test seeder for all 6 roles
└── run_all_backend_tests.py    # Test runner for all 22 backend test suites
```

---

## 🗄️ Relational Database Schema (MySQL 8)

The backend interacts with **27 normalized relational tables** in MySQL:

| Domain | Table Name | Purpose |
| :--- | :--- | :--- |
| **Identity & Access** | `users` | User credentials, roles, roll numbers, department. |
| | `device_tokens` | Active FCM registration tokens per user. |
| | `device_identity_keys` | Student device public keys for Ed25519 identity. |
| | `device_certificates` | Institution-signed identity certificates. |
| **Attendance** | `sessions` | Teacher classroom attendance broadcast sessions. |
| | `attendance` | Confirmed attendance check-ins with anti-proxy flags. |
| | `coupons` | Time-limited rotating coupon codes for manual entry. |
| | `saved_classes` | Teacher pinned subjects and batch schedules. |
| **Leave & Perimeter** | `leave_requests` | Student leave applications, dates, and warden decisions. |
| | `gate_passes` | Approved cryptographic passes, valid windows, HMAC tokens. |
| | `visitor_requests` | Campus visitor registrations and guest check-ins. |
| **Dining Services** | `mess_menus` | Weekly breakfast, lunch, snacks, and dinner schedules. |
| | `mess_meals` | Specific meal items, allergen warnings, calories. |
| | `meal_entries` | Consumed student meals (duplicate-protected via nonces). |
| | `mess_feedbacks` | Student ratings (1-5 stars) and qualitative feedback. |
| **Hostel & Facilities**| `hostel_allocations` | Student room and bed number assignments. |
| | `hostel_assets` | Inventory items assigned to rooms (fans, desks, cots). |
| | `asset_issues` | Defect reports and maintenance tickets for hostel assets. |
| **Student Affairs** | `complaints` | Grievance tickets, severity, assigned teams. |
| | `complaint_status_histories` | Audited state transitions with remarks and timestamps. |
| | `document_requests` | Degree/bonafide certificate requests and issue status. |
| | `fee_records` | Semester dues, payment balances, and transaction refs. |
| | `class_updates` | Classroom shift circulars and instant lecture updates. |
| **Communication** | `notices` | Scoped broadcast announcements with targeted roles. |
| | `notification_deliveries`| Read receipts per recipient (`DELIVERED`, `READ`). |
| **Audit & Governance**| `request_audits` | Immutable log of all administrative actions. |

---

## 🔐 Cryptographic Implementation Details

### 1. CampusOS Passport (Ed25519)
- **Identity Issuance**: The client mobile app generates an asymmetric Ed25519 keypair in local secure storage. The public key is submitted to [`/api/passport/keys`](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/backend/routes/passport.py).
- **Presentation**: Students present a QR code signed by their private key. The payload includes:
  `{ student_id, nonce, timestamp, signature }`.
- **Verification**: The verifier verifies the signature using the student's public key or cached institutional trust bundle ([`utils/crypto.py`](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/backend/utils/crypto.py)).
- **Replay Protection**: Nonces must be fresh (within 30 seconds) and are recorded to prevent replay attacks.

### 2. Gate Pass HMAC-SHA256
- When a Warden approves a leave request, the backend creates an entry in `gate_passes` and generates an HMAC token:
  `HMAC-SHA256(student_id + pass_id + valid_until, GATE_PASS_SECRET)`.
- Security guards at the campus gate scan the QR code to verify validity without requiring a live cloud lookup.

---

## ⚙️ Configuration & Environment

Environment variables are loaded automatically from [backend/.env](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/backend/.env) via [backend/config.py](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/backend/config.py):

| Variable | Description | Default / Example |
| :--- | :--- | :--- |
| `DATABASE_URL` | MySQL connection string (PyMySQL driver) | `mysql+pymysql://root:password@localhost/attentify` |
| `GATE_PASS_SECRET` | Secret key used for signing HMAC gate passes | `campusos_gate_super_secret_key_2026` |
| `PASSPORT_INSTITUTION_KEY_ID` | Identifier for institutional root key | `campusos-root-2026-v1` |
| `PASSPORT_INSTITUTION_PRIVATE_KEY` | Base64-encoded Ed25519 institutional key | *(Optional in dev)* |
| `JWT_SECRET` | Secret key for issuing and validating HS256 JWTs | `campusos_jwt_sec_8f9c2d1b4e053a6f1d2e4c8b7a9f0e3d` |
| `JWT_EXPIRATION_HOURS` | Lifetime of user auth token in hours | `168` (7 days) |
| `PORT` | HTTP port for Flask development server | `5000` |
| `FLASK_DEBUG` | Flask debug hot reload toggle | `false` |

---

## 🚀 Setup & Execution

### 1. Installation
```bash
python -m venv venv
.\venv\Scripts\Activate.ps1   # Windows PowerShell
pip install -r requirements.txt
```

### 2. Database Migration & Seeding
Ensure MySQL is running and the database specified in `DATABASE_URL` exists.
Run the deterministic seeder to create tables and initialize test accounts:
```bash
python seed_test_data.py --reset --verify
```

### 3. Run Development Server
```bash
python run.py
```
API endpoints are accessible at: `http://localhost:5000/api`

---

## 🧪 Testing Backend Test Suites

The backend includes 22 individual test suites covering all roles, security vectors, and edge cases:

```bash
# Run the complete test suite runner:
python run_all_backend_tests.py

# Or run individual test suites:
python test_gate_security.py
python test_phase6_security_attacks.py
python test_cross_role_e2e.py
python test_mess_staff_verification.py
python test_step1c_passport_identity.py
python test_step21b_notices.py
```
