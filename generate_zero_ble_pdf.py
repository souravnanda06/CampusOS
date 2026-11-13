import os
import sys
import subprocess
import markdown
import re

def build_pdf():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    md_path = os.path.join(script_dir, "docs", "CAMPUSOS_ZERO_BLE_ATTENDANCE_EXPLAINER.md")
    html_path = os.path.join(script_dir, "docs", "CAMPUSOS_ZERO_BLE_ATTENDANCE_EXPLAINER.html")
    pdf_path = os.path.join(script_dir, "CampusOS_Zero_BLE_Attendance_Architecture_Guide.pdf")
    
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

    md_content = re.sub(
        r'> \[!(NOTE|IMPORTANT|WARNING|TIP|CAUTION)\]\s*\n((?:> .*\n?)+)',
        lambda m: replace_alerts(re.match(r'> \[!(NOTE|IMPORTANT|WARNING|TIP|CAUTION)\]\s*\n(.*)', m.group(0), re.DOTALL)),
        md_content
    )
    
    md_content = re.sub(r'<div class="callout-body">\s*> (.*?)</div>', r'<div class="callout-body">\1</div>', md_content, flags=re.DOTALL)

    # Protect mermaid blocks from being mangled by markdown extension
    mermaid_blocks = []
    def save_mermaid(match):
        idx = len(mermaid_blocks)
        mermaid_blocks.append(match.group(1).strip())
        return f"<!--MERMAID_PLACEHOLDER_{idx}-->"

    md_content = re.sub(r'```mermaid\s*\n([\s\S]*?)```', save_mermaid, md_content)

    html_body = markdown.markdown(
        md_content,
        extensions=[
            'markdown.extensions.tables',
            'markdown.extensions.fenced_code',
            'markdown.extensions.nl2br',
            'markdown.extensions.sane_lists'
        ]
    )

    # Restore mermaid blocks
    for i, code in enumerate(mermaid_blocks):
        clean_code = code.replace("<", "&lt;").replace(">", "&gt;")
        replacement = f'<div class="mermaid-container"><pre class="mermaid">{clean_code}</pre></div>'
        html_body = html_body.replace(f"<!--MERMAID_PLACEHOLDER_{i}-->", replacement)

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
            content: "CampusOS — Zero-BLE Attendance Architecture Guide";
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
        font-size: 20pt;
        letter-spacing: -0.5px;
        line-height: 1.2;
        border-bottom: 2px solid #DC2626;
        padding-bottom: 6px;
        margin-top: 0;
        color: #991B1B;
    }

    h2 {
        font-size: 13.5pt;
        letter-spacing: -0.3px;
        color: #1E293B;
        border-bottom: 1px solid #E2E8F0;
        padding-bottom: 4px;
        margin-top: 1.5em;
        page-break-after: avoid;
    }

    h3 {
        font-size: 11pt;
        color: #334155;
        margin-top: 1.1em;
        page-break-after: avoid;
    }

    p {
        margin-top: 0;
        margin-bottom: 0.7em;
        text-align: justify;
    }

    ul, ol {
        margin-top: 0;
        margin-bottom: 0.8em;
        padding-left: 20px;
    }

    li {
        margin-bottom: 0.3em;
    }

    code {
        font-family: 'JetBrains Mono', Consolas, Monaco, monospace;
        font-size: 8.5pt;
        background-color: #F1F5F9;
        color: #0F172A;
        padding: 2px 5px;
        border-radius: 4px;
        border: 1px solid #E2E8F0;
    }

    pre {
        font-family: 'JetBrains Mono', Consolas, Monaco, monospace;
        font-size: 8pt;
        line-height: 1.4;
        background-color: #0F172A;
        color: #E2E8F0;
        padding: 10px 12px;
        border-radius: 6px;
        overflow-x: auto;
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

    .mermaid-container {
        background: #F8FAFC;
        border: 1px solid #E2E8F0;
        border-radius: 8px;
        padding: 12px;
        margin: 1em 0;
        text-align: center;
        page-break-inside: avoid;
    }

    .mermaid {
        background: transparent !important;
        font-family: 'Plus Jakarta Sans', sans-serif !important;
        color: #0F172A !important;
    }

    table {
        width: 100%;
        border-collapse: collapse;
        margin: 1em 0;
        font-size: 8.5pt;
        page-break-inside: avoid;
    }

    th, td {
        border: 1px solid #CBD5E1;
        padding: 6px 10px;
        text-align: left;
    }

    th {
        background-color: #F1F5F9;
        color: #0F172A;
        font-weight: 700;
        border-bottom: 2px solid #94A3B8;
    }

    tr:nth-child(even) {
        background-color: #F8FAFC;
    }

    blockquote {
        margin: 1em 0;
        padding: 10px 16px;
        background-color: #F8FAFC;
        border-left: 4px solid #3B82F6;
        font-style: italic;
        color: #334155;
        border-radius: 0 6px 6px 0;
        page-break-inside: avoid;
    }

    .callout {
        border-left: 4px solid #2563EB;
        background: #EFF6FF;
        border-radius: 0 6px 6px 0;
        padding: 8px 12px;
        margin: 0.9em 0;
        page-break-inside: avoid;
    }

    .callout-title {
        font-weight: 700;
        font-size: 9pt;
        margin-bottom: 4px;
        color: #1E40AF;
    }

    .callout-body {
        font-size: 8.5pt;
        line-height: 1.45;
        color: #1E293B;
    }

    .callout-warning {
        border-left-color: #E11D48;
        background: #FFF1F2;
    }
    .callout-warning .callout-title {
        color: #BE123C;
    }

    .callout-important {
        border-left-color: #D97706;
        background: #FFFBEB;
    }
    .callout-important .callout-title {
        color: #B45309;
    }

    .callout-tip {
        border-left-color: #059669;
        background: #ECFDF5;
    }
    .callout-tip .callout-title {
        color: #047857;
    }

    hr {
        border: none;
        border-top: 1px solid #E2E8F0;
        margin: 1.5em 0;
    }
    """

    full_html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>CampusOS — Zero-BLE Attendance Architecture Guide</title>
    <style>
    {css_style}
    </style>
    <script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"></script>
    <script>
    mermaid.initialize({{
        startOnLoad: true,
        theme: 'neutral',
        flowchart: {{ useMaxWidth: true, htmlLabels: true, curve: 'basis' }},
        sequence: {{ useMaxWidth: true, showSequenceNumbers: true }}
    }});
    </script>
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
        "--virtual-time-budget=5000",
        "--run-all-compositor-stages-before-draw",
        "--no-pdf-header-footer",
        f"--print-to-pdf={pdf_path}",
        html_path
    ]

    print("[RUNNING] Compiling Zero-BLE PDF via Headless Edge...")
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode == 0 and os.path.exists(pdf_path):
        size_kb = os.path.getsize(pdf_path) / 1024
        print(f"[SUCCESS] Zero-BLE PDF Generated Successfully!")
        print(f"  -> Path: {pdf_path}")
        print(f"  -> Size: {size_kb:.2f} KB")
    else:
        print(f"[ERROR] Failed to compile PDF (exit code {res.returncode}):")
        print(res.stderr or res.stdout)
        sys.exit(1)

if __name__ == "__main__":
    build_pdf()
