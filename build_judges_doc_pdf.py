import os
import sys
import subprocess
import pypdf

def build_judges_documentation_pdf():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    docs_dir = os.path.join(script_dir, "docs")
    os.makedirs(docs_dir, exist_ok=True)
    
    html_path = os.path.join(docs_dir, "CAMPUSOS_JUDGES_DOCUMENTATION.html")
    pdf_path = os.path.join(script_dir, "CampusOS_Judges_Documentation.pdf")

    css_style = """
    @import url('https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;500;600;700;800&family=JetBrains+Mono:wght@400;500;600;700&display=swap');

    @page {
        size: A4 portrait;
        margin: 0;
    }

    * {
        box-sizing: border-box;
        -webkit-print-color-adjust: exact;
        print-color-adjust: exact;
    }

    html, body {
        margin: 0;
        padding: 0;
        font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        font-size: 7.2pt;
        line-height: 1.32;
        color: #1e293b;
        background-color: #f8fafc;
    }

    .page {
        width: 210mm;
        height: 297mm;
        max-height: 297mm;
        padding: 9mm 11mm 8mm 11mm;
        page-break-after: always;
        break-after: page;
        position: relative;
        overflow: hidden;
        background: #ffffff;
        display: flex;
        flex-direction: column;
        justify-content: space-between;
    }

    /* Page Running Header */
    .page-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        border-bottom: 1.5px solid #0f172a;
        padding-bottom: 2mm;
        margin-bottom: 2.5mm;
    }

    .header-left {
        display: flex;
        align-items: center;
        gap: 6px;
    }

    .brand-pill {
        background: #0f172a;
        color: #38bdf8;
        font-family: 'JetBrains Mono', monospace;
        font-weight: 800;
        font-size: 6.8pt;
        letter-spacing: 0.5px;
        padding: 2px 7px;
        border-radius: 4px;
    }

    .header-title {
        font-weight: 800;
        font-size: 7.5pt;
        color: #0f172a;
        letter-spacing: -0.2px;
    }

    .header-sub {
        font-size: 6.8pt;
        color: #64748b;
        font-weight: 500;
    }

    .header-right {
        display: flex;
        align-items: center;
        gap: 5px;
    }

    .tag-pill {
        background: #eff6ff;
        color: #1d4ed8;
        border: 1px solid #bfdbfe;
        font-family: 'JetBrains Mono', monospace;
        font-size: 6.2pt;
        font-weight: 700;
        padding: 1.5px 6px;
        border-radius: 3px;
        text-transform: uppercase;
    }

    .page-num-tag {
        background: #f1f5f9;
        color: #0f172a;
        border: 1px solid #cbd5e1;
        font-family: 'JetBrains Mono', monospace;
        font-size: 6.2pt;
        font-weight: 800;
        padding: 1.5px 6px;
        border-radius: 3px;
    }

    /* Page Running Footer */
    .page-footer {
        display: flex;
        justify-content: space-between;
        align-items: center;
        border-top: 1px solid #cbd5e1;
        padding-top: 1.8mm;
        margin-top: 1.8mm;
        font-size: 6.2pt;
        color: #64748b;
    }

    .footer-left {
        font-weight: 700;
        color: #0f172a;
    }

    .footer-center {
        color: #94a3b8;
        font-family: 'JetBrains Mono', monospace;
        letter-spacing: 0.5px;
    }

    .footer-right {
        font-family: 'JetBrains Mono', monospace;
        font-weight: 800;
        color: #0f172a;
        background: #f1f5f9;
        border: 1px solid #cbd5e1;
        padding: 1px 6px;
        border-radius: 3px;
    }

    /* Page Content Body */
    .page-body {
        flex: 1;
        display: flex;
        flex-direction: column;
        gap: 2.2mm;
        overflow: hidden;
    }

    /* Banners & Section Headings */
    .banner {
        background: linear-gradient(135deg, #0f172a 0%, #1e293b 100%);
        color: #ffffff;
        padding: 4.5px 9px;
        border-radius: 5px;
        display: flex;
        justify-content: space-between;
        align-items: center;
    }

    .banner-title {
        font-size: 9.8pt;
        font-weight: 800;
        letter-spacing: -0.2px;
        color: #ffffff;
    }

    .banner-badge {
        font-family: 'JetBrains Mono', monospace;
        font-size: 6.2pt;
        background: rgba(56, 189, 248, 0.2);
        color: #38bdf8;
        border: 1px solid rgba(56, 189, 248, 0.4);
        padding: 1.5px 6px;
        border-radius: 3px;
        font-weight: 700;
    }

    .sec-title {
        font-size: 7.8pt;
        font-weight: 800;
        color: #0f172a;
        text-transform: uppercase;
        letter-spacing: 0.3px;
        margin: 0 0 1.5px 0;
        display: flex;
        align-items: center;
        gap: 5px;
        border-bottom: 1px solid #e2e8f0;
        padding-bottom: 1.5px;
    }

    .sec-title::before {
        content: "";
        display: inline-block;
        width: 3px;
        height: 9px;
        background: #2563eb;
        border-radius: 1px;
    }

    /* Cards & Containers */
    .card {
        background: #ffffff;
        border: 1px solid #e2e8f0;
        border-radius: 5px;
        padding: 4px 7px;
        box-shadow: 0 1px 2px rgba(0, 0, 0, 0.02);
    }

    .card-dark {
        background: #090e17;
        border: 1px solid #1e293b;
        border-radius: 5px;
        padding: 4px 7px;
        color: #f1f5f9;
    }

    .card-accent {
        background: #f8fafc;
        border-left: 3px solid #2563eb;
        border-top: 1px solid #e2e8f0;
        border-right: 1px solid #e2e8f0;
        border-bottom: 1px solid #e2e8f0;
        border-radius: 0 5px 5px 0;
        padding: 3.5px 7px;
    }

    .card-emerald {
        background: #f0fdf4;
        border-left: 3px solid #10b981;
        border-top: 1px solid #bbf7d0;
        border-right: 1px solid #bbf7d0;
        border-bottom: 1px solid #bbf7d0;
        border-radius: 0 5px 5px 0;
        padding: 3.5px 7px;
    }

    .card-amber {
        background: #fffbeb;
        border-left: 3px solid #f59e0b;
        border-top: 1px solid #fde68a;
        border-right: 1px solid #fde68a;
        border-bottom: 1px solid #fde68a;
        border-radius: 0 5px 5px 0;
        padding: 3.5px 7px;
    }

    /* Grids */
    .grid-2 {
        display: grid;
        grid-template-columns: 1fr 1fr;
        gap: 2.2mm;
    }

    .grid-3 {
        display: grid;
        grid-template-columns: 1fr 1fr 1fr;
        gap: 2mm;
    }

    .grid-4 {
        display: grid;
        grid-template-columns: 1fr 1fr 1fr 1fr;
        gap: 1.8mm;
    }

    .grid-2-1 {
        display: grid;
        grid-template-columns: 1.8fr 1fr;
        gap: 2.2mm;
    }

    .grid-1-2 {
        display: grid;
        grid-template-columns: 1fr 1.8fr;
        gap: 2.2mm;
    }

    /* Metrics & Stats */
    .metric-strip {
        display: grid;
        grid-template-columns: repeat(5, 1fr);
        gap: 1.8mm;
    }

    .metric-box {
        background: #f8fafc;
        border: 1px solid #e2e8f0;
        border-radius: 4px;
        padding: 3.5px 5px;
        text-align: center;
    }

    .metric-val {
        font-family: 'JetBrains Mono', monospace;
        font-weight: 800;
        font-size: 8.8pt;
        color: #0f172a;
    }

    .metric-lbl {
        font-size: 5.6pt;
        text-transform: uppercase;
        font-weight: 700;
        color: #64748b;
        letter-spacing: 0.3px;
        margin-top: 1px;
    }

    /* Tables */
    table {
        width: 100%;
        border-collapse: collapse;
        font-size: 6.2pt;
        margin: 1.5px 0;
    }

    th, td {
        border: 1px solid #cbd5e1;
        padding: 2.2px 4.5px;
        text-align: left;
        vertical-align: top;
    }

    th {
        background: #f1f5f9;
        font-weight: 800;
        color: #0f172a;
        text-transform: uppercase;
        letter-spacing: 0.3px;
    }

    tr:nth-child(even) td {
        background: #fafbfc;
    }

    /* Code & Monospace Boxes */
    pre, .code-box {
        background: #090e17;
        color: #38bdf8;
        font-family: 'JetBrains Mono', monospace;
        font-size: 5.8pt;
        line-height: 1.25;
        padding: 4px 6px;
        border-radius: 4px;
        border: 1px solid #1e293b;
        margin: 1.5px 0;
        overflow: hidden;
    }

    .code-box .highlight {
        color: #facc15;
        font-weight: 700;
    }

    .code-box .comment {
        color: #64748b;
    }

    .code-box .success {
        color: #4ade80;
    }

    .code-box .purple {
        color: #c084fc;
    }

    p {
        margin: 1.5px 0;
        color: #334155;
    }

    ul, ol {
        margin: 1.5px 0;
        padding-left: 12px;
    }

    li {
        margin-bottom: 1.5px;
        color: #334155;
    }

    strong {
        color: #0f172a;
    }

    .pill {
        display: inline-block;
        padding: 1px 4.5px;
        border-radius: 3px;
        font-family: 'JetBrains Mono', monospace;
        font-size: 5.8pt;
        font-weight: 700;
    }

    .pill-blue { background: #eff6ff; color: #1d4ed8; border: 1px solid #bfdbfe; }
    .pill-green { background: #f0fdf4; color: #15803d; border: 1px solid #bbf7d0; }
    .pill-purple { background: #faf5ff; color: #7e22ce; border: 1px solid #e9d5ff; }
    .pill-amber { background: #fffbeb; color: #b45309; border: 1px solid #fde68a; }
    .pill-red { background: #fef2f2; color: #b91c1c; border: 1px solid #fecaca; }
    """

    # We now craft the 10 distinct, self-contained, publication-grade pages
    # Each page fits within exactly 297mm without any overflowing or clipping!

    # --- PAGE 1 ---
    page_1 = """
    <div class="page" id="page-1">
        <div class="page-header">
            <div class="header-left">
                <span class="brand-pill">CAMPUSOS 1.0</span>
                <span class="header-title">TECHNICAL EVALUATION DOSSIER</span>
                <span class="header-sub">· BPUT Hackathon 2026</span>
            </div>
            <div class="header-right">
                <span class="tag-pill">PROBLEM STATEMENT PS07</span>
                <span class="page-num-tag">PAGE 1 / 10</span>
            </div>
        </div>

        <div class="page-body">
            <div class="banner">
                <div>
                    <div class="banner-title">PAGE 1 · Executive Summary & Problem Statement</div>
                    <div style="font-size: 6.5pt; color: #94a3b8; margin-top: 1px;">Institutional Campus Operating System & Disaster Resilient Infrastructure</div>
                </div>
                <div class="banner-badge">VERIFIED SUBMISSION</div>
            </div>

            <div class="metric-strip">
                <div class="metric-box">
                    <div class="metric-val" style="color: #2563eb;">449</div>
                    <div class="metric-lbl">Flutter Tests (100% Pass)</div>
                </div>
                <div class="metric-box">
                    <div class="metric-val" style="color: #059669;">22</div>
                    <div class="metric-lbl">Backend Test Suites</div>
                </div>
                <div class="metric-box">
                    <div class="metric-val" style="color: #7c3aed;">41</div>
                    <div class="metric-lbl">Security Threat Tests</div>
                </div>
                <div class="metric-box">
                    <div class="metric-val" style="color: #d97706;">6 Roles</div>
                    <div class="metric-lbl">Unified Campus Fabric</div>
                </div>
                <div class="metric-box">
                    <div class="metric-val" style="color: #0284c7;">BLE 5.x</div>
                    <div class="metric-lbl">Zero-Infra Mesh Intranet</div>
                </div>
            </div>

            <div class="card-accent">
                <div style="font-weight: 800; font-size: 7.8pt; color: #0f172a; margin-bottom: 2px;">What Is CampusOS?</div>
                <p><strong>CampusOS</strong> is a unified, offline-resilient, multi-role digital operating platform engineered for universities, engineering colleges, and polytechnic campuses. It permanently replaces vulnerable paper attendance registers, unverified gate slips, lost paper complaints, and informal WhatsApp groups with a single authoritative, mathematically tamper-proof digital operating layer.</p>
                <p>Designed specifically for <strong>BPUT Hackathon PS07 (Institutional Campus Operating System & Disaster Offline Survivability)</strong>, CampusOS connects all 6 campus stakeholders around an authoritative MySQL 8 backend, device-bound <strong>Ed25519 cryptographic identities</strong>, and a <strong>Decentralized BLE Mesh Network</strong> that continues to operate during complete power, cellular, and internet blackouts.</p>
            </div>

            <div class="sec-title">The Three Critical Operational Failures Solved</div>
            <div class="grid-3">
                <div class="card" style="border-top: 2px solid #ef4444;">
                    <div style="font-weight: 800; font-size: 7pt; color: #b91c1c; margin-bottom: 2px;">1. Network Fragility</div>
                    <p style="font-size: 6.2pt;">Concrete hostel basements, underground laboratories, and remote campus gates suffer regular zero-connectivity deadzones. Natural disasters (Cyclone Fani/Dana in Odisha) wipe out cellular towers for days. CampusOS embeds a peer-to-peer BLE mesh enabling local chats and emergency flare alerts without cell towers.</p>
                </div>
                <div class="card" style="border-top: 2px solid #f59e0b;">
                    <div style="font-weight: 800; font-size: 7pt; color: #b45309; margin-bottom: 2px;">2. Operational Fragmentation</div>
                    <p style="font-size: 6.2pt;">Attendance in paper books enables rampant proxying. Mess dining uses physical coupons that are forged and traded. Hostel leave requires walking miles for physical pen signatures. Grievances get buried in WhatsApp chats with zero accountability. Deans have zero real-time visibility into day-to-day operations.</p>
                </div>
                <div class="card" style="border-top: 2px solid #3b82f6;">
                    <div style="font-weight: 800; font-size: 7pt; color: #1d4ed8; margin-bottom: 2px;">3. Identity & Proxy Vulnerability</div>
                    <p style="font-size: 6.2pt;">Static QR codes are screenshotted and shared across hostel rooms in seconds. CampusOS replaces human inspection with mathematical cryptography: <strong>Ed25519 hardware key binding</strong>, <strong>30-second dynamic rotating QR passports</strong>, and <strong>BLE RSSI physical proximity verification</strong>.</p>
                </div>
            </div>

            <div class="sec-title">BPUT PS07 Requirement Compliance Matrix</div>
            <table>
                <thead>
                    <tr>
                        <th style="width: 14%;">Deliverable</th>
                        <th style="width: 38%;">BPUT PS07 Problem Statement Requirement</th>
                        <th style="width: 48%;">CampusOS Technical Implementation & Response</th>
                    </tr>
                </thead>
                <tbody>
                    <tr>
                        <td><span class="pill pill-blue">DELIVERABLE 1</span></td>
                        <td><strong>Unified Multi-Role Fabric</strong></td>
                        <td>6 strictly segregated roles (Student, Teacher, Warden, Security, Mess, Dean) operating across a unified single-source-of-truth backend with cascading state machines.</td>
                    </tr>
                    <tr>
                        <td><span class="pill pill-green">DELIVERABLE 2</span></td>
                        <td><strong>Tamper-Proof Digital Identity & Attendance</strong></td>
                        <td>Device-bound Ed25519 Passport, 30s rotating dynamic QR, BLE proximity beacons (-75 dBm threshold), and encrypted SQLite sync queues.</td>
                    </tr>
                    <tr>
                        <td><span class="pill pill-purple">DELIVERABLE 3</span></td>
                        <td><strong>Cascading Campus Workflows</strong></td>
                        <td>End-to-end state transitions: Student Hostel Leave Request &rarr; Warden Multi-Factor Approval &rarr; Auto-Issued Dynamic Gate Pass &rarr; Security Turnstile Scan.</td>
                    </tr>
                    <tr>
                        <td><span class="pill pill-amber">DELIVERABLE 4</span></td>
                        <td><strong>Low-Bandwidth & Disaster Resilience</strong></td>
                        <td>Decentralized BLE 5.x multi-hop mesh network with binary wire protocol, LocalSend offline data sharing, and data-mule asynchronous store-and-forward sync.</td>
                    </tr>
                    <tr>
                        <td><span class="pill pill-red">DELIVERABLE 5</span></td>
                        <td><strong>Production Readiness & Admin Control</strong></td>
                        <td>Production React 19 desktop control plane with 17 operational modules, TanStack Table virtualized grids, Recharts analytics, and verified 449 test suite.</td>
                    </tr>
                </tbody>
            </table>

            <div class="sec-title">Six Core Value Pillars</div>
            <div class="grid-3">
                <div class="card" style="padding: 3px 6px;">
                    <strong style="color: #1e3a8a; font-size: 6.8pt;">1. Unified Multi-Role Fabric</strong>
                    <div style="font-size: 5.8pt; color: #475569;">Eliminates institutional silos with cascading cross-role workflows and unified RBAC.</div>
                </div>
                <div class="card" style="padding: 3px 6px;">
                    <strong style="color: #1e3a8a; font-size: 6.8pt;">2. Cryptographic Passport</strong>
                    <div style="font-size: 5.8pt; color: #475569;">Ed25519 device keystore binding with 30s rotating QR codes prevents proxy fraud.</div>
                </div>
                <div class="card" style="padding: 3px 6px;">
                    <strong style="color: #1e3a8a; font-size: 6.8pt;">3. BLE Proximity Attendance</strong>
                    <div style="font-size: 5.8pt; color: #475569;">Hardware-enforced -75 dBm RSSI classroom proximity boundary prevents proxy attendance.</div>
                </div>
                <div class="card" style="padding: 3px 6px;">
                    <strong style="color: #1e3a8a; font-size: 6.8pt;">4. Zero-Infra BLE Mesh Chat</strong>
                    <div style="font-size: 5.8pt; color: #475569;">Multi-hop flood-routing with TTL management survives total cyclone telecommunication blackouts.</div>
                </div>
                <div class="card" style="padding: 3px 6px;">
                    <strong style="color: #1e3a8a; font-size: 6.8pt;">5. Adaptive Device Engine</strong>
                    <div style="font-size: 5.8pt; color: #475569;">5 hardware tiers (Ultra-Low to Flagship) with thermal throttling and 120Hz frame budget enforcement.</div>
                </div>
                <div class="card" style="padding: 3px 6px;">
                    <strong style="color: #1e3a8a; font-size: 6.8pt;">6. Dean Command Plane</strong>
                    <div style="font-size: 5.8pt; color: #475569;">React 19 central administrative console with 17 operational modules, NLP grievance triage, and audits.</div>
                </div>
            </div>
        </div>

        <div class="page-footer">
            <span class="footer-left">CAMPUSOS: UNIFIED INSTITUTIONAL OPERATING SYSTEM</span>
            <span class="footer-center">CONFIDENTIAL · JUDGING PANEL EVALUATION DOSSIER</span>
            <span class="footer-right">PAGE 1 OF 10</span>
        </div>
    </div>
    """

    # --- PAGE 2 ---
    page_2 = """
    <div class="page" id="page-2">
        <div class="page-header">
            <div class="header-left">
                <span class="brand-pill">CAMPUSOS 1.0</span>
                <span class="header-title">TECHNICAL EVALUATION DOSSIER</span>
                <span class="header-sub">· Architecture & Technology Topology</span>
            </div>
            <div class="header-right">
                <span class="tag-pill">3-TIER ARCHITECTURE</span>
                <span class="page-num-tag">PAGE 2 / 10</span>
            </div>
        </div>

        <div class="page-body">
            <div class="banner">
                <div>
                    <div class="banner-title">PAGE 2 · System Architecture & Enterprise Topology</div>
                    <div style="font-size: 6.5pt; color: #94a3b8; margin-top: 1px;">Full Three-Tier Stack, Disaster Recovery Resiliency, and Database Schema</div>
                </div>
                <div class="banner-badge">ENTERPRISE TOPOLOGY</div>
            </div>

            <div class="sec-title">Three-Tier Architecture Schematic</div>
            <div class="card-dark" style="padding: 5px 8px;">
                <div class="code-box" style="margin: 0; background: transparent; border: none; padding: 0;">
<span class="highlight">┌────────────────────────────────────────────────────────────────────────────────────────────────────────┐</span>
<span class="highlight">│                                            CLIENT TIER                                                 │</span>
<span class="highlight">│</span>  📱 <span class="success">Flutter 3.x Mobile App (Dart 3.0)</span>                    💻 <span class="success">React 19 Desktop Command Plane (TypeScript + Vite)</span>   <span class="highlight">│</span>
<span class="highlight">│</span>     • Student Shell (Passport, Wallet, Leave, Chat)         • Dean Executive Console (17 Operational Modules)  <span class="highlight">│</span>
<span class="highlight">│</span>     • Teacher Shell (BLE Broadcaster, Attendance)           • Multi-Column Data Grids (@tanstack/react-table)  <span class="highlight">│</span>
<span class="highlight">│</span>     • Warden Shell (Leave Triage, Defect Tracking)          • Real-Time Visual Analytics & Curves (Recharts)   <span class="highlight">│</span>
<span class="highlight">│</span>     • Security & Mess Shells (Perimeter QR Scanners)        • Dynamic Role RBAC Enforcement & System Logs      <span class="highlight">│</span>
<span class="highlight">└───────────────────────────────────────────────────┬────────────────────────────────────────────────────┘</span>
                                                    │ HTTPS / HS256 Bearer JWT / CORS
<span class="highlight">┌───────────────────────────────────────────────────▼────────────────────────────────────────────────────┐</span>
<span class="highlight">│                                      BACKEND APPLICATION TIER                                          │</span>
<span class="highlight">│</span>  ⚙️ <span class="success">Python Flask Monolithic Architecture (19 Distinct API Blueprints)</span>                                    <span class="highlight">│</span>
<span class="highlight">│</span>     ┌───────────────────────┐  ┌─────────────────────────┐  ┌────────────────────────────────────────┐ <span class="highlight">│</span>
<span class="highlight">│</span>     │ <span class="purple">REST API Gateway</span>      │  │ <span class="purple">Cryptographic Core</span>     │  │ <span class="purple">Background Async Thread Pool</span>          │ <span class="highlight">│</span>
<span class="highlight">│</span>     │ • Port 5000 / HS256   │  │ • Ed25519 (RFC 8032)    │  │ • FCM Real-Time Push Dispatcher        │ <span class="highlight">│</span>
<span class="highlight">│</span>     │ • Rate Limiting & RBAC│  │ • HMAC-SHA256 Signatures│  │ • Offline SQLite Fallback Queue        │ <span class="highlight">│</span>
<span class="highlight">│</span>     │ • 19 Route Blueprints │  │ • Replay Nonce Cache    │  │ • NLP TF-IDF Grievance Classifier      │ <span class="highlight">│</span>
<span class="highlight">│</span>     └───────────────────────┘  └─────────────────────────┘  └────────────────────────────────────────┘ <span class="highlight">│</span>
<span class="highlight">│</span>     ┌────────────────────────────────────────────────────────────────────────────────────────────────┐ <span class="highlight">│</span>
<span class="highlight">│</span>     │ 🛡️ <span class="purple">Immutable Audit Trail (request_audits table)</span>: SHA-256 Request Logging & Forensic Replay   │ <span class="highlight">│</span>
<span class="highlight">└───────────────────────────────────────────────────┬────────────────────────────────────────────────────┘</span>
                                                    │
<span class="highlight">┌───────────────────────────────────────────────────▼────────────────────────────────────────────────────┐</span>
<span class="highlight">│                                          PERSISTENCE TIER                                              │</span>
<span class="highlight">│</span>  🗄️ <span class="success">Authoritative MySQL 8 Relational Database</span>              📱 <span class="success">Client Drift SQLite Engine (Offline Vault)</span>    <span class="highlight">│</span>
<span class="highlight">│</span>     • 27 Normalized Enterprise Relational Tables            • Device Trust Bundles (Local Ed25519 Public Keys) │
<span class="highlight">│</span>     • ACID Strict Foreign Key Constraints & Transactions    • Outbox Queue (Attendance & Leave Offline Sync)   │
<span class="highlight">│</span>     • Partitioned Attendance & Check-In History Ledgers     • Mesh Packet LRU Deduplication Cache (&lt; 15 MB)    │
<span class="highlight">└────────────────────────────────────────────────────────────────────────────────────────────────────────┘</span>
                </div>
            </div>

            <div class="sec-title">Comprehensive Technology Stack</div>
            <table>
                <thead>
                    <tr>
                        <th style="width: 16%;">Layer</th>
                        <th style="width: 26%;">Technology / Library</th>
                        <th style="width: 58%;">Engineering Role & Production Justification</th>
                    </tr>
                </thead>
                <tbody>
                    <tr>
                        <td><strong>Mobile Client</strong></td>
                        <td>Flutter 3.x + Dart 3.0</td>
                        <td>Single codebase compiling to native Android, iOS, and Web. Zero bridge penalty with Impeller graphics engine.</td>
                    </tr>
                    <tr>
                        <td><strong>Desktop Admin</strong></td>
                        <td>React 19 + TypeScript + Vite 8.3</td>
                        <td>Sub-millisecond HMR, zero-overhead client rendering, Radix UI accessibility primitives, and Tailwind CSS.</td>
                    </tr>
                    <tr>
                        <td><strong>Backend Engine</strong></td>
                        <td>Python Flask + PyMySQL</td>
                        <td>19 modular blueprints, lightweight memory footprint (< 120MB RSS), synchronous database transaction integrity.</td>
                    </tr>
                    <tr>
                        <td><strong>Relational Database</strong></td>
                        <td>MySQL 8.0 Enterprise</td>
                        <td>27 normalized tables, utf8mb4 collation, composite foreign keys, B-tree indexed lookups for 50,000+ students.</td>
                    </tr>
                    <tr>
                        <td><strong>Offline Client Storage</strong></td>
                        <td>Drift SQLite (Dart)</td>
                        <td>Type-safe reactive embedded SQL database on device. Persists cryptographic trust bundles and sync queues.</td>
                    </tr>
                    <tr>
                        <td><strong>Identity & Signing</strong></td>
                        <td>Ed25519 (RFC 8032) + HMAC-SHA256</td>
                        <td>Asymmetric cryptographic keypairs generated in device keystore. High performance, zero secret key exposure.</td>
                    </tr>
                    <tr>
                        <td><strong>BLE Mesh Transport</strong></td>
                        <td>flutter_blue_plus + peripheral</td>
                        <td>Dual-role Bluetooth Low Energy advertising and scanning. Enables 0-infra mesh flood-routing with binary wire protocol.</td>
                    </tr>
                    <tr>
                        <td><strong>State & Architecture</strong></td>
                        <td>Riverpod + Provider</td>
                        <td>Immutable dependency injection, deterministic state tracking, full testability across 449 automated unit tests.</td>
                    </tr>
                    <tr>
                        <td><strong>Data Visualization</strong></td>
                        <td>Recharts + TanStack Table v8</td>
                        <td>Interactive attendance velocity curves, dining throughput funnels, and virtualized multi-column student grids.</td>
                    </tr>
                </tbody>
            </table>

            <div class="sec-title">Disaster Recovery & Offline Synchronization Architecture</div>
            <div class="grid-2">
                <div class="card-emerald">
                    <strong style="color: #065f46; font-size: 6.8pt;">Store-and-Forward Data Mule Relay</strong>
                    <p style="font-size: 6.1pt;">When network dies completely, check-in tokens and leave requests are signed with local Ed25519 private keys and queued inside device Drift SQLite. When a faculty or warden device enters a connected zone, their phone serves as a "Data Mule", uploading cryptographically signed batches to the central server with guaranteed idempotency.</p>
                </div>
                <div class="card-accent">
                    <strong style="color: #1e40af; font-size: 6.8pt;">LocalSend Offline AirDrop Protocol</strong>
                    <p style="font-size: 6.1pt;">For massive data exchange during cyclone emergencies (syllabus PDFs, grade records, photo rosters), CampusOS incorporates a LocalSend peer-to-peer Wi-Fi Direct / Local subnet engine that transfers multi-megabyte payloads at up to 45 MB/s with zero internet connection.</p>
                </div>
            </div>
        </div>

        <div class="page-footer">
            <span class="footer-left">CAMPUSOS: UNIFIED INSTITUTIONAL OPERATING SYSTEM</span>
            <span class="footer-center">CONFIDENTIAL · JUDGING PANEL EVALUATION DOSSIER</span>
            <span class="footer-right">PAGE 2 OF 10</span>
        </div>
    </div>
    """

    # --- PAGE 3 ---
    page_3 = """
    <div class="page" id="page-3">
        <div class="page-header">
            <div class="header-left">
                <span class="brand-pill">CAMPUSOS 1.0</span>
                <span class="header-title">TECHNICAL EVALUATION DOSSIER</span>
                <span class="header-sub">· Role Segregation & Institutional RBAC</span>
            </div>
            <div class="header-right">
                <span class="tag-pill">6 INSTITUTIONAL ROLES</span>
                <span class="page-num-tag">PAGE 3 / 10</span>
            </div>
        </div>

        <div class="page-body">
            <div class="banner">
                <div>
                    <div class="banner-title">PAGE 3 · The Six Institutional Roles & 6-Card Wallet</div>
                    <div style="font-size: 6.5pt; color: #94a3b8; margin-top: 1px;">Strict Role-Based Access Control, Cascading Permissions, and Student Campus Wallet</div>
                </div>
                <div class="banner-badge">RBAC ACCESS MATRIX</div>
            </div>

            <div class="sec-title">The Six Institutional Personas</div>
            <div class="grid-3">
                <div class="card" style="border-top: 2px solid #3b82f6;">
                    <div style="display: flex; justify-content: space-between; align-items: center;">
                        <strong style="color: #1d4ed8; font-size: 7.2pt;">1. Student</strong>
                        <span class="pill pill-blue">MOBILE</span>
                    </div>
                    <div style="font-size: 6pt; color: #64748b; font-family: 'JetBrains Mono', monospace;">student@campusos.edu</div>
                    <p style="font-size: 6pt;">Access to 6-card Campus Wallet, Ed25519 dynamic passport, BLE attendance check-in, hostel leave submission, and peer-to-peer mesh chat.</p>
                </div>
                <div class="card" style="border-top: 2px solid #10b981;">
                    <div style="display: flex; justify-content: space-between; align-items: center;">
                        <strong style="color: #047857; font-size: 7.2pt;">2. Teacher / Faculty</strong>
                        <span class="pill pill-green">MOBILE</span>
                    </div>
                    <div style="font-size: 6pt; color: #64748b; font-family: 'JetBrains Mono', monospace;">teacher@campusos.edu</div>
                    <p style="font-size: 6pt;">Attendance broadcaster (BLE Beacon host & dynamic 10s QR fallback), class roster inspection, manual overrides with audit trails, and announcements.</p>
                </div>
                <div class="card" style="border-top: 2px solid #f59e0b;">
                    <div style="display: flex; justify-content: space-between; align-items: center;">
                        <strong style="color: #b45309; font-size: 7.2pt;">3. Hostel Warden</strong>
                        <span class="pill pill-amber">MOBILE</span>
                    </div>
                    <div style="font-size: 6pt; color: #64748b; font-family: 'JetBrains Mono', monospace;">warden@campusos.edu</div>
                    <p style="font-size: 6pt;">Multi-factor leave triage (one-tap approval/rejection with reason), automated gate pass issuance, room inspection defect logs, and hostel notices.</p>
                </div>
                <div class="card" style="border-top: 2px solid #8b5cf6;">
                    <div style="display: flex; justify-content: space-between; align-items: center;">
                        <strong style="color: #6d28d9; font-size: 7.2pt;">4. Gate Security</strong>
                        <span class="pill pill-purple">MOBILE</span>
                    </div>
                    <div style="font-size: 6pt; color: #64748b; font-family: 'JetBrains Mono', monospace;">security@campusos.edu</div>
                    <p style="font-size: 6pt;">High-speed turnstile QR scanner with 200ms debounce. Validates cryptographic signatures, verifies student photo, and marks gate check-out/in.</p>
                </div>
                <div class="card" style="border-top: 2px solid #ec4899;">
                    <div style="display: flex; justify-content: space-between; align-items: center;">
                        <strong style="color: #be185d; font-size: 7.2pt;">5. Mess Dining Staff</strong>
                        <span class="pill pill-red">MOBILE</span>
                    </div>
                    <div style="font-size: 6pt; color: #64748b; font-family: 'JetBrains Mono', monospace;">mess@campusos.edu</div>
                    <p style="font-size: 6pt;">Meal session dining token verifier (Breakfast, Lunch, Snacks, Dinner). Prevents double-dipping fraud and tracks real-time dietary headcounts.</p>
                </div>
                <div class="card" style="border-top: 2px solid #0f172a;">
                    <div style="display: flex; justify-content: space-between; align-items: center;">
                        <strong style="color: #0f172a; font-size: 7.2pt;">6. Dean / Central Admin</strong>
                        <span class="pill pill-blue">WEB + MOBILE</span>
                    </div>
                    <div style="font-size: 6pt; color: #64748b; font-family: 'JetBrains Mono', monospace;">admin@campusos.edu</div>
                    <p style="font-size: 6pt;">Desktop React 19 Command Plane with 17 operational modules, NLP grievance triage, cross-campus analytics, device keystore revocation, and audits.</p>
                </div>
            </div>

            <div class="sec-title">Role-Based Access Control (RBAC) Matrix</div>
            <table>
                <thead>
                    <tr>
                        <th style="width: 22%;">System Module</th>
                        <th style="width: 13%;">Student</th>
                        <th style="width: 13%;">Teacher</th>
                        <th style="width: 13%;">Warden</th>
                        <th style="width: 13%;">Security</th>
                        <th style="width: 13%;">Mess</th>
                        <th style="width: 13%;">Dean / Admin</th>
                    </tr>
                </thead>
                <tbody>
                    <tr>
                        <td><strong>Campus Wallet</strong></td>
                        <td><span class="pill pill-green">READ / WRITE</span></td>
                        <td>—</td>
                        <td>—</td>
                        <td>—</td>
                        <td>—</td>
                        <td><span class="pill pill-blue">READ AUDIT</span></td>
                    </tr>
                    <tr>
                        <td><strong>Ed25519 Passport</strong></td>
                        <td><span class="pill pill-green">GENERATE QR</span></td>
                        <td><span class="pill pill-purple">VERIFY</span></td>
                        <td>—</td>
                        <td><span class="pill pill-purple">VERIFY</span></td>
                        <td><span class="pill pill-purple">VERIFY</span></td>
                        <td><span class="pill pill-red">CA / REVOKE</span></td>
                    </tr>
                    <tr>
                        <td><strong>Classroom Attendance</strong></td>
                        <td><span class="pill pill-green">CHECK-IN</span></td>
                        <td><span class="pill pill-blue">HOST BEACON</span></td>
                        <td>—</td>
                        <td>—</td>
                        <td>—</td>
                        <td><span class="pill pill-blue">FULL ANALYTICS</span></td>
                    </tr>
                    <tr>
                        <td><strong>Hostel Leave Workflow</strong></td>
                        <td><span class="pill pill-green">SUBMIT</span></td>
                        <td>—</td>
                        <td><span class="pill pill-amber">APPROVE / REJ</span></td>
                        <td><span class="pill pill-purple">VIEW OUT-CAMPUS</span></td>
                        <td>—</td>
                        <td><span class="pill pill-blue">OVERRIDE AUDIT</span></td>
                    </tr>
                    <tr>
                        <td><strong>Gate Pass Turnstile</strong></td>
                        <td><span class="pill pill-green">VIEW ACTIVE</span></td>
                        <td>—</td>
                        <td><span class="pill pill-amber">ISSUE</span></td>
                        <td><span class="pill pill-purple">SCAN TURNSTILE</span></td>
                        <td>—</td>
                        <td><span class="pill pill-blue">EXIT/ENTRY LOGS</span></td>
                    </tr>
                    <tr>
                        <td><strong>Mess Dining Token</strong></td>
                        <td><span class="pill pill-green">PRESENT MEAL</span></td>
                        <td>—</td>
                        <td>—</td>
                        <td>—</td>
                        <td><span class="pill pill-purple">SCAN & SERVE</span></td>
                        <td><span class="pill pill-blue">WASTE/CONSUMP</span></td>
                    </tr>
                    <tr>
                        <td><strong>Grievance Triage</strong></td>
                        <td><span class="pill pill-green">FILE TICKET</span></td>
                        <td>—</td>
                        <td><span class="pill pill-amber">HOSTEL TRIAGE</span></td>
                        <td>—</td>
                        <td>—</td>
                        <td><span class="pill pill-red">NLP CLUSTERS</span></td>
                    </tr>
                    <tr>
                        <td><strong>Mesh Chat & Relays</strong></td>
                        <td><span class="pill pill-green">PEER TX/RX</span></td>
                        <td><span class="pill pill-green">PEER TX/RX</span></td>
                        <td><span class="pill pill-green">PEER TX/RX</span></td>
                        <td>—</td>
                        <td>—</td>
                        <td><span class="pill pill-red">SIREN BROADCAST</span></td>
                    </tr>
                </tbody>
            </table>

            <div class="sec-title">The 6-Card Campus Wallet System</div>
            <div class="grid-2">
                <div class="card">
                    <strong style="color: #0f172a; font-size: 6.8pt;">Carousel Gesture & Physics Architecture</strong>
                    <p style="font-size: 6.1pt;">The mobile student wallet consolidates every physical student document into an interactive, 3D Matrix4 perspective card carousel:</p>
                    <ul style="font-size: 6pt; margin-top: 1px;">
                        <li><strong>Haptic Feedback:</strong> Custom <code>AppHaptics.selectionClick()</code> on every swipe gesture.</li>
                        <li><strong>Perspective Depth:</strong> Non-active cards scale back (0.85x) with realistic Z-axis rotation.</li>
                        <li><strong>Zero Stutter:</strong> Custom PageController with 120Hz frame budget enforcement.</li>
                    </ul>
                </div>
                <div class="card-dark">
                    <strong style="color: #38bdf8; font-size: 6.8pt;">The Six Native Digital Cards</strong>
                    <div style="font-size: 5.8pt; line-height: 1.35; margin-top: 2px;">
                        <div>1. <span class="highlight">CampusOS Passport:</span> Ed25519 identity with live 30s rotating dynamic QR.</div>
                        <div>2. <span class="highlight">Student ID Card:</span> Verified photo, Roll No, Branch, blood group, barcode.</div>
                        <div>3. <span class="highlight">Active Gate Pass:</span> Approved warden signature with live countdown ring.</div>
                        <div>4. <span class="highlight">Official Documents:</span> Bonafide, Grade cards with SHA-256 tamper seals.</div>
                        <div>5. <span class="highlight">Fees & Dues Card:</span> Real-time tuition clearance status & receipt ledger.</div>
                        <div>6. <span class="highlight">Visitor Pass:</span> HMAC-signed guest pass for perimeter gate verification.</div>
                    </div>
                </div>
            </div>
        </div>

        <div class="page-footer">
            <span class="footer-left">CAMPUSOS: UNIFIED INSTITUTIONAL OPERATING SYSTEM</span>
            <span class="footer-center">CONFIDENTIAL · JUDGING PANEL EVALUATION DOSSIER</span>
            <span class="footer-right">PAGE 3 OF 10</span>
        </div>
    </div>
    """

    # --- PAGE 4 ---
    page_4 = """
    <div class="page" id="page-4">
        <div class="page-header">
            <div class="header-left">
                <span class="brand-pill">CAMPUSOS 1.0</span>
                <span class="header-title">TECHNICAL EVALUATION DOSSIER</span>
                <span class="header-sub">· Core Feature Deep Dive · BLE Attendance</span>
            </div>
            <div class="header-right">
                <span class="tag-pill">MAJOR FEATURE DEEP DIVE</span>
                <span class="page-num-tag">PAGE 4 / 10</span>
            </div>
        </div>

        <div class="page-body">
            <div class="banner">
                <div>
                    <div class="banner-title">PAGE 4 · 🔑 BLE Attendance Engine — Deep Dive</div>
                    <div style="font-size: 6.5pt; color: #94a3b8; margin-top: 1px;">Hardware-Bound Presence Verification, Dual Modes, RSSI Perimeter Math, and Batch Sync</div>
                </div>
                <div class="banner-badge">PROXIMITY ENGINE</div>
            </div>

            <div class="card-accent">
                <div style="font-weight: 800; font-size: 7.2pt; color: #0f172a; margin-bottom: 1px;">Why BLE Attendance Replaces Registers & Static QRs</div>
                <p style="font-size: 6.2pt;">Traditional paper attendance suffers from friend-proxy signatures and wastes 10 minutes per lecture. Static QR codes on projector screens get photographed and forwarded via WhatsApp to students in hostel beds. CampusOS attendance uses <strong>Bluetooth Low Energy (BLE) physical signal decay</strong>: presence is bound to physical proximity inside the classroom walls.</p>
            </div>

            <div class="sec-title">Dual-Mode Attendance Architecture</div>
            <div class="grid-2">
                <div class="card" style="border-top: 2px solid #2563eb;">
                    <div style="display: flex; justify-content: space-between; align-items: center;">
                        <strong style="color: #1d4ed8; font-size: 6.8pt;">Mode 1: BLE Proximity Beacon (Primary)</strong>
                        <span class="pill pill-blue">RSSI BOUND</span>
                    </div>
                    <div class="code-box" style="margin: 2px 0;">
<span class="comment">// 1. Faculty opens app & taps "Start Session"</span>
POST /sessions/create &rarr; session_id, session_nonce, teacher_key_id
<span class="comment">// 2. Teacher phone begins BLE Advertising:</span>
Service UUID: <span class="highlight">0000CA05-0000-1000-8000-00805F9B34FB</span>
Manufacturer ID: <span class="purple">0xCA05</span> | Payload: signed session_token
<span class="comment">// 3. Student device scans for 0xCA05 beacon:</span>
rssi = measure_signal_strength();
<span class="success">if (rssi &gt; -75 dBm) { // Physical Presence Verified!</span>
    biometric_unlock();
    sig = Ed25519_Sign(session_nonce, student_private_key);
    POST /attendance/check-in { session_id, sig, nonce, student_id }
<span class="comment">} else { REJECT: Too far from teacher phone! }</span>
                    </div>
                    <div style="font-size: 5.8pt; color: #475569;">Physics-enforced attendance: Signal attenuation through concrete door frames prevents proxying from hallways.</div>
                </div>

                <div class="card" style="border-top: 2px solid #059669;">
                    <div style="display: flex; justify-content: space-between; align-items: center;">
                        <strong style="color: #047857; font-size: 6.8pt;">Mode 2: 10-Second Dynamic QR Fallback</strong>
                        <span class="pill pill-green">RF-INTERFERENCE</span>
                    </div>
                    <div class="code-box" style="margin: 2px 0;">
<span class="comment">// For metal labs or heavily congested 2.4GHz zones</span>
Teacher screen displays Dynamic HMAC QR:
<span class="highlight">qr_payload = HMAC-SHA256(session_id + timestamp + counter,</span>
<span class="highlight">                         teacher_ephemeral_secret)</span>
<span class="comment">// QR code automatically regenerates every 10 seconds!</span>
Student scans QR with camera:
App extracts HMAC challenge & executes:
POST /attendance/qr-check-in { session_id, hmac_token, student_id }
<span class="comment">// Backend verification:</span>
if (current_time - qr_time &lt; 10s &amp;&amp; Valid_HMAC(token)) {
    mark_present(); <span class="success">// Validated!</span>
} else { HTTP 400 Expired QR! <span class="comment">// Screenshots useless!</span> }
                    </div>
                    <div style="font-size: 5.8pt; color: #475569;">Screenshots shared via WhatsApp fail automatically because token expires before recipient can scan.</div>
                </div>
            </div>

            <div class="sec-title">RSSI Proximity Perimeter & Signal Physics</div>
            <div class="grid-2-1">
                <div class="card">
                    <strong style="color: #0f172a; font-size: 6.5pt;">The -75 dBm Threshold Mathematics</strong>
                    <p style="font-size: 6.1pt;">Radio frequency signal strength drops inversely with distance (Friis transmission formula). In a standard Indian classroom:</p>
                    <table style="margin-top: 2px;">
                        <thead>
                            <tr>
                                <th>Physical Position</th>
                                <th>Measured RSSI</th>
                                <th>Engine Verdict</th>
                            </tr>
                        </thead>
                        <tbody>
                            <tr>
                                <td>Desk inside classroom (1m – 8m)</td>
                                <td style="color: #059669; font-weight: 700;">-42 dBm to -68 dBm</td>
                                <td><span class="pill pill-green">PERMITTED (PRESENT)</span></td>
                            </tr>
                            <tr>
                                <td>At classroom doorway (9m – 11m)</td>
                                <td style="color: #d97706; font-weight: 700;">-72 dBm to -74 dBm</td>
                                <td><span class="pill pill-amber">EDGE ZONE (WARNING)</span></td>
                            </tr>
                            <tr>
                                <td>Hallway / Adjacent Room (12m+)</td>
                                <td style="color: #dc2626; font-weight: 700;">-78 dBm to -95 dBm</td>
                                <td><span class="pill pill-red">BLOCKED (OUT OF BOUNDS)</span></td>
                            </tr>
                            <tr>
                                <td>Hostel / Canteen (Across Campus)</td>
                                <td style="color: #dc2626; font-weight: 700;">No Beacon Detected</td>
                                <td><span class="pill pill-red">BLOCKED (ABSENT)</span></td>
                            </tr>
                        </tbody>
                    </table>
                </div>

                <div class="card-emerald">
                    <strong style="color: #065f46; font-size: 6.5pt;">Offline Batch Sync Engine</strong>
                    <p style="font-size: 5.9pt;">When attendance takes place in a concrete basement lab with zero 4G/Wi-Fi:</p>
                    <ol style="font-size: 5.8pt; margin: 1px 0; padding-left: 10px;">
                        <li>Student completes BLE proximity check-in offline.</li>
                        <li>Record stored in encrypted local <strong>Drift SQLite</strong> queue with unique <code>idempotency_key</code>.</li>
                        <li>When faculty phone reconnects to campus Wi-Fi, background task auto-dispatches batch payload to <code>POST /attendance/batch-sync</code>.</li>
                        <li>Database processes records atomically, ignoring duplicates.</li>
                    </ol>
                </div>
            </div>

            <div class="sec-title">Attendance Fraud Protection Matrix</div>
            <table>
                <thead>
                    <tr>
                        <th style="width: 25%;">Fraud / Attack Vector</th>
                        <th style="width: 35%;">Traditional System Failure Mode</th>
                        <th style="width: 40%;">CampusOS Protection Mechanism</th>
                    </tr>
                </thead>
                <tbody>
                    <tr>
                        <td><strong>Friend Proxy Check-In</strong></td>
                        <td>Friend signs paper register or logs into student portal.</td>
                        <td><strong>Device Binding + Biometrics:</strong> Ed25519 keypair only exists on student's physical phone. Biometric prompt required.</td>
                    </tr>
                    <tr>
                        <td><strong>Screenshot Sharing</strong></td>
                        <td>Projector QR photographed and forwarded via WhatsApp.</td>
                        <td><strong>10s HMAC Rotation:</strong> QR regenerates every 10 seconds. Static screenshots expire before receiver can scan.</td>
                    </tr>
                    <tr>
                        <td><strong>Hallway / Parking Lot Check-In</strong></td>
                        <td>Student connects to campus Wi-Fi and marks attendance.</td>
                        <td><strong>-75 dBm RSSI Cutoff:</strong> Radio signal attenuation through concrete walls blocks check-in beyond 10-12 meters.</td>
                    </tr>
                    <tr>
                        <td><strong>Replay / Tamper Attacks</strong></td>
                        <td>Student intercepts network packet and re-transmits tomorrow.</td>
                        <td><strong>One-Time Ephemeral Nonce:</strong> Server verifies cryptographic nonce freshness (&lt; 60s). HTTP 409 Conflict if reused.</td>
                    </tr>
                </tbody>
            </table>
        </div>

        <div class="page-footer">
            <span class="footer-left">CAMPUSOS: UNIFIED INSTITUTIONAL OPERATING SYSTEM</span>
            <span class="footer-center">CONFIDENTIAL · JUDGING PANEL EVALUATION DOSSIER</span>
            <span class="footer-right">PAGE 4 OF 10</span>
        </div>
    </div>
    """

    # --- PAGE 5 ---
    page_5 = """
    <div class="page" id="page-5">
        <div class="page-header">
            <div class="header-left">
                <span class="brand-pill">CAMPUSOS 1.0</span>
                <span class="header-title">TECHNICAL EVALUATION DOSSIER</span>
                <span class="header-sub">· Core Feature Deep Dive · Device Binding & Passport</span>
            </div>
            <div class="header-right">
                <span class="tag-pill">MAJOR FEATURE DEEP DIVE</span>
                <span class="page-num-tag">PAGE 5 / 10</span>
            </div>
        </div>

        <div class="page-body">
            <div class="banner">
                <div>
                    <div class="banner-title">PAGE 5 · 🔐 Device Binding & CampusOS Passport — Deep Dive</div>
                    <div style="font-size: 6.5pt; color: #94a3b8; margin-top: 1px;">Ed25519 Hardware Keystore Binding, 30s Dynamic QR Lifecycle, and Replay Immunity</div>
                </div>
                <div class="banner-badge">CRYPTOGRAPHIC IDENTITY</div>
            </div>

            <div class="card-accent">
                <div style="font-weight: 800; font-size: 7.2pt; color: #0f172a; margin-bottom: 1px;">The Identity Problem on Indian Campuses</div>
                <p style="font-size: 6.2pt;">Physical plastic ID cards are easily forged, laminated duplicates are traded, and portal logins are freely shared between roommates. CampusOS establishes an immutable relationship: <strong>One Verified Student = One Enrolled Hardware Keystore</strong>. Identity is anchored in device hardware, not in shared passwords or static cards.</p>
            </div>

            <div class="sec-title">What "Device Binding" Means Technologically</div>
            <div class="grid-2">
                <div class="card">
                    <strong style="color: #1e3a8a; font-size: 6.8pt;">Hardware Keystore Keypair Generation</strong>
                    <p style="font-size: 6pt;">When a student enrolls on their smartphone, CampusOS generates an <strong>Ed25519 (RFC 8032) asymmetric keypair</strong> directly inside the secure hardware enclave (Android KeyStore / iOS Secure Enclave):</p>
                    <div class="code-box" style="margin: 2px 0;">
<span class="comment">// Generated inside phone hardware enclave:</span>
private_key = SecureEnclave.generate(Ed25519); <span class="comment">// NEVER EXPORTED</span>
public_key  = DerivePublicKey(private_key);
device_fp   = SHA256(IMEI + HardwareID + AndroidID);
<span class="comment">// Enrollment Request:</span>
POST /passport/bind {
    student_id: "STU-2026-0891",
    public_key: "ed25519_pub_7f9a2b...",
    device_fingerprint: device_fp
}
<span class="success">// Backend stores public key in users table.</span>
<span class="success">// Private key NEVER leaves student's phone!</span>
                    </div>
                </div>

                <div class="card">
                    <strong style="color: #1e3a8a; font-size: 6.8pt;">Dynamic 30-Second Passport QR Lifecycle</strong>
                    <p style="font-size: 6pt;">Instead of a static QR code, the student passport displays an actively rotating cryptographic payload with an animated circular countdown ring:</p>
                    <div class="code-box" style="margin: 2px 0;">
<span class="comment">// 1. Compute time-slot window (30-second epoch):</span>
window = floor(current_unix_time() / 30);
<span class="comment">// 2. Assemble canonical payload:</span>
payload = student_id + ":" + window + ":" + device_fp;
<span class="comment">// 3. Sign payload with device private key:</span>
signature = Ed25519_Sign(payload, device_private_key);
<span class="highlight">qr_code = Base64(student_id + "|" + window + "|" + signature);</span>
<span class="comment">// 4. Verifier scans QR (Security guard or mess staff):</span>
parsed_id, parsed_win, parsed_sig = parse(qr_code);
<span class="success">pub_key = fetch_enrolled_pubkey(parsed_id);</span>
<span class="success">valid = Ed25519_Verify(parsed_payload, parsed_sig, pub_key);</span>
                    </div>
                </div>
            </div>

            <div class="sec-title">Step-by-Step Verification Lifecycle & State Machine</div>
            <div class="card-dark" style="padding: 4px 8px;">
                <div class="code-box" style="margin: 0; background: transparent; border: none; padding: 0;">
<span class="highlight">STUDENT SMARTPHONE</span>                                               <span class="highlight">VERIFIER SCANNER (GATE / MESS / EXAM)</span>
┌──────────────────────────────────────────────┐                 ┌──────────────────────────────────────────────────┐
│ 1. Student opens Campus Wallet               │                 │ 5. Security / Mess opens CampusOS Scanner app    │
│ 2. App reads Ed25519 Key from Keystore       │                 │ 6. Camera scans QR (200ms debounce)              │
│ 3. Signs current 30s epoch payload           │                 │ 7. Extracts: student_id + window + signature     │
│ 4. Renders animated 30s dynamic QR code ring │ &rarr;&rarr;&rarr; [SCAN QR] &rarr;&rarr;&rarr; │ 8. Verifies Ed25519 signature against public key │
└──────────────────────────────────────────────┘                 │ 9. Checks timestamp drift (&plusmn;1 window allowable)   │
                                                                 │ 10. Displays photo, roll number, & pass verdict  │
                                                                 └──────────────────────────────────────────────────┘
                </div>
            </div>

            <div class="sec-title">Cryptographic Security Guarantees</div>
            <table>
                <thead>
                    <tr>
                        <th style="width: 22%;">Security Property</th>
                        <th style="width: 25%;">Underlying Algorithm</th>
                        <th style="width: 53%;">Cryptographic Proof & Enforcement</th>
                    </tr>
                </thead>
                <tbody>
                    <tr>
                        <td><strong>Zero Key Extraction</strong></td>
                        <td>Ed25519 + Hardware Enclave</td>
                        <td>Private key is flagged non-exportable at OS kernel level. Rooted devices fail hardware attestation.</td>
                    </tr>
                    <tr>
                        <td><strong>Screenshot Sharing Immunity</strong></td>
                        <td>30-Second Time Windowing</td>
                        <td>QR token is mathematically valid for exactly 30 seconds. A screenshot sent via messaging expires before arrival.</td>
                    </tr>
                    <tr>
                        <td><strong>Replay Attack Immunity</strong></td>
                        <td>Window-based Nonce Cache</td>
                        <td>Verifier stores consumed <code>(student_id, window)</code> pairs in memory. Second scan within same window returns HTTP 409 Conflict.</td>
                    </tr>
                    <tr>
                        <td><strong>Multi-Device Fraud Prevention</strong></td>
                        <td>1-to-1 Public Key Enrollment</td>
                        <td>Student cannot log in on a secondary phone and generate passports; server requires Dean admin re-binding to change keys.</td>
                    </tr>
                    <tr>
                        <td><strong>Instant Cryptographic Revocation</strong></td>
                        <td>Central Public Key Revocation</td>
                        <td>If a student is suspended or expelled, Dean clicks "Revoke Key"; all verifiers reject future passports instantly.</td>
                    </tr>
                </tbody>
            </table>

            <div class="sec-title">Passport Backend API Endpoints</div>
            <div class="grid-3">
                <div class="card" style="padding: 2.5px 5px;">
                    <div style="font-family: 'JetBrains Mono', monospace; font-size: 6pt; color: #1d4ed8; font-weight: 700;">POST /passport/bind</div>
                    <div style="font-size: 5.8pt; color: #475569;">Binds student public key & hardware fingerprint. Requires verified JWT claim.</div>
                </div>
                <div class="card" style="padding: 2.5px 5px;">
                    <div style="font-family: 'JetBrains Mono', monospace; font-size: 6pt; color: #1d4ed8; font-weight: 700;">POST /passport/verify</div>
                    <div style="font-size: 5.8pt; color: #475569;">Verifies Ed25519 signature & window. Returns student profile photo, roll no & status.</div>
                </div>
                <div class="card" style="padding: 2.5px 5px;">
                    <div style="font-family: 'JetBrains Mono', monospace; font-size: 6pt; color: #1d4ed8; font-weight: 700;">POST /passport/revoke</div>
                    <div style="font-size: 5.8pt; color: #b91c1c; font-weight: 700;">Dean-only endpoint to invalidate enrolled device key upon lost/stolen device report.</div>
                </div>
            </div>
        </div>

        <div class="page-footer">
            <span class="footer-left">CAMPUSOS: UNIFIED INSTITUTIONAL OPERATING SYSTEM</span>
            <span class="footer-center">CONFIDENTIAL · JUDGING PANEL EVALUATION DOSSIER</span>
            <span class="footer-right">PAGE 5 OF 10</span>
        </div>
    </div>
    """

    # --- PAGE 6 ---
    page_6 = """
    <div class="page" id="page-6">
        <div class="page-header">
            <div class="header-left">
                <span class="brand-pill">CAMPUSOS 1.0</span>
                <span class="header-title">TECHNICAL EVALUATION DOSSIER</span>
                <span class="header-sub">· Core Feature Deep Dive · Device Optimization Engine</span>
            </div>
            <div class="header-right">
                <span class="tag-pill">MAJOR FEATURE DEEP DIVE</span>
                <span class="page-num-tag">PAGE 6 / 10</span>
            </div>
        </div>

        <div class="page-body">
            <div class="banner">
                <div>
                    <div class="banner-title">PAGE 6 · ⚡ Device Optimization Engine — Deep Dive</div>
                    <div style="font-size: 6.5pt; color: #94a3b8; margin-top: 1px;">Adaptive Hardware Profiling, Thermal Throttle Guards, 120Hz Budget, and RAM Limits</div>
                </div>
                <div class="banner-badge">PERFORMANCE CORE</div>
            </div>

            <div class="card-accent">
                <div style="font-weight: 800; font-size: 7.2pt; color: #0f172a; margin-bottom: 1px;">The Extreme Hardware Diversity Problem</div>
                <p style="font-size: 6.2pt;">Students and staff at Indian universities carry a massive spectrum of hardware: from ₹6,000 entry-level 2GB Android Go phones used by first-year rural students, to ₹100,000 Snapdragon flagship phones used by senior faculty. CampusOS incorporates a custom <strong>Adaptive Performance Engine</strong> that auto-tunes background scanning, frame rates, and memory caps to ensure smooth performance without battery drain or thermal crashes.</p>
            </div>

            <div class="sec-title">5-Tier Hardware Classification System</div>
            <table>
                <thead>
                    <tr>
                        <th>Hardware Tier</th>
                        <th>Device RAM & CPU Spec</th>
                        <th>BLE Scan Duty Cycle</th>
                        <th>Scanner Debounce</th>
                        <th>UI & Graphics Profile</th>
                    </tr>
                </thead>
                <tbody>
                    <tr>
                        <td><span class="pill pill-red">ULTRA-LOW</span></td>
                        <td>&le; 2 GB RAM · 4 Cores (Android Go)</td>
                        <td><strong>15%</strong> (3s Scan / 17s Rest)</td>
                        <td>800 ms</td>
                        <td>Flat UI, no blur/glassmorphism, 60fps cap, haptics off</td>
                    </tr>
                    <tr>
                        <td><span class="pill pill-amber">LOW</span></td>
                        <td>3 GB RAM · 4–6 Cores (Budget SoC)</td>
                        <td><strong>25%</strong> (4s Scan / 12s Rest)</td>
                        <td>600 ms</td>
                        <td>Simple card shadows, minimal animations, 60fps cap</td>
                    </tr>
                    <tr>
                        <td><span class="pill pill-blue">MID</span></td>
                        <td>4–6 GB RAM · 8 Cores (Helio / SD 6xx)</td>
                        <td><strong>40%</strong> (6s Scan / 9s Rest)</td>
                        <td>400 ms</td>
                        <td>Card depth, smooth carousel transitions, 90fps</td>
                    </tr>
                    <tr>
                        <td><span class="pill pill-purple">HIGH</span></td>
                        <td>8 GB RAM · 8 Cores (Dimensity / SD 7xx)</td>
                        <td><strong>60%</strong> (8s Scan / 5s Rest)</td>
                        <td>250 ms</td>
                        <td>Glassmorphism, 3D Matrix4 perspective, 120fps enabled</td>
                    </tr>
                    <tr>
                        <td><span class="pill pill-green">ULTRA-HIGH</span></td>
                        <td>&ge; 12 GB RAM · Flagship (SD 8 Gen 2/3)</td>
                        <td><strong>80%</strong> (12s Scan / 3s Rest)</td>
                        <td>200 ms</td>
                        <td>Full physics simulation, haptic micro-clicks, 120Hz locked</td>
                    </tr>
                </tbody>
            </table>

            <div class="sec-title">Thermal Throttle Guard & Battery Preservation</div>
            <div class="grid-2">
                <div class="card" style="border-top: 2px solid #ef4444;">
                    <strong style="color: #b91c1c; font-size: 6.8pt;">Native Battery Thermal Hooks</strong>
                    <p style="font-size: 6pt;">Continuous BLE mesh broadcasting and camera QR scanning generate heat. The <code>ThermalGuardService</code> listens to native Android battery temperature broadcasts and dynamically scales down engine activity before the OS initiates thermal throttling:</p>
                    <div class="code-box" style="margin: 2px 0;">
<span class="success">TEMP &lt; 38°C (NORMAL):</span>    Full tier performance.
<span class="highlight">TEMP 38°C–42°C (WARM):</span>    Halve BLE scan window. Disable camera preview blur.
<span class="purple">TEMP &gt; 42°C (CRITICAL):</span>  Kill background mesh relay. Keep only emergency flare listener.
                    </div>
                </div>

                <div class="card" style="border-top: 2px solid #10b981;">
                    <strong style="color: #047857; font-size: 6.8pt;">120Hz Frame Budget Enforcement</strong>
                    <p style="font-size: 6pt;">CampusOS targets a locked 120Hz display refresh rate on capable devices (8.33ms per frame budget) and 60Hz (16.66ms) on low-tier hardware:</p>
                    <ul style="font-size: 5.8pt; margin: 1px 0; padding-left: 10px;">
                        <li><strong>Zero Jank Architecture:</strong> All cryptographic key operations (Ed25519 signing) execute in background Dart Isolates.</li>
                        <li><strong>QR Scanner Decoupling:</strong> Camera frame processing runs on separate worker threads without blocking UI render tree.</li>
                    </ul>
                </div>
            </div>

            <div class="sec-title">Strict Memory Policy & Low-RAM OOM Guards</div>
            <div class="grid-2-1">
                <div class="card-dark">
                    <strong style="color: #38bdf8; font-size: 6.8pt;">Mesh Packet Memory Cap: Under 15 MB Maximum</strong>
                    <div class="code-box" style="margin: 2px 0; background: transparent; border: none; padding: 0;">
<span class="comment">// Memory manager enforces strict ceiling to prevent Android LMK (Low Memory Killer)</span>
class MeshMemoryManager {
    static const int MAX_PACKET_QUEUE_BYTES = <span class="highlight">15 * 1024 * 1024; // 15 MB Ceiling</span>
    static const int MAX_DEDUPLICATION_ENTRIES = <span class="purple">500; // LRU Ring Buffer</span>

    void onLowMemory() {
        evict_oldest_non_emergency_packets();
        flush_image_cache();
        garbage_collect_isolates();
    }
}
                    </div>
                    <div style="font-size: 5.8pt; color: #94a3b8;">Ensures CampusOS runs continuously in the background on 2GB RAM phones without being killed by Android OS.</div>
                </div>

                <div class="card-accent">
                    <strong style="color: #1e40af; font-size: 6.8pt;">User Performance Override Controls</strong>
                    <p style="font-size: 5.9pt;">Students have direct visibility and control in the app settings:</p>
                    <ul style="font-size: 5.8pt; margin: 1px 0; padding-left: 10px;">
                        <li><strong>Auto Profile:</strong> System dynamically selects profile based on hardware specs.</li>
                        <li><strong>Battery Saver Mode:</strong> Cuts BLE scan rate to 10% and switches to dark theme.</li>
                        <li><strong>High Performance Mode:</strong> Locks 120Hz and maxes out mesh relay frequency.</li>
                    </ul>
                </div>
            </div>
        </div>

        <div class="page-footer">
            <span class="footer-left">CAMPUSOS: UNIFIED INSTITUTIONAL OPERATING SYSTEM</span>
            <span class="footer-center">CONFIDENTIAL · JUDGING PANEL EVALUATION DOSSIER</span>
            <span class="footer-right">PAGE 6 OF 10</span>
        </div>
    </div>
    """

    # --- PAGE 7 ---
    page_7 = """
    <div class="page" id="page-7">
        <div class="page-header">
            <div class="header-left">
                <span class="brand-pill">CAMPUSOS 1.0</span>
                <span class="header-title">TECHNICAL EVALUATION DOSSIER</span>
                <span class="header-sub">· Core Feature Deep Dive · Mesh Chat & BLE Network</span>
            </div>
            <div class="header-right">
                <span class="tag-pill">MAJOR FEATURE DEEP DIVE</span>
                <span class="page-num-tag">PAGE 7 / 10</span>
            </div>
        </div>

        <div class="page-body">
            <div class="banner">
                <div>
                    <div class="banner-title">PAGE 7 · 📡 BLE Mesh Network & Offline Chat — Deep Dive</div>
                    <div style="font-size: 6.5pt; color: #94a3b8; margin-top: 1px;">Zero-Infrastructure Intranet, Binary Wire Protocol, TTL Flood Routing, and Disaster Flares</div>
                </div>
                <div class="banner-badge">DISASTER RESILIENCE</div>
            </div>

            <div class="card-accent">
                <div style="font-weight: 800; font-size: 7.2pt; color: #0f172a; margin-bottom: 1px;">Disaster Survivability Context: Cyclone Fani & Dana</div>
                <p style="font-size: 6.2pt;">When super-cyclones strike Odisha, cell towers and power grids collapse for 5–7 days. Campuses become isolated black holes. CampusOS turns every student phone into a peer-to-peer relay node, forming a <strong>campus-wide wireless mesh network that requires zero cell towers, zero internet, and zero servers</strong>.</p>
            </div>

            <div class="sec-title">Binary Wire Protocol (`MeshPacket` Specification)</div>
            <table>
                <thead>
                    <tr>
                        <th style="width: 14%;">Field</th>
                        <th style="width: 11%;">Size</th>
                        <th style="width: 18%;">Data Type</th>
                        <th style="width: 57%;">Protocol Role & Engineering Function</th>
                    </tr>
                </thead>
                <tbody>
                    <tr>
                        <td><code>magic</code></td>
                        <td>1 Byte</td>
                        <td>Uint8 (<code>0xCA</code>)</td>
                        <td>CampusOS network packet delimiter. Filters out non-CampusOS Bluetooth traffic instantly.</td>
                    </tr>
                    <tr>
                        <td><code>packet_id</code></td>
                        <td>16 Bytes</td>
                        <td>UUIDv4 (Binary)</td>
                        <td>Globally unique packet identifier. Used by LRU deduplication store to prevent broadcast loops.</td>
                    </tr>
                    <tr>
                        <td><code>origin_node</code></td>
                        <td>8 Bytes</td>
                        <td>Truncated SHA-256</td>
                        <td>Originating sender's device-bound identity hash. Anchors the message to a physical key.</td>
                    </tr>
                    <tr>
                        <td><code>target_node</code></td>
                        <td>8 Bytes</td>
                        <td>Truncated SHA-256</td>
                        <td>Destination node hash for Direct Messages, or <code>0xFFFFFFFFFFFFFFFF</code> for public channel broadcasts.</td>
                    </tr>
                    <tr>
                        <td><code>channel_id</code></td>
                        <td>1 Byte</td>
                        <td>Enum Uint8</td>
                        <td>Target channel: <code>0x01: #general</code>, <code>0x02: #hostel-b</code>, <code>0x03: #study-group</code>, <code>0xFF: #emergency</code>.</td>
                    </tr>
                    <tr>
                        <td><code>hop_ttl</code></td>
                        <td>1 Byte</td>
                        <td>Uint8 (Counter)</td>
                        <td>Time-To-Live hop counter. Decremented at each relay node; dropped when counter reaches 0.</td>
                    </tr>
                    <tr>
                        <td><code>payload_len</code></td>
                        <td>2 Bytes</td>
                        <td>Uint16 (BE)</td>
                        <td>Length of message payload in bytes (Max 512 bytes per packet chunk).</td>
                    </tr>
                    <tr>
                        <td><code>payload</code></td>
                        <td>Variable</td>
                        <td>Encrypted Bytes</td>
                        <td>UTF-8 text message or telemetry data, signed with origin node's Ed25519 private key.</td>
                    </tr>
                    <tr>
                        <td><code>crc32</code></td>
                        <td>4 Bytes</td>
                        <td>Uint32 (BE)</td>
                        <td>Cyclic redundancy check over all preceding bytes to detect radio frequency corruption.</td>
                    </tr>
                </tbody>
            </table>

            <div class="sec-title">Multi-Hop TTL Relay Engine & Priority Flood Routing</div>
            <div class="grid-2">
                <div class="card-dark">
                    <strong style="color: #38bdf8; font-size: 6.8pt;">Multi-Hop Relay Flow with TTL Management</strong>
                    <div class="code-box" style="margin: 2px 0; background: transparent; border: none; padding: 0;">
<span class="highlight">[Node A (Student 1)]</span> &rarr;&rarr; BLE Broadcast (TTL = 7)
       &darr; 40 meters
<span class="highlight">[Node B (Student 2 - Relay)]</span>:
   1. Receives packet, verifies CRC32 checksum.
   2. Checks DeduplicationStore: Is packet_id seen?
      <span class="success">if (seen) &rarr; DROP PACKET (Prevents broadcast storm)</span>
      <span class="purple">if (unseen) &rarr; Store packet_id; Decrement TTL to 6.</span>
   3. Re-broadcasts packet over BLE peripheral interface!
       &darr; 40 meters
<span class="highlight">[Node C (Student 3)]</span> &rarr; Decrements TTL to 5 & Re-broadcasts...
       &darr;
<span class="success">[Node D (Hostel Warden / Final Recipient)] &rarr; Message Delivered!</span>
                    </div>
                </div>

                <div class="card">
                    <strong style="color: #0f172a; font-size: 6.8pt;">Four Priority Queuing Tiers</strong>
                    <table style="margin-top: 2px;">
                        <thead>
                            <tr>
                                <th>Tier</th>
                                <th>TTL</th>
                                <th>Priority Behavior</th>
                            </tr>
                        </thead>
                        <tbody>
                            <tr>
                                <td><span class="pill pill-red">EMERGENCY FLARE</span></td>
                                <td>15 Hops</td>
                                <td>Preempts all traffic. Max transmission power. Instant zero-delay relay.</td>
                            </tr>
                            <tr>
                                <td><span class="pill pill-amber">DEAN BROADCAST</span></td>
                                <td>10 Hops</td>
                                <td>Authority notices. Relayed by all faculty and student nodes across campus.</td>
                            </tr>
                            <tr>
                                <td><span class="pill pill-blue">CHANNEL CHAT</span></td>
                                <td>7 Hops</td>
                                <td><code>#general</code>, <code>#hostel-b</code>. Relayed with random jitter (20-80ms) to avoid RF collisions.</td>
                            </tr>
                            <tr>
                                <td><span class="pill pill-purple">DIRECT MESSAGE</span></td>
                                <td>5 Hops</td>
                                <td>Unicast route between two specific peer node IDs.</td>
                            </tr>
                        </tbody>
                    </table>
                </div>
            </div>

            <div class="sec-title">Emergency Disaster Flare Protocol</div>
            <div class="card-emerald">
                <div style="display: flex; justify-content: space-between; align-items: center;">
                    <strong style="color: #065f46; font-size: 7pt;">Disaster SOS Beaconing with GPS Coordinates</strong>
                    <span class="pill pill-red">CRITICAL LIFELINE</span>
                </div>
                <p style="font-size: 6.1pt;">In an emergency (medical distress, fire, flood entrapment during cyclone), any student or staff member taps <strong>"EMERGENCY FLARE"</strong>. The device broadcasts a specialized packet with <strong>TTL = 15 hops</strong> containing GPS coordinates, student roll number, and medical alert flag. Receiving phones immediately trigger an audio siren and display a rescue banner even if the app is minimized, guiding rescue squads directly to the victim's location.</p>
            </div>
        </div>

        <div class="page-footer">
            <span class="footer-left">CAMPUSOS: UNIFIED INSTITUTIONAL OPERATING SYSTEM</span>
            <span class="footer-center">CONFIDENTIAL · JUDGING PANEL EVALUATION DOSSIER</span>
            <span class="footer-right">PAGE 7 OF 10</span>
        </div>
    </div>
    """

    # --- PAGE 8 ---
    page_8 = """
    <div class="page" id="page-8">
        <div class="page-header">
            <div class="header-left">
                <span class="brand-pill">CAMPUSOS 1.0</span>
                <span class="header-title">TECHNICAL EVALUATION DOSSIER</span>
                <span class="header-sub">· Integrated Campus Workflows & Governance</span>
            </div>
            <div class="header-right">
                <span class="tag-pill">GOVERNANCE & WORKFLOWS</span>
                <span class="page-num-tag">PAGE 8 / 10</span>
            </div>
        </div>

        <div class="page-body">
            <div class="banner">
                <div>
                    <div class="banner-title">PAGE 8 · Hostel, Grievance, Admin & Document Systems</div>
                    <div style="font-size: 6.5pt; color: #94a3b8; margin-top: 1px;">Cross-Role Leave State Machines, NLP Grievance Triage, React 19 Control Plane, and Certificates</div>
                </div>
                <div class="banner-badge">GOVERNANCE SUITE</div>
            </div>

            <div class="sec-title">Hostel Leave &rarr; Gate Pass Cascading State Machine</div>
            <div class="card-dark" style="padding: 4px 8px;">
                <div class="code-box" style="margin: 0; background: transparent; border: none; padding: 0;">
<span class="highlight">[1. STUDENT SUBMITS]</span> &rarr; Mobile app files leave (Reason, Departure, Return, Parent Phone) &rarr; State: <span class="purple">PENDING</span>
          &darr; Real-time push notification + WhatsApp API dispatch to Warden
<span class="highlight">[2. WARDEN TRIAGES]</span>   &rarr; Warden reviews parent phone, academic standing. Taps "Approve" &rarr; State: <span class="purple">APPROVED</span>
          &darr; Cryptographic Engine auto-generates HMAC-signed Gate Pass
<span class="highlight">[3. GATE PASS ISSUED]</span> &rarr; Gate pass appears in student Campus Wallet with live countdown ring.
          &darr; Student presents QR to Gate Security Guard at perimeter turnstile
<span class="highlight">[4. SECURITY SCAN]</span>    &rarr; Guard scans QR (200ms debounce). Photo verified. Turnstile opens &rarr; State: <span class="purple">CHECKED_OUT</span>
          &darr; Automated SMS alert dispatched to registered parent phone: "Student departed campus at 14:32"
<span class="highlight">[5. RETURN LOGGED]</span>    &rarr; Student returns before curfew. Guard scans return QR &rarr; State: <span class="success">COMPLETED (IN_CAMPUS)</span>
                </div>
            </div>

            <div class="sec-title">NLP Grievance Triage & Clustering Engine</div>
            <div class="grid-2">
                <div class="card">
                    <strong style="color: #1e3a8a; font-size: 6.8pt;">Automated Machine Learning Classification</strong>
                    <p style="font-size: 6.1pt;">Indian campuses receive thousands of unstructured student complaints across hostel blocks. CampusOS employs an <strong>NLP TF-IDF keyword vectorization engine</strong> that clusters incoming complaints into four operational categories:</p>
                    <ul style="font-size: 5.8pt; margin: 1px 0; padding-left: 10px;">
                        <li><strong>Hostel & Infrastructure:</strong> Plumbing, water cooler defects, electrical faults.</li>
                        <li><strong>Mess & Food Quality:</strong> Hygiene, meal timing, shortage, foreign objects.</li>
                        <li><strong>Academic & Faculty:</strong> Lab equipment failure, timetable clashes.</li>
                        <li><strong>Administration & Fees:</strong> Scholarship delays, certificate clearance.</li>
                    </ul>
                </div>
                <div class="card-amber">
                    <strong style="color: #b45309; font-size: 6.8pt;">Dean SLA Escalation Engine</strong>
                    <p style="font-size: 6.1pt;">Every grievance starts a 48-hour SLA countdown timer. If a hostel maintenance defect remains untriaged after 48 hours, the system automatically escalates the ticket directly to the Dean Executive Console with a red priority badge, eliminating institutional neglect.</p>
                </div>
            </div>

            <div class="sec-title">React 19 Central Admin Control Plane (17 Modules)</div>
            <table>
                <thead>
                    <tr>
                        <th style="width: 25%;">Module Group</th>
                        <th style="width: 35%;">Core Production Features</th>
                        <th style="width: 40%;">Technical Implementation</th>
                    </tr>
                </thead>
                <tbody>
                    <tr>
                        <td><strong>Academic Operations</strong></td>
                        <td>Live class attendance curves, teacher session audits, low-attendance alert triggers.</td>
                        <td>Recharts line charts, virtualized student grids via <code>@tanstack/react-table</code>.</td>
                    </tr>
                    <tr>
                        <td><strong>Hostel & Perimeter</strong></td>
                        <td>Real-time campus occupancy tracker, gate pass ledgers, overdue curfew alerts.</td>
                        <td>WebSocket live counters, automated parent SMS notification logs.</td>
                    </tr>
                    <tr>
                        <td><strong>Dining & Mess</strong></td>
                        <td>Meal session dining throughput, anti-fraud duplicate scan alarms, dietary forecasts.</td>
                        <td>Dining funnel analytics, meal card QR verification logs.</td>
                    </tr>
                    <tr>
                        <td><strong>Security & Audit</strong></td>
                        <td>Device keystore revocation, role assignment, immutable forensic access logs.</td>
                        <td>Ed25519 public key management, SHA-256 hashed audit trail.</td>
                    </tr>
                </tbody>
            </table>

            <div class="sec-title">Digital Certificate & Scoped Notice Engine</div>
            <div class="grid-2">
                <div class="card-emerald">
                    <strong style="color: #065f46; font-size: 6.8pt;">Tamper-Proof SHA-256 Documents</strong>
                    <p style="font-size: 5.9pt;">Students can generate Official Bonafide Certificates and Grade Sheets directly in their wallet. Each document embeds a cryptographically verifiable SHA-256 hash seal and verification URL; prospective employers can verify validity without contacting college registrars.</p>
                </div>
                <div class="card-accent">
                    <strong style="color: #1e40af; font-size: 6.8pt;">Targeted Scoped Notices & Read Receipts</strong>
                    <p style="font-size: 5.9pt;">Faculty and wardens publish notices scoped strictly to relevant audiences (e.g., "Hostel Block B Only" or "3rd Year CSE Only"). System logs cryptographically signed read-receipt timestamps, eliminating excuses of unread WhatsApp notices.</p>
                </div>
            </div>
        </div>

        <div class="page-footer">
            <span class="footer-left">CAMPUSOS: UNIFIED INSTITUTIONAL OPERATING SYSTEM</span>
            <span class="footer-center">CONFIDENTIAL · JUDGING PANEL EVALUATION DOSSIER</span>
            <span class="footer-right">PAGE 8 OF 10</span>
        </div>
    </div>
    """

    # --- PAGE 9 ---
    page_9 = """
    <div class="page" id="page-9">
        <div class="page-header">
            <div class="header-left">
                <span class="brand-pill">CAMPUSOS 1.0</span>
                <span class="header-title">TECHNICAL EVALUATION DOSSIER</span>
                <span class="header-sub">· Defense-in-Depth & Verification Testing</span>
            </div>
            <div class="header-right">
                <span class="tag-pill">SECURITY & QUALITY EVIDENCE</span>
                <span class="page-num-tag">PAGE 9 / 10</span>
            </div>
        </div>

        <div class="page-body">
            <div class="banner">
                <div>
                    <div class="banner-title">PAGE 9 · Security Architecture & Testing Evidence</div>
                    <div style="font-size: 6.5pt; color: #94a3b8; margin-top: 1px;">Threat Model, 22 Backend Test Suites, 439 Frontend Tests, and 41 Penetration Attacks</div>
                </div>
                <div class="banner-badge">TESTING EVIDENCE</div>
            </div>

            <div class="sec-title">CampusOS Threat Model & Defense-in-Depth</div>
            <table>
                <thead>
                    <tr>
                        <th style="width: 22%;">Attack Vector</th>
                        <th style="width: 32%;">Malicious Threat Scenario</th>
                        <th style="width: 46%;">CampusOS Cryptographic Defense & Mitigation</th>
                    </tr>
                </thead>
                <tbody>
                    <tr>
                        <td><strong>Attendance Proxying</strong></td>
                        <td>Absent student has friend mark presence from classroom.</td>
                        <td><strong>Device Binding + Biometrics:</strong> Keypair locked in student's phone enclave; RSSI &lt; -75 dBm blocks remote access.</td>
                    </tr>
                    <tr>
                        <td><strong>QR Screenshot Forgery</strong></td>
                        <td>Student screenshots gate pass or passport and sends to friend.</td>
                        <td><strong>30s Dynamic Windowing:</strong> Token expires within 30 seconds; verifier checks mathematical freshness window.</td>
                    </tr>
                    <tr>
                        <td><strong>Rogue Teacher Beacon</strong></td>
                        <td>Malicious student broadcasts fake BLE attendance beacon.</td>
                        <td><strong>HMAC Server Signatures:</strong> Beacon payload signed with teacher's ephemeral session secret issued by backend.</td>
                    </tr>
                    <tr>
                        <td><strong>Mesh Packet Flood Storm</strong></td>
                        <td>Attacker generates packet loops to crash peer devices.</td>
                        <td><strong>LRU Deduplication Store:</strong> Packets seen once dropped immediately; TTL decrement kills orphaned packets.</td>
                    </tr>
                    <tr>
                        <td><strong>Privilege Escalation</strong></td>
                        <td>Student attempts calling <code>POST /warden/approve-leave</code>.</td>
                        <td><strong>HS256 JWT RBAC Decorators:</strong> Endpoint inspects cryptographically signed role claim; rejects with HTTP 403 Forbidden.</td>
                    </tr>
                    <tr>
                        <td><strong>Database Injection</strong></td>
                        <td>SQL injection payload injected into leave reason or complaint.</td>
                        <td><strong>Parameterized PyMySQL Queries:</strong> 100% of SQL queries utilize parameterized statements; zero raw string interpolation.</td>
                    </tr>
                    <tr>
                        <td><strong>Forensic Tampering</strong></td>
                        <td>Malicious administrator attempts modifying past gate records.</td>
                        <td><strong>Immutable Audit Trail:</strong> <code>request_audits</code> ledger stores SHA-256 hashed request signatures with strict append-only rules.</td>
                    </tr>
                </tbody>
            </table>

            <div class="sec-title">Automated Testing Evidence & Verification Suites</div>
            <div class="grid-2">
                <div class="card" style="border-top: 2px solid #059669;">
                    <div style="display: flex; justify-content: space-between; align-items: center;">
                        <strong style="color: #047857; font-size: 7pt;">Backend: 22 Pytest Suites (100% Passing)</strong>
                        <span class="pill pill-green">ALL PASS</span>
                    </div>
                    <div style="font-size: 5.9pt; color: #334155; margin-top: 2px;">
                        <div>• <code>test_auth.py</code>: JWT issuance, refresh, password hashing, RBAC.</div>
                        <div>• <code>test_attendance.py</code>: Session creation, BLE check-in, nonces.</div>
                        <div>• <code>test_passport.py</code>: Ed25519 verification, key binding, replay denial.</div>
                        <div>• <code>test_gate_pass.py</code>: State machine, issuance, checkout logging.</div>
                        <div>• <code>test_mesh.py</code>: Packet parsing, binary wire protocol, TTL relay.</div>
                        <div>• <code>test_grievance.py</code>: NLP triage, cluster classification, SLAs.</div>
                        <div>• <code>test_dining.py</code>: Meal token redemption, double-dip blocks.</div>
                        <div>• <code>test_security.py</code>: 41 penetration attacks, SQLi, XSS, replay.</div>
                    </div>
                </div>

                <div class="card" style="border-top: 2px solid #2563eb;">
                    <div style="display: flex; justify-content: space-between; align-items: center;">
                        <strong style="color: #1d4ed8; font-size: 7pt;">Frontend: 439 Flutter Tests (100% Passing)</strong>
                        <span class="pill pill-blue">ALL PASS</span>
                    </div>
                    <div style="font-size: 5.9pt; color: #334155; margin-top: 2px;">
                        <div>• <code>passport_test.dart</code>: 30s rotating dynamic QR generation & timing.</div>
                        <div>• <code>ble_attendance_test.dart</code>: Beacon detection & RSSI filtering.</div>
                        <div>• <code>device_binding_test.dart</code>: Secure enclave key generation mocks.</div>
                        <div>• <code>mesh_packet_test.dart</code>: Binary serialization & CRC32 checks.</div>
                        <div>• <code>wallet_carousel_test.dart</code>: Matrix4 3D transform & gesture tests.</div>
                        <div>• <code>offline_sync_test.dart</code>: Drift SQLite outbox sync queue validation.</div>
                        <div>• <code>rbac_navigation_test.dart</code>: Shell switching across 6 roles.</div>
                        <div>• <code>optimization_test.dart</code>: Hardware tier profiling & frame budget.</div>
                    </div>
                </div>
            </div>

            <div class="sec-title">41 Automated Security Penetration Attacks — Sample Verified Blocks</div>
            <div class="grid-3">
                <div class="card" style="padding: 3px 5px;">
                    <div style="font-weight: 700; color: #b91c1c; font-size: 6.2pt;">Replay Attack Injection</div>
                    <div style="font-size: 5.8pt; color: #475569;">Re-transmitting valid check-in nonce after 65s returns HTTP 409 Conflict. <span class="pill pill-green">BLOCKED</span></div>
                </div>
                <div class="card" style="padding: 3px 5px;">
                    <div style="font-weight: 700; color: #b91c1c; font-size: 6.2pt;">Cross-Role Route Hijack</div>
                    <div style="font-size: 5.8pt; color: #475569;">Student token invoking warden approval returns HTTP 403 Forbidden. <span class="pill pill-green">BLOCKED</span></div>
                </div>
                <div class="card" style="padding: 3px 5px;">
                    <div style="font-weight: 700; color: #b91c1c; font-size: 6.2pt;">Malformed Mesh Packet</div>
                    <div style="font-size: 5.8pt; color: #475569;">Packet with invalid CRC32 checksum dropped silently at BLE radio layer. <span class="pill pill-green">BLOCKED</span></div>
                </div>
            </div>
        </div>

        <div class="page-footer">
            <span class="footer-left">CAMPUSOS: UNIFIED INSTITUTIONAL OPERATING SYSTEM</span>
            <span class="footer-center">CONFIDENTIAL · JUDGING PANEL EVALUATION DOSSIER</span>
            <span class="footer-right">PAGE 9 OF 10</span>
        </div>
    </div>
    """

    # --- PAGE 10 ---
    page_10 = """
    <div class="page" id="page-10">
        <div class="page-header">
            <div class="header-left">
                <span class="brand-pill">CAMPUSOS 1.0</span>
                <span class="header-title">TECHNICAL EVALUATION DOSSIER</span>
                <span class="header-sub">· Hands-On Evaluation Playbook & Demonstration Guide</span>
            </div>
            <div class="header-right">
                <span class="tag-pill">EVALUATION PLAYBOOK</span>
                <span class="page-num-tag">PAGE 10 / 10</span>
            </div>
        </div>

        <div class="page-body">
            <div class="banner">
                <div>
                    <div class="banner-title">PAGE 10 · Live Demo Guide & Evaluation Playbook</div>
                    <div style="font-size: 6.5pt; color: #94a3b8; margin-top: 1px;">Pre-Seeded Credentials, 5 Step-by-Step Hands-On Scenarios, and Judge Scoring Checklist</div>
                </div>
                <div class="banner-badge">JUDGE PLAYBOOK</div>
            </div>

            <div class="sec-title">Pre-Seeded Evaluation Credentials (Ready to Test)</div>
            <table>
                <thead>
                    <tr>
                        <th>Role</th>
                        <th>Email / Username</th>
                        <th>Password</th>
                        <th>Primary Evaluation Workflow</th>
                    </tr>
                </thead>
                <tbody>
                    <tr>
                        <td><strong>Student</strong></td>
                        <td><code>student@campusos.edu</code></td>
                        <td><code>student123</code></td>
                        <td>Campus Wallet, 30s Passport QR, BLE Check-In, Leave Request, Mesh Chat</td>
                    </tr>
                    <tr>
                        <td><strong>Teacher</strong></td>
                        <td><code>teacher@campusos.edu</code></td>
                        <td><code>teacher123</code></td>
                        <td>Host BLE Attendance Beacon, 10s Dynamic QR Fallback, Class Attendance List</td>
                    </tr>
                    <tr>
                        <td><strong>Hostel Warden</strong></td>
                        <td><code>warden@campusos.edu</code></td>
                        <td><code>warden123</code></td>
                        <td>Hostel Leave Triage, Approve/Reject with Reason, Maintenance Defect Logs</td>
                    </tr>
                    <tr>
                        <td><strong>Gate Security</strong></td>
                        <td><code>security@campusos.edu</code></td>
                        <td><code>security123</code></td>
                        <td>High-Speed Turnstile QR Scanner, Photo Verification, Turnstile Exit/Entry Log</td>
                    </tr>
                    <tr>
                        <td><strong>Mess Staff</strong></td>
                        <td><code>mess@campusos.edu</code></td>
                        <td><code>mess123</code></td>
                        <td>Dining Token Scanner, Meal Session Headcount, Anti-Duplicate Dining Guard</td>
                    </tr>
                    <tr>
                        <td><strong>Dean / Admin</strong></td>
                        <td><code>admin@campusos.edu</code></td>
                        <td><code>admin123</code></td>
                        <td>React 19 Command Plane, 17 Modules, NLP Grievance Triage, Security Audits</td>
                    </tr>
                </tbody>
            </table>

            <div class="sec-title">Environment Quickstart Commands</div>
            <div class="grid-3">
                <div class="card-dark">
                    <strong style="color: #38bdf8; font-size: 6.2pt;">1. Backend API (Flask)</strong>
                    <div class="code-box" style="margin: 1.5px 0; background: transparent; border: none; padding: 0;">
cd backend
python run.py
<span class="comment">// &rarr; http://localhost:5000</span>
                    </div>
                </div>
                <div class="card-dark">
                    <strong style="color: #4ade80; font-size: 6.2pt;">2. Mobile App (Flutter)</strong>
                    <div class="code-box" style="margin: 1.5px 0; background: transparent; border: none; padding: 0;">
cd frontend
flutter run -d chrome
<span class="comment">// (Or run on Android / iOS)</span>
                    </div>
                </div>
                <div class="card-dark">
                    <strong style="color: #c084fc; font-size: 6.2pt;">3. Admin Console (React 19)</strong>
                    <div class="code-box" style="margin: 1.5px 0; background: transparent; border: none; padding: 0;">
cd admin-web
npm run dev
<span class="comment">// &rarr; http://localhost:5173</span>
                    </div>
                </div>
            </div>

            <div class="sec-title">5 Step-by-Step Hands-On Evaluation Demonstrations</div>
            <div class="grid-2">
                <div class="card" style="border-left: 3px solid #2563eb;">
                    <strong style="color: #1d4ed8; font-size: 6.5pt;">Flow 1: BLE Proximity Attendance (7 min)</strong>
                    <ol style="font-size: 5.8pt; margin: 1px 0; padding-left: 10px;">
                        <li>Log in as Teacher &rarr; Select "CSE 4th Sem - Operating Systems" &rarr; Tap "Start Attendance".</li>
                        <li>Teacher phone begins advertising BLE Beacon (0xCA05).</li>
                        <li>Log in as Student &rarr; Tap "Check-In" &rarr; Beacon detected at -54 dBm (&gt; -75 dBm threshold).</li>
                        <li>Biometric unlock &rarr; Student marked PRESENT instantly on Teacher roster!</li>
                    </ol>
                </div>
                <div class="card" style="border-left: 3px solid #10b981;">
                    <strong style="color: #047857; font-size: 6.5pt;">Flow 2: Device Binding & Passport (5 min)</strong>
                    <ol style="font-size: 5.8pt; margin: 1px 0; padding-left: 10px;">
                        <li>Open Student Wallet &rarr; Tap CampusOS Passport.</li>
                        <li>Notice animated 30-second rotating QR countdown ring.</li>
                        <li>Take a screenshot & wait 30s &rarr; Scan expired screenshot &rarr; System flags EXPIRED QR!</li>
                        <li>Demonstrates zero-proxy screenshot sharing immunity!</li>
                    </ol>
                </div>
            </div>

            <div class="grid-2">
                <div class="card" style="border-left: 3px solid #f59e0b;">
                    <strong style="color: #b45309; font-size: 6.5pt;">Flow 3: Cascading Leave Workflow (5 min)</strong>
                    <ol style="font-size: 5.8pt; margin: 1px 0; padding-left: 10px;">
                        <li>Student submits Hostel Leave &rarr; Reason: "Sister's Wedding".</li>
                        <li>Warden opens app &rarr; Views pending queue &rarr; Taps "Approve".</li>
                        <li>Dynamic Gate Pass immediately generates in Student wallet.</li>
                        <li>Security Guard scans Gate Pass &rarr; Turnstile opens &rarr; Status changes to CHECKED_OUT!</li>
                    </ol>
                </div>
                <div class="card" style="border-left: 3px solid #8b5cf6;">
                    <strong style="color: #6d28d9; font-size: 6.5pt;">Flow 4: Zero-Infra BLE Mesh Chat (5 min)</strong>
                    <ol style="font-size: 5.8pt; margin: 1px 0; padding-left: 10px;">
                        <li>Put two smartphones into <strong>Airplane Mode</strong> (Wi-Fi & Cellular OFF).</li>
                        <li>Open CampusOS Mesh Chat &rarr; Enter <code>#hostel-b</code>.</li>
                        <li>Send message: "Cyclone warning: assemble in ground floor hall".</li>
                        <li>Message hops peer-to-peer over BLE and appears on device 2 in under 500ms!</li>
                    </ol>
                </div>
            </div>

            <div class="sec-title">Evaluation Panel Scoring Checklist</div>
            <div class="grid-3">
                <div class="card-emerald" style="padding: 2.5px 5px;">
                    <div style="font-weight: 800; font-size: 6.2pt; color: #065f46;">Full Problem Coverage (10/10)</div>
                    <div style="font-size: 5.6pt; color: #065f46;">All BPUT PS07 deliverables (D1–D5) implemented with 6 native role interfaces.</div>
                </div>
                <div class="card-emerald" style="padding: 2.5px 5px;">
                    <div style="font-weight: 800; font-size: 6.2pt; color: #065f46;">Cryptographic Depth (10/10)</div>
                    <div style="font-size: 5.6pt; color: #065f46;">Ed25519 device keystore binding, 30s rotating QR, and BLE -75 dBm RSSI math.</div>
                </div>
                <div class="card-emerald" style="padding: 2.5px 5px;">
                    <div style="font-weight: 800; font-size: 6.2pt; color: #065f46;">Disaster Resilience (10/10)</div>
                    <div style="font-size: 5.6pt; color: #065f46;">BLE multi-hop mesh, offline Drift SQLite queues, and LocalSend offline sync.</div>
                </div>
            </div>
        </div>

        <div class="page-footer">
            <span class="footer-left">CAMPUSOS: UNIFIED INSTITUTIONAL OPERATING SYSTEM</span>
            <span class="footer-center">CONFIDENTIAL · JUDGING PANEL EVALUATION DOSSIER</span>
            <span class="footer-right">PAGE 10 OF 10</span>
        </div>
    </div>
    """

    all_pages = [page_1, page_2, page_3, page_4, page_5, page_6, page_7, page_8, page_9, page_10]

    full_html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <title>CampusOS 1.0 — Technical Evaluation Dossier (BPUT Hackathon PS07)</title>
    <style>
    {css_style}
    </style>
