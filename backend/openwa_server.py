"""
OpenWA Dev Gateway & Interactive WhatsApp Emulator for CampusOS.
Implements the OpenWA REST API specification on port 2785 and bundles
a real-time WhatsApp simulation dashboard.
"""

import sys
import json
import uuid
import datetime
import urllib.request
import urllib.error
from flask import Flask, request, jsonify, render_template_string

if sys.platform == 'win32':
    try:
        if sys.stdout and hasattr(sys.stdout, 'reconfigure'):
            sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

app = Flask(__name__)

SENT_MESSAGES = []
CAMPUSOS_WEBHOOK_URL = "http://127.0.0.1:5000/whatsapp/webhook"

DASHBOARD_HTML = """
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>OpenWA Gateway — CampusOS WhatsApp Console</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
  <style>
    :root {
      --bg: #0b101b;
      --card: #131b2e;
      --card-border: #1e293b;
      --primary: #25d366;
      --primary-hover: #1ebd5a;
      --text: #f8fafc;
      --text-muted: #94a3b8;
      --accent: #38bdf8;
      --bubble-in: #1e293b;
      --bubble-out: #056162;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background: var(--bg);
      color: var(--text);
      font-family: 'Plus Jakarta Sans', sans-serif;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
    }
    header {
      background: #0f172a;
      border-bottom: 1px solid var(--card-border);
      padding: 16px 24px;
      display: flex;
      align-items: center;
      justify-content: space-between;
    }
    .logo {
      display: flex;
      align-items: center;
      gap: 12px;
      font-weight: 700;
      font-size: 1.15rem;
    }
    .logo-badge {
      background: #25d36622;
      color: var(--primary);
      border: 1px solid #25d36644;
      padding: 4px 8px;
      border-radius: 6px;
      font-size: 0.75rem;
      font-family: 'JetBrains Mono', monospace;
    }
    .status-pill {
      display: flex;
      align-items: center;
      gap: 8px;
      font-size: 0.82rem;
      color: #a7f3d0;
      background: #064e3b44;
      border: 1px solid #065f46;
      padding: 6px 14px;
      border-radius: 9999px;
    }
    .dot {
      width: 8px;
      height: 8px;
      background: var(--primary);
      border-radius: 50%;
      box-shadow: 0 0 10px var(--primary);
      animation: pulse 2s infinite;
    }
    @keyframes pulse {
      0%, 100% { opacity: 1; }
      50% { opacity: 0.4; }
    }
    main {
      flex: 1;
      display: grid;
      grid-template-columns: 1.2fr 1fr;
      gap: 20px;
      padding: 24px;
      max-width: 1400px;
      width: 100%;
      margin: 0 auto;
    }
    .panel {
      background: var(--card);
      border: 1px solid var(--card-border);
      border-radius: 14px;
      display: flex;
      flex-direction: column;
      overflow: hidden;
      height: calc(100vh - 120px);
    }
    .panel-header {
      padding: 16px 20px;
      border-bottom: 1px solid var(--card-border);
      background: #111827;
      display: flex;
      align-items: center;
      justify-content: space-between;
    }
    .panel-header h2 {
      font-size: 0.95rem;
      font-weight: 600;
      display: flex;
      align-items: center;
      gap: 8px;
    }
    .badge-count {
      background: #1e293b;
      padding: 2px 8px;
      border-radius: 12px;
      font-size: 0.75rem;
      color: var(--text-muted);
    }
    .panel-body {
      flex: 1;
      overflow-y: auto;
      padding: 16px;
      display: flex;
      flex-direction: column;
      gap: 12px;
    }
    /* Feed item */
    .msg-card {
      background: #0f172a;
      border: 1px solid #1e293b;
      border-radius: 10px;
      padding: 14px;
      display: flex;
      flex-direction: column;
      gap: 8px;
    }
    .msg-card-top {
      display: flex;
      align-items: center;
      justify-content: space-between;
      font-size: 0.78rem;
    }
    .recipient {
      font-family: 'JetBrains Mono', monospace;
      color: var(--accent);
      font-weight: 500;
    }
    .time { color: var(--text-muted); }
    .msg-text {
      font-size: 0.88rem;
      line-height: 1.5;
      white-space: pre-wrap;
      color: #e2e8f0;
      background: #131d33;
      padding: 10px;
      border-radius: 8px;
      border-left: 3px solid var(--primary);
    }
    /* Chat simulator */
    .chat-view {
      display: flex;
      flex-direction: column;
      height: 100%;
    }
    .chat-messages {
      flex: 1;
      overflow-y: auto;
      padding: 16px;
      display: flex;
      flex-direction: column;
      gap: 12px;
      background: #0a0f1d;
    }
    .chat-bubble {
      max-width: 82%;
      padding: 10px 14px;
      border-radius: 12px;
      font-size: 0.88rem;
      line-height: 1.45;
      white-space: pre-wrap;
      position: relative;
    }
    .chat-bubble.in {
      align-self: flex-start;
      background: var(--bubble-in);
      color: #f1f5f9;
      border-bottom-left-radius: 3px;
    }
    .chat-bubble.out {
      align-self: flex-end;
      background: var(--bubble-out);
      color: #f1f5f9;
      border-bottom-right-radius: 3px;
    }
    .chat-bubble-meta {
      font-size: 0.68rem;
      color: #94a3b8;
      margin-top: 4px;
      text-align: right;
    }
    .chat-controls {
      padding: 16px;
      background: #111827;
      border-top: 1px solid var(--card-border);
      display: flex;
      flex-direction: column;
      gap: 10px;
    }
    .role-select {
      display: flex;
      gap: 8px;
      font-size: 0.8rem;
    }
    .role-btn {
      background: #1e293b;
      border: 1px solid #334155;
      color: #cbd5e1;
      padding: 6px 12px;
      border-radius: 6px;
      cursor: pointer;
      font-size: 0.78rem;
    }
    .role-btn.active {
      background: #047857;
      border-color: #10b981;
      color: #fff;
    }
    .input-row {
      display: flex;
      gap: 8px;
    }
    .input-box {
      flex: 1;
      background: #0b1120;
      border: 1px solid #334155;
      border-radius: 8px;
      color: #fff;
      padding: 10px 14px;
      font-size: 0.88rem;
      font-family: inherit;
      outline: none;
    }
    .input-box:focus { border-color: var(--primary); }
    .send-btn {
      background: var(--primary);
      color: #000;
      font-weight: 600;
      border: none;
      border-radius: 8px;
      padding: 0 18px;
      cursor: pointer;
      transition: background 0.15s;
    }
    .send-btn:hover { background: var(--primary-hover); }
    .quick-chips {
      display: flex;
      gap: 6px;
      flex-wrap: wrap;
    }
    .chip {
      background: #1e293b;
      font-size: 0.72rem;
      padding: 3px 8px;
      border-radius: 12px;
      cursor: pointer;
      color: #94a3b8;
      border: 1px solid #334155;
    }
    .chip:hover { color: #f8fafc; border-color: var(--primary); }
  </style>
</head>
<body>
  <header>
    <div class="logo">
      <span>🟢 OpenWA Gateway</span>
      <span class="logo-badge">PORT 2785</span>
      <span class="logo-badge">BAILEYS ENGINE</span>
    </div>
    <div class="status-pill">
      <span class="dot"></span>
      <span>Session: default (Connected & Live)</span>
    </div>
  </header>

  <main>
    <!-- Left: Sent Message Feed -->
    <div class="panel">
      <div class="panel-header">
        <h2>📤 Outbound WhatsApp Dispatches (From CampusOS)</h2>
        <span class="badge-count" id="outbound-count">0 messages</span>
      </div>
      <div class="panel-body" id="outbound-feed">
        <p style="color: var(--text-muted); font-size: 0.85rem; text-align: center; margin-top: 40px;">
          No outbound WhatsApp messages yet.<br>
          Trigger a Gate Pass transit, Leave approval, or Fee alert in CampusOS to view them here in real time!
        </p>
      </div>
    </div>

    <!-- Right: Interactive WhatsApp Simulator -->
    <div class="panel">
      <div class="panel-header">
        <h2>📱 Interactive WhatsApp Simulator (To CampusOS Copilot)</h2>
        <span class="badge-count">2-Way Bot</span>
      </div>
      <div class="chat-view">
        <div class="chat-messages" id="sim-chat">
          <div class="chat-bubble in">
            👋 Welcome to CampusOS WhatsApp Simulator! Select a caller profile below and test conversational interactions with the Campus Copilot AI bot or check Parent status inquiries.
            <div class="chat-bubble-meta">System</div>
          </div>
        </div>
        <div class="chat-controls">
          <div class="role-select">
            <button class="role-btn active" id="btn-student" onclick="setProfile('student')">👨‍🎓 Student (+91 9998887776)</button>
            <button class="role-btn" id="btn-parent" onclick="setProfile('parent')">🛡️ Parent (+91 8887776665)</button>
            <button class="role-btn" id="btn-guest" onclick="setProfile('guest')">👤 Unregistered Guest</button>
          </div>
          <div class="quick-chips">
            <span class="chip" onclick="quickSend('What is the dinner menu tonight?')">🍽️ Mess Menu</span>
            <span class="chip" onclick="quickSend('What is my attendance percentage?')">📊 My Attendance</span>
            <span class="chip" onclick="quickSend('gatepass')">🎟️ Gate Pass Status</span>
            <span class="chip" onclick="quickSend('Where is my next class?')">📍 Next Class</span>
          </div>
          <div class="input-row">
            <input type="text" id="sim-input" class="input-box" placeholder="Type a message to WhatsApp bot..." onkeydown="if(event.key==='Enter') sendSimMessage()">
            <button class="send-btn" onclick="sendSimMessage()">Send</button>
          </div>
        </div>
      </div>
    </div>
  </main>

  <script>
    let activePhone = '919998887776';
    let lastMsgCount = 0;

    function setProfile(type) {
      document.querySelectorAll('.role-btn').forEach(b => b.classList.remove('active'));
      if (type === 'student') {
        activePhone = '919998887776';
        document.getElementById('btn-student').classList.add('active');
      } else if (type === 'parent') {
        activePhone = '918887776665';
        document.getElementById('btn-parent').classList.add('active');
      } else {
        activePhone = '919000000000';
        document.getElementById('btn-guest').classList.add('active');
      }
    }

    function quickSend(txt) {
      document.getElementById('sim-input').value = txt;
      sendSimMessage();
    }

    async function sendSimMessage() {
      const input = document.getElementById('sim-input');
      const text = input.value.trim();
      if (!text) return;
      input.value = '';

      const chat = document.getElementById('sim-chat');
      // Append user bubble
      const userBubble = document.createElement('div');
      userBubble.className = 'chat-bubble out';
      userBubble.innerHTML = text + '<div class="chat-bubble-meta">' + new Date().toLocaleTimeString() + ' • ' + activePhone + '</div>';
      chat.appendChild(userBubble);
      chat.scrollTop = chat.scrollHeight;

      // Forward to CampusOS webhook
      try {
        const resp = await fetch('/api/simulator/send', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ phone: activePhone, text: text })
        });
        const data = await resp.json();
      } catch (e) {
        console.error(e);
      }
    }

    async function pollUpdates() {
      try {
        const resp = await fetch('/api/messages');
        const list = await resp.json();
        if (list.length !== lastMsgCount) {
          lastMsgCount = list.length;
          renderFeed(list);
        }
      } catch (e) {}
      setTimeout(pollUpdates, 1500);
    }

    function renderFeed(list) {
      document.getElementById('outbound-count').innerText = list.length + ' messages';
      const feed = document.getElementById('outbound-feed');
      if (list.length === 0) return;
      feed.innerHTML = '';
      [...list].reverse().forEach(m => {
        const card = document.createElement('div');
        card.className = 'msg-card';
        card.innerHTML = `
          <div class="msg-card-top">
            <span class="recipient">To: ${m.chatId}</span>
            <span class="time">${new Date(m.timestamp).toLocaleTimeString()}</span>
          </div>
          <div class="msg-text">${m.text}</div>
        `;
        feed.appendChild(card);
      });
    }

    pollUpdates();
  </script>
</body>
</html>
"""

