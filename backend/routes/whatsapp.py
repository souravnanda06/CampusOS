import re
import logging
from flask import Blueprint, request, jsonify
from extensions import db
from models.user import User
from models.gate_pass import GatePass
from models.attendance import Attendance, Session
from config import Config
from services.whatsapp_service import (
    format_whatsapp_jid,
    send_whatsapp_async,
    send_whatsapp_message_sync,
    is_openwa_configured
)

logger = logging.getLogger('campusos.whatsapp_bp')
whatsapp_bp = Blueprint('whatsapp_bp', __name__)


def _find_user_by_incoming_phone(phone_digits: str) -> tuple[User | None, bool]:
    """
    Attempts to match an incoming phone number against student/faculty 'phone'
    or guardian 'parent_phone'. Returns (User, is_parent_match).
    """
    if not phone_digits:
        return None, False

    # Extract last 10 digits for flexible national matching
    ten_digits = phone_digits[-10:] if len(phone_digits) >= 10 else phone_digits

    # 1. Match direct user phone
    user = User.query.filter(
        db.or_(
            User.phone == phone_digits,
            User.phone.like(f"%{ten_digits}")
        )
    ).first()
    if user:
        return user, False

    # 2. Match parent phone
    parent_user = User.query.filter(
        db.or_(
            User.parent_phone == phone_digits,
            User.parent_phone.like(f"%{ten_digits}")
        )
    ).first()
    if parent_user:
        return parent_user, True

    return None, False


@whatsapp_bp.route('/whatsapp/status', methods=['GET'])
def get_whatsapp_status():
    """Returns the operational status of the OpenWA WhatsApp integration."""
    return jsonify({
        "status": "operational",
        "openwaEnabled": getattr(Config, 'OPENWA_ENABLED', True),
        "gatewayUrl": getattr(Config, 'OPENWA_BASE_URL', 'http://localhost:2785'),
        "sessionId": getattr(Config, 'OPENWA_SESSION_ID', 'default'),
        "hasApiKey": bool(getattr(Config, 'OPENWA_API_KEY', ''))
    }), 200


@whatsapp_bp.route('/whatsapp/send', methods=['POST'])
def send_custom_whatsapp():
    """
    Administrative or programmatic endpoint to dispatch a direct WhatsApp message.
    Requires recipient phone number and text body.
    """
    data = request.json or {}
    phone = (data.get('phone') or data.get('chatId') or '').strip()
    text = (data.get('text') or data.get('message') or '').strip()
    is_async = data.get('async', True)

    if not phone or not text:
        return jsonify({"message": "Recipient 'phone' and 'text' message body are required"}), 400

    if is_async:
        send_whatsapp_async(phone, text)
        return jsonify({
            "message": "WhatsApp dispatch scheduled asynchronously",
            "recipient": phone
        }), 202
    else:
        success = send_whatsapp_message_sync(phone, text)
        return jsonify({
            "message": "Message sent" if success else "Failed to dispatch message (gateway offline)",
            "success": success,
            "recipient": phone
        }), 200 if success else 502