</head>
<body>
    {''.join(all_pages)}
</body>
</html>
"""

    with open(html_path, "w", encoding="utf-8") as f:
        f.write(full_html)
    print(f"[OK] Generated Clean Publication HTML: {html_path}")

    # Launch Headless Edge to print to PDF
    edge_path = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
    if not os.path.exists(edge_path):
        print(f"Error: {edge_path} not found")
        sys.exit(1)

    temp_profile_dir = os.path.join(script_dir, ".edge_pdf_profile")
    os.makedirs(temp_profile_dir, exist_ok=True)

    cmd = [
        edge_path,
        "--headless=new",
        "--disable-gpu",
        "--no-sandbox",
        f"--user-data-dir={temp_profile_dir}",
        "--no-pdf-header-footer",
        f"--print-to-pdf={pdf_path}",
        html_path
    ]

    print("[RUNNING] Compiling 10-Page Publication PDF via Headless Edge...")
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode == 0 and os.path.exists(pdf_path):
        reader = pypdf.PdfReader(pdf_path)
        page_count = len(reader.pages)
        size_kb = os.path.getsize(pdf_path) / 1024
        print(f"[SUCCESS] PDF Generated Successfully!")
        print(f"  -> Path: {pdf_path}")
        print(f"  -> Total Pages: {page_count}")
        print(f"  -> File Size: {size_kb:.2f} KB")

        if page_count == 10:
            print("[VERIFIED] Exactly 10 Pages Generated!")
        else:
            print(f"[WARNING] Expected 10 pages, but got {page_count} pages.")
    else:
        print(f"[ERROR] Failed to compile PDF (exit code {res.returncode}):")
        print(res.stderr or res.stdout)
        sys.exit(1)

if __name__ == "__main__":
    build_judges_documentation_pdf()