@app.route('/', methods=['GET'])
@app.route('/dashboard', methods=['GET'])
def index():
    return render_template_string(DASHBOARD_HTML)


@app.route('/health', methods=['GET'])
def health():
    return jsonify({
        "status": "healthy",
        "engine": "baileys",
        "session": "default",
        "version": "0.30.0"
    }), 200


@app.route('/api/sessions', methods=['GET'])
def list_sessions():
    return jsonify([{
        "id": "default",
        "status": "AUTHENTICATED",
        "engine": "baileys",
        "phone": "+91 99000 12345"
    }]), 200


@app.route('/api/messages', methods=['GET'])
def get_messages():
    return jsonify(SENT_MESSAGES), 200


@app.route('/api/sessions/<session_id>/messages/send-text', methods=['POST'])
@app.route('/api/sendText', methods=['POST'])
def send_text(session_id="default"):
    data = request.json or {}
    chat_id = data.get('chatId') or data.get('phone') or ''
    text = data.get('text') or data.get('message') or ''

    if not chat_id or not text:
        return jsonify({"message": "chatId and text are required"}), 400

    msg_record = {
        "id": f"msg_{uuid.uuid4().hex[:12]}",
        "chatId": chat_id,
        "text": text,
        "timestamp": datetime.datetime.now().isoformat(),
        "status": "DELIVERED"
    }
    SENT_MESSAGES.append(msg_record)

    return jsonify({
        "success": True,
        "messageId": msg_record["id"],
        "chatId": chat_id,
        "timestamp": msg_record["timestamp"]
    }), 200


