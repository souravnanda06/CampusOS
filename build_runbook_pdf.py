import os
import sys
import subprocess
import markdown
import re

def build_pdf():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    md_path = os.path.join(script_dir, "docs", "CAMPUSOS_BACKEND_DEPLOYMENT_RUNBOOK.md")
    html_path = os.path.join(script_dir, "docs", "CAMPUSOS_BACKEND_DEPLOYMENT_RUNBOOK.html")
    pdf_path = os.path.join(script_dir, "CampusOS_Backend_Deployment_Runbook.pdf")
    
    if not os.path.exists(md_path):
        print(f"Error: {md_path} not found")
        sys.exit(1)
        
    with open(md_path, "r", encoding="utf-8") as f:
        md_content = f.read()

    # Pre-process callouts: > [!NOTE], > [!IMPORTANT], > [!WARNING], > [!TIP]
    def replace_alerts(match):
        alert_type = match.group(1).upper()
        content = match.group(2).strip()
        css_class = "callout-note"
        icon = "ℹ️ NOTE"
        if alert_type == "IMPORTANT":
            css_class = "callout-important"
            icon = "⚡ IMPORTANT"
        elif alert_type in ("WARNING", "CAUTION"):
            css_class = "callout-warning"
            icon = "⚠️ WARNING"
        elif alert_type == "TIP":
            css_class = "callout-tip"
            icon = "💡 TIP"
            
        return f'<div class="callout {css_class}"><div class="callout-title">{icon}</div><div class="callout-body">{content}</div></div>'

    # Convert alert blockquotes
    md_content = re.sub(
        r'> \[!(NOTE|IMPORTANT|WARNING|TIP|CAUTION)\]\s*\n((?:> .*\n?)+)',
        lambda m: replace_alerts(re.match(r'> \[!(NOTE|IMPORTANT|WARNING|TIP|CAUTION)\]\s*\n(.*)', m.group(0), re.DOTALL)),
        md_content
    )
    
    # Clean leftover '>' in alert bodies if any
    md_content = re.sub(r'<div class="callout-body">\s*> (.*?)</div>', r'<div class="callout-body">\1</div>', md_content, flags=re.DOTALL)

    html_body = markdown.markdown(
        md_content,
        extensions=[
            'markdown.extensions.tables',
            'markdown.extensions.fenced_code',
            'markdown.extensions.nl2br',
            'markdown.extensions.sane_lists'
        ]
    )

    css_style = """
    @import url('https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;500;600;700;800&family=JetBrains+Mono:wght@400;500;600&display=swap');

    @page {
        size: A4 portrait;
        margin: 18mm 14mm 18mm 14mm;
        @bottom-right {
            content: "Page " counter(page) " of " counter(pages);
            font-family: 'Plus Jakarta Sans', sans-serif;
            font-size: 8pt;
            color: #64748B;
        }
        @bottom-left {
            content: "CampusOS — Backend Deployment Runbook (LAN & Production)";
            font-family: 'Plus Jakarta Sans', sans-serif;
            font-size: 8pt;
            color: #64748B;
        }
    }

    body {
        font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        font-size: 9.5pt;
        line-height: 1.55;
        color: #1E293B;
        background-color: #FFFFFF;
        margin: 0;
        padding: 0;
    }

    h1, h2, h3, h4, h5, h6 {
        color: #0F172A;
        font-weight: 700;
        margin-top: 1.3em;
        margin-bottom: 0.4em;
        page-break-after: avoid;
    }

    h1 {
        font-size: 22pt;
        letter-spacing: -0.5px;
        line-height: 1.2;
        border-bottom: 2.5px solid #0284C7;
        padding-bottom: 8px;
        margin-top: 0;
        color: #0F172A;
    }

    h2 {
        font-size: 14pt;
        letter-spacing: -0.3px;
        border-bottom: 1.5px solid #E2E8F0;
        padding-bottom: 4px;
        margin-top: 1.6em;
        color: #0369A1;
    }

    h3 {
        font-size: 11.5pt;
        color: #0F172A;
        margin-top: 1.2em;
    }

    h4 {
        font-size: 10pt;
        color: #334155;
    }

    p {
        margin: 0.5em 0;
    }

    table {
        width: 100%;
        border-collapse: collapse;
        margin: 1em 0;
        font-size: 8.5pt;
        page-break-inside: avoid;
        background: #FFFFFF;
    }

    th, td {
        border: 1px solid #CBD5E1;
        padding: 6px 9px;
        text-align: left;
        vertical-align: top;
    }

    th {
        background-color: #F1F5F9;
        color: #0F172A;
        font-weight: 700;
    }

    tr:nth-child(even) td {
        background-color: #F8FAFC;
    }

    code {
        font-family: 'JetBrains Mono', Consolas, Monaco, monospace;
        font-size: 8.5pt;
        background-color: #F1F5F9;
        color: #0284C7;
        padding: 1.5px 4.5px;
        border-radius: 4px;
        border: 1px solid #E2E8F0;
    }

    pre {
        background-color: #0F172A;
        color: #F8FAFC;
        padding: 10px 14px;
        border-radius: 6px;
        overflow-x: auto;
        font-family: 'JetBrains Mono', Consolas, Monaco, monospace;
        font-size: 8pt;
        line-height: 1.45;
        margin: 0.8em 0;
        page-break-inside: avoid;
    }

    pre code {
        background-color: transparent;
        color: inherit;
        padding: 0;
        border: none;
        font-size: inherit;
    }

    hr {
        border: 0;
        border-top: 1px solid #E2E8F0;
        margin: 1.6em 0;
    }

    ul, ol {
        margin: 0.5em 0;
        padding-left: 20px;
    }

    li {
        margin: 0.25em 0;
    }

    .callout {
        border-radius: 6px;
        padding: 10px 14px;
        margin: 1em 0;
        page-break-inside: avoid;
    }

    .callout-title {
        font-weight: 700;
        font-size: 9pt;
        margin-bottom: 4px;
        display: flex;
        align-items: center;
        gap: 6px;
    }

    .callout-body {
        font-size: 8.5pt;
        line-height: 1.5;
    }

    .callout-note {
        background-color: #EFF6FF;
        border-left: 4px solid #3B82F6;
        color: #1E3A8A;
    }
    .callout-note .callout-title { color: #1D4ED8; }

    .callout-important {
        background-color: #EEF2FF;
        border-left: 4px solid #6366F1;
        color: #312E81;
    }
    .callout-important .callout-title { color: #4338CA; }

    .callout-warning {
        background-color: #FFFBEB;
        border-left: 4px solid #F59E0B;
        color: #78350F;
    }
    .callout-warning .callout-title { color: #B45309; }

    .callout-tip {
        background-color: #F0FDF4;
        border-left: 4px solid #10B981;
        color: #064E3B;
    }
    .callout-tip .callout-title { color: #047857; }

    .badge {
        display: inline-block;
        padding: 2px 7px;
        font-size: 7.5pt;
        font-weight: 600;
        border-radius: 4px;
        text-transform: uppercase;
    }
    .badge-pass { background-color: #DCFCE7; color: #15803D; }
    .badge-warn { background-color: #FEF3C7; color: #B45309; }
    .badge-crit { background-color: #FEE2E2; color: #B91C1C; }
    """

    full_html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>CampusOS — Backend Deployment Runbook</title>
    <style>
    {css_style}
    </style>
</head>
<body>
    {html_body}
</body>
</html>
"""

    with open(html_path, "w", encoding="utf-8") as f:
        f.write(full_html)
    print(f"[OK] Generated HTML: {html_path}")

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

    print("[RUNNING] Compiling PDF via Headless Edge...")
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode == 0 and os.path.exists(pdf_path):
        size_kb = os.path.getsize(pdf_path) / 1024
        print(f"[SUCCESS] PDF Generated Successfully!")
        print(f"  -> Path: {pdf_path}")
        print(f"  -> Size: {size_kb:.2f} KB")
    else:
        print(f"[ERROR] Failed to compile PDF (exit code {res.returncode}):")
        print(res.stderr or res.stdout)
        sys.exit(1)

if __name__ == "__main__":
    build_pdf()
