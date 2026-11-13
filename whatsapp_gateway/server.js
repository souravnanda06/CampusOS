const express = require('express');
const QRCode = require('qrcode');
const pino = require('pino');
const path = require('path');
const fs = require('fs');
const http = require('http');

const {
  default: makeWASocket,
  useMultiFileAuthState,
  DisconnectReason,
  fetchLatestBaileysVersion,
  Browsers
} = require('@whiskeysockets/baileys');

const app = express();
app.use(express.json());

const PORT = 2785;
const CAMPUSOS_WEBHOOK = "http://127.0.0.1:5000/whatsapp/webhook";
const AUTH_DIR = path.join(__dirname, 'baileys_auth_info');

let sock = null;
let currentQR = null;
let qrDataUrl = null;
let connectionStatus = 'DISCONNECTED'; // DISCONNECTED, CONNECTING, CONNECTED
let connectedUser = null;
const messageLogs = [];

async function forwardToCampusOS(payload) {
  try {
    const data = JSON.stringify(payload);
    const url = new URL(CAMPUSOS_WEBHOOK);
    const req = http.request(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(data)
      },
      timeout: 5000
    });
    req.on('error', (err) => console.log('[Webhook Error]', err.message));
    req.write(data);
    req.end();
  } catch (err) {
    console.log('[Webhook Failed]', err.message);
  }
}

async function flushQueuedMessages() {
  if (!sock || connectionStatus !== 'CONNECTED') return;

  for (const m of messageLogs) {
    if (m.status === 'QUEUED_AWAITING_PAIRING') {
      try {
        const rawDigits = m.chatId.replace(/\D/g, '');
        const targetJid = `${rawDigits}@s.whatsapp.net`;
        const sent = await sock.sendMessage(targetJid, { text: m.text });
        m.status = 'SENT_TO_WHATSAPP';
        m.id = sent.key.id;
        console.log(`🚀 [Auto-Flushed Message] To: ${targetJid} (ID: ${sent.key.id})`);
      } catch (e) {
        console.error('Failed to flush message:', e.message);
      }
    }
  }
}

async function connectToWhatsApp() {
  try {
    if (!fs.existsSync(AUTH_DIR)) {
      fs.mkdirSync(AUTH_DIR, { recursive: true });
    }

    const { state, saveCreds } = await useMultiFileAuthState(AUTH_DIR);
    const { version } = await fetchLatestBaileysVersion();

    connectionStatus = 'CONNECTING';

    sock = makeWASocket({
      version,
      logger: pino({ level: 'silent' }),
      printQRInTerminal: true,
      auth: state,
      browser: Browsers.windows('Desktop'),
      syncFullHistory: false,
      markOnlineOnConnect: true,
      keepAliveIntervalMs: 25000
    });

    sock.ev.on('creds.update', saveCreds);

    sock.ev.on('connection.update', async (update) => {
      const { connection, lastDisconnect, qr } = update;

      if (qr) {
        currentQR = qr;
        try {
          qrDataUrl = await QRCode.toDataURL(qr);
        } catch (err) {
          console.error('Failed to generate QR Data URL', err);
        }
        console.log('📱 [OpenWA] New WhatsApp Web pairing QR code generated.');
      }

      if (connection === 'close') {
        const statusCode = (lastDisconnect?.error)?.output?.statusCode;
        const isLoggedOut = statusCode === DisconnectReason.loggedOut || statusCode === 401;
        console.log(`🔴 [OpenWA] Connection closed (code ${statusCode || 'unknown'}).`);

        connectionStatus = 'DISCONNECTED';
        currentQR = null;
        qrDataUrl = null;
        connectedUser = null;

        if (isLoggedOut) {
          console.log('🧹 [OpenWA] Session unlinked. Purging stale auth credentials for fresh scan...');
          try {
            fs.rmSync(AUTH_DIR, { recursive: true, force: true });
          } catch (e) {}
        }

        // Always re-initialize to keep gateway alive and listening
        setTimeout(connectToWhatsApp, 2500);
      } else if (connection === 'open') {
        console.log('🟢 [OpenWA] WhatsApp connection opened successfully!');
        connectionStatus = 'CONNECTED';
        currentQR = null;
        qrDataUrl = null;
        connectedUser = sock.user ? sock.user.id.split(':')[0] : 'Linked';

        // Auto-flush queued messages immediately
        setTimeout(flushQueuedMessages, 1000);
      }
    });

    sock.ev.on('messages.upsert', async (m) => {
      if (m.type === 'notify') {
        for (const msg of m.messages) {
          if (!msg.key.fromMe && msg.message) {
            const senderJid = msg.key.remoteJid;
            const text = msg.message.conversation || msg.message.extendedTextMessage?.text || '';
            if (text) {
              console.log(`📩 [OpenWA Inbound] From: ${senderJid} | Body: ${text}`);
              messageLogs.push({
                direction: 'INBOUND',
                chatId: senderJid,
                text: text,
                timestamp: new Date().toISOString()
              });

              // Forward to CampusOS Copilot Webhook
              forwardToCampusOS({
                event: 'message.received',
                data: {
                  chatId: senderJid,
                  body: text,
                  fromMe: false,
                  timestamp: msg.messageTimestamp
                }
              });
            }
          }
        }
      }
    });
  } catch (err) {
    console.error('Error in connectToWhatsApp:', err.message);
    setTimeout(connectToWhatsApp, 3000);
  }
}