@app.route('/api/simulator/send', methods=['POST'])
def simulator_inbound():
    """Simulates an inbound WhatsApp user message forwarded to CampusOS Webhook."""
    data = request.json or {}
    phone = data.get('phone', '919998887776')
    text = data.get('text', '')
    chat_id = f"{phone}@c.us" if '@' not in phone else phone

    webhook_payload = {
        "event": "message.received",
        "data": {
            "chatId": chat_id,
            "body": text,
            "fromMe": False,
            "type": "chat",
            "timestamp": int(datetime.datetime.now().timestamp())
        }
    }

    try:
        req_bytes = json.dumps(webhook_payload).encode('utf-8')
        req = urllib.request.Request(
            CAMPUSOS_WEBHOOK_URL,
            data=req_bytes,
            headers={'Content-Type': 'application/json'},
            method='POST'
        )
        with urllib.request.urlopen(req, timeout=8.0) as resp:
            resp_body = resp.read().decode('utf-8')
            return jsonify({"status": "forwarded_to_campusos", "response": resp_body}), 200
    except Exception as e:
        return jsonify({"status": "webhook_error", "error": str(e)}), 502


if __name__ == '__main__':
    port = 2785
    print(f"🟢 [OpenWA Gateway] Starting WhatsApp API & Dashboard on http://localhost:{port}...")
    app.run(debug=False, host='0.0.0.0', port=port)
