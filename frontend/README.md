# CampusOS Mobile: Multi-Role Flutter Client

[![Flutter Version](https://img.shields.io/badge/Flutter-3.19%2B-blue?style=flat-square)](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/frontend/pubspec.yaml)
[![Platforms](https://img.shields.io/badge/Platforms-Android%20%7C%20iOS%20%7C%20Web-orange?style=flat-square)](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/frontend)
[![Tests Passing](https://img.shields.io/badge/Flutter%20Tests-439%20Passing-success?style=flat-square)](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/frontend/test)
[![Localization](https://img.shields.io/badge/Languages-EN%20%7C%20HI%20%7C%20OR%20%7C%20BN-emerald?style=flat-square)](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/frontend/lib/core/localization)

The **CampusOS Mobile App** is a unified, multi-role client application developed with Flutter. It provides role-tailored digital shells for all campus stakeholders—**Students**, **Teachers**, **Hostel Wardens**, **Mess Staff**, **Security Guards**, and **System Administrators**—within a single codebase.

---

## 📱 Role Experiences & Core Features

### 1. Student Experience ([lib/student/](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/frontend/lib/student))
- **Campus Wallet Carousel**: Interactive satin-finished card carousel featuring:
  1. *Campus Passport*: Biometrically unlocked Ed25519 digital identity with a 30-second rotating cryptographic QR code.
  2. *Student Institutional ID*: Official registration card with department and emergency details.
  3. *Gate Pass*: Real-time countdown timer, valid window indicators, and offline HMAC barcode.
  4. *Academic Documents*: Quick preview and document viewer sheet for certificates.
  5. *Fees & Dues*: Balance breakdown, due dates, and fee receipts.
  6. *Visitor Pass*: Dynamically displayed upon approval of external guest visits.
- **Attendance Check-In**: BLE background scanning and camera-based dynamic QR fallback.
- **Hostel Leave & Passes**: Instant leave filing, status tracker, and gate pass presentation.
- **Dining Portal**: Daily nutrition, weekly menu schedules, and meal rating feedback.
- **Grievance Triage**: Maintenance defect submissions with real-time audit trail updates.
- **Academic Updates**: Instant classroom shifts and notice broadcasts with swipe-to-dismiss.

### 2. Teacher Experience ([lib/teacher/](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/frontend/lib/teacher))
- **BLE Attendance Broadcasting**: Initiates Bluetooth Low Energy sessions broadcasting classroom tokens.
- **Dynamic QR Fallback**: High-visibility animated QR code for students without functioning BLE hardware.
- **Batch Attendance Sync**: Prevents lost records during spotty campus connectivity.
- **Classroom Shifts**: Instant academic circular broadcast to enrolled student cohorts.

### 3. Hostel Warden Experience ([lib/warden/](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/frontend/lib/warden))
- **Leave Request Inbox**: Fast-action triage inbox to approve or reject student leave requests.
- **Automated Gate Pass Issuance**: Approving a leave automatically generates an HMAC gate pass.
- **Hostel Defect Inspection**: Room asset management, maintenance issues, and room allocations.
- **Visitor Review**: Pre-screen and approve campus visitor requests.

### 4. Gate Security Experience ([lib/security/](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/frontend/lib/security))
- **High-Speed QR Scanner**: Scans student gate passes and visitor passes in under 300ms.
- **Cryptographic Offline Verification**: Validates HMAC-SHA256 signatures locally.
- **Anti-Passback & Replay Defense**: Blocks duplicate entry/exit attempts and enforces 30-minute grace windows.
- **Real-Time Transit Log**: Live feed of departures and returns with timestamps.

### 5. Mess Staff Experience ([lib/mess/](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/frontend/lib/mess))
- **Dining Entry Scanner**: Scans rotating student Passport QR codes to grant dining access.
- **Duplicate Meal Blocker**: Real-time rejection of duplicate meals within the same meal window.
- **Menu Management**: Weekly meal schedule publisher with calorie and allergen tags.
- **Feedback Analytics**: Live rating metrics and sentiment curves from diners.

### 6. Mobile Admin Experience ([lib/admin/](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/frontend/lib/admin))
- Mobile control dashboard for rapid response to critical campus events.
- Broadcast emergency announcements with scoped target audiences.
- Monitor active campus metrics and grievance ageing flags.

---

## 📂 Project Architecture

```
frontend/lib/
├── main.dart                   # Application entrypoint & initialization
│
├── core/                       # Core Foundation Modules
│   ├── theme/                  # Institutional color system & card elevations
│   ├── localization/           # Translations for English, Hindi, Odia, Bengali
│   ├── performance/            # Adaptive frame-rate engine (60Hz/120Hz budgets)
│   ├── security/               # Local biometrics & secure key storage
│   └── haptics/                # Tactile feedback helpers
│
├── data/                       # Local Storage & Network Layer
│   ├── local/                  # Drift SQLite database & DAOs
│   ├── models/                 # Dart domain data classes
│   └── repositories/           # Repositories bridging API & local cache
│
├── router/                     # Navigation & Route Routing
│   └── app_router.dart         # Role-based route guards and transitions
│
├── student/                    # Student feature screens & widgets
├── teacher/                    # Teacher feature screens & attendance broadcaster
├── warden/                     # Warden feature screens & leave inbox
├── mess/                       # Mess staff feature screens & meal verifiers
├── security/                   # Gate security feature screens & pass scanners
├── admin/                      # Admin mobile telemetry & management
└── shared/                     # Shared widgets, notices modal, and search dialog
```

---

## 🌐 Multilingual & Accessibility Support

CampusOS Mobile is engineered for full institutional inclusivity:
- **Languages**: 
  - English (`en`)
  - Hindi (`hi`)
  - Odia (`or`)
  - Bengali (`bn`)
- **Accessibility**:
  - Touch target sizes conform to `≥ 48dp` minimums.
  - Text scales cleanly up to `1.5x` without layout clipping.
  - High-contrast visual tokens ensuring readability in outdoor sunlight.

---

## ⚡ Adaptive Performance Engine

- **Frame Budget Awareness**: Dynamically monitors frame drop intervals.
- **Display Optimization**: Automatically adapts rendering workloads to support high-refresh-rate displays (90Hz / 120Hz).
- **Repaint Boundaries**: Critical high-frequency animated elements (e.g., wallet carousel, QR timers) are wrapped in `RepaintBoundary` to prevent layout thrashing.

---

## 🚀 Getting Started

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Run Code Generation (Drift Database)
```bash
dart run build_runner build --delete-conflicting-outputs
```

### 3. Run the App
- **Connect an Android or iOS device** or launch an emulator.
- Launch in debug mode:
  ```bash
  flutter run
  ```
- Or launch on Google Chrome for quick web preview:
  ```bash
  flutter run -d chrome
  ```

---

## 🧪 Testing

The mobile application is thoroughly verified by 439 unit and widget tests:

```bash
# Run all tests:
flutter test

# Run specific suite:
flutter test test/student_wallet_test.dart
flutter test test/localization_test.dart
```
