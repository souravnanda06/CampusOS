import re
import json
import logging
import threading
import urllib.request
import urllib.error
from flask import current_app
from config import Config

logger = logging.getLogger('campusos.whatsapp')


def format_whatsapp_jid(phone: str, default_country_code: str = '91') -> str | None:
    """
    Standardizes a phone string into a valid WhatsApp JID (e.g. '919876543210@c.us').
    Removes leading zeroes, plus signs, dashes, spaces, and brackets.
    """
    if not phone or not isinstance(phone, str):
        return None

    clean = phone.strip()
    if '@c.us' in clean or '@g.us' in clean:
        return clean

    # Strip everything except digits
    digits = re.sub(r'\D', '', clean)
    if not digits:
        return None

    # Handle standard 10-digit mobile numbers by prepending country code (default 91)
    if len(digits) == 10:
        digits = f"{default_country_code}{digits}"
    elif len(digits) == 11 and digits.startswith('0'):
        digits = f"{default_country_code}{digits[1:]}"

    return f"{digits}@c.us"


def extract_phone_digits(jid_or_phone: str) -> str:
    """Extracts raw digits without domain suffix."""
    if not jid_or_phone:
        return ''
    base = jid_or_phone.split('@')[0]
    return re.sub(r'\D', '', base)


def is_openwa_configured() -> bool:
    """Checks whether OpenWA integration is enabled."""
    return getattr(Config, 'OPENWA_ENABLED', True)


def send_whatsapp_message_sync(chat_id_or_phone: str, text: str, session_id: str | None = None) -> bool:
    """
    Synchronously dispatches a text message via OpenWA REST gateway.
    Safely catches network/timeout errors to protect caller stability.
    """
    if not is_openwa_configured():
        logger.debug("OpenWA is disabled; skipping WhatsApp message.")
        return False

    chat_id = format_whatsapp_jid(chat_id_or_phone)
    if not chat_id or not text or not text.strip():
        logger.warning(f"Invalid recipient or empty text for WhatsApp dispatch: '{chat_id_or_phone}'")
        return False

    base_url = (getattr(Config, 'OPENWA_BASE_URL', 'http://localhost:2785') or 'http://localhost:2785').rstrip('/')
    sid = session_id or getattr(Config, 'OPENWA_SESSION_ID', 'default') or 'default'
    api_key = getattr(Config, 'OPENWA_API_KEY', '') or ''

    # Primary endpoint for OpenWA v1+ multi-session gateway
    primary_url = f"{base_url}/api/sessions/{sid}/messages/send-text"
    fallback_url = f"{base_url}/api/sendText"

    payload_bytes = json.dumps({
        "chatId": chat_id,
        "text": text.strip()
    }).encode('utf-8')

    headers = {
        'Content-Type': 'application/json',
        'User-Agent': 'CampusOS-Backend/1.0.0'
    }
    if api_key:
        headers['X-API-Key'] = api_key

    for target_url in [primary_url, fallback_url]:
        try:
            req = urllib.request.Request(target_url, data=payload_bytes, headers=headers, method='POST')
            with urllib.request.urlopen(req, timeout=4.0) as resp:
                status_code = resp.getcode()
                if 200 <= status_code < 300:
                    logger.info(f"WhatsApp notification sent successfully to {chat_id} via {target_url}")
                    return True
        except urllib.error.HTTPError as he:
            # If 404 on session route, try fallback endpoint once
            if he.code == 404 and target_url == primary_url:
                continue
            logger.warning(f"OpenWA returned HTTP {he.code} for {target_url}: {he.reason}")
            break
        except urllib.error.URLError as ue:
            logger.info(f"OpenWA gateway offline or unreachable at {target_url}: {ue.reason}")
            break
        except Exception as e:
            logger.error(f"Unexpected error sending WhatsApp message via OpenWA: {e}")
            break

    return False


def send_whatsapp_async(chat_id_or_phone: str, text: str, session_id: str | None = None):
    """Fires WhatsApp message in background daemon thread to avoid blocking request cycle."""
    thread = threading.Thread(
        target=send_whatsapp_message_sync,
        args=(chat_id_or_phone, text, session_id),
        daemon=True
    )
    thread.start()


# ==============================================================================
# Domain-Specific Institutional WhatsApp Notification Templates
# ==============================================================================

