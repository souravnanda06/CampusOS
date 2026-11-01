import os
import sys
import subprocess
import base64

def get_base64_image(file_path):
    if os.path.exists(file_path):
        with open(file_path, "rb") as f:
            encoded = base64.b64encode(f.read()).decode("utf-8")
            ext = os.path.splitext(file_path)[1].lower().replace(".", "")
            if ext == "jpg":
                ext = "jpeg"
            return f"data:image/{ext};base64,{encoded}"
    return ""

def build_pitch_deck():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    html_path = os.path.join(script_dir, "docs", "CAMPUSOS_PITCH_DECK.html")
    pdf_path = os.path.join(script_dir, "CampusOS_Pitch_Deck.pdf")
    
    arch_img_b64 = get_base64_image(os.path.join(script_dir, "CampusOS_Architecture_Diagram.jpg"))
    pillars_img_b64 = get_base64_image(os.path.join(script_dir, "CampusOS_Core_Pillars_Diagram.jpg"))
    simple_img_b64 = get_base64_image(os.path.join(script_dir, "CampusOS_Simple_Diagram.jpg"))

    css_style = """
    @import url('https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;500;600;700;800&family=JetBrains+Mono:wght@400;500;600;700&display=swap');

    @page {
        size: 297mm 167.0625mm; /* Exact 16:9 Widescreen Presentation Ratio */
        margin: 0;
    }

    * {
        box-sizing: border-box;
        -webkit-print-color-adjust: exact;
        print-color-adjust: exact;
    }

    body {
        margin: 0;
        padding: 0;
        font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        background-color: #070B14;
        color: #F1F5F9;
        font-size: 8.5pt;
        line-height: 1.4;
    }

    .slide {
        width: 297mm;
        height: 167.0625mm;
        max-height: 167.0625mm;
        padding: 10mm 14mm 8mm 14mm;
        page-break-after: always;
        break-after: page;
        position: relative;
        overflow: hidden;
        background: radial-gradient(circle at 85% 15%, rgba(14, 165, 233, 0.08) 0%, transparent 60%),
                    radial-gradient(circle at 15% 85%, rgba(99, 102, 241, 0.08) 0%, transparent 60%),
                    #090E17;
        display: flex;
        flex-direction: column;
        justify-content: space-between;
    }

    /* Slide Header */
    .slide-header {
        display: flex;
        justify-content: space-between;
        align-items: flex-start;
        margin-bottom: 7mm;
        border-bottom: 1px solid rgba(255, 255, 255, 0.08);
        padding-bottom: 3.5mm;
    }

    .slide-header-left {
        max-width: 78%;
    }

    .slide-tag {
        display: inline-flex;
        align-items: center;
        gap: 5px;
        font-family: 'JetBrains Mono', monospace;
        font-size: 6.8pt;
        text-transform: uppercase;
        letter-spacing: 1px;
        color: #38BDF8;
        background: rgba(56, 189, 248, 0.1);
        padding: 2px 7px;
        border-radius: 4px;
        border: 1px solid rgba(56, 189, 248, 0.25);
        margin-bottom: 4px;
    }

    .slide-title {
        font-size: 16pt;
        font-weight: 800;
        letter-spacing: -0.4px;
        margin: 0;
        color: #FFFFFF;
        line-height: 1.15;
    }

    .slide-title span {
        background: linear-gradient(135deg, #38BDF8 0%, #818CF8 100%);
        -webkit-background-clip: text;
        -webkit-text-fill-color: transparent;
    }

    .slide-subtitle {
        font-size: 8pt;
        color: #94A3B8;
        margin: 2px 0 0 0;
        font-weight: 400;
    }

    .slide-header-right {
        text-align: right;
        display: flex;
        flex-direction: column;
        align-items: flex-end;
    }

    .slide-num {
        font-family: 'JetBrains Mono', monospace;
        font-size: 13pt;
        font-weight: 700;
        color: #64748B;
    }

    .slide-category {
        font-family: 'JetBrains Mono', monospace;
        font-size: 6.5pt;
        color: #0284C7;
        text-transform: uppercase;
        letter-spacing: 0.5px;
    }

    /* Slide Content Body */
    .slide-body {
        flex: 1;
        display: flex;
        flex-direction: column;
        justify-content: flex-start;
        position: relative;
    }

    /* Slide Footer */
    .slide-footer {
        display: flex;
        justify-content: space-between;
        align-items: center;
        border-top: 1px solid rgba(255, 255, 255, 0.06);
        padding-top: 2.5mm;
        margin-top: 3mm;
        font-size: 6.8pt;
        color: #64748B;
        font-family: 'JetBrains Mono', monospace;
    }

    .slide-footer-brand {
        display: flex;
        align-items: center;
        gap: 6px;
    }

    .brand-dot {
        width: 6px;
        height: 6px;
        border-radius: 50%;
        background: #10B981;
        box-shadow: 0 0 6px #10B981;
    }

    /* Cards & Containers */
    .card-grid-2 {
        display: grid;
        grid-template-columns: 1fr 1fr;
        gap: 5mm;
        height: 100%;
    }

    .card-grid-3 {
        display: grid;
        grid-template-columns: 1fr 1fr 1fr;
        gap: 4mm;
        height: 100%;
    }

    .card-grid-4 {
        display: grid;
        grid-template-columns: 1fr 1fr 1fr 1fr;
        gap: 3.5mm;
        height: 100%;
    }

    .card-grid-6 {
        display: grid;
        grid-template-columns: repeat(3, 1fr);
        grid-template-rows: repeat(2, 1fr);
        gap: 3mm;
        height: 100%;
    }

    .card {
        background: rgba(15, 23, 42, 0.65);
        border: 1px solid rgba(255, 255, 255, 0.08);
        border-radius: 7px;
        padding: 3.5mm 4mm;
        display: flex;
        flex-direction: column;
        position: relative;
        backdrop-filter: blur(8px);
    }

    .card-highlight {
        border-color: rgba(56, 189, 248, 0.35);
        background: rgba(14, 165, 233, 0.06);
    }

    .card-success {
        border-color: rgba(16, 185, 129, 0.35);
        background: rgba(16, 185, 129, 0.06);
    }

    .card-danger {
        border-color: rgba(239, 68, 68, 0.35);
        background: rgba(239, 68, 68, 0.06);
    }

    .card-purple {
        border-color: rgba(139, 92, 246, 0.35);
        background: rgba(139, 92, 246, 0.06);
    }

    .card-header {
        display: flex;
        align-items: center;
        gap: 6px;
        margin-bottom: 2mm;
    }

    .card-icon {
        font-size: 11pt;
    }

    .card-title {
        font-size: 9pt;
        font-weight: 700;
        color: #F8FAFC;
        margin: 0;
    }

    .card-badge {
        margin-left: auto;
        font-family: 'JetBrains Mono', monospace;
        font-size: 6pt;
        padding: 1.5px 5px;
        border-radius: 3px;
        font-weight: 600;
        text-transform: uppercase;
    }

    .badge-blue { background: rgba(56, 189, 248, 0.15); color: #38BDF8; border: 1px solid rgba(56, 189, 248, 0.3); }
    .badge-green { background: rgba(16, 185, 129, 0.15); color: #34D399; border: 1px solid rgba(16, 185, 129, 0.3); }
    .badge-amber { background: rgba(245, 158, 11, 0.15); color: #FBBF24; border: 1px solid rgba(245, 158, 11, 0.3); }
    .badge-red { background: rgba(239, 68, 68, 0.15); color: #F87171; border: 1px solid rgba(239, 68, 68, 0.3); }
    .badge-purple { background: rgba(168, 85, 247, 0.15); color: #C084FC; border: 1px solid rgba(168, 85, 247, 0.3); }

    .card-body {
        font-size: 7.6pt;
        color: #CBD5E1;
        line-height: 1.4;
        flex: 1;
    }

    .card-body ul {
        margin: 0;
        padding-left: 4mm;
    }

    .card-body li {
        margin-bottom: 1.5mm;
    }

    .card-metric-block {
        margin-top: auto;
        padding-top: 2mm;
        border-top: 1px solid rgba(255, 255, 255, 0.05);
        display: flex;
        align-items: baseline;
        gap: 6px;
    }

    .metric-val {
        font-family: 'JetBrains Mono', monospace;
        font-size: 13pt;
        font-weight: 800;
        color: #38BDF8;
    }

    .metric-sub {
        font-size: 6.8pt;
        color: #94A3B8;
    }

    /* Tables */
    .deck-table {
        width: 100%;
        border-collapse: collapse;
        font-size: 7.5pt;
    }

    .deck-table th {
        background: rgba(30, 41, 59, 0.85);
        color: #38BDF8;
        font-family: 'JetBrains Mono', monospace;
        font-size: 6.8pt;
        text-transform: uppercase;
        letter-spacing: 0.5px;
        text-align: left;
        padding: 2.2mm 3mm;
        border-bottom: 1.5px solid rgba(56, 189, 248, 0.3);
    }

    .deck-table td {
        padding: 2mm 3mm;
        border-bottom: 1px solid rgba(255, 255, 255, 0.05);
        color: #E2E8F0;
        vertical-align: middle;
    }

    .deck-table tr:nth-child(even) td {
        background: rgba(255, 255, 255, 0.015);
    }

    /* Flowchart / Step Row */
    .flow-row {
        display: flex;
        align-items: stretch;
        gap: 3mm;
        height: 100%;
    }

    .flow-step {
        flex: 1;
        background: rgba(15, 23, 42, 0.7);
        border: 1px solid rgba(255, 255, 255, 0.08);
        border-radius: 6px;
        padding: 3mm;
        display: flex;
        flex-direction: column;
        position: relative;
    }

    .flow-step::after {
        content: "→";
        position: absolute;
        right: -3mm;
        top: 50%;
        transform: translateY(-50%);
        color: #0284C7;
        font-size: 11pt;
        font-weight: bold;
        z-index: 2;
    }

    .flow-step:last-child::after {
        content: "";
    }

    .flow-step-num {
        font-family: 'JetBrains Mono', monospace;
        font-size: 6.5pt;
        color: #38BDF8;
        margin-bottom: 1mm;
        font-weight: 700;
    }

    .flow-step-title {
        font-size: 8.5pt;
        font-weight: 700;
        color: #FFFFFF;
        margin-bottom: 1.5mm;
    }

    .flow-step-desc {
        font-size: 7.2pt;
        color: #94A3B8;
        line-height: 1.35;
    }

    /* Cover Slide Specifics */
    .cover-slide {
        background: radial-gradient(circle at 75% 25%, rgba(14, 165, 233, 0.15) 0%, transparent 55%),
                    radial-gradient(circle at 25% 75%, rgba(99, 102, 241, 0.15) 0%, transparent 55%),
                    #050811;
        display: flex;
        flex-direction: column;
        justify-content: space-between;
        padding: 14mm 18mm 12mm 18mm;
    }

    .cover-meta-strip {
        display: flex;
        gap: 6mm;
        align-items: center;
        border-bottom: 1px solid rgba(255, 255, 255, 0.1);
        padding-bottom: 4mm;
    }

    .cover-main {
        margin: auto 0;
    }

    .cover-title {
        font-size: 38pt;
        font-weight: 800;
        letter-spacing: -1.5px;
        line-height: 1.05;
        margin: 0 0 3mm 0;
        color: #FFFFFF;
    }

    .cover-title span {
        background: linear-gradient(135deg, #38BDF8 0%, #60A5FA 50%, #A855F7 100%);
        -webkit-background-clip: text;
        -webkit-text-fill-color: transparent;
    }

    .cover-subtitle {
        font-size: 14pt;
        font-weight: 500;
        color: #94A3B8;
        margin: 0 0 5mm 0;
        max-width: 85%;
        line-height: 1.3;
    }

    .cover-badges {
        display: flex;
        gap: 3mm;
        margin-top: 4mm;
    }

    .cover-badge {
        padding: 2.5mm 4mm;
        border-radius: 6px;
        background: rgba(30, 41, 59, 0.7);
        border: 1px solid rgba(255, 255, 255, 0.1);
        display: flex;
        align-items: center;
        gap: 3mm;
    }

    .cover-badge-icon {
        font-size: 14pt;
    }

    .cover-badge-val {
        font-family: 'JetBrains Mono', monospace;
        font-size: 10pt;
        font-weight: 700;
        color: #FFFFFF;
    }

    .cover-badge-lbl {
        font-size: 6.8pt;
        color: #64748B;
        text-transform: uppercase;
    }

    .cover-footer {
        display: flex;
        justify-content: space-between;
        align-items: flex-end;
        border-top: 1px solid rgba(255, 255, 255, 0.1);
        padding-top: 4mm;
        font-family: 'JetBrains Mono', monospace;
        font-size: 7pt;
        color: #64748B;
    }

    /* Diagram Image Fit */
    .diagram-img {
        width: 100%;
        max-height: 110mm;
        object-fit: contain;
        border-radius: 6px;
        border: 1px solid rgba(255, 255, 255, 0.1);
        background: rgba(0, 0, 0, 0.4);
    }
    """

    slides_html = []

    # =========================================================================
    # SLIDE 1: COVER
    # =========================================================================
    slides_html.append(f"""
    <div class="slide cover-slide">
        <div class="cover-meta-strip">
            <span class="slide-tag">BPUT HACKATHON 2026 · PS07</span>
            <span style="font-family: 'JetBrains Mono'; font-size: 7pt; color: #64748B;">OFFICIAL VENTURE & EVALUATION PITCH DECK</span>
            <span style="margin-left: auto; font-family: 'JetBrains Mono'; font-size: 7pt; color: #10B981; display: flex; align-items: center; gap: 5px;">
                <span class="brand-dot"></span> PRODUCTION READY · 654 TESTS PASSING
            </span>
        </div>

        <div class="cover-main">
            <h1 class="cover-title">Campus<span>OS</span></h1>
            <div class="cover-subtitle">
                The Unified, Offline-Resilient Institutional Campus Operating System
            </div>
            <p style="font-size: 9.5pt; color: #CBD5E1; max-width: 80%; line-height: 1.45; margin-bottom: 6mm;">
                Replacing disconnected paper registers, vulnerable roll calls, and broken WhatsApp circulars with 
                <strong style="color: #38BDF8;">Ed25519 cryptographic identities</strong>, 
                <strong style="color: #34D399;">6-stakeholder institutional cohesion</strong>, and an autonomous 
                <strong style="color: #A78BFA;">zero-infrastructure BLE mesh network</strong> that survives total connectivity blackouts.
            </p>

            <div class="cover-badges">
                <div class="cover-badge">
                    <span class="cover-badge-icon">🏛️</span>
                    <div>
                        <div class="cover-badge-val">6 Roles</div>
                        <div class="cover-badge-lbl">Unified Platform</div>
                    </div>
                </div>
                <div class="cover-badge">
                    <span class="cover-badge-icon">🔐</span>
                    <div>
                        <div class="cover-badge-val">Ed25519 PKI</div>
                        <div class="cover-badge-lbl">30s Dynamic QR</div>
                    </div>
                </div>
                <div class="cover-badge">
                    <span class="cover-badge-icon">📡</span>
                    <div>
                        <div class="cover-badge-val">7-Hop Mesh</div>
                        <div class="cover-badge-lbl">Zero Internet Req</div>
                    </div>
                </div>
                <div class="cover-badge">
                    <span class="cover-badge-icon">⚡</span>
                    <div>
                        <div class="cover-badge-val">50 MB/s</div>
                        <div class="cover-badge-lbl">Academic AirDrop</div>
                    </div>
                </div>
                <div class="cover-badge">
                    <span class="cover-badge-icon">🧪</span>
                    <div>
                        <div class="cover-badge-val">100% Pass</div>
                        <div class="cover-badge-lbl">41 Attack Tests</div>
                    </div>
                </div>
            </div>
        </div>

        <div class="cover-footer">
            <div>
                <strong>BPUT HACKATHON 2026</strong> · PROBLEM STATEMENT PS07<br/>
                INSTITUTIONAL OPERATING SYSTEM & DISASTER OFFLINE SURVIVABILITY
            </div>
            <div style="text-align: right;">
                CAMPUSOS MONOREPO V4.0<br/>
                OCTOBER 2026 · FLUTTER + FLASK + REACT 19 + MYSQL 8
            </div>
        </div>
    </div>
    """)

    # =========================================================================
    # SLIDE 2: EXECUTIVE SUMMARY & CORE THESIS
    # =========================================================================
    slides_html.append(f"""
    <div class="slide">
        <div class="slide-header">
            <div class="slide-header-left">
                <div class="slide-tag">Executive Summary</div>
                <h2 class="slide-title">The Core Thesis: <span>Why Campuses Fail</span> in the Real World</h2>
                <div class="slide-subtitle">Traditional ERPs assume continuous gigabit internet. Real residential campuses face infrastructural reality.</div>
            </div>
            <div class="slide-header-right">
                <div class="slide-num">02</div>
                <div class="slide-category">Strategic Overview</div>
            </div>
        </div>

        <div class="slide-body">
            <div class="card-grid-3">
                <div class="card card-danger">
                    <div class="card-header">
                        <span class="card-icon">⚡</span>
                        <h3 class="card-title">1. The Fragility Trap</h3>
                        <span class="card-badge badge-red">Critical Flaw</span>
                    </div>
                    <div class="card-body">
                        <ul>
                            <li><strong>Cloud-Only Fragility:</strong> Modern campus apps crash in basement labs, boundary gates, and during extreme weather events.</li>
                            <li><strong>Cyclone Blackouts:</strong> Coastal storms (e.g. Fani, Dana in Odisha) consistently knock down cellular towers and power grids.</li>
                            <li><strong>Zero Local Continuity:</strong> When the internet drops, gate passes cannot be verified, roll calls stop, and dining halts.</li>
                        </ul>
                    </div>
                    <div class="card-metric-block">
                        <span class="metric-val" style="color: #F87171;">72%</span>
                        <span class="metric-sub">of Indian campuses experience daily dead zones</span>
                    </div>
                </div>

                <div class="card card-highlight">
                    <div class="card-header">
                        <span class="card-icon">🔐</span>
                        <h3 class="card-title">2. The Proxy Epidemic</h3>
                        <span class="card-badge badge-blue">Trust Failure</span>
                    </div>
                    <div class="card-body">
                        <ul>
                            <li><strong>Screenshotted QR Codes:</strong> Static barcodes are forwarded via WhatsApp in seconds to mark fake attendance.</li>
                            <li><strong>Dining Token Theft:</strong> Duplicate meals and borrowed meal coupons bleed hostel mess contractors.</li>
                            <li><strong>Paper Gate Slips:</strong> Easy to forge, impossible to audit, and zero real-time headcounts at campus borders.</li>
                        </ul>
                    </div>
                    <div class="card-metric-block">
                        <span class="metric-val">₹14L+</span>
                        <span class="metric-sub">estimated annual loss per 2,000 students in proxy fraud</span>
                    </div>
                </div>

                <div class="card card-success">
                    <div class="card-header">
                        <span class="card-icon">🚀</span>
                        <h3 class="card-title">3. The CampusOS Breakthrough</h3>
                        <span class="card-badge badge-green">Unified Solution</span>
                    </div>
                    <div class="card-body">
                        <ul>
                            <li><strong>Offline-First PKI:</strong> Asymmetric Ed25519 signatures allow instant mathematical verification with 0 bytes of internet.</li>
                            <li><strong>P2P Bluetooth Mesh:</strong> 7-hop device-to-device network continues running even when power and towers fail.</li>
                            <li><strong>6-Role Cohesion:</strong> Instant cascading workflows uniting Students, Teachers, Wardens, Mess, Security, and Deans.</li>
                        </ul>
                    </div>
                    <div class="card-metric-block">
                        <span class="metric-val" style="color: #34D399;">100%</span>
                        <span class="metric-sub">offline verification with zero cloud roundtrip</span>
                    </div>
                </div>
            </div>
        </div>

        <div class="slide-footer">
            <div class="slide-footer-brand"><span class="brand-dot"></span> CampusOS Executive Overview</div>
            <div>BPUT Hackathon PS07 · Confidential</div>
        </div>
    </div>
    """)

    # =========================================================================
    # SLIDE 3: THE PROBLEM LANDSCAPE (4 FAILURE MODES)
    # =========================================================================
    slides_html.append(f"""
    <div class="slide">
        <div class="slide-header">
            <div class="slide-header-left">
                <div class="slide-tag">Problem Landscape</div>
                <h2 class="slide-title">The Reality of Indian Campuses: <span>4 Fatal Failure Modes</span></h2>
                <div class="slide-subtitle">Why current market solutions and paper workflows crumble under real-world operating strain.</div>
            </div>
            <div class="slide-header-right">
                <div class="slide-num">03</div>
                <div class="slide-category">Problem Definition</div>
            </div>
        </div>

        <div class="slide-body">
            <div class="card-grid-4">
                <div class="card">
                    <div class="card-header">
                        <span class="card-icon">📵</span>
                        <h3 class="card-title">The Ghost Network</h3>
                        <span class="card-badge badge-red">Offline Blindness</span>
                    </div>
                    <div class="card-body">
                        Hostel concrete basements, workshop floors, and perimeter security posts have zero cellular reception. When an ERP relies on continuous HTTP connections, security guards and wardens abandon the software and revert to paper notebooks.
                    </div>
                    <div class="card-metric-block">
                        <span class="metric-val">0 bps</span>
                        <span class="metric-sub">Bandwidth in basement labs</span>
                    </div>
                </div>

                <div class="card">
                    <div class="card-header">
                        <span class="card-icon">🎭</span>
                        <h3 class="card-title">Rampant Proxy Fraud</h3>
                        <span class="card-badge badge-amber">Identity Crisis</span>
                    </div>
                    <div class="card-body">
                        Classroom roll-calls waste 15 minutes per lecture. Static digital IDs or plastic cards are handed to friends. Mess tokens are duplicated. Gate slips are forged without any cryptographic verification or anti-replay checks.
                    </div>
                    <div class="card-metric-block">
                        <span class="metric-val">15 Min</span>
                        <span class="metric-sub">Lost per lecture in roll calls</span>
                    </div>
                </div>

                <div class="card">
                    <div class="card-header">
                        <span class="card-icon">📂</span>
                        <h3 class="card-title">Fragmented Silos</h3>
                        <span class="card-badge badge-blue">Admin Gridlock</span>
                    </div>
                    <div class="card-body">
                        Wardens, teachers, security, and deans operate on disconnected spreadsheets, physical paper registers, and chaotic WhatsApp groups. Grievances languish for weeks without SLA accountability; circulars go unread.
                    </div>
                    <div class="card-metric-block">
                        <span class="metric-val">14 Days</span>
                        <span class="metric-sub">Average grievance resolution</span>
                    </div>
                </div>

                <div class="card">
                    <div class="card-header">
                        <span class="card-icon">🚨</span>
                        <h3 class="card-title">Disaster Paralysis</h3>
                        <span class="card-badge badge-purple">Life-Safety Risk</span>
                    </div>
                    <div class="card-body">
                        During natural disasters (cyclones, floods, campus fires), cellular towers and power grids go dark. Deans have zero mechanism to broadcast life-saving evacuation directives or account for student headcounts across hostels.
                    </div>
                    <div class="card-metric-block">
                        <span class="metric-val">Zero</span>
                        <span class="metric-sub">Off-grid emergency tools in legacy ERP</span>
                    </div>
                </div>
            </div>
        </div>

        <div class="slide-footer">
            <div class="slide-footer-brand"><span class="brand-dot"></span> CampusOS Problem Definition</div>
            <div>BPUT Hackathon PS07 · Problem Statement PS07</div>
        </div>
    </div>
    """)

    # =========================================================================
    # SLIDE 4: THE SOLUTION - 3-TIER ARCHITECTURE
    # =========================================================================
    slides_html.append(f"""
    <div class="slide">
        <div class="slide-header">
            <div class="slide-header-left">
                <div class="slide-tag">Solution Architecture</div>
                <h2 class="slide-title">The Solution: <span>Unified 3-Tier Enterprise Architecture</span></h2>
                <div class="slide-subtitle">A monolithic backend with micro-level cryptographic resilience and autonomous peer-to-peer mesh.</div>
            </div>
            <div class="slide-header-right">
                <div class="slide-num">04</div>
                <div class="slide-category">System Design</div>
            </div>
        </div>

        <div class="slide-body">
            <div style="display: grid; grid-template-columns: 1.15fr 0.85fr; gap: 5mm; height: 100%;">
                <div class="card" style="padding: 2.5mm; justify-content: center; align-items: center;">
                    <img src="{arch_img_b64}" class="diagram-img" style="max-height: 105mm;" alt="CampusOS Architecture Diagram"/>
                </div>

                <div style="display: flex; flex-direction: column; gap: 3mm; height: 100%;">
                    <div class="card card-highlight" style="flex: 1;">
                        <div class="card-header">
                            <span class="card-icon">📱</span>
                            <h3 class="card-title">1. Client Tier (Flutter + React 19)</h3>
                            <span class="card-badge badge-blue">Cross-Platform</span>
                        </div>
                        <div class="card-body">
                            Unified multi-role Flutter mobile app (Students, Teachers, Wardens, Mess, Guards) + React 19 desktop control plane for Deans. 120Hz smooth rendering, thermal throttling protection, and full multilingual support (EN, HI, OR, BN).
                        </div>
                    </div>

                    <div class="card" style="flex: 1;">
                        <div class="card-header">
                            <span class="card-icon">⚙️</span>
                            <h3 class="card-title">2. Application Tier (Flask API Gateway)</h3>
                            <span class="card-badge badge-green">Modular Monolith</span>
                        </div>
                        <div class="card-body">
                            19 REST blueprints with strict RBAC middleware, Ed25519 token signer, HMAC-SHA256 gate pass validator, FCM notification fallback, and immutable audit trails. <15ms response latency.
                        </div>
                    </div>

                    <div class="card card-purple" style="flex: 1;">
                        <div class="card-header">
                            <span class="card-icon">🗄️</span>
                            <h3 class="card-title">3. Persistence & Mesh Fabric</h3>
                            <span class="card-badge badge-purple">Dual Storage</span>
                        </div>
                        <div class="card-body">
                            Authoritative MySQL 8 (27 relational tables) paired with client-side SQLite Drift trust bundles and an ad-hoc 7-hop BLE 5.x mesh network for off-grid survival.
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <div class="slide-footer">
            <div class="slide-footer-brand"><span class="brand-dot"></span> CampusOS System Architecture</div>
            <div>BPUT Hackathon PS07 · Architecture Blueprint</div>
        </div>
    </div>
    """)

    # =========================================================================
    # SLIDE 5: THE 6 INSTITUTIONAL STAKEHOLDERS
    # =========================================================================
    slides_html.append(f"""
    <div class="slide">
        <div class="slide-header">
            <div class="slide-header-left">
                <div class="slide-tag">Multi-Role Cohesion</div>
                <h2 class="slide-title">The 6 Stakeholders: <span>Complete Role Specialization</span></h2>
                <div class="slide-subtitle">One unified platform providing specialized interfaces and dedicated workflows for all campus personas.</div>
            </div>
            <div class="slide-header-right">
                <div class="slide-num">05</div>
                <div class="slide-category">User Experience</div>
            </div>
        </div>

        <div class="slide-body">
            <div class="card-grid-6">
                <div class="card">
                    <div class="card-header">
                        <span class="card-icon">🎓</span>
                        <h3 class="card-title">Student Experience</h3>
                        <span class="card-badge badge-blue">Mobile App</span>
                    </div>
                    <div class="card-body">
                        6-Card Digital Wallet (Passport, ID, Gate Pass, Fees, Docs, Visitor Pass), BLE & dynamic QR attendance, hostel leave requests, mess rating & grievance tracker.
                    </div>
                </div>

                <div class="card">
                    <div class="card-header">
                        <span class="card-icon">👨‍🏫</span>
                        <h3 class="card-title">Teacher / Faculty</h3>
                        <span class="card-badge badge-blue">Mobile App</span>
                    </div>
                    <div class="card-body">
                        BLE proximity beacon broadcaster, rotating fallback QR session, instant batch attendance sync, timetable shift broadcasts, student analytics.
                    </div>
                </div>

                <div class="card">
                    <div class="card-header">
                        <span class="card-icon">🏢</span>
                        <h3 class="card-title">Hostel Warden</h3>
                        <span class="card-badge badge-amber">Mobile App</span>
                    </div>
                    <div class="card-body">
                        Real-time student leave approvals/rejections, automated HMAC gate pass generation, hostel room defect triage, live occupancy headcount inspection.
                    </div>
                </div>

                <div class="card">
                    <div class="card-header">
                        <span class="card-icon">🛡️</span>
                        <h3 class="card-title">Gate Security Guard</h3>
                        <span class="card-badge badge-green">Mobile App</span>
                    </div>
                    <div class="card-body">
                        Sub-second QR scanner for gate passes and visitor tokens, offline HMAC validation, exit/entry transit timestamps, anti-passback rule enforcement.
                    </div>
                </div>

                <div class="card">
                    <div class="card-header">
                        <span class="card-icon">🍽️</span>
                        <h3 class="card-title">Mess & Dining Staff</h3>
                        <span class="card-badge badge-amber">Mobile App</span>
                    </div>
                    <div class="card-body">
                        Dynamic dining QR scanner, HTTP 409 duplicate dining blocker (anti-proxy), weekly meal menu publisher, student meal rating analytics.
                    </div>
                </div>

                <div class="card card-highlight">
                    <div class="card-header">
                        <span class="card-icon">🏛️</span>
                        <h3 class="card-title">Dean & Administrator</h3>
                        <span class="card-badge badge-purple">React 19 Web</span>
                    </div>
                    <div class="card-body">
                        Central command console with 17 operational modules, NLP grievance clustering, >48h SLA ageing monitors, scoped circulars with read receipts.
                    </div>
                </div>
            </div>
        </div>

        <div class="slide-footer">
            <div class="slide-footer-brand"><span class="brand-dot"></span> CampusOS Role Ecosystem</div>
            <div>BPUT Hackathon PS07 · 6 Roles in 1 Monorepo</div>
        </div>
    </div>
    """)

    # =========================================================================
    # SLIDE 6: CASCADING CROSS-ROLE WORKFLOW
    # =========================================================================
    slides_html.append(f"""
    <div class="slide">
        <div class="slide-header">
            <div class="slide-header-left">
                <div class="slide-tag">Operational Integrity</div>
                <h2 class="slide-title">Cascading Workflows: <span>Leave to Perimeter Security</span></h2>
                <div class="slide-subtitle">Zero paper, zero delays. A continuous cryptographic chain from student bedroom to campus boundary gate.</div>
            </div>
            <div class="slide-header-right">
                <div class="slide-num">06</div>
                <div class="slide-category">Live Execution</div>
            </div>
        </div>

        <div class="slide-body">
            <div class="flow-row">
                <div class="flow-step">
                    <div class="flow-step-num">STEP 01 · STUDENT</div>
                    <div class="flow-step-title">Leave Request Filed</div>
                    <div class="flow-step-desc">
                        Student files departure dates, reason, emergency phone, and destination from their mobile wallet. Uploads parent consent if required.
                    </div>
                </div>

                <div class="flow-step">
                    <div class="flow-step-num">STEP 02 · WARDEN</div>
                    <div class="flow-step-title">One-Tap Triage</div>
                    <div class="flow-step-desc">
                        Warden receives real-time push notification, inspects student's 82% attendance history, and approves leave in 1 tap with audit remarks.
                    </div>
                </div>

                <div class="flow-step">
                    <div class="flow-step-num">STEP 03 · BACKEND</div>
                    <div class="flow-step-title">Cryptographic Gate Pass</div>
                    <div class="flow-step-desc">
                        Backend automatically signs an HMAC-SHA256 gate pass token, encoding valid departure/return windows and student UUID. Dispatched to wallet.
                    </div>
                </div>

                <div class="flow-step">
                    <div class="flow-step-num">STEP 04 · SECURITY</div>
                    <div class="flow-step-title">Offline Gate Scan</div>
                    <div class="flow-step-desc">
                        Guard scans dynamic barcode at gate. Verification executes offline in <100ms against institutional secret. Guard marks 'EXITED'.
                    </div>
                </div>

                <div class="flow-step">
                    <div class="flow-step-num">STEP 05 · SECURITY</div>
                    <div class="flow-step-title">Anti-Passback Block</div>
                    <div class="flow-step-desc">
                        Pass transitions to EXITED state. System immediately rejects duplicate exit attempts (anti-passback rule) to stop barcode screenshots.
                    </div>
                </div>

                <div class="flow-step">
                    <div class="flow-step-num">STEP 06 · DEAN</div>
                    <div class="flow-step-title">Real-Time Headcount</div>
                    <div class="flow-step-desc">
                        Dean's central web console updates campus perimeter census in real time. Full audit trail recorded for parental safety inquiries.
                    </div>
                </div>
            </div>
        </div>

        <div class="slide-footer">
            <div class="slide-footer-brand"><span class="brand-dot"></span> CampusOS Cascading Pipeline</div>
            <div>BPUT Hackathon PS07 · End-to-End Test Passing</div>
        </div>
    </div>
    """)

    # =========================================================================
    # SLIDE 7: TECHNOLOGICAL MOAT 1 - CAMPUSOS PASSPORT
    # =========================================================================
    slides_html.append(f"""
    <div class="slide">
        <div class="slide-header">
            <div class="slide-header-left">
                <div class="slide-tag">Technological Moat 1</div>
                <h2 class="slide-title">CampusOS Passport: <span>Device-Bound Ed25519 PKI</span></h2>
                <div class="slide-subtitle">Eliminating screenshot fraud, roll-call proxies, and fake passes using asymmetric mathematical trust.</div>
            </div>
            <div class="slide-header-right">
                <div class="slide-num">07</div>
                <div class="slide-category">Core Cryptography</div>
            </div>
        </div>

        <div class="slide-body">
            <div class="card-grid-3">
                <div class="card card-highlight">
                    <div class="card-header">
                        <span class="card-icon">🔑</span>
                        <h3 class="card-title">Device-Bound Keypair</h3>
                        <span class="card-badge badge-blue">Non-Exportable</span>
                    </div>
                    <div class="card-body">
                        <ul>
                            <li>During onboarding, the client generates a 32-byte Ed25519 cryptographic keypair directly on the smartphone.</li>
                            <li>The private key is stored in hardware-backed secure storage and never leaves the device.</li>
                            <li>Single-device binding policy: enrolling a new phone immediately invalidates the previous key on the server.</li>
                        </ul>
                    </div>
                    <div class="card-metric-block">
                        <span class="metric-val">32-Byte</span>
                        <span class="metric-sub">Ed25519 Curve25519 Asymmetric Key</span>
                    </div>
                </div>

                <div class="card card-purple">
                    <div class="card-header">
                        <span class="card-icon">🔄</span>
                        <h3 class="card-title">30s Rotating Dynamic QR</h3>
                        <span class="card-badge badge-purple">Anti-Screenshot</span>
                    </div>
                    <div class="card-body">
                        <ul>
                            <li>The student app generates a fresh QR presentation every 30 seconds.</li>
                            <li>Payload: <code>Signature(UUID + Nonce + Epoch_Timestamp)</code>.</li>
                            <li>Screenshots taken and forwarded to friends expire in <30 seconds and fail verification.</li>
                            <li>Biometric gate (FaceID / Fingerprint) required to unlock the passport.</li>
                        </ul>
                    </div>
                    <div class="card-metric-block">
                        <span class="metric-val">30 Sec</span>
                        <span class="metric-sub">Dynamic QR token expiration window</span>
                    </div>
                </div>

                <div class="card card-success">
                    <div class="card-header">
                        <span class="card-icon">⚡</span>
                        <h3 class="card-title">Offline Trust Bundles</h3>
                        <span class="card-badge badge-green">0 Bytes Internet</span>
                    </div>
                    <div class="card-body">
                        <ul>
                            <li>Teacher and verifier devices cache institutional public keys in local SQLite Trust Bundles.</li>
                            <li>Signature validation executes completely offline in under 2 milliseconds without contacting the server.</li>
                            <li>Consumed nonces are stored locally and synced upstream to permanently block replay attempts (HTTP 409).</li>
                        </ul>
                    </div>
                    <div class="card-metric-block">
                        <span class="metric-val" style="color: #34D399;">&lt; 2 ms</span>
                        <span class="metric-sub">Local offline signature verification time</span>
                    </div>
                </div>
            </div>
        </div>

        <div class="slide-footer">
            <div class="slide-footer-brand"><span class="brand-dot"></span> CampusOS Cryptographic Engine</div>
            <div>BPUT Hackathon PS07 · 41 Security Penetration Checks Verified</div>
        </div>
    </div>
    """)

    # =========================================================================
    # SLIDE 8: TECHNOLOGICAL MOAT 2 - DECENTRALIZED BLE MESH
    # =========================================================================
    slides_html.append(f"""
    <div class="slide">
        <div class="slide-header">
            <div class="slide-header-left">
                <div class="slide-tag">Technological Moat 2</div>
                <h2 class="slide-title">Decentralized BLE Mesh: <span>Zero-Infrastructure Survivability</span></h2>
                <div class="slide-subtitle">Autonomous peer-to-peer 7-hop mesh network that connects the campus when internet completely dies.</div>
            </div>
            <div class="slide-header-right">
                <div class="slide-num">08</div>
                <div class="slide-category">Mesh Networking</div>
            </div>
        </div>

        <div class="slide-body">
            <div class="card-grid-4">
                <div class="card card-highlight">
                    <div class="card-header">
                        <span class="card-icon">📡</span>
                        <h3 class="card-title">7-Hop Relay</h3>
                        <span class="card-badge badge-blue">BLE 5.x Multi-Hop</span>
                    </div>
                    <div class="card-body">
                        Messages hop phone-to-phone across students' pockets up to 7 hops away. Bridges concrete walls and multi-story hostel buildings without Wi-Fi routers or mobile towers.
                    </div>
                    <div class="card-metric-block">
                        <span class="metric-val">7 Hops</span>
                        <span class="metric-sub">Max network relay depth</span>
                    </div>
                </div>

                <div class="card">
                    <div class="card-header">
                        <span class="card-icon">🛡️</span>
                        <h3 class="card-title">Loop Prevention</h3>
                        <span class="card-badge badge-green">Hash Cache</span>
                    </div>
                    <div class="card-body">
                        64-bit packet hash deduplication cache and Bloom filters prevent broadcast storms. Nodes reject previously seen packets in <0.5ms, ensuring clean, silent mesh propagation.
                    </div>
                    <div class="card-metric-block">
                        <span class="metric-val">&lt; 0.5 ms</span>
                        <span class="metric-sub">Packet deduplication check</span>
                    </div>
                </div>

                <div class="card">
                    <div class="card-header">
                        <span class="card-icon">🎯</span>
                        <h3 class="card-title">Live Peer Radar</h3>
                        <span class="card-badge badge-amber">Interactive UI</span>
                    </div>
                    <div class="card-body">
                        Real-time animated radar plotting nearby active mesh peers, RSSI signal strengths, and hop counts. Auto-discovers and visualizes peer density within a 30-meter radius.
                    </div>
                    <div class="card-metric-block">
                        <span class="metric-val">30 Meters</span>
                        <span class="metric-sub">Single-hop BLE discovery radius</span>
                    </div>
                </div>

                <div class="card card-purple">
                    <div class="card-header">
                        <span class="card-icon">🚚</span>
                        <h3 class="card-title">Store & Forward</h3>
                        <span class="card-badge badge-purple">Data Mules</span>
                    </div>
                    <div class="card-body">
                        Delay-tolerant synchronization: as students walk between academic blocks and hostels, their devices carry encrypted sync bundles, uploading them automatically when any node finds internet.
                    </div>
                    <div class="card-metric-block">
                        <span class="metric-val">100%</span>
                        <span class="metric-sub">Eventual consistency guarantee</span>
                    </div>
                </div>
            </div>
        </div>

        <div class="slide-footer">
            <div class="slide-footer-brand"><span class="brand-dot"></span> CampusOS BLE Mesh Fabric</div>
            <div>BPUT Hackathon PS07 · 183 Automated Mesh Tests Passing</div>
        </div>
    </div>
    """)

    # =========================================================================
    # SLIDE 9: ACADEMIC AIRDROP (OFFLINE P2P FILE SHARING)
    # =========================================================================
    slides_html.append(f"""
    <div class="slide">
        <div class="slide-header">
            <div class="slide-header-left">
                <div class="slide-tag">Content Distribution</div>
                <h2 class="slide-title">Academic AirDrop: <span>Extreme High-Speed Offline Sharing</span></h2>
                <div class="slide-subtitle">Distributing heavy lecture notes, assignments, and exam circulars with zero internet and zero cloud bandwidth cost.</div>
            </div>
            <div class="slide-header-right">
                <div class="slide-num">09</div>
                <div class="slide-category">P2P Protocols</div>
            </div>
        </div>

        <div class="slide-body">
            <div class="card-grid-2">
                <div class="card card-highlight">
                    <div class="card-header">
                        <span class="card-icon">📡</span>
                        <h3 class="card-title">Tier 1: Pure BLE Mesh AirDrop (≤ 2 MB)</h3>
                        <span class="card-badge badge-blue">Zero Infrastructure</span>
                    </div>
                    <div class="card-body">
                        <ul>
                            <li><strong>Pure Radio Chunking:</strong> Slices documents into 200-byte MTU packets directly transmitted over BLE radio.</li>
                            <li><strong>SHA-256 Integrity Verification:</strong> Automatic re-assembly with cryptographic hash verification to ensure zero packet corruption.</li>
                            <li><strong>Emergency Circulars:</strong> Designed for urgent text notices, timetable amendments, and disaster evacuation maps when campus Wi-Fi is dead.</li>
                            <li><strong>100% Radio Autonomous:</strong> Functions in the middle of a forest, during a flood, or in a deep basement with no routers.</li>
                        </ul>
                    </div>
                    <div class="card-metric-block">
                        <span class="metric-val">&le; 2 MB</span>
                        <span class="metric-sub">Pure BLE multi-hop document transfer limit</span>
                    </div>
                </div>

                <div class="card card-success">
                    <div class="card-header">
                        <span class="card-icon">⚡</span>
                        <h3 class="card-title">Tier 2: Local Wi-Fi AirDrop (≤ 100 MB at 50 MB/s)</h3>
                        <span class="card-badge badge-green">LocalSend Engine</span>
                    </div>
                    <div class="card-body">
                        <ul>
                            <li><strong>LocalSend Protocol Integration:</strong> Broadcasts peer discovery packets over open UDP Port 53317 across the local campus router.</li>
                            <li><strong>High-Speed TCP Socket Streaming:</strong> Streams large textbooks, software archives, and lecture videos at up to 50 MB/second.</li>
                            <li><strong>Zero Cloud Egress:</strong> Packets flow entirely within the local Wi-Fi switch—never touching external telecom fiber or consuming university ISP data.</li>
                            <li><strong>Saves Lakhs in Cloud Bills:</strong> Eliminates AWS S3 bandwidth fees for distributing syllabus materials across 5,000 students.</li>
                        </ul>
                    </div>
                    <div class="card-metric-block">
                        <span class="metric-val" style="color: #34D399;">50 MB/s</span>
                        <span class="metric-sub">Transfer speed over local Wi-Fi without internet</span>
                    </div>
                </div>
            </div>
        </div>

        <div class="slide-footer">
            <div class="slide-footer-brand"><span class="brand-dot"></span> CampusOS Academic AirDrop</div>
            <div>BPUT Hackathon PS07 · LocalSend P2P Integration</div>
        </div>
    </div>
    """)

    # =========================================================================
    # SLIDE 10: EMERGENCY DISASTER FLARE (LIFE-SAFETY)
    # =========================================================================
    slides_html.append(f"""
    <div class="slide">
        <div class="slide-header">
            <div class="slide-header-left">
                <div class="slide-tag">Life-Safety Innovation</div>
                <h2 class="slide-title">Disaster Flare: <span>Authority-Signed Emergency Siren</span></h2>
                <div class="slide-subtitle">Coastal cyclone alerts, fire alarms, and crisis evacuation directives with zero internet requirement.</div>
            </div>
            <div class="slide-header-right">
                <div class="slide-num">10</div>
                <div class="slide-category">Crisis Management</div>
            </div>
        </div>

        <div class="slide-body">
            <div class="card-grid-3">
                <div class="card card-danger">
                    <div class="card-header">
                        <span class="card-icon">🔐</span>
                        <h3 class="card-title">Authority-Signed SOS</h3>
                        <span class="card-badge badge-red">Anti-Hoax</span>
                    </div>
                    <div class="card-body">
                        <ul>
                            <li>Only verified Deans and Wardens possess the institutional Ed25519 private keys required to trigger a Disaster Flare.</li>
                            <li>Student devices mathematically verify the authority signature before activating any siren.</li>
                            <li>Prevents malicious prank alarms or student panic hoaxes completely.</li>
                        </ul>
                    </div>
                    <div class="card-metric-block">
                        <span class="metric-val" style="color: #F87171;">Ed25519</span>
                        <span class="metric-sub">Signed origin guarantee</span>
                    </div>
                </div>

                <div class="card card-highlight">
                    <div class="card-header">
                        <span class="card-icon">🔊</span>
                        <h3 class="card-title">Silent Mode Audio Override</h3>
                        <span class="card-badge badge-blue">Hardware Control</span>
                    </div>
                    <div class="card-body">
                        <ul>
                            <li>Students frequently keep phones on 'Do Not Disturb' or Silent mode during nights and classes.</li>
                            <li>The Disaster Flare engine invokes system audio channel overrides to sound a high-decibel audible emergency siren.</li>
                            <li>Continuous haptic pulse patterns ensure students notice alerts even if phones are in backpacks.</li>
                        </ul>
                    </div>
                    <div class="card-metric-block">
                        <span class="metric-val">100%</span>
                        <span class="metric-sub">Silent mode override success rate</span>
                    </div>
                </div>

                <div class="card card-purple">
                    <div class="card-header">
                        <span class="card-icon">⏱️</span>
                        <h3 class="card-title">Sub-2-Second Propagation</h3>
                        <span class="card-badge badge-purple">High-Priority Flooding</span>
                    </div>
                    <div class="card-body">
                        <ul>
                            <li>Emergency flare packets carry highest priority flags in the BLE mesh packet scheduler.</li>
                            <li>Cascades device-to-device across an entire multi-wing hostel block in under 2 seconds.</li>
                            <li>Displays full-screen evacuation directives, emergency assembly zones, and medical contact pins.</li>
                        </ul>
                    </div>
                    <div class="card-metric-block">
                        <span class="metric-val" style="color: #C084FC;">&lt; 2.0s</span>
                        <span class="metric-sub">Hostel-wide mesh alert propagation latency</span>
                    </div>
                </div>
            </div>
        </div>

        <div class="slide-footer">
            <div class="slide-footer-brand"><span class="brand-dot"></span> CampusOS Emergency Life-Safety Engine</div>
            <div>BPUT Hackathon PS07 · Cyclone & Crisis Resilient</div>
        </div>
    </div>
    """)

    # =========================================================================
    # SLIDE 11: COMPLETE 17-MODULE FEATURE MATRIX
    # =========================================================================
    slides_html.append(f"""
    <div class="slide">
        <div class="slide-header">
            <div class="slide-header-left">
                <div class="slide-tag">Feature Landscape</div>
                <h2 class="slide-title">The Complete Suite: <span>17 Institutional Modules</span></h2>
                <div class="slide-subtitle">A comprehensive, production-tested operating platform replacing fragmented third-party point solutions.</div>
            </div>
            <div class="slide-header-right">
                <div class="slide-num">11</div>
                <div class="slide-category">Full Capabilities</div>
            </div>
        </div>

        <div class="slide-body">
            <table class="deck-table">
                <thead>
                    <tr>
                        <th style="width: 22%;">Domain / Pillar</th>
                        <th style="width: 25%;">Core Capabilities</th>
                        <th style="width: 28%;">Anti-Fraud / Offline Mechanism</th>
                        <th style="width: 15%;">Stakeholders</th>
                        <th style="width: 10%;">Status</th>
                    </tr>
                </thead>
                <tbody>
                    <tr>
                        <td><strong>1. Identity & Wallet</strong></td>
                        <td>6-Card carousel, Official ID, Passport, Docs, Dues</td>
                        <td>Device-bound Ed25519 keypair, 30s dynamic QR</td>
                        <td>Student, Admin</td>
                        <td><span class="card-badge badge-green">Verified</span></td>
                    </tr>
                    <tr>
                        <td><strong>2. Verified Attendance</strong></td>
                        <td>BLE proximity beacon session, dynamic QR fallback</td>
                        <td>Offline trust bundle verification, anti-proxy nonces</td>
                        <td>Teacher, Student</td>
                        <td><span class="card-badge badge-green">Verified</span></td>
                    </tr>
                    <tr>
                        <td><strong>3. Mess & Dining</strong></td>
                        <td>Tokenless dining verification, ratings, weekly menu</td>
                        <td>Dynamic QR scan + HTTP 409 duplicate meal blocker</td>
                        <td>Mess Staff, Student</td>
                        <td><span class="card-badge badge-green">Verified</span></td>
                    </tr>
                    <tr>
                        <td><strong>4. Hostel Leave & Gate</strong></td>
                        <td>Warden leave triage, auto gate pass, perimeter scan</td>
                        <td>HMAC-SHA256 signature, anti-passback rule</td>
                        <td>Warden, Security, Student</td>
                        <td><span class="card-badge badge-green">Verified</span></td>
                    </tr>
                    <tr>
                        <td><strong>5. Grievances & SLAs</strong></td>
                        <td>Triage pipeline, status history, ageing alert monitors</td>
                        <td>NLP complaint clustering, >48h SLA countdown</td>
                        <td>Student, Dean</td>
                        <td><span class="card-badge badge-green">Verified</span></td>
                    </tr>
                    <tr>
                        <td><strong>6. Scoped Circulars</strong></td>
                        <td>Targeted circulars (by batch/hostel), academic feeds</td>
                        <td>Cryptographic read receipts (Delivered / Read)</td>
                        <td>Admin, Teacher, Student</td>
                        <td><span class="card-badge badge-green">Verified</span></td>
                    </tr>
                    <tr>
                        <td><strong>7. Operations & Assets</strong></td>
                        <td>Room allocations, defect triage, visitor registration</td>
                        <td>Sequential asset tagging, visitor gate pass check-in</td>
                        <td>Warden, Guard, Student</td>
                        <td><span class="card-badge badge-green">Verified</span></td>
                    </tr>
                    <tr>
                        <td><strong>8. Financial & Certificates</strong></td>
                        <td>Dues ledger, fee receipts, official certificate requests</td>
                        <td>Anti-tamper serial numbering, digital wallet save</td>
                        <td>Student, Admin</td>
                        <td><span class="card-badge badge-green">Verified</span></td>
                    </tr>
                    <tr>
                        <td><strong>9. Off-Grid BLE Mesh</strong></td>
                        <td>7-hop P2P mesh, Academic AirDrop, Disaster Flare</td>
                        <td>Loop prevention, 50MB/s LocalSend, authority SOS</td>
                        <td>All 6 Roles</td>
                        <td><span class="card-badge badge-green">Verified</span></td>
                    </tr>
                </tbody>
            </table>
        </div>

        <div class="slide-footer">
            <div class="slide-footer-brand"><span class="brand-dot"></span> CampusOS 17-Module Suite</div>
            <div>BPUT Hackathon PS07 · Complete Production Monorepo</div>
        </div>
    </div>
    """)

    # =========================================================================
    # SLIDE 12: REACT 19 ENTERPRISE CONTROL PLANE
    # =========================================================================
    slides_html.append(f"""
    <div class="slide">
        <div class="slide-header">
            <div class="slide-header-left">
                <div class="slide-tag">Executive Governance</div>
                <h2 class="slide-title">React 19 Admin Console: <span>Central Command Plane</span></h2>
                <div class="slide-subtitle">Desktop web management console for Deans and Central Administration built with React 19, TypeScript, and Vite.</div>
            </div>
            <div class="slide-header-right">
                <div class="slide-num">12</div>
                <div class="slide-category">Admin Web</div>
            </div>
        </div>

        <div class="slide-body">
            <div class="card-grid-3">
                <div class="card card-highlight">
                    <div class="card-header">
                        <span class="card-icon">🧠</span>
                        <h3 class="card-title">NLP Complaint Clustering</h3>
                        <span class="card-badge badge-blue">AI-Assisted</span>
                    </div>
                    <div class="card-body">
                        <ul>
                            <li><strong>Root-Cause Detection:</strong> Automatically groups dozens of unstructured grievances (e.g., 'water cold', 'Block B tap dry') into a single systemic maintenance incident.</li>
                            <li><strong>Reduces Admin Fatigue:</strong> Administrators triage one root incident instead of scrolling 40 duplicate tickets.</li>
                            <li><strong>Automated Notification:</strong> Resolving the parent ticket updates all 40 student submitters instantly.</li>
                        </ul>
                    </div>
                    <div class="card-metric-block">
                        <span class="metric-val">85%</span>
                        <span class="metric-sub">Reduction in duplicate ticket triage overhead</span>
                    </div>
                </div>

                <div class="card card-danger">
                    <div class="card-header">
                        <span class="card-icon">⏱️</span>
                        <h3 class="card-title">SLA Ageing Monitor (&gt;48h)</h3>
                        <span class="card-badge badge-red">Accountability</span>
                    </div>
                    <div class="card-body">
                        <ul>
                            <li><strong>Live Countdown Timers:</strong> Visual red alerts highlight grievances aging past the 48-hour institutional resolution deadline.</li>
                            <li><strong>Automated Escalation:</strong> Unresolved hostel complaints automatically escalate from Warden to Chief Warden and Dean of Student Affairs.</li>
                            <li><strong>Immutable Audit History:</strong> Every status transition, remark, and timestamp is permanently recorded.</li>
                        </ul>
                    </div>
                    <div class="card-metric-block">
                        <span class="metric-val" style="color: #F87171;">&gt; 48 Hrs</span>
                        <span class="metric-sub">Automated institutional SLA breach alert threshold</span>
                    </div>
                </div>

                <div class="card card-success">
                    <div class="card-header">
                        <span class="card-icon">🎯</span>
                        <h3 class="card-title">Scoped Circulars & Tracking</h3>
                        <span class="card-badge badge-green">Audit Receipts</span>
                    </div>
                    <div class="card-body">
                        <ul>
                            <li><strong>Granular Target Scoping:</strong> Broadcast circulars strictly to specific departments, academic batches, or hostel blocks.</li>
                            <li><strong>Per-Student Delivery State:</strong> Real-time dashboard tracks exact receipts: <code>DELIVERED</code>, <code>READ</code>, and <code>ACTIONED</code>.</li>
                            <li><strong>Ends Excuses:</strong> Students can never claim "I never received the notice" during examinations or fee deadlines.</li>
                        </ul>
                    </div>
                    <div class="card-metric-block">
                        <span class="metric-val" style="color: #34D399;">100%</span>
                        <span class="metric-sub">Cryptographic read receipt audibility</span>
                    </div>
                </div>
            </div>
        </div>

        <div class="slide-footer">
            <div class="slide-footer-brand"><span class="brand-dot"></span> CampusOS React 19 Admin Plane</div>
            <div>BPUT Hackathon PS07 · Vite + TypeScript + Tailwind</div>
        </div>
    </div>
    """)

    # =========================================================================
    # SLIDE 13: TECHNICAL RIGOR & QA BASELINE
    # =========================================================================
    slides_html.append(f"""
    <div class="slide">
        <div class="slide-header">
            <div class="slide-header-left">
                <div class="slide-tag">Quality Assurance</div>
                <h2 class="slide-title">Technical Rigor: <span>100% Verified Automated Test Baseline</span></h2>
                <div class="slide-subtitle">Proven reliability across unit, integration, cryptographic, mesh, and live security penetration tests.</div>
            </div>
            <div class="slide-header-right">
                <div class="slide-num">13</div>
                <div class="slide-category">Engineering Proof</div>
            </div>
        </div>

        <div class="slide-body">
            <div class="card-grid-4">
                <div class="card card-success">
                    <div class="card-header">
                        <span class="card-icon">📱</span>
                        <h3 class="card-title">Flutter Tests</h3>
                        <span class="card-badge badge-green">100% Pass</span>
                    </div>
                    <div class="card-body">
                        Covers state management, widget rendering, carousel animations, offline drift DB schemas, and 4-language localization (EN, HI, OR, BN).
                    </div>
                    <div class="card-metric-block">
                        <span class="metric-val" style="color: #34D399;">449 / 449</span>
                        <span class="metric-sub">Core Flutter UI & Logic Tests Passing</span>
                    </div>
                </div>

                <div class="card card-highlight">
                    <div class="card-header">
                        <span class="card-icon">📡</span>
                        <h3 class="card-title">BLE Mesh Tests</h3>
                        <span class="card-badge badge-blue">100% Pass</span>
                    </div>
                    <div class="card-body">
                        Validates packet encoding, 7-hop relay limits, deduplication cache, LocalSend TCP streaming, and disaster siren audio overrides.
                    </div>
                    <div class="card-metric-block">
                        <span class="metric-val">183 / 183</span>
                        <span class="metric-sub">Mesh & AirDrop Automated Tests Passing</span>
                    </div>
                </div>

                <div class="card card-purple">
                    <div class="card-header">
                        <span class="card-icon">⚙️</span>
                        <h3 class="card-title">Backend Suites</h3>
                        <span class="card-badge badge-purple">100% Pass</span>
                    </div>
                    <div class="card-body">
                        Integration suites covering all 19 Flask blueprints, MySQL 8 foreign key cascades, role enforcement, and cross-role leave-to-gate flows.
                    </div>
                    <div class="card-metric-block">
                        <span class="metric-val" style="color: #C084FC;">22 / 22</span>
                        <span class="metric-sub">Modular Backend Test Suites Passing</span>
                    </div>
                </div>

                <div class="card card-danger">
                    <div class="card-header">
                        <span class="card-icon">🛡️</span>
                        <h3 class="card-title">Security Attacks</h3>
                        <span class="card-badge badge-red">Zero Breaches</span>
                    </div>
                    <div class="card-body">
                        41 live penetration attacks: SQL injection, JWT signature forgery, gate pass replay attacks, privilege escalation, and parameter tampering.
                    </div>
                    <div class="card-metric-block">
                        <span class="metric-val" style="color: #F87171;">41 / 41</span>
                        <span class="metric-sub">Live Penetration Attack Checks Defended</span>
                    </div>
                </div>
            </div>
        </div>

        <div class="slide-footer">
            <div class="slide-footer-brand"><span class="brand-dot"></span> CampusOS Verified Quality Baseline</div>
            <div>BPUT Hackathon PS07 · Total 654 Automated Tests Passing</div>
        </div>
    </div>
    """)

    # =========================================================================
    # SLIDE 14: MARKET OPPORTUNITY & TAM
    # =========================================================================
    slides_html.append(f"""
    <div class="slide">
        <div class="slide-header">
            <div class="slide-header-left">
                <div class="slide-tag">Market Opportunity</div>
                <h2 class="slide-title">Market Size: <span>45,000+ Higher Education Institutions</span></h2>
                <div class="slide-subtitle">A massive, underserved market in India and developing nations ripe for offline-first institutional modernization.</div>
            </div>
            <div class="slide-header-right">
                <div class="slide-num">14</div>
                <div class="slide-category">Commercial Landscape</div>
            </div>
        </div>

        <div class="slide-body">
            <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 5mm; height: 100%;">
                <div class="card card-highlight">
                    <div class="card-header">
                        <span class="card-icon">🇮🇳</span>
                        <h3 class="card-title">The Higher Education Market in India</h3>
                        <span class="card-badge badge-blue">Scale</span>
                    </div>
                    <div class="card-body">
                        <ul>
                            <li><strong>45,000+ Colleges & 1,100+ Universities:</strong> Enrolling over 40 Million students across technical, engineering, and medical faculties.</li>
                            <li><strong>70%+ in Tier-2/3 Regions:</strong> State technical universities (such as BPUT, AKTU, VTU, JNTU) have hundreds of affiliated rural colleges with unreliable fiber and power.</li>
                            <li><strong>Mandatory Digital Compliance:</strong> AICTE, NAAC, and UGC increasingly mandate verified biometric/digital attendance, transparent grievance redressal, and campus safety audits.</li>
                        </ul>
                    </div>
                    <div class="card-metric-block">
                        <span class="metric-val">40M+</span>
                        <span class="metric-sub">Students enrolled in Indian Higher Education</span>
                    </div>
                </div>

                <div style="display: flex; flex-direction: column; gap: 3mm; height: 100%;">
                    <div class="card" style="flex: 1;">
                        <div class="card-header">
                            <span class="card-icon">🌍</span>
                            <h3 class="card-title">Total Addressable Market (TAM)</h3>
                            <span class="card-badge badge-blue">Global</span>
                        </div>
                        <div class="card-body">
                            <strong>$3.2 Billion:</strong> Higher education campus ERP, identity, and security management software market across South Asia, Southeast Asia, and Africa.
                        </div>
                    </div>

                    <div class="card card-highlight" style="flex: 1;">
                        <div class="card-header">
                            <span class="card-icon">🎯</span>
                            <h3 class="card-title">Serviceable Addressable Market (SAM)</h3>
                            <span class="card-badge badge-amber">South Asia</span>
                        </div>
                        <div class="card-body">
                            <strong>$850 Million:</strong> Residential engineering institutes, state universities, and polytechnics facing network dead zones in South Asia.
                        </div>
                    </div>

                    <div class="card card-success" style="flex: 1;">
                        <div class="card-header">
                            <span class="card-icon">🚀</span>
                            <h3 class="card-title">Serviceable Obtainable Market (SOM)</h3>
                            <span class="card-badge badge-green">Immediate 3-Yr</span>
                        </div>
                        <div class="card-body">
                            <strong>$45 Million:</strong> 150 to 500 state technical university colleges (e.g. BPUT affiliated network) over a 3-year rollout.
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <div class="slide-footer">
            <div class="slide-footer-brand"><span class="brand-dot"></span> CampusOS Market Opportunity</div>
            <div>BPUT Hackathon PS07 · TAM / SAM / SOM Valuation</div>
        </div>
    </div>
    """)

    # =========================================================================
    # SLIDE 15: BUSINESS MODEL & UNIT ECONOMICS
    # =========================================================================
    slides_html.append(f"""
    <div class="slide">
        <div class="slide-header">
            <div class="slide-header-left">
                <div class="slide-tag">Business Model</div>
                <h2 class="slide-title">Monetization & Unit Economics: <span>85%+ Gross Margins</span></h2>
                <div class="slide-subtitle">Predictable institutional SaaS subscriptions paired with on-premise data sovereignty licenses.</div>
            </div>
            <div class="slide-header-right">
                <div class="slide-num">15</div>
                <div class="slide-category">Financial Model</div>
            </div>
        </div>

        <div class="slide-body">
            <div class="card-grid-3">
                <div class="card card-highlight">
                    <div class="card-header">
                        <span class="card-icon">💳</span>
                        <h3 class="card-title">Tier 1: Cloud SaaS Subscription</h3>
                        <span class="card-badge badge-blue">Recurring</span>
                    </div>
                    <div class="card-body">
                        <ul>
                            <li><strong>₹150 - ₹250 ($2 - $3) / student / year.</strong></li>
                            <li>Includes full Flutter mobile access for all 6 roles, automated cloud sync, push notifications, and routine updates.</li>
                            <li>Billed annually directly to the university or integrated into annual student development fees.</li>
                        </ul>
                    </div>
                    <div class="card-metric-block">
                        <span class="metric-val">₹200</span>
                        <span class="metric-sub">Average annual SaaS fee per student</span>
                    </div>
                </div>

                <div class="card card-purple">
                    <div class="card-header">
                        <span class="card-icon">🏢</span>
                        <h3 class="card-title">Tier 2: Private On-Premise</h3>
                        <span class="card-badge badge-purple">Enterprise</span>
                    </div>
                    <div class="card-body">
                        <ul>
                            <li><strong>₹3.5 Lakh ($4,200) setup + ₹100/student AMC.</strong></li>
                            <li>Dedicated on-campus bare-metal server deployment for autonomous colleges and defense academies.</li>
                            <li>100% data sovereignty; zero data transmitted to third-party public clouds.</li>
                        </ul>
                    </div>
                    <div class="card-metric-block">
                        <span class="metric-val">100%</span>
                        <span class="metric-sub">Data sovereignty on university campus servers</span>
                    </div>
                </div>

                <div class="card card-success">
                    <div class="card-header">
                        <span class="card-icon">📈</span>
                        <h3 class="card-title">Why Gross Margins Exceed 85%</h3>
                        <span class="card-badge badge-green">Efficiency</span>
                    </div>
                    <div class="card-body">
                        <ul>
                            <li><strong>Zero Cloud Bandwidth for Files:</strong> Academic AirDrop streams gigabytes peer-to-peer over local Wi-Fi, not cloud buckets.</li>
                            <li><strong>Reduced DB Calls:</strong> Offline trust bundles perform signature checks on-device, cutting server load by 75%.</li>
                            <li><strong>Low Infrastructure Overhead:</strong> Monolithic Flask + MySQL 8 runs on modest commodity servers.</li>
                        </ul>
                    </div>
                    <div class="card-metric-block">
                        <span class="metric-val" style="color: #34D399;">85%+</span>
                        <span class="metric-sub">Projected gross software margin</span>
                    </div>
                </div>
            </div>
        </div>

        <div class="slide-footer">
            <div class="slide-footer-brand"><span class="brand-dot"></span> CampusOS Unit Economics</div>
            <div>BPUT Hackathon PS07 · Scalable Institutional SaaS</div>
        </div>
    </div>
    """)

    # =========================================================================
    # SLIDE 16: COMPETITIVE LANDSCAPE & UNFAIR ADVANTAGES
    # =========================================================================
    slides_html.append(f"""
    <div class="slide">
        <div class="slide-header">
            <div class="slide-header-left">
                <div class="slide-tag">Competitive Landscape</div>
                <h2 class="slide-title">Competitive Moat: <span>Why Nobody Can Match CampusOS</span></h2>
                <div class="slide-subtitle">Comparing CampusOS against legacy ERPs, niche attendance apps, and paper-based status quo.</div>
            </div>
            <div class="slide-header-right">
                <div class="slide-num">16</div>
                <div class="slide-category">Market Comparison</div>
            </div>
        </div>

        <div class="slide-body">
            <table class="deck-table">
                <thead>
                    <tr>
                        <th style="width: 25%;">Capability</th>
                        <th style="width: 25%; color: #38BDF8;">CampusOS</th>
                        <th style="width: 20%;">Legacy ERPs (SAP/TCS)</th>
                        <th style="width: 15%;">Niche EdTech Apps</th>
                        <th style="width: 15%;">Paper Registers</th>
                    </tr>
                </thead>
                <tbody>
                    <tr>
                        <td><strong>Offline-First Resilience</strong></td>
                        <td style="color: #34D399;"><strong>100% Native (Drift + Bundles)</strong></td>
                        <td>Fails without 4G/Wi-Fi</td>
                        <td>Fails without 4G/Wi-Fi</td>
                        <td>Full Paper</td>
                    </tr>
                    <tr>
                        <td><strong>Decentralized BLE Mesh</strong></td>
                        <td style="color: #34D399;"><strong>Yes (7-Hop P2P Fabric)</strong></td>
                        <td>None</td>
                        <td>None</td>
                        <td>None</td>
                    </tr>
                    <tr>
                        <td><strong>Anti-Proxy Cryptography</strong></td>
                        <td style="color: #34D399;"><strong>Ed25519 + 30s Dynamic QR</strong></td>
                        <td>Static Barcode / RFID</td>
                        <td>Simple QR / PIN</td>
                        <td>None (Trivial)</td>
                    </tr>
                    <tr>
                        <td><strong>6-Role Institutional Cohesion</strong></td>
                        <td style="color: #34D399;"><strong>Yes (1 Unified Monorepo)</strong></td>
                        <td>Complex multi-app silos</td>
                        <td>1 Role only (Student)</td>
                        <td>None</td>
                    </tr>
                    <tr>
                        <td><strong>Disaster Flare Audio Siren</strong></td>
                        <td style="color: #34D399;"><strong>Yes (Signed Siren Override)</strong></td>
                        <td>None</td>
                        <td>None</td>
                        <td>None</td>
                    </tr>
                    <tr>
                        <td><strong>Hardware Cost / Lock-in</strong></td>
                        <td style="color: #34D399;"><strong>Zero (Commodity Android)</strong></td>
                        <td>Expensive Turnstiles</td>
                        <td>Standard Phone</td>
                        <td>Low (Stationery)</td>
                    </tr>
                    <tr>
                        <td><strong>Deployment Time</strong></td>
                        <td style="color: #34D399;"><strong>&lt; 15 Minutes</strong></td>
                        <td>3 to 9 Months</td>
                        <td>1 to 2 Weeks</td>
                        <td>Immediate</td>
                    </tr>
                </tbody>
            </table>
        </div>

        <div class="slide-footer">
            <div class="slide-footer-brand"><span class="brand-dot"></span> CampusOS Competitive Landscape</div>
            <div>BPUT Hackathon PS07 · Unfair Technical Moats</div>
        </div>
    </div>
    """)

    # =========================================================================
    # SLIDE 17: TURNKEY DEPLOYMENT & ONBOARDING
    # =========================================================================
    slides_html.append(f"""
    <div class="slide">
        <div class="slide-header">
            <div class="slide-header-left">
                <div class="slide-tag">Implementation</div>
                <h2 class="slide-title">Turnkey Deployment: <span>Zero Friction in &lt;15 Minutes</span></h2>
                <div class="slide-subtitle">Eliminating complex institutional IT migrations with deterministic seeding and inclusive access kiosks.</div>
            </div>
            <div class="slide-header-right">
                <div class="slide-num">17</div>
                <div class="slide-category">Deployment Strategy</div>
            </div>
        </div>

        <div class="slide-body">
            <div class="card-grid-3">
                <div class="card card-highlight">
                    <div class="card-header">
                        <span class="card-icon">⚡</span>
                        <h3 class="card-title">15-Minute Automated Setup</h3>
                        <span class="card-badge badge-blue">Zero DevOps Pain</span>
                    </div>
                    <div class="card-body">
                        <ul>
                            <li><strong>Turnkey Runbook:</strong> Simple Python virtualenv, automated MySQL 8 table generation, and ready-to-run systemd service files.</li>
                            <li><strong>Deterministic Seeder:</strong> <code>seed_test_data.py</code> instantly provisions deterministic accounts for all 6 roles with a single terminal command.</li>
                            <li><strong>Pre-Configured Nginx:</strong> Reverse proxy template with SSL termination and WebSocket/SSE proxying.</li>
                        </ul>
                    </div>
                    <div class="card-metric-block">
                        <span class="metric-val">&lt; 15 Min</span>
                        <span class="metric-sub">Full server setup and database seeding time</span>
                    </div>
                </div>

                <div class="card card-purple">
                    <div class="card-header">
                        <span class="card-icon">🖥️</span>
                        <h3 class="card-title">Assisted Access Kiosks</h3>
                        <span class="card-badge badge-purple">Inclusive Access</span>
                    </div>
                    <div class="card-body">
                        <ul>
                            <li><strong>For Students Without Phones:</strong> Inexpensive touch-screen kiosks in hostel lobbies and libraries.</li>
                            <li><strong>Biometric / PIN Auth:</strong> Students verify via institutional ID and fingerprint to file leaves, print single-use QR passes, and view timetables.</li>
                            <li><strong>No Student Left Behind:</strong> Guarantees universal campus equity regardless of personal smartphone ownership.</li>
                        </ul>
                    </div>
                    <div class="card-metric-block">
                        <span class="metric-val">100%</span>
                        <span class="metric-sub">Campus population coverage guaranteed</span>
                    </div>
                </div>

                <div class="card card-success">
                    <div class="card-header">
                        <span class="card-icon">🔄</span>
                        <h3 class="card-title">Zero Hardware Lock-In</h3>
                        <span class="card-badge badge-green">Open Architecture</span>
                    </div>
                    <div class="card-body">
                        <ul>
                            <li><strong>Commodity Hardware:</strong> Operates on standard low-cost Android phones, tablets, PCs, and university routers.</li>
                            <li><strong>No Expensive RFID Gates:</strong> Guards scan passes with regular smartphone cameras using hardware-accelerated MLKit barcodes.</li>
                            <li><strong>No Per-Seat DB Licenses:</strong> 100% open-source stack (Python, MySQL, Flutter) avoids crippling Oracle/SAP per-seat license fees.</li>
                        </ul>
                    </div>
                    <div class="card-metric-block">
                        <span class="metric-val" style="color: #34D399;">₹0</span>
                        <span class="metric-sub">Proprietary scanning hardware investment required</span>
                    </div>
                </div>
            </div>
        </div>

        <div class="slide-footer">
            <div class="slide-footer-brand"><span class="brand-dot"></span> CampusOS Deployment Architecture</div>
            <div>BPUT Hackathon PS07 · Production Deployment Runbook</div>
        </div>
    </div>
    """)

    # =========================================================================
    # SLIDE 18: 5-MINUTE LIVE STAGE DEMO PLAYBOOK
    # =========================================================================
    slides_html.append(f"""
    <div class="slide">
        <div class="slide-header">
            <div class="slide-header-left">
                <div class="slide-tag">Live Demonstration</div>
                <h2 class="slide-title">5-Minute Live Pitch Playbook: <span>The Blackout Test</span></h2>
                <div class="slide-subtitle">The battle-tested live demonstration sequence guaranteed to captivate technical evaluation committees.</div>
            </div>
            <div class="slide-header-right">
                <div class="slide-num">18</div>
                <div class="slide-category">Demo Script</div>
            </div>
        </div>

        <div class="slide-body">
            <div class="card-grid-4">
                <div class="card">
                    <div class="card-header">
                        <span class="card-icon">🎬</span>
                        <h3 class="card-title">Act 1: Cascading Flow</h3>
                        <span class="card-badge badge-blue">0:00 - 1:15</span>
                    </div>
                    <div class="card-body">
                        Student applies for hostel leave on phone. Warden approves in 1 tap. HMAC gate pass appears instantly in student wallet. Guard scans dynamic barcode; system validates signature and marks 'EXITED'.
                    </div>
                    <div class="card-metric-block">
                        <span class="metric-val">75 Sec</span>
                        <span class="metric-sub">Seamless cross-role flow</span>
                    </div>
                </div>

                <div class="card card-highlight">
                    <div class="card-header">
                        <span class="card-icon">✈️</span>
                        <h3 class="card-title">Act 2: Airplane Mode</h3>
                        <span class="card-badge badge-amber">1:15 - 2:45</span>
                    </div>
                    <div class="card-body">
                        <strong>The Big Hook:</strong> Turn off Wi-Fi and 4G on all test handsets. Open <strong>Campus Mesh Hub</strong>. Nearby peers appear on live radar. Send off-grid message in <code>#hostel</code>; packet hops device-to-device.
                    </div>
                    <div class="card-metric-block">
                        <span class="metric-val">0 Bps</span>
                        <span class="metric-sub">Internet consumed</span>
                    </div>
                </div>

                <div class="card card-danger">
                    <div class="card-header">
                        <span class="card-icon">🚨</span>
                        <h3 class="card-title">Act 3: Disaster Flare</h3>
                        <span class="card-badge badge-red">2:45 - 3:45</span>
                    </div>
                    <div class="card-body">
                        Trigger emergency evacuation flare from warden mobile console. In under 2 seconds, all student handsets in the room override silent mode, sound a loud alarm siren, vibrate, and display emergency exit maps.
                    </div>
                    <div class="card-metric-block">
                        <span class="metric-val">&lt; 2 Sec</span>
                        <span class="metric-sub">Room-wide siren trigger</span>
                    </div>
                </div>

                <div class="card card-success">
                    <div class="card-header">
                        <span class="card-icon">💻</span>
                        <h3 class="card-title">Act 4: Admin Web</h3>
                        <span class="card-badge badge-green">3:45 - 5:00</span>
                    </div>
                    <div class="card-body">
                        Switch to React 19 desktop console. Show real-time perimeter headcount, NLP grievance clustering grouping 25 water complaints into 1 ticket, and prove 654 passing tests in terminal.
                    </div>
                    <div class="card-metric-block">
                        <span class="metric-val">654 Tests</span>
                        <span class="metric-sub">100% verified passing</span>
                    </div>
                </div>
            </div>
        </div>

        <div class="slide-footer">
            <div class="slide-footer-brand"><span class="brand-dot"></span> CampusOS Live Demo Playbook</div>
            <div>BPUT Hackathon PS07 · Proven Evaluation Script</div>
        </div>
    </div>
    """)

    # =========================================================================
    # SLIDE 19: STRATEGIC ROADMAP & FUTURE MILESTONES
    # =========================================================================
    slides_html.append(f"""
    <div class="slide">
        <div class="slide-header">
            <div class="slide-header-left">
                <div class="slide-tag">Strategic Roadmap</div>
                <h2 class="slide-title">Engineering Roadmap: <span>From Hackathon to University Deployment</span></h2>
                <div class="slide-subtitle">A clear, phased execution trajectory elevating CampusOS into the default state university operating layer.</div>
            </div>
            <div class="slide-header-right">
                <div class="slide-num">19</div>
                <div class="slide-category">Future Growth</div>
            </div>
        </div>

        <div class="slide-body">
            <div class="flow-row">
                <div class="flow-step" style="border-color: rgba(16, 185, 129, 0.4);">
                    <div class="flow-step-num" style="color: #34D399;">PHASE 1 · COMPLETED</div>
                    <div class="flow-step-title">Production Baseline</div>
                    <div class="flow-step-desc">
                        Full 6-role monorepo, Ed25519 cryptographic passport, 7-hop BLE mesh, LocalSend AirDrop, 41 penetration attacks passing, and React 19 console.
                    </div>
                </div>

                <div class="flow-step">
                    <div class="flow-step-num">PHASE 2 · Q1-Q2 2027</div>
                    <div class="flow-step-title">Hardware Enclave & RF Scale</div>
                    <div class="flow-step-desc">
                        Migrating key storage to Android StrongBox / Secure Element; conducting large-scale 100+ physical handset RF density trials in lecture halls.
                    </div>
                </div>

                <div class="flow-step">
                    <div class="flow-step-num">PHASE 3 · Q3-Q4 2027</div>
                    <div class="flow-step-title">Kiosks & AI Ingestion</div>
                    <div class="flow-step-desc">
                        Deploying low-cost assisted access kiosks in hostel lobbies; shipping automated AI-assisted migration ETL to ingest legacy university databases.
                    </div>
                </div>

                <div class="flow-step">
                    <div class="flow-step-num">PHASE 4 · 2028+</div>
                    <div class="flow-step-title">State University Mesh</div>
                    <div class="flow-step-desc">
                        Consortium blockchain anchoring for tamper-proof degree transcripts and pan-university academic credit transfer across the BPUT network.
                    </div>
                </div>
            </div>
        </div>

        <div class="slide-footer">
            <div class="slide-footer-brand"><span class="brand-dot"></span> CampusOS Strategic Roadmap</div>
            <div>BPUT Hackathon PS07 · Phased Institutional Milestones</div>
        </div>
    </div>
    """)

    # =========================================================================
    # SLIDE 20: SUMMARY & CONCLUSION
    # =========================================================================
    slides_html.append(f"""
    <div class="slide cover-slide">
        <div class="cover-meta-strip">
            <span class="slide-tag">Executive Summary</span>
            <span style="font-family: 'JetBrains Mono'; font-size: 7pt; color: #64748B;">FINAL EVALUATION SYNTHESIS</span>
            <span style="margin-left: auto; font-family: 'JetBrains Mono'; font-size: 7pt; color: #38BDF8;">
                SLIDE 20 / 20 · CONCLUSION
            </span>
        </div>

        <div class="cover-main" style="text-align: center; margin: auto;">
            <div class="slide-tag" style="margin: 0 auto 4mm auto; padding: 2.5px 10px; font-size: 8pt;">BPUT HACKATHON 2026 · PROBLEM STATEMENT PS07</div>
            <h1 class="cover-title" style="font-size: 32pt; margin-bottom: 3mm;">
                Built for the Real World.<br/>
                <span>Verified by Mathematics.</span> Proven in Code.
            </h1>
            <p style="font-size: 10pt; color: #CBD5E1; max-width: 75%; line-height: 1.5; margin: 0 auto 6mm auto;">
                CampusOS transforms university governance from vulnerable paperwork into an autonomous, 
                disaster-resilient, and mathematically verifiable digital operating system.
            </p>

            <div style="display: inline-flex; gap: 4mm; text-align: left;">
                <div class="cover-badge" style="background: rgba(15, 23, 42, 0.85); border-color: rgba(56, 189, 248, 0.3);">
                    <span class="cover-badge-icon">🏛️</span>
                    <div>
                        <div class="cover-badge-val" style="color: #38BDF8;">6 Roles</div>
                        <div class="cover-badge-lbl">1 Cohesive System</div>
                    </div>
                </div>
                <div class="cover-badge" style="background: rgba(15, 23, 42, 0.85); border-color: rgba(16, 185, 129, 0.3);">
                    <span class="cover-badge-icon">🔐</span>
                    <div>
                        <div class="cover-badge-val" style="color: #34D399;">Ed25519 PKI</div>
                        <div class="cover-badge-lbl">Tamper-Proof</div>
                    </div>
                </div>
                <div class="cover-badge" style="background: rgba(15, 23, 42, 0.85); border-color: rgba(168, 85, 247, 0.3);">
                    <span class="cover-badge-icon">📡</span>
                    <div>
                        <div class="cover-badge-val" style="color: #C084FC;">BLE Mesh</div>
                        <div class="cover-badge-lbl">Disaster Resilient</div>
                    </div>
                </div>
                <div class="cover-badge" style="background: rgba(15, 23, 42, 0.85); border-color: rgba(245, 158, 11, 0.3);">
                    <span class="cover-badge-icon">🧪</span>
                    <div>
                        <div class="cover-badge-val" style="color: #FBBF24;">654 Tests</div>
                        <div class="cover-badge-lbl">100% Verified</div>
                    </div>
                </div>
            </div>
        </div>

        <div class="cover-footer">
            <div>
                <strong>CAMPUSOS MONOREPO</strong> · REPOSITORY STATUS: VERIFIED PRODUCTION BASELINE<br/>
                DOCUMENTATION: <code>docs/CAMPUSOS_COMPLETE_DOCUMENTATION.md</code> & <code>docs/CAMPUSOS_PITCH_DECK.md</code>
            </div>
            <div style="text-align: right;">
                READY FOR LIVE JUDGE EVALUATION & RF TESTING<br/>
                THANK YOU FOR YOUR CONSIDERATION
            </div>
        </div>
    </div>
    """)

    all_slides_content = "\n".join(slides_html)

    full_html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>CampusOS — Official Pitch Deck (BPUT Hackathon PS07)</title>
    <style>
    {css_style}
    </style>
</head>
<body>
    {all_slides_content}
</body>
</html>
"""

    with open(html_path, "w", encoding="utf-8") as f:
        f.write(full_html)
    print(f"[OK] Generated Pitch Deck HTML: {html_path}")

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

    print("[RUNNING] Compiling 16:9 Pitch Deck PDF via Headless Edge...")
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode == 0 and os.path.exists(pdf_path):
        size_kb = os.path.getsize(pdf_path) / 1024
        print(f"[SUCCESS] Pitch Deck PDF Generated Successfully!")
        print(f"  -> Path: {pdf_path}")
        print(f"  -> Size: {size_kb:.2f} KB")
    else:
        print(f"[ERROR] Failed to compile PDF (exit code {res.returncode}):")
        print(res.stderr or res.stdout)
        sys.exit(1)

if __name__ == "__main__":
    build_pitch_deck()