// ==========================================
// OpenWA REST API Endpoints
// ==========================================

app.get('/health', (req, res) => {
  res.json({
    status: connectionStatus === 'CONNECTED' ? 'healthy' : 'degraded',
    connectionStatus,
    engine: 'baileys-live',
    user: connectedUser,
    hasQR: Boolean(qrDataUrl)
  });
});

app.get('/api/status', (req, res) => {
  res.json({
    status: connectionStatus,
    phone: connectedUser,
    qr: qrDataUrl,
    messagesCount: messageLogs.length
  });
});

app.get('/api/sessions', (req, res) => {
  res.json([{
    id: 'default',
    status: connectionStatus === 'CONNECTED' ? 'AUTHENTICATED' : 'SCAN_QR_CODE',
    engine: 'baileys',
    phone: connectedUser || null
  }]);
});

app.get('/api/messages', (req, res) => {
  res.json(messageLogs);
});

// Outbound Message Dispatch
app.post(['/api/sessions/:sessionId/messages/send-text', '/api/sendText'], async (req, res) => {
  const { chatId, text, phone } = req.body;
  let target = chatId || phone;

  if (!target || !text) {
    return res.status(400).json({ message: 'chatId and text are required' });
  }

  // Format recipient JID
  let digits = target.replace(/\D/g, '');
  if (digits.length === 10) {
    digits = '91' + digits;
  }
  const jid = `${digits}@s.whatsapp.net`;

  console.log(`📤 [OpenWA Dispatch Request] To: ${jid} | Text: ${text.slice(0, 40)}...`);

  if (!sock || connectionStatus !== 'CONNECTED') {
    // Log message as queued/pending link
    const logItem = {
      id: `msg_${Date.now()}`,
      direction: 'OUTBOUND',
      chatId: `${digits}@c.us`,
      text: text,
      status: 'QUEUED_AWAITING_PAIRING',
      timestamp: new Date().toISOString()
    };
    messageLogs.push(logItem);
    return res.json({
      success: true,
      queued: true,
      messageId: logItem.id,
      note: 'Gateway active; scan QR code at http://localhost:2785 to complete physical WhatsApp network delivery.'
    });
  }

  try {
    const sent = await sock.sendMessage(jid, { text: text });
    const logItem = {
      id: sent.key.id,
      direction: 'OUTBOUND',
      chatId: `${digits}@c.us`,
      text: text,
      status: 'SENT_TO_WHATSAPP',
      timestamp: new Date().toISOString()
    };
    messageLogs.push(logItem);

    console.log(`✅ [Delivered to WhatsApp Network] Message ID: ${sent.key.id}`);
    res.json({
      success: true,
      messageId: sent.key.id,
      chatId: `${digits}@c.us`,
      timestamp: logItem.timestamp
    });
  } catch (err) {
    console.error('Error sending WhatsApp message:', err);
    res.status(500).json({ error: err.message });
  }
});