def send_gate_exit_alert(parent_phone: str, student_name: str, reg_no: str, gate_name: str, timestamp_str: str, destination: str | None = None):
    """Notifies parent that student has physically scanned OUT of the campus gates."""
    dest_clause = f"\n*Destination:* {destination}" if destination else ""
    msg = (
        f"🏛️ *CampusOS Gate Transit Alert*\n\n"
        f"Dear Guardian, your ward *{student_name}* (ID: {reg_no or 'N/A'}) has checked *OUT* of campus.\n\n"
        f"📍 *Gate:* {gate_name or 'Main Gate'}\n"
        f"⏰ *Time:* {timestamp_str}{dest_clause}\n"
        f"🛡️ *Status:* Verified & Scanned by Gate Security\n\n"
        f"_This is an automated safety alert generated by CampusOS._"
    )
    send_whatsapp_async(parent_phone, msg)


def send_gate_entry_alert(parent_phone: str, student_name: str, reg_no: str, gate_name: str, timestamp_str: str):
    """Notifies parent that student has safely returned and checked IN through the campus gates."""
    msg = (
        f"🏛️ *CampusOS Gate Transit Alert*\n\n"
        f"Dear Guardian, your ward *{student_name}* (ID: {reg_no or 'N/A'}) has safely checked *IN* to campus.\n\n"
        f"📍 *Gate:* {gate_name or 'Main Gate'}\n"
        f"⏰ *Time:* {timestamp_str}\n"
        f"🛡️ *Status:* Safe Arrival Recorded\n\n"
        f"_This is an automated safety alert generated by CampusOS._"
    )
    send_whatsapp_async(parent_phone, msg)


def send_leave_approval_alert(parent_phone: str, student_name: str, reason: str, from_date: str, to_date: str, gate_pass_code: str | None = None):
    """Notifies parent that student's hostel leave request was approved by the Warden."""
    pass_clause = f"\n🎟️ *Gate Pass ID:* {gate_pass_code}" if gate_pass_code else ""
    msg = (
        f"📋 *CampusOS Hostel Leave Notification*\n\n"
        f"Dear Guardian, hostel leave for your ward *{student_name}* has been *APPROVED* by the Hostel Warden.\n\n"
        f"🗓️ *Period:* {from_date} to {to_date}\n"
        f"📝 *Reason:* {reason}{pass_clause}\n\n"
        f"If you did not authorize this leave, please contact the Hostel Warden desk immediately."
    )
    send_whatsapp_async(parent_phone, msg)


def send_attendance_shortage_alert(recipient_phone: str, student_name: str, subject_name: str, percentage: float, attended: int, total: int):
    """Notifies student or parent regarding statutory attendance shortage (<75%)."""
    msg = (
        f"⚠️ *CampusOS Statutory Attendance Alert*\n\n"
        f"Student: *{student_name}*\n"
        f"Subject: *{subject_name}*\n"
        f"Current Attendance: *{percentage:.1f}%* ({attended}/{total} classes attended)\n\n"
        f"❗ *Notice:* The mandatory University / BPUT examination eligibility threshold is *75%*. "
        f"Please meet your departmental academic advisor to regularize attendance."
    )
    send_whatsapp_async(recipient_phone, msg)


def send_fee_due_alert(recipient_phone: str, student_name: str, fee_title: str, amount: float, due_date: str):
    """Dispatches fee due reminder directly to parent or student WhatsApp."""
    msg = (
        f"💳 *CampusOS Institutional Fee Reminder*\n\n"
        f"Dear Guardian/Student, an institutional fee of *₹{amount:,.2f}* for *{fee_title}* is due on *{due_date}* "
        f"for *{student_name}*.\n\n"
        f"Please settle the fee through the CampusOS student portal before the due date to avoid late charges."
    )
    send_whatsapp_async(recipient_phone, msg)


def send_visitor_pass_alert(visitor_phone: str, visitor_name: str, pass_code: str, host_name: str, visit_date: str):
    """Sends visitor digital pass code to visitor's phone."""
    msg = (
        f"🎟️ *CampusOS Digital Visitor Pass*\n\n"
        f"Welcome *{visitor_name}*,\n"
        f"Your entry pass for visiting *{host_name}* on *{visit_date}* has been approved.\n\n"
        f"🔑 *Visitor Pass Code:* {pass_code}\n"
        f"Show this code or tell it to the gate security officer upon arrival for swift check-in."
    )
    send_whatsapp_async(visitor_phone, msg)
