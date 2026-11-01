# CampusOS Admin Web: Central Administrative Control Plane

[![React 19](https://img.shields.io/badge/React-19.2-blue?style=flat-square)](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/admin-web/package.json)
[![Vite](https://img.shields.io/badge/Bundler-Vite%208-purple?style=flat-square)](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/admin-web/vite.config.ts)
[![TypeScript](https://img.shields.io/badge/TypeScript-6.0-blue?style=flat-square)](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/admin-web/tsconfig.json)
[![Tailwind CSS](https://img.shields.io/badge/Styling-Tailwind%20CSS-teal?style=flat-square)](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/admin-web/tailwind.config.js)
[![TanStack Query](https://img.shields.io/badge/State-TanStack%20Query%20v5-red?style=flat-square)](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/admin-web/package.json)

The **CampusOS Admin Web** application is a desktop-first institutional control plane designed for University Deans, Department Heads, System Administrators, and Campus Directors. It delivers real-time operational visibility, complaint triage, automated hostel asset auditing, and communication management across the entire campus.

---

## 🛠️ Technology Stack

- **Framework**: [React 19](https://react.dev) with [TypeScript](https://www.typescriptlang.org)
- **Bundler & Tooling**: [Vite 8](https://vitejs.dev) with Fast Refresh & Oxlint
- **UI Components & Icons**: [Radix UI Primitives](https://www.radix-ui.com), [Lucide React](https://lucide.dev)
- **Styling**: [Tailwind CSS 3.4](https://tailwindcss.com) with custom institutional design tokens
- **Data Management**: [TanStack Query v5](https://tanstack.com/query) for server-state caching
- **Data Tables**: [TanStack Table v8](https://tanstack.com/table) for high-performance sortable & filterable tables
- **Visual Analytics**: [Recharts v3](https://recharts.org) for real-time operational charts

---

## 🧩 Feature Modules (17 Active Domains)

Located in [admin-web/src/features/](file:///d:/DEVLOPEMENT/CampusOS-1.0.0/admin-web/src/features):

| Feature Module | Path | Operational Capabilities |
| :--- | :--- | :--- |
| **Dashboard** | `src/features/dashboard` | High-level KPI cards, live attendance averages, urgent grievance counter, gate transit rates. |
| **Complaints** | `src/features/complaints` | Grievance triage board, SLA ageing flags (>48h), status updates, recurrence clustering insights. |
| **Attendance** | `src/features/attendance` | Departmental attendance analytics, teacher broadcast sessions, proxy anomaly reports. |
| **Students** | `src/features/students` | Student registry, department filtering, profile status, and roll number lookup. |
| **Notices** | `src/features/notices` | Scoped broadcast circular composer (Student, Teacher, All), priority tags, delivery receipts. |
| **Gate Security** | `src/features/security` | Real-time entry/exit transit log, active off-campus student count, gate pass verification audit. |
| **Mess Dining** | `src/features/mess` | Weekly dining menu publisher, nutritional breakdowns, turnout vs. meal consumption trends. |
| **Hostel & Assets**| `src/features/hostel` | Room inventory inspection, bed allocations, asset maintenance backlogs. |
| **Documents** | `src/features/documents` | Degree and bonafide certificate verification, official issuance serials. |
| **Fees & Dues** | `src/features/fees` | Semester fee tracking, outstanding dues reports, transaction receipt verification. |
| **Visitors** | `src/features/visitors` | Guest visitor pre-clearance, check-in timestamps, and host student verification. |
| **Academic** | `src/features/academic` | Department course schedules, class shift circulars, and teacher assignments. |
| **Passport** | `src/features/passport` | Institutional root key status, public key trust bundle inspector, certificate revocation. |
| **Notifications** | `src/features/notifications` | Push notification delivery metrics and FCM broadcast monitoring. |
| **Audit Logs** | `src/features/audit` | Immutable log of all administrative actions and status mutations (`request_audits`). |
| **Search** | `src/features/search` | Quick omnibox search across students, staff, tickets, passes, and circulars. |
| **Auth** | `src/features/auth` | Administrator login, token refresh, and session management. |

---

## 📁 Project Structure

```
admin-web/
├── index.html                  # HTML entrypoint
├── vite.config.ts              # Vite configuration with React plugin
├── tailwind.config.js          # Institutional color palette & layout tokens
│
└── src/
    ├── main.tsx                # React DOM render entrypoint
    ├── App.tsx                 # Root router & layout container
    ├── index.css               # Global styling & Tailwind directives
    │
    ├── features/               # 17 Domain-specific feature modules
    ├── components/             # Reusable UI components (Modals, Tables, Cards, Inputs)
    ├── services/               # API clients communicating with Flask Backend
    ├── types/                  # Domain TypeScript interfaces
    └── lib/                    # Utility functions & formatting helpers
```

---

## ⚡ Development & Build Commands

### 1. Install Dependencies
```bash
npm install
```

### 2. Run Development Server
```bash
npm run dev
# Server accessible at http://localhost:5173
```

### 3. Production Build
```bash
npm run build
# Generates production assets in dist/
```

### 4. Code Linting
```bash
npm run lint
```

---

## 🔗 Backend Connectivity

The web console expects the CampusOS Flask backend running on `http://localhost:5000` (or the configured base URL). Ensure CORS headers allow administrative client origins.
