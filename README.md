# CampusOS: Institutional Campus Operating System

[![System Status](https://img.shields.io/badge/System-Operational-emerald?style=flat-square)](file:///d:/DEVLOPEMENT/CampusOS-1.0.0)
[![BPUT Hackathon 2026](https://img.shields.io/badge/Hackathon-BPUT%20PS07-blue?style=flat-square)](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/docs/CAMPUSOS_COMPLETE_DOCUMENTATION.md)
[![Backend Tests](https://img.shields.io/badge/Backend%20Suites-22%20Passing-success?style=flat-square)](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/backend/run_all_backend_tests.py)
[![Flutter Tests](https://img.shields.io/badge/Flutter%20Tests-439%20Passing-success?style=flat-square)](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/frontend/test)
[![License](https://img.shields.io/badge/License-Proprietary%20%2F%20Institutional-orange?style=flat-square)](file:///d:/DEVLOPEMENT/CampusOS-1.0.0)

**CampusOS** is a unified, offline-resilient, multi-role digital operating platform engineered for universities, engineering colleges, and polytechnic campuses. It replaces disconnected legacy registers, vulnerable roll calls, unverified paper slips, and informal social groups with a unified digital operating layer.

Built originally for the **BPUT Hackathon 2026 (Problem Statement PS07)**, CampusOS connects all six primary institutional stakeholders—**Students**, **Teachers**, **Hostel Wardens**, **System Administrators / Deans**, **Mess Staff**, and **Gate Security Guards**—around an authoritative MySQL 8 backend, device-bound Ed25519 cryptographic identities ([CampusOS Passport](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/backend/routes/passport.py)), and an adaptive client runtime.

---

## 🏛️ System Architecture

CampusOS consists of three tightly coupled components:

```mermaid
graph TD
    subgraph Clients["Client Tier"]
        MobileApp["📱 Flutter Mobile App<br/>(Student, Teacher, Warden, Mess, Security, Admin)<br/>iOS / Android / Web"]
        AdminWeb["💻 React 19 Admin Web<br/>(Deans & Central Administration)<br/>Vite + TypeScript + Tailwind"]
    end

    subgraph CoreServices["Backend Application Tier (Flask Monolith)"]
        APIGateway["REST API Gateway (Port 5000)<br/>Flask + CORS + RBAC Middleware"]
        CryptoService["🔐 Cryptographic Engine<br/>Ed25519 Passports + HMAC-SHA256 Gate Passes"]
        NotificationEngine["🔔 Notification Engine<br/>FCM + SQLite/MySQL Fallback"]
        AuditService["📜 Immutable Audit Trail<br/>request_audits & Status History"]
    end

    subgraph DataStorage["Authoritative Persistence Tier"]
        MySQL[(🗄️ MySQL 8 Database<br/>27 Normalized Tables)]
        LocalCache[(📱 Local SQLite / Drift<br/>Offline Trust Bundles & Sync)]
    end

    MobileApp -->|HTTPS / JWT Bearer| APIGateway
    AdminWeb -->|HTTPS / JWT Bearer| APIGateway
    MobileApp -.->|Offline Mode / BLE| LocalCache
    APIGateway --> CryptoService
    APIGateway --> NotificationEngine
    APIGateway --> AuditService
    APIGateway --> MySQL
```

---

## 👥 The 6 Institutional Roles

| Role | Primary Interface | Key Capabilities |
| :--- | :--- | :--- |
| **Student** | [Flutter App](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/frontend/lib/student) | Digital Wallet (Passport, Student ID, Gate Pass, Fees, Documents), BLE/QR attendance check-in, Hostel leave filing, Grievance tracking, Mess menu & ratings, Academic update feed. |
| **Teacher** | [Flutter App](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/frontend/lib/teacher) | BLE beacon broadcast session, dynamic QR code fallback attendance, batch attendance sync, class schedule broadcasts, student attendance analytics. |
| **Hostel Warden** | [Flutter App](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/frontend/lib/warden) | Real-time leave approvals/rejections, automated gate pass trigger, hostel asset defect triage, room allocation inspector, visitor approval. |
| **Gate Security** | [Flutter App](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/frontend/lib/security) | High-speed QR scanner for HMAC gate passes and visitor passes, exit/entry transit timestamps, anti-passback replay blocker, offline verification. |
| **Mess Staff** | [Flutter App](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/frontend/lib/mess) | Rotating dynamic QR meal scanner, duplicate dining prevention (HTTP 409), weekly menu publisher, meal feedback analytics. |
| **Administrator / Dean** | [React Admin Web](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/admin-web/src) & [Mobile Admin](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/frontend/lib/admin) | Central command console: 17 feature modules, system metrics, complaints SLA ageing (>48h), recurring complaint clustering, scoped circulars, fee tracking. |

---

## 📁 Repository Structure

```
CampusOS-1.0.0/
├── backend/                       # Python Flask Modular Monolith API
│   ├── app.py                     # Application factory & composition root
│   ├── config.py                  # Configuration loader (.env, MySQL, JWT, Keys)
│   ├── extensions.py              # Shared SQLAlchemy, Firebase Admin instances
│   ├── run.py                     # Local backend execution entrypoint
│   ├── models/                    # 27 SQLAlchemy domain models
│   ├── routes/                    # 19 Flask route blueprints
│   ├── services/                  # Domain services (notices, clustering, passport)
│   ├── middleware/                # RBAC and JWT token authorization
│   ├── utils/                     # Cryptographic utilities (Ed25519, HMAC)
│   ├── seed_test_data.py          # Relational test data seeder for all 6 roles
│   └── run_all_backend_tests.py   # Test runner executing all 22 test suites
│
├── frontend/                      # Flutter 3.x Mobile & Web Application
│   ├── lib/
│   │   ├── main.dart              # Application entrypoint & multi-role initialization
│   │   ├── core/                  # Localization (en, hi, or, bn), themes, haptics
│   │   ├── student/               # Student shell, wallet carousel, requests, feed
│   │   ├── teacher/               # Teacher shell, attendance broadcaster, reports
│   │   ├── warden/                # Warden shell, leave triage, hostel assets
│   │   ├── mess/                  # Mess staff shell, meal scanner, menu editor
│   │   ├── security/              # Security shell, gate scanner, visitor check-in
│   │   ├── admin/                 # Admin mobile dashboard & quick controls
│   │   ├── shared/                # Cross-role components, notices, search dialogs
│   │   └── router/                # Deep linking & route navigation definitions
│   └── test/                      # 439 Flutter unit and widget tests
│
├── admin-web/                     # React 19 + TypeScript + Vite Admin Web Console
│   ├── src/
│   │   ├── features/              # 17 Feature modules (Dashboard, Grievances, etc.)
│   │   ├── components/            # Reusable UI components (Radix + Tailwind)
│   │   ├── services/              # API client & backend service bridges
│   │   └── types/                 # TypeScript type definitions
│   └── vite.config.ts             # Vite bundler configuration
│
└── docs/                          # Comprehensive System Documentation
    ├── CAMPUSOS_COMPLETE_DOCUMENTATION.md   # Complete 1,400+ line master spec
    ├── CAMPUSOS_BACKEND_DEPLOYMENT_RUNBOOK.md # Production deployment runbook
    ├── passport_1d_dynamic_qr.md            # Dynamic QR cryptographic specs
    ├── passport_1e_qr_verifier.md          # Offline QR verifier engine
    └── passport_1f_offline_verification.md  # Trust bundle synchronization
```

---

## ⚡ Quickstart Guide

### 1. Prerequisites
- **Python**: 3.10+ (with `pip` and virtual environment)
- **Node.js**: 18+ (with `npm`)
- **Flutter SDK**: 3.19+ (with Dart 3.0+)
- **MySQL**: 8.0+ running locally or remotely

---

### 2. Backend Setup ([backend/](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/backend))

1. Navigate to the backend directory:
   ```bash
   cd backend
   ```
2. Create and activate a Python virtual environment:
   ```bash
   python -m venv venv
   # Windows PowerShell:
   .\venv\Scripts\Activate.ps1
   # macOS/Linux:
   source venv/bin/activate
   ```
3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
4. Configure environment variables in [backend/.env](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/backend/.env):
   ```ini
   DATABASE_URL=mysql+pymysql://root:password@localhost/attentify
   GATE_PASS_SECRET=campusos_gate_super_secret_key_2026
   PASSPORT_INSTITUTION_KEY_ID=campusos-root-2026-v1
   PASSPORT_INSTITUTION_PRIVATE_KEY=your_base64_ed25519_private_key
   JWT_SECRET=campusos_jwt_sec_8f9c2d1b4e053a6f1d2e4c8b7a9f0e3d
   PORT=5000
   FLASK_DEBUG=false
   ```
5. Seed database with deterministic multi-role accounts:
   ```bash
   python seed_test_data.py --reset --verify
   ```
6. Start the API server:
   ```bash
   python run.py
   # Server runs at http://localhost:5000
   ```

---

### 3. Frontend Mobile Setup ([frontend/](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/frontend))

1. Navigate to the frontend directory:
   ```bash
   cd frontend
   ```
2. Fetch Flutter packages:
   ```bash
   flutter pub get
   ```
3. Run code generation (Drift SQLite models):
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```
4. Run the application:
   ```bash
   # Run on connected Android / iOS device:
   flutter run

   # Or run on Chrome for testing:
   flutter run -d chrome
   ```

---

### 4. Admin Web Setup ([admin-web/](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/admin-web))

1. Navigate to the admin web directory:
   ```bash
   cd admin-web
   ```
2. Install Node dependencies:
   ```bash
   npm install
   ```
3. Launch the development server:
   ```bash
   npm run dev
   # Vite development server runs at http://localhost:5173
   ```
4. Build for production:
   ```bash
   npm run build
   ```

---

## 🔑 Pre-Seeded Test Credentials

Use these verified accounts created by [seed_test_data.py](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/backend/seed_test_data.py):

| Role | Email | Password | Primary Experience |
| :--- | :--- | :--- | :--- |
| **System Admin / Dean** | `admin@campusos.edu` | `Admin@1234` | Full Admin Web control plane & Mobile Admin |
| **Faculty / Teacher** | `teacher@campusos.edu` | `Teacher@1234` | Teacher Mobile App (Attendance & Broadcasts) |
| **Student** | `student@campusos.edu` | `Student@1234` | Student Mobile App (Wallet, Passport, Requests) |
| **Hostel Warden** | `warden@campusos.edu` | `Warden@1234` | Warden Mobile App (Leave & Hostel Triage) |
| **Mess Staff** | `mess@campusos.edu` | `Mess@1234` | Mess Mobile App (Dining QR Verification) |
| **Security Guard** | `security@campusos.edu` | `Security@1234` | Gate Security Mobile App (Pass Scanner) |

---

## 🧪 Automated Testing & Verification

CampusOS includes comprehensive test harnesses across both the backend and frontend.

### Backend Test Suites (22 Suites)
Execute all backend integration, security attack, and cryptographic tests:
```bash
python backend/run_all_backend_tests.py
```
Key backend test suites:
- [test_phase6_security_attacks.py](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/backend/test_phase6_security_attacks.py): 41 live security penetration checks (SQL injection, JWT forgery, replay attacks, privilege escalation).
- [test_gate_security.py](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/backend/test_gate_security.py): HMAC-SHA256 signature validation, anti-passback rules, grace periods.
- [test_step1c_passport_identity.py](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/backend/test_step1c_passport_identity.py): Ed25519 identity generation and device binding.
- [test_mess_staff_verification.py](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/backend/test_mess_staff_verification.py): Meal verification and duplicate meal prevention (HTTP 409).
- [test_cross_role_e2e.py](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/backend/test_cross_role_e2e.py): End-to-end multi-role leave-to-gate pass workflow.

### Frontend Test Suites (439 Tests)
Execute all Flutter unit, provider, and widget tests:
```bash
cd frontend
flutter test
```

---

## 🔐 Cryptography & Offline Security Highlights

1. **CampusOS Passport (Ed25519)**:
   - Each student generates a device-bound 32-byte Ed25519 keypair during onboarding.
   - Dynamic presentation QR codes expire every 30 seconds and contain a cryptographic signature over `[UUID, Nonce, Timestamp]`.
   - Verifiers validate signatures offline against pre-cached institutional trust bundles.
2. **Gate Pass HMAC-SHA256**:
   - Warden approval triggers server-side generation of a signed pass token.
   - Guards scan the barcode to verify institutional signature without needing continuous internet connectivity.
3. **Anti-Replay Nonces**:
   - Duplicate meal scans or attendance checks with consumed nonces fail immediately with `HTTP 409 Conflict`.

---

## 📚 Deep-Dive Documentation Links

For comprehensive engineering specifications, deployment guides, and design rationale, refer to:
- 📖 [Complete Product, Architecture & Mesh Spec](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/docs/CAMPUSOS_COMPLETE_DOCUMENTATION.md): 45-chapter master specification covering all domain flows, decentralized BLE mesh (Phases M1–M7), database schemas, 41 security penetration checks, and performance budgets.
- 📡 [BLE Mesh & Academic AirDrop Specification](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/docs/CAMPUSOS_MESH_COMPLETE_SPECIFICATION.md): Deep-dive into zero-infrastructure BLE ad-hoc relaying, LocalSend Wi-Fi AirDrop, and disaster flare emergency sirens.
- 🚀 [Backend Deployment Runbook](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/docs/CAMPUSOS_BACKEND_DEPLOYMENT_RUNBOOK.md): Step-by-step production setup, systemd service configuration, Nginx reverse proxy, and MySQL hardening.
- 📱 [Frontend Architecture Guide](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/frontend/README.md): Detailed mobile app documentation.
- 💻 [Admin Web Console Guide](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/admin-web/README.md): Desktop web application module architecture.
- ⚙️ [Backend Services & API Catalog](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/backend/README.md): Complete catalog of 19 Blueprints and database schema.
- 📄 [Precompiled Documentation PDF](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/CampusOS_Complete_Product_and_Implementation_Documentation.pdf) (1.5 MB print-ready PDF) & [Runbook PDF](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/CampusOS_Backend_Deployment_Runbook.pdf).
- 🎯 [Official Master Pitch Deck (PDF)](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/CampusOS_Pitch_Deck.pdf) (Print-ready 16:9 widescreen presentation deck, 20 slides), [Pitch Deck Markdown Spec](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/docs/CAMPUSOS_PITCH_DECK.md) & [Interactive Presentation HTML](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/docs/CAMPUSOS_PITCH_DECK.html).