// Interactive Dashboard UI
app.get(['/', '/dashboard'], (req, res) => {
  res.send(`
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>OpenWA Live WhatsApp Gateway</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
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
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { background: var(--bg); color: var(--text); font-family: 'Plus Jakarta Sans', sans-serif; min-height: 100vh; display: flex; flex-direction: column; }
    header { background: #0f172a; border-bottom: 1px solid var(--card-border); padding: 16px 24px; display: flex; align-items: center; justify-content: space-between; }
    .logo { display: flex; align-items: center; gap: 12px; font-weight: 700; font-size: 1.15rem; }
    .badge { background: #25d36622; color: var(--primary); border: 1px solid #25d36644; padding: 4px 8px; border-radius: 6px; font-size: 0.75rem; font-family: 'JetBrains Mono', monospace; }
    .status-pill { display: flex; align-items: center; gap: 8px; font-size: 0.82rem; padding: 6px 14px; border-radius: 9999px; }
    .status-connected { color: #a7f3d0; background: #064e3b44; border: 1px solid #065f46; }
    .status-pairing { color: #fde68a; background: #78350f44; border: 1px solid #b45309; }
    main { flex: 1; display: grid; grid-template-columns: 380px 1fr; gap: 20px; padding: 24px; max-width: 1400px; width: 100%; margin: 0 auto; }
    .card { background: var(--card); border: 1px solid var(--card-border); border-radius: 14px; display: flex; flex-direction: column; overflow: hidden; }
    .card-header { padding: 16px 20px; border-bottom: 1px solid var(--card-border); background: #111827; font-weight: 600; font-size: 0.95rem; }
    .card-body { padding: 20px; flex: 1; display: flex; flex-direction: column; }
    .qr-container { background: #fff; padding: 16px; border-radius: 12px; width: fit-content; margin: 0 auto 16px; display: flex; align-items: center; justify-content: center; }
    .qr-container img { width: 220px; height: 220px; display: block; }
    .instructions { font-size: 0.85rem; line-height: 1.6; color: var(--text-muted); }
    .instructions ol { padding-left: 20px; margin-top: 8px; }
    .instructions li { margin-bottom: 4px; }
    .connected-box { background: #064e3b22; border: 1px solid #065f46; border-radius: 12px; padding: 20px; text-align: center; }
    .connected-box h3 { color: var(--primary); margin-bottom: 6px; }
    .feed { flex: 1; overflow-y: auto; display: flex; flex-direction: column; gap: 10px; }
    .msg-item { background: #0f172a; border: 1px solid #1e293b; border-radius: 10px; padding: 12px; font-size: 0.85rem; }
    .msg-header { display: flex; justify-content: space-between; margin-bottom: 6px; font-family: 'JetBrains Mono', monospace; font-size: 0.75rem; color: var(--accent); }
    .msg-body { white-space: pre-wrap; color: #e2e8f0; background: #131d33; padding: 8px 10px; border-radius: 6px; border-left: 3px solid var(--primary); }
    .send-test-box { margin-top: 16px; padding-top: 16px; border-top: 1px solid var(--card-border); display: flex; gap: 8px; }
    input { background: #0b1120; border: 1px solid #334155; border-radius: 8px; color: #fff; padding: 10px 14px; font-size: 0.88rem; flex: 1; }
    button { background: var(--primary); color: #000; font-weight: 600; border: none; border-radius: 8px; padding: 0 18px; cursor: pointer; }
    button:hover { background: var(--primary-hover); }
  </style>
</head>
<body>
  <header>
    <div class="logo">
      <span>🟢 OpenWA Live Gateway</span>
      <span class="badge">BAILEYS MULTI-DEVICE</span>
      <span class="badge">PORT 2785</span>
    </div>
    <div id="status-pill" class="status-pill status-pairing">
      <span id="status-text">Connecting...</span>
    </div>
  </header>

  <main>
    <!-- Left Column: Pairing & Status -->
    <div class="card">
      <div class="card-header">📲 WhatsApp Account Pairing</div>
      <div class="card-body" id="pairing-pane">
        <div style="text-align:center; padding: 40px 0; color: var(--text-muted);">
          Loading pairing status...
        </div>
      </div>
    </div>

    <!-- Right Column: Live Message Feed -->
    <div class="card">
      <div class="card-header" style="display:flex; justify-content:space-between; align-items:center;">
        <span>📜 Live WhatsApp Feed (CampusOS Dispatches)</span>
        <span id="msg-count" style="font-size:0.75rem; color:var(--text-muted);">0 messages</span>
      </div>
      <div class="card-body">
        <div class="feed" id="feed">
          <div style="text-align:center; padding: 40px 0; color: var(--text-muted);">
            No messages sent or received yet.<br>Use the quick-send box below to send a live message to your phone!
          </div>
        </div>

        <div class="send-test-box">
          <input type="text" id="target-phone" value="8908275228" placeholder="Mobile Number (e.g. 8908275228)" style="max-width: 170px;">
          <input type="text" id="target-msg" value="🏛️ Hello from CampusOS! Your WhatsApp gateway is active." placeholder="Message text...">
          <button onclick="sendTestMessage()">Send</button>
        </div>
      </div>
    </div>
  </main>

  <script>
    async function updateStatus() {
      try {
        const res = await fetch('/api/status');
        const data = await res.json();
        
        const pill = document.getElementById('status-pill');
        const text = document.getElementById('status-text');
        const pane = document.getElementById('pairing-pane');

        if (data.status === 'CONNECTED') {
          pill.className = 'status-pill status-connected';
          text.innerText = 'Connected as +' + data.phone;
          pane.innerHTML = \`
            <div class="connected-box">
              <h3>✅ Authenticated & Active</h3>
              <p style="font-size:0.85rem; color:#94a3b8; margin-top:4px;">
                Linked Phone: <strong>+\${data.phone}</strong>
              </p>
              <p style="font-size:0.78rem; color:#64748b; margin-top:8px;">
                CampusOS is now transmitting live messages over the WhatsApp network.
              </p>
            </div>
            <div class="instructions" style="margin-top:20px;">
              <strong>Active Services:</strong>
              <ul>
                <li>Gate pass entry/exit transit alerts to parents</li>
                <li>Hostel leave approval notifications</li>
                <li>Two-way Campus Copilot WhatsApp bot</li>
              </ul>
            </div>
          \`;
        } else if (data.qr) {
          pill.className = 'status-pill status-pairing';
          text.innerText = 'Scan QR Code to Link';
          pane.innerHTML = \`
            <div class="qr-container">
              <img src="\${data.qr}" alt="WhatsApp QR Code">
            </div>
            <div class="instructions">
              <strong>How to connect:</strong>
              <ol>
                <li>Open <strong>WhatsApp</strong> on your mobile phone</li>
                <li>Tap <strong>Settings / ⋮ Menu</strong> &gt; <strong>Linked Devices</strong></li>
                <li>Tap <strong>Link a Device</strong> and point your camera at this QR code</li>
              </ol>
            </div>
          \`;
        } else {
          pill.className = 'status-pill status-pairing';
          text.innerText = 'Initializing engine...';
          pane.innerHTML = '<div style="text-align:center; padding: 40px 0; color: var(--text-muted);">Starting Baileys WebSocket connection...</div>';
        }
      } catch (e) {
        console.error(e);
      }
    }

    async function updateFeed() {
      try {
        const res = await fetch('/api/messages');
        const msgs = await res.json();
        document.getElementById('msg-count').innerText = msgs.length + ' messages';
        const feed = document.getElementById('feed');
        if (msgs.length === 0) return;
        feed.innerHTML = '';
        [...msgs].reverse().forEach(m => {
          const div = document.createElement('div');
          div.className = 'msg-item';
          div.innerHTML = \`
            <div class="msg-header">
              <span>\${m.direction || 'OUTBOUND'} &gt; \${m.chatId}</span>
              <span>\${new Date(m.timestamp).toLocaleTimeString()} • \${m.status || 'DELIVERED'}</span>
            </div>
            <div class="msg-body">\${m.text}</div>
          \`;
          feed.appendChild(div);
        });
      } catch (e) {}
    }

    async function sendTestMessage() {
      const phone = document.getElementById('target-phone').value.trim();
      const text = document.getElementById('target-msg').value.trim();
      if (!phone || !text) return;
      try {
        const res = await fetch('/api/sendText', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ phone, text })
        });
        const result = await res.json();
        updateFeed();
      } catch (err) {
        alert('Error: ' + err.message);
      }
    }

    setInterval(updateStatus, 1500);
    setInterval(updateFeed, 2000);
    updateStatus();
    updateFeed();
  </script>
</body>
</html>
  `);
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🟢 [OpenWA Gateway] Server listening on http://0.0.0.0:${PORT}`);
  connectToWhatsApp();
});