@whatsapp_bp.route('/whatsapp/webhook', methods=['GET', 'POST'])
def openwa_webhook():
    """
    Handles inbound webhook deliveries from OpenWA.
    Extracts incoming sender and text, and routes requests to Campus Copilot
    or guardian inquiry handlers.
    """
    if request.method == 'GET':
        return jsonify({"status": "CampusOS OpenWA Webhook Active"}), 200

    payload = request.get_json(silent=True) or {}
    
    # OpenWA delivers varying payload structures depending on event version
    # Normalizing data wrapper if present
    data = payload.get('data') if isinstance(payload.get('data'), dict) else payload

    # Ignore system/status events that aren't message receipts
    event_type = str(payload.get('event') or payload.get('type') or data.get('type') or '')
    if 'ack' in event_type.lower() or 'battery' in event_type.lower():
        return jsonify({"status": "ignored_non_message_event"}), 200

    # Extract sender JID and message text
    chat_id = (
        data.get('chatId')
        or data.get('from')
        or data.get('sender', {}).get('id')
        or payload.get('chatId')
        or ''
    )
    if isinstance(chat_id, dict):
        chat_id = chat_id.get('_serialized') or chat_id.get('id') or ''

    # Filter out group chats (@g.us) and status broadcasts to focus on direct 1:1 assistance
    if not chat_id or '@g.us' in chat_id or 'status@broadcast' in chat_id:
        return jsonify({"status": "ignored_group_or_broadcast"}), 200

    # Ignore messages sent by the bot account itself
    is_from_me = bool(data.get('fromMe') or payload.get('fromMe'))
    if is_from_me:
        return jsonify({"status": "ignored_outbound"}), 200

    body = (
        data.get('body')
        or data.get('text')
        or data.get('caption')
        or payload.get('body')
        or ''
    ).strip()

    if not body:
        return jsonify({"status": "empty_body"}), 200

    # Extract digits to match against CampusOS users
    sender_digits = re.sub(r'\D', '', chat_id.split('@')[0])
    user, is_parent = _find_user_by_incoming_phone(sender_digits)

    # 1. Registered Student or Teacher User -> Route to Campus Copilot AI
    if user and not is_parent:
        try:
            from services.copilot_service import run_copilot_chat
            copilot_result = run_copilot_chat(
                user=user,
                message=body,
                language='en',
                screen_context='whatsapp_chat'
            )
            reply_text = copilot_result.get('reply') or "I processed your request, but have no text reply."
            # Append friendly signature
            formatted_reply = f"{reply_text}\n\n_— CampusOS AI Copilot_"
            send_whatsapp_async(chat_id, formatted_reply)
            return jsonify({"status": "routed_to_copilot", "user": user.name}), 200
        except Exception as e:
            logger.error(f"Error routing WhatsApp query to Copilot: {e}")
            fallback = "Hello! CampusOS Copilot is currently processing academic records. Please try again shortly."
            send_whatsapp_async(chat_id, fallback)
            return jsonify({"status": "copilot_error", "error": str(e)}), 500

    # 2. Registered Parent / Guardian -> Quick Ward Status Response
    if user and is_parent:
        clean_prompt = body.lower()
        if any(w in clean_prompt for w in ['gate', 'pass', 'leave', 'exit', 'out']):
            recent_gp = GatePass.query.filter_by(student_id=user.id).order_by(GatePass.created_at.desc()).first()
            if recent_gp:
                gp_status = recent_gp.status
                exit_time = recent_gp.actual_exit_time or 'Not yet exited'
                reply = (
                    f"🏛️ *CampusOS Guardian Inquiry*\n\n"
                    f"Ward: *{user.name}* (ID: {user.registration_number or 'N/A'})\n"
                    f"Current Gate Pass Status: *{gp_status}*\n"
                    f"Gate Name: *{recent_gp.gate_name or 'Main Gate'}*\n"
                    f"Exit Time: *{exit_time}*\n"
                    f"Destination: *{recent_gp.destination or 'N/A'}*"
                )
            else:
                reply = f"No active or recent gate passes found for your ward *{user.name}*."
        elif any(w in clean_prompt for w in ['attendance', 'present', 'absent', 'class']):
            records = Attendance.query.filter_by(user_id=user.id).all()
            total = len(records)
            present = sum(1 for r in records if (r.status or '').upper() == 'PRESENT')
            pct = (present / total * 100) if total > 0 else 0.0
            reply = (
                f"🏛️ *CampusOS Guardian Attendance Inquiry*\n\n"
                f"Ward: *{user.name}*\n"
                f"Overall Attendance: *{pct:.1f}%* ({present}/{total} sessions attended)\n"
                f"Statutory Threshold: *75.0%*"
            )
        else:
            reply = (
                f"👋 *Welcome to CampusOS Parent Helpline*\n\n"
                f"You are registered as the guardian for *{user.name}* (Roll: {user.registration_number or 'N/A'}).\n\n"
                f"You can reply with keywords:\n"
                f"• *gatepass* - Check your ward's latest campus exit/entry\n"
                f"• *attendance* - Check your ward's current attendance percentage\n"
                f"• *help* - Contact campus student affairs"
            )
        send_whatsapp_async(chat_id, reply)
        return jsonify({"status": "parent_inquiry_handled"}), 200

    # 3. Unrecognized Number -> Informative Onboarding Prompt
    onboarding_msg = (
        f"👋 *Welcome to CampusOS WhatsApp Assistance*\n\n"
        f"We couldn't locate an active account or registered guardian record linked to this number (`+{sender_digits}`).\n\n"
        f"If you are a student or faculty member:\n"
        f"1. Open the *CampusOS Mobile App*\n"
        f"2. Go to *Profile -> Contact Details*\n"
        f"3. Enter this phone number and save.\n\n"
        f"Once linked, you can check attendance, mess menus, and timetables directly via this WhatsApp chat!"
    )
    send_whatsapp_async(chat_id, onboarding_msg)
    return jsonify({"status": "unrecognized_phone_prompted"}), 200
