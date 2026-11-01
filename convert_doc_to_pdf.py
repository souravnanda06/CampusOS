import os
import sys
import subprocess
import markdown
import re

def build_pdf():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    md_path = os.path.join(script_dir, "docs", "CAMPUSOS_COMPLETE_DOCUMENTATION.md")
    html_path = os.path.join(script_dir, "docs", "CAMPUSOS_DOCUMENTATION.html")
    pdf_path = os.path.join(script_dir, "CampusOS_Complete_Product_and_Implementation_Documentation.pdf")
    
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
        elif alert_type == "WARNING" or alert_type == "CAUTION":
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
        margin: 20mm 16mm 20mm 16mm;
        @bottom-right {
            content: "Page " counter(page) " of " counter(pages);
            font-family: 'Plus Jakarta Sans', sans-serif;
            font-size: 8pt;
            color: #64748B;
        }
        @bottom-left {
            content: "CampusOS — BPUT Hackathon PS07 Documentation";
            font-family: 'Plus Jakarta Sans', sans-serif;
            font-size: 8pt;
            color: #64748B;
        }
    }

    body {
        font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        font-size: 10pt;
        line-height: 1.6;
        color: #1E293B;
        background-color: #FFFFFF;
        margin: 0;
        padding: 0;
    }

    h1, h2, h3, h4, h5, h6 {
        color: #0F172A;
        font-weight: 700;
        margin-top: 1.4em;
        margin-bottom: 0.5em;
        page-break-after: avoid;
    }

    h1 {
        font-size: 24pt;
        letter-spacing: -0.5px;
        line-height: 1.2;
        border-bottom: 2px solid #0F172A;
        padding-bottom: 8px;
        margin-top: 0;
    }

    h2 {
        font-size: 15pt;
        letter-spacing: -0.3px;
        border-bottom: 1px solid #E2E8F0;
        padding-bottom: 5px;
        margin-top: 1.8em;
    }

    h3 {
        font-size: 12pt;
        color: #1E293B;
    }

    h4 {
        font-size: 10.5pt;
        color: #334155;
    }

    p {
        margin: 0.6em 0;
    }

    table {
        width: 100%;
        border-collapse: collapse;
        margin: 1.2em 0;
        font-size: 8.5pt;
        page-break-inside: avoid;
        background: #FFFFFF;
    }

    th, td {
        border: 1px solid #CBD5E1;
        padding: 6px 10px;
        text-align: left;
        vertical-align: top;
    }

    th {
        background-color: #0F172A;
        color: #F8FAFC;
        font-weight: 600;
        text-transform: uppercase;
        font-size: 7.5pt;
        letter-spacing: 0.5px;
    }

    tr:nth-child(even) td {
        background-color: #F8FAFC;
    }

    pre {
        background-color: #0F172A;
        color: #E2E8F0;
        padding: 12px 14px;
        border-radius: 6px;
        font-family: 'JetBrains Mono', Consolas, monospace;
        font-size: 8pt;
        line-height: 1.45;
        overflow-x: auto;
        page-break-inside: avoid;
        border: 1px solid #1E293B;
        margin: 1em 0;
    }

    code {
        font-family: 'JetBrains Mono', Consolas, monospace;
        font-size: 8.5pt;
        background-color: #F1F5F9;
        color: #0F172A;
        padding: 2px 5px;
        border-radius: 4px;
        border: 1px solid #E2E8F0;
    }

    pre code {
        background-color: transparent;
        color: inherit;
        padding: 0;
        border: none;
    }

    blockquote {
        margin: 1em 0;
        padding: 10px 16px;
        border-left: 4px solid #2563EB;
        background-color: #F8FAFC;
        color: #334155;
        page-break-inside: avoid;
        border-radius: 0 4px 4px 0;
    }

    .callout {
        margin: 1.2em 0;
        padding: 12px 16px;
        border-radius: 6px;
        page-break-inside: avoid;
        border-left: 5px solid;
    }

    .callout-title {
        font-weight: 700;
        font-size: 9pt;
        margin-bottom: 4px;
        text-transform: uppercase;
        letter-spacing: 0.5px;
    }

    .callout-body {
        font-size: 9.5pt;
    }

    .callout-note {
        background-color: #EFF6FF;
        border-color: #2563EB;
        color: #1E3A8A;
    }

    .callout-important {
        background-color: #F5F3FF;
        border-color: #7C3AED;
        color: #4C1D95;
    }

    .callout-warning {
        background-color: #FFFBEB;
        border-color: #D97706;
        color: #78350F;
    }

    .callout-tip {
        background-color: #ECFDF5;
        border-color: #059669;
        color: #064E3B;
    }

    ul, ol {
        margin: 0.6em 0;
        padding-left: 20px;
    }

    li {
        margin-bottom: 4px;
    }

    hr {
        border: none;
        border-top: 1px solid #E2E8F0;
        margin: 2em 0;
    }

    .cover-meta {
        background: #F8FAFC;
        border: 1px solid #E2E8F0;
        border-radius: 8px;
        padding: 16px 20px;
        margin-bottom: 2em;
    }

    .cover-meta table {
        margin: 0;
        background: transparent;
    }

    .cover-meta td {
        border: none;
        padding: 4px 8px;
    }

    .status-badge {
        display: inline-block;
        padding: 2px 8px;
        border-radius: 9999px;
        font-size: 7.5pt;
        font-weight: 700;
        letter-spacing: 0.3px;
    }

    .badge-green { background: #DCFCE7; color: #166534; }
    .badge-yellow { background: #FEF9C3; color: #854D0E; }
    .badge-blue { background: #DBEAFE; color: #1E40AF; }
    .badge-red { background: #FEE2E2; color: #991B1B; }

    .page-break {
        page-break-before: always;
    }
    """

    full_html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>CampusOS — Complete Product & Implementation Documentation</title>
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
