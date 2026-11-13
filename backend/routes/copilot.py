import base64
import json
from flask import Blueprint, jsonify, request
from middleware.auth import get_authenticated_requester
from services.copilot_service import get_role_suggestions, run_copilot_chat
from services.copilot_tools import canonical_copilot_role, execute_pending_action

copilot_bp = Blueprint('copilot_bp', __name__)


@copilot_bp.route('/copilot/suggestions', methods=['GET'])
@copilot_bp.route('/api/copilot/suggestions', methods=['GET'])
def copilot_suggestions():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required"}), 401

    role = canonical_copilot_role(requester.role)
    if role not in ('student', 'teacher', 'admin'):
        return jsonify({
            "message": f"AI Copilot is currently enabled for student, teacher, and admin roles (got '{requester.role}')",
            "resultCode": "FORBIDDEN",
        }), 403

    lang = request.args.get('language') or 'en'
    return jsonify({
        "role": role,
        "suggestions": get_role_suggestions(role, lang),
    }), 200


@copilot_bp.route('/copilot/chat', methods=['POST'])
@copilot_bp.route('/api/copilot/chat', methods=['POST'])
def copilot_chat():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required"}), 401

    role = canonical_copilot_role(requester.role)
    if role not in ('student', 'teacher', 'admin'):
        return jsonify({
            "message": f"AI Copilot is currently enabled for student, teacher, and admin roles (got '{requester.role}')",
            "resultCode": "FORBIDDEN",
        }), 403

    attachments = []
    if request.content_type and 'multipart/form-data' in request.content_type.lower():
        message = (request.form.get('message') or '').strip()
        language = (request.form.get('language') or 'en').strip().lower()
        screen_context = request.form.get('screenContext')
        raw_hist = request.form.get('history') or '[]'
        try:
            parsed_hist = json.loads(raw_hist)
            history = parsed_hist if isinstance(parsed_hist, list) else []
        except Exception:
            history = []

        uploaded_files = request.files.getlist('files') or request.files.getlist('file')
        for f in uploaded_files[:3]:
            raw_bytes = f.read()
            if not raw_bytes:
                continue
            attachments.append({
                'filename': f.filename or 'notes.pdf',
                'mimeType': f.mimetype or 'application/octet-stream',
                'dataBase64': base64.b64encode(raw_bytes).decode('ascii'),
            })
    else:
        data = request.json or {}
        message = (data.get('message') or '').strip()
        history = data.get('history') if isinstance(data.get('history'), list) else []
        language = (data.get('language') or 'en').strip().lower()
        screen_context = data.get('screenContext')
        raw_att = data.get('attachments')
        if isinstance(raw_att, list):
            for att in raw_att[:3]:
                if isinstance(att, dict) and att.get('dataBase64'):
                    attachments.append({
                        'filename': str(att.get('filename') or 'attachment'),
                        'mimeType': str(att.get('mimeType') or 'application/octet-stream'),
                        'dataBase64': str(att.get('dataBase64')),
                    })

    if not message and not attachments:
        return jsonify({"message": "message or attachment is required"}), 400
    if not message and attachments:
        message = (
            "Generate a structured assessment paper with answer key from the uploaded notes."
            if role == 'teacher'
            else "Summarize and create practice questions from the uploaded notes."
        )

    result = run_copilot_chat(
        user=requester,
        message=message,
        history=history,
        language=language,
        screen_context=screen_context,
        attachments=attachments,
    )
    return jsonify(result), 200


@copilot_bp.route('/copilot/confirm', methods=['POST'])
@copilot_bp.route('/api/copilot/confirm', methods=['POST'])
def copilot_confirm():
    requester, err_resp = get_authenticated_requester()
    if err_resp:
        return err_resp
    if not requester:
        return jsonify({"message": "Authentication required"}), 401

    role = canonical_copilot_role(requester.role)
    if role not in ('student', 'teacher', 'admin'):
        return jsonify({
            "message": f"AI Copilot is currently enabled for student, teacher, and admin roles (got '{requester.role}')",
            "resultCode": "FORBIDDEN",
        }), 403

    data = request.json or {}
    action_id = (data.get('actionId') or '').strip()
    if not action_id:
        return jsonify({"message": "actionId is required"}), 400

    payload_resp, status_code = execute_pending_action(
        user=requester,
        role=role,
        action_id=action_id,
        remote_addr=request.remote_addr,
    )
    return jsonify(payload_resp), status_code
