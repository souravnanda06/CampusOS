# CampusOS: Institutional Campus Operating System

[![System Status](https://img.shields.io/badge/System-Operational-emerald?style=flat-square)](file:///d:/DEVLOPEMENT/CampusOS-1.0.0)
[![BPUT Hackathon 2026](https://img.shields.io/badge/Hackathon-BPUT%20PS07-blue?style=flat-square)](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/docs/CAMPUSOS_COMPLETE_DOCUMENTATION.md)
[![License](https://img.shields.io/badge/License-Proprietary%20%2F%20Institutional-orange?style=flat-square)](file:///d:/DEVLOPEMENT/CampusOS-1.0.0)
[![Backend](https://img.shields.io/badge/Backend-Flask%20%7C%20SQLAlchemy%20%7C%20MySQL%208-blue?style=flat-square)](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/backend)
[![Frontend Mobile](https://img.shields.io/badge/Mobile-Flutter%203.x%20%7C%20Dart%203-02569B?style=flat-square)](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/frontend)
[![Admin Web](https://img.shields.io/badge/Admin%20Web-React%2019%20%7C%20Vite%20%7C%20Tailwind-61DAFB?style=flat-square)](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/admin-web)
[![WhatsApp Gateway](https://img.shields.io/badge/WhatsApp-Baileys%20%7C%20Node.js-25D366?style=flat-square)](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/whatsapp_gateway)
[![Offline Mesh](https://img.shields.io/badge/Mesh-BLE%20GATT%20%7C%20Multi--hop-8A2BE2?style=flat-square)](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/frontend/lib/core/mesh)

**CampusOS** is a comprehensive, offline-resilient, multi-role digital operating platform engineered for universities, engineering colleges, and technical campuses. It replaces disconnected paper registers, vulnerable roll calls, insecure paper gate passes, and informal communication channels with an integrated institutional operating system.

Originally developed for the **BPUT Hackathon 2026 (Problem Statement PS07)**, CampusOS connects all six institutional stakeholders—**Students**, **Teachers**, **Hostel Wardens**, **System Administrators / Deans**, **Mess Staff**, and **Gate Security Guards**—around an authoritative MySQL/SQLite data layer, device-bound Ed25519 cryptographic identities ([CampusOS Passport](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/backend/routes/passport.py)), decentralized BLE mesh networking, and AI-powered intelligence.

---

## 🌟 Key Highlights & Innovative Capabilities

1. **🔐 CampusOS Passport (Cryptographic Digital Identity)**:
   - Device-bound Ed25519 public-key cryptography with on-device keypair generation.
   - Dynamic 30-second rotating presentation QR codes signed over `[student_uuid, nonce, timestamp]`.
   - Complete offline verifiability via pre-cached institutional public keys and anti-replay nonce tracking.
   - Dual-engine Face Authentication (Local MLKit on-device processing + server-side face embeddings).

2. **📡 Zero-BLE & Hybrid Smart Attendance**:
   - Zero-BLE multi-hop relaying and dynamic QR rotation.
   - Classroom Wi-Fi / Hotspot proximity fallback when Bluetooth is unavailable or disabled.
   - Fraud prevention with device hardware telemetry, anti-spoofing challenge-response, and tamper-resistant audit logs.

3. **💬 Off-Grid Campus BLE Mesh Chat**:
   - Decentralized, serverless peer-to-peer messaging via Bluetooth Low Energy GATT and ad-hoc multi-hop flooding.
   - Multi-channel support (Emergency, Campus Broadcast, Hostel, Batch).
   - Autonomous device-to-backend bi-directional sync whenever a mesh node reconnects to campus Wi-Fi or cellular networks.
   - Integrated offline profanity and harassment content moderation filters.

4. **📲 Institutional WhatsApp Gateway**:
   - Built on Baileys Node.js microservice (`whatsapp_gateway/`) and Dockerized OpenWA architecture.
   - Automated interactive notification delivery (daily attendance alerts, mess menu updates, emergency broadcasts, gate pass alerts, fee dues).
   - Inbound query responder for students and parents (e.g., balance check, attendance percentage, today's menu).

5. **🤖 CampusOS Copilot (AI-Powered Administrative Intelligence)**:
   - Floating AI assistant available on Flutter mobile and React 19 Admin Web.
   - Natural language queries across institutional records: student fee status, attendance analytics, room availability, leave approvals.
   - Intelligent automated routing and smart summarization of grievances and circulars.

6. **💼 Career Hub & ATS Resume Studio**:
   - Student smart profiles, skill tagging, and automated portfolio builder.
   - Built-in ATS-grade resume parsing and scoring against campus placement drives.
   - Placement coordinator dashboard for publishing job drives, shortlisting candidates, and tracking applications.

7. **🚨 SOS & Campus Emergency Siren System**:
   - Native hardware siren alarm (`EmergencySirenEngine.kt`) triggered with Apple-grade continuous gestures.
   - Immediate broadcast across local BLE mesh nodes and instant push notification dispatch to Campus Security and Hostel Wardens.

---

## 🏛️ System Architecture

```mermaid
graph TD
    subgraph Clients["Client Tier"]
        MobileApp["📱 Flutter Mobile App<br/>(Student, Teacher, Warden, Mess, Security, Admin)<br/>iOS / Android / Web"]
        AdminWeb["💻 React 19 Admin Console<br/>(Deans & Central Administration)<br/>Vite + TypeScript + Tailwind"]
    end

    subgraph MeshTier["Decentralized Edge Tier"]
        BLEMesh["📡 BLE GATT Mesh Network<br/>Peer-to-Peer Multi-hop Relaying"]
        LocalCache["📱 Drift / Local SQLite<br/>Offline Trust Bundles & Pending Sync Queues"]
    end

    subgraph Gateways["Ingress & Notification Tier"]
        APIGateway["🌐 REST API Gateway (Port 5000)<br/>Flask + CORS + JWT/RBAC Middleware"]
        WAGateway["📲 WhatsApp Service Gateway (Port 3001)<br/>Node.js + Baileys WebSocket"]
    end

    subgraph CoreServices["Backend Application Tier (Flask Modular Monolith)"]
        CryptoService["🔐 Cryptographic Engine<br/>Ed25519 Passports + HMAC Gate Passes"]
        CopilotService["🤖 CampusOS Copilot<br/>LLM Multi-turn Tools & Insights Engine"]
        ATSPlacement["💼 Career & ATS Engine<br/>Placement Pipeline & Resume Matcher"]
        NotificationEngine["🔔 Notification Engine<br/>FCM + WhatsApp + SMS Fallback"]
        AuditService["📜 Immutable Audit Trail<br/>request_audits & Status History"]
    end

    subgraph DataStorage["Persistence Tier"]
        MySQL[(🗄️ MySQL 8 Database<br/>Normalized Multi-Role Schema)]
    end

    MobileApp -->|HTTPS / JWT Bearer| APIGateway
    AdminWeb -->|HTTPS / JWT Bearer| APIGateway
    MobileApp <-->|Off-Grid P2P| BLEMesh
    MobileApp <-->|Read / Write| LocalCache
    APIGateway <-->|Webhook / REST| WAGateway
    APIGateway --> CryptoService
    APIGateway --> CopilotService
    APIGateway --> ATSPlacement
    APIGateway --> NotificationEngine
    APIGateway --> AuditService
    APIGateway --> MySQL
```

---

## 👥 The 6 Institutional Roles

| Role | Primary Interface | Key Capabilities |
| :--- | :--- | :--- |
| **Student** | [Flutter App](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/frontend/lib/student) | Digital Wallet (Campus Passport, Student ID, Gate Pass, Fee Receipts), BLE/QR attendance check-in, Hostel leave filing, Grievance tracking, Mess menu & dining feedback, Academic feed, Career Hub & ATS resume matcher, BLE Mesh Chat, SOS Emergency Siren. |
| **Teacher** | [Flutter App](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/frontend/lib/teacher) | BLE beacon session broadcasting, Dynamic QR code attendance fallback, Batch attendance synchronization, Real-time roster analytics, Class announcements, Course update publishing. |
| **Hostel Warden** | [Flutter App](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/frontend/lib/warden) | Real-time leave approvals/rejections with automated Gate Pass generation, Hostel asset defect triage, Room allocation inspector, Visitor approval, Curfew monitoring. |
| **Gate Security** | [Flutter App](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/frontend/lib/security) | High-speed QR scanner for HMAC gate passes and visitor passes, Instant anti-passback replay blocker, Transit timestamp logger, Offline pass validation. |
| **Mess Staff** | [Flutter App](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/frontend/lib/mess) | Rotating dynamic QR meal scanner, Duplicate dining attempt blocker (`HTTP 409 Conflict`), Weekly menu manager, Meal quality feedback ratings dashboard. |
| **Administrator / Dean** | [React Admin Web](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/admin-web/src) & [Mobile Admin](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/frontend/lib/admin) | Central command console: 17 feature modules, System KPIs, Grievance SLA tracking (>48h ageing), Recurring complaint AI clustering, Scoped circulars, Fee tracking, User onboarding, Copilot AI operations. |

---

## 📁 Repository Structure

```
CampusOS-1.0.0/
├── backend/                       # Python Flask Modular Monolith API
│   ├── app.py                     # Application factory & composition root
│   ├── config.py                  # Configuration loader (.env, MySQL/SQLite, JWT, Keys)
│   ├── extensions.py              # Shared SQLAlchemy, Firebase Admin instances
│   ├── run.py                     # Local backend execution entrypoint
│   ├── models/                    # SQLAlchemy domain models (27+ tables)
│   ├── routes/                    # Flask route blueprints (Auth, Attendance, Copilot, Career, etc.)
│   ├── services/                  # Business logic (Passport, Copilot, Career ATS, WhatsApp, Mesh)
│   ├── middleware/                # RBAC and JWT token authorization
│   ├── utils/                     # Cryptographic utilities (Ed25519, HMAC-SHA256)
│   ├── seed_test_data.py          # Deterministic test data seeder for all 6 roles
│   └── run_all_backend_tests.py   # Master backend test suite executor
│
├── frontend/                      # Flutter 3.x Multi-Platform Mobile Application
│   ├── lib/
│   │   ├── main.dart              # Application entrypoint & multi-role initialization
│   │   ├── core/                  # Localization (en, hi, or, bn), themes, BLE GATT manager
│   │   │   └── mesh/              # Mesh chat sync, moderation filter, channels
│   │   ├── student/               # Student shell, wallet carousel, requests, career hub, emergency
│   │   ├── teacher/               # Teacher shell, attendance broadcaster, roster analytics
│   │   ├── warden/                # Warden shell, leave triage, hostel asset management
│   │   ├── mess/                  # Mess staff shell, meal scanner, menu publisher
│   │   ├── security/              # Security shell, gate scanner, visitor check-in
│   │   ├── admin/                 # Mobile admin dashboard & quick controls
│   │   └── shared/                # Copilot assistant sheet, animated dock, Cupertino/Apple motion
│   └── test/                      # 439+ Flutter unit, provider, and widget tests
│
├── admin-web/                     # React 19 + TypeScript + Vite Admin Web Console
│   ├── src/
│   │   ├── features/              # Feature modules (Dashboard, Grievances, Fees, Copilot, Career, etc.)
│   │   ├── components/            # Reusable UI components (Tailwind CSS + Lucide icons)
│   │   ├── services/              # API client & backend service bridges
│   │   └── types/                 # TypeScript type definitions
│   └── vite.config.ts             # Vite bundler configuration
│
├── whatsapp_gateway/              # Lightweight Baileys-based WhatsApp Gateway Microservice
│   ├── server.js                  # Express.js REST server & WhatsApp connection manager
│   ├── package.json               # Node.js dependencies (@whiskeysockets/baileys, etc.)
│   └── README.md                  # WhatsApp Gateway setup and webhook instructions
│
└── docs/                          # Comprehensive System Documentation & PDF Explanations
    ├── CAMPUSOS_COMPLETE_DOCUMENTATION.md             # 1,400+ line master specification
    ├── CAMPUSOS_BACKEND_DEPLOYMENT_RUNBOOK.md           # Production deployment runbook
    ├── CAMPUSOS_CORE_FEATURES_SPECIFICATION.md          # Complete functional specification
    ├── CAMPUSOS_HYBRID_ATTENDANCE_EXPLAINER.md          # Zero-BLE & Hybrid attendance design
    ├── CAMPUSOS_MESH_CHAT_AND_BLE_ATTENDANCE_DOCUMENTATION.md # BLE Mesh chat & attendance protocol
    ├── CampusOS_Core_Features_Specification.pdf         # Print-ready architectural PDF
    └── CampusOS_Mesh_Chat_and_BLE_Attendance_Documentation.pdf # BLE Mesh documentation PDF
```

---

## ⚡ Quickstart Guide

### 1. Prerequisites
- **Python**: 3.10+ (with `pip` and virtual environment support)
- **Node.js**: 18+ (with `npm`)
- **Flutter SDK**: 3.19+ (with Dart 3.0+)
- **MySQL**: 8.0+ (optional; SQLite fallback enabled for rapid local testing)

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
   DATABASE_URL=mysql+pymysql://root:password@localhost/campusos
   # Or use SQLite for rapid local testing:
   # DATABASE_URL=sqlite:///app.db

   JWT_SECRET=campusos_jwt_sec_8f9c2d1b4e053a6f1d2e4c8b7a9f0e3d
   GATE_PASS_SECRET=campusos_gate_super_secret_key_2026
   PASSPORT_INSTITUTION_KEY_ID=campusos-root-2026-v1
   PASSPORT_INSTITUTION_PRIVATE_KEY=your_base64_ed25519_private_key
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
3. Run code generation (Drift SQLite / Riverpod models if modified):
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```
4. Run the application:
   ```bash
   # Run on connected physical Android/iOS device or emulator:
   flutter run

   # Or run in Chrome browser:
   flutter run -d chrome
   ```

---

### 4. Admin Web Console Setup ([admin-web/](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/admin-web))

1. Navigate to the admin web directory:
   ```bash
   cd admin-web
   ```
2. Install dependencies:
   ```bash
   npm install
   ```
3. Launch the development server:
   ```bash
   npm run dev
   # Console runs at http://localhost:5173
   ```
4. Compile for production deployment:
   ```bash
   npm run build
   ```

---

### 5. WhatsApp Gateway Microservice Setup ([whatsapp_gateway/](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/whatsapp_gateway))

1. Navigate to the microservice directory:
   ```bash
   cd whatsapp_gateway
   ```
2. Install dependencies:
   ```bash
   npm install
   ```
3. Start the gateway service:
   ```bash
   npm start
   # Service listens at http://localhost:3001
   ```
4. Scan the terminal QR code using WhatsApp on an institutional phone to pair the session.

---

## 🔑 Pre-Seeded Test Credentials

Use these verified accounts created by [seed_test_data.py](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/backend/seed_test_data.py):

| Role | Email | Password | Primary Experience |
| :--- | :--- | :--- | :--- |
| **System Admin / Dean** | `admin@campusos.edu` | `Admin@1234` | Full Admin Web control plane & Mobile Admin |
| **Faculty / Teacher** | `teacher@campusos.edu` | `Teacher@1234` | Teacher Mobile App (Attendance & Broadcasts) |
| **Student** | `student@campusos.edu` | `Student@1234` | Student Mobile App (Wallet, Passport, Requests, Career) |
| **Hostel Warden** | `warden@campusos.edu` | `Warden@1234` | Warden Mobile App (Leave & Hostel Triage) |
| **Mess Staff** | `mess@campusos.edu` | `Mess@1234` | Mess Mobile App (Dining QR Verification) |
| **Security Guard** | `security@campusos.edu` | `Security@1234` | Gate Security Mobile App (Pass Scanner) |

---

## 🧪 Automated Testing & Verification

CampusOS includes end-to-end automated test coverage across both backend APIs and Flutter client interfaces.

### Backend Automated Test Suites
Run the comprehensive backend test runner:
```bash
python backend/run_all_backend_tests.py
```
Key backend test suites:
- `test_cross_role_e2e.py`: Complete multi-role leave-to-gate pass lifecycle.
- `test_gate_security.py`: HMAC-SHA256 signature validation, anti-passback rules, and grace periods.
- `test_step1c_passport_identity.py`: Ed25519 identity generation and device binding.
- `test_career_placement.py`: ATS resume parsing, skill matching, and job application pipeline.
- `test_mesh_chat_sync.py`: Offline message queue reconciliation and sync idempotency.
- `test_whatsapp_integration.py`: Outbound notification queue and inbound message handler.

### Frontend Flutter Test Suites (439+ Tests)
Run all Flutter widget, provider, and unit tests:
```bash
cd frontend
flutter test
```
Key Flutter test suites:
- `test/student/passport_zero_ble_hybrid_attendance_test.dart`: Zero-BLE and Wi-Fi proximity fallbacks.
- `test/mesh/mesh_chat_test.dart`: Mesh GATT packet handling and offline message storage.
- `test/shared/copilot_widget_test.dart`: Floating AI assistant conversation and tool invocation.
- `test/student/career_hub_screen_test.dart`: Career Hub, ATS score displays, and job filtering.
- `test/student/face_auth_apple_design_test.dart`: Face ID viewfinder UI and biometric state transitions.

---

## 📚 Deep-Dive Technical Documentation

For detailed architectural diagrams, protocol definitions, and deployment guides:

- 📖 [Complete Product & Architecture Master Spec](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/docs/CAMPUSOS_COMPLETE_DOCUMENTATION.md): Complete 45-chapter architectural guide.
- 📱 [CampusOS Core Features Specification](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/docs/CAMPUSOS_CORE_FEATURES_SPECIFICATION.md): Feature breakdown across all 6 roles.
- 📡 [Hybrid Attendance Architecture Guide](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/docs/CAMPUSOS_HYBRID_ATTENDANCE_EXPLAINER.md): Zero-BLE, BLE GATT, and Wi-Fi fallback mechanisms.
- 💬 [BLE Mesh Chat & Attendance Documentation](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/docs/CAMPUSOS_MESH_CHAT_AND_BLE_ATTENDANCE_DOCUMENTATION.md): Deep-dive into decentralized mesh protocols.
- 🚀 [Backend Deployment Runbook](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/docs/CAMPUSOS_BACKEND_DEPLOYMENT_RUNBOOK.md): Systemd, Nginx, SSL, and MySQL production configuration.
- 📄 [Print-Ready Documentation PDFs](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/docs/):
  - [CampusOS_Core_Features_Specification.pdf](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/docs/CampusOS_Core_Features_Specification.pdf)
  - [CampusOS_Mesh_Chat_and_BLE_Attendance_Documentation.pdf](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/docs/CampusOS_Mesh_Chat_and_BLE_Attendance_Documentation.pdf)
