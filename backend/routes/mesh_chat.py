import base64
import json
import os
import re
import time
import uuid
from typing import Any, Dict, List, Optional
from flask import Blueprint, request, jsonify

from config import Config
from extensions import db
from middleware.auth import get_authenticated_requester
from middleware.roles import is_admin, is_security_guard, is_warden
from models.mesh_chat import MeshChannel, MeshMessage, MeshModerationFlag, MeshAccountRestriction
from models.passport import DeviceIdentityKey
from models.user import User
from services.mesh_moderation_service import (
    build_mesh_packet_signable_bytes,
    moderate_text,
    verify_mesh_packet_signature,
)

mesh_chat_bp = Blueprint("mesh_chat_bp", __name__)

DEFAULT_CHANNELS: List[Dict[str, Any]] = [
    {
        "channelId": "channel:general",
        "name": "#general",
        "description": "Campus-wide public discussion channel",
        "isDirectMessage": False,
        "participants": [],
    },
    {
        "channelId": "channel:hostel-b",
        "name": "#hostel-b",
        "description": "Hostel Block B resident updates and notices",
        "isDirectMessage": False,
        "participants": [],
    },
    {
        "channelId": "channel:study-group",
        "name": "#study-group",
        "description": "Peer collaborative study & lab materials discussion",
        "isDirectMessage": False,
        "participants": [],
    },
    {
        "channelId": "channel:emergency",
        "name": "#emergency",
        "description": "Official institutional emergency disaster flare alerts",
        "isDirectMessage": False,
        "participants": [],
    },
]

_EMERGENCY_ROLES = {"admin", "dean", "director", "warden", "teacher", "faculty"}
_CHANNEL_SLUG_RE = re.compile(r"^[a-z0-9][a-z0-9\-_]{1,31}$")


def _now_ms() -> int:
    return int(time.time() * 1000)


def _ensure_tables():
    """Ensures mesh chat SQLite/SQLAlchemy tables exist even if DB wasn't pre-migrated."""
    db.create_all()


def _require_authenticated_user():
    user, err_resp = get_authenticated_requester()
    if err_resp:
        return None, err_resp
    if not user:
        return None, (
            jsonify({
                "message": "Authentication required",
                "resultCode": "UNAUTHORIZED",
            }),
            401,
        )
    return user, None


def _verify_message_signature_if_present(msg: Dict[str, Any], sender_user_id: Optional[str]) -> Dict[str, Any]:
    """
    Attempts cryptographic verification when signature + canonical packet fields are supplied.
    Returns dict with keys: verified (bool), revoked (bool), reason (str).
    """
    sig_b64 = (msg.get("signatureBase64") or msg.get("signature") or "").strip()
    if not sig_b64 or not sender_user_id:
        return {"verified": False, "revoked": False, "reason": "No signature or senderUserId provided"}

    active_key = (
        DeviceIdentityKey.query.filter_by(user_id=sender_user_id)
        .order_by(DeviceIdentityKey.created_at.desc())
        .first()
    )
    if not active_key:
        return {"verified": False, "revoked": False, "reason": "Sender has no registered Passport key"}

    if active_key.status == "REVOKED":
        return {"verified": False, "revoked": True, "reason": "Sender Passport key is REVOKED"}

    signable_b64 = (msg.get("signableBytesBase64") or "").strip()
    signable_bytes: Optional[bytes] = None
    if signable_b64:
        try:
            signable_bytes = base64.b64decode(signable_b64)
        except Exception:
            return {"verified": False, "revoked": False, "reason": "Malformed signableBytesBase64"}
    elif msg.get("payloadBase64") and msg.get("messageId"):
        try:
            payload_bytes = base64.b64decode(msg["payloadBase64"])
            signable_bytes = build_mesh_packet_signable_bytes(
                packet_id_hex=str(msg["messageId"]),
                packet_type_code=int(msg.get("packetTypeCode", 0x01)),
                initial_hop_budget=int(msg.get("initialHopBudget", int(msg.get("ttl", 7)) + int(msg.get("hopCount", 0)))),
                timestamp_ms=int(msg.get("createdAt")),
                sender_device_id=str(msg.get("senderDeviceId") or sender_user_id),
                sender_role=str(msg.get("senderRole") or "student"),
                payload_bytes=payload_bytes,
            )
        except Exception as exc:
            return {"verified": False, "revoked": False, "reason": f"Could not reconstruct packet bytes: {exc}"}

    if signable_bytes is None:
        return {"verified": False, "revoked": False, "reason": "Signable packet bytes not included"}

    ok, reason = verify_mesh_packet_signature(
        public_key_b64=active_key.public_key_b64,
        signature_b64=sig_b64,
        signable_bytes=signable_bytes,
    )
    return {"verified": ok, "revoked": False, "reason": reason}


@mesh_chat_bp.route("/mesh-chat/health", methods=["GET"])
def mesh_chat_health():
    try:
        _ensure_tables()
        count = MeshMessage.query.count()
        return jsonify({
            "configured": True,
            "connected": True,
            "storage": "sqlite",
            "messageCount": count,
        }), 200
    except Exception as exc:
        return jsonify({
            "configured": True,
            "connected": False,
            "storage": "sqlite",
            "message": str(exc),
        }), 503


@mesh_chat_bp.route("/mesh-chat/channels", methods=["GET"])
def list_mesh_channels():
    requester, err_resp = _require_authenticated_user()
    if err_resp:
        return err_resp

    _ensure_tables()
    channels_by_id: Dict[str, Dict[str, Any]] = {
        ch["channelId"]: dict(ch) for ch in DEFAULT_CHANNELS
    }

    rows = MeshChannel.query.all()
    for ch in rows:
        if not ch.is_direct_message or requester.id in ch.get_participants():
            channels_by_id[ch.channel_id] = ch.to_dict()

    return jsonify({"channels": list(channels_by_id.values())}), 200


@mesh_chat_bp.route("/mesh-chat/channels", methods=["POST"])
def create_mesh_channel():
    requester, err_resp = _require_authenticated_user()
    if err_resp:
        return err_resp

    _ensure_tables()
    restriction = db.session.get(MeshAccountRestriction, requester.id)
    if restriction and restriction.status in ("RESTRICTED", "REVOKED"):
        return jsonify({
            "message": f"Account restricted from Mesh Chat: {restriction.reason or 'Safety violation'}",
            "resultCode": "ACCOUNT_RESTRICTED",
        }), 403
    data = request.json or {}
    raw_name = (data.get("name") or "").strip().lstrip("#").lower()
    slug = re.sub(r"[^a-z0-9\-_]+", "-", raw_name).strip("-")
    if not _CHANNEL_SLUG_RE.match(slug):
        return jsonify({
            "message": "Channel name must be 2-32 lowercase alphanumeric, hyphen, or underscore characters",
            "resultCode": "INVALID_CHANNEL_NAME",
        }), 400

    channel_id = f"channel:{slug}"
    if channel_id == "channel:emergency":
        return jsonify({"message": "Cannot recreate reserved #emergency channel"}), 400

    existing = db.session.get(MeshChannel, channel_id)
    if existing:
        return jsonify({"channel": existing.to_dict()}), 201

    description = (data.get("description") or "").strip()[:160]
    channel = MeshChannel(
        channel_id=channel_id,
        name=f"#{slug}",
        description=description or f"Campus mesh channel #{slug}",
        is_direct_message=False,
        participants_json="[]",
        created_by=requester.id,
        created_at=_now_ms(),
    )
    db.session.add(channel)
    db.session.commit()
    return jsonify({"channel": channel.to_dict()}), 201


@mesh_chat_bp.route("/mesh-chat/sync", methods=["POST"])
def sync_mesh_messages():
    """
    Uploads unsynced mesh chat messages (public channels or E2EE DM envelopes) to SQLite.
    Supports delayed catch-up across devices and runs server-side moderation & Ed25519 checks.
    """
    requester, err_resp = _require_authenticated_user()
    if err_resp:
        return err_resp

    _ensure_tables()
    data = request.json or {}
    raw_messages = data.get("messages")
    if not isinstance(raw_messages, list):
        return jsonify({"message": "messages array is required"}), 400
    if len(raw_messages) > 100:
        return jsonify({"message": "Maximum 100 messages per sync batch"}), 400

    synced_ids: List[str] = []
    rejected: List[Dict[str, str]] = []
    verdicts: Dict[str, Dict[str, Any]] = {}

    for item in raw_messages:
        if not isinstance(item, dict):
            continue

        message_id = str(item.get("messageId") or "").strip()
        channel_id = str(item.get("channelId") or "").strip()
        text = str(item.get("text") or "").strip()
        image_b64 = item.get("imageBase64")
        is_encrypted = bool(item.get("isEncrypted", False))

        if not message_id or not channel_id:
            rejected.append({"messageId": message_id, "reason": "Missing messageId or channelId"})
            continue

        if not text and not image_b64:
            rejected.append({"messageId": message_id, "reason": "Empty message payload"})
            continue

        sender_role = str(item.get("senderRole") or requester.role or "student").lower().strip()
        if channel_id in ("channel:emergency", "emergency"):
            if requester.role.lower() not in _EMERGENCY_ROLES or sender_role not in _EMERGENCY_ROLES:
                rejected.append({
                    "messageId": message_id,
                    "reason": "Unauthorized role for #emergency channel",
                })
                continue

        claimed_sender_user_id = str(item.get("senderUserId") or "").strip() or None
        sender_device_id = str(item.get("senderDeviceId") or requester.id).strip()
        sig_check = _verify_message_signature_if_present(item, claimed_sender_user_id or requester.id)

        if sig_check["revoked"]:
            rejected.append({"messageId": message_id, "reason": sig_check["reason"]})
            continue

        if claimed_sender_user_id and claimed_sender_user_id != requester.id and claimed_sender_user_id != sender_device_id:
            if not sig_check["verified"]:
                # When packets are relayed across the mesh by an honest node, allow them
                # into public broadcast channels or DMs where requester is a participant,
                # stamped with verification_state="UNVERIFIED" and synced_by_user_id=requester.id.
                is_public_or_dm_participant = not channel_id.startswith("dm:") or (
                    requester.id in channel_id.split(":")[1:] or
                    sender_device_id in channel_id.split(":")[1:]
                )
                if not is_public_or_dm_participant:
                    rejected.append({
                        "messageId": message_id,
                        "reason": "Cannot relay private message for non-participant",
                    })
                    continue
                effective_sender_user_id = claimed_sender_user_id
            else:
                effective_sender_user_id = claimed_sender_user_id
        else:
            effective_sender_user_id = requester.id

        # Enforce admin Mesh Chat account restrictions/revocations
        sender_restriction = db.session.get(MeshAccountRestriction, effective_sender_user_id)
        if sender_restriction and sender_restriction.status in ("RESTRICTED", "REVOKED"):
            rejected.append({
                "messageId": message_id,
                "reason": f"Account {sender_restriction.status.lower()}: {sender_restriction.reason or 'Moderated by admin'}",
            })
            continue

        # Enforce admin channel restrictions / dismantling
        ch_record = db.session.get(MeshChannel, channel_id)
        if ch_record and (ch_record.status or "").upper() in ("RESTRICTED", "DISMANTLED"):
            rejected.append({
                "messageId": message_id,
                "reason": f"Channel is restricted: {ch_record.restricted_reason or 'Messaging is disabled'}",
            })
            continue

        try:
            created_at = int(item.get("createdAt") or _now_ms())
        except (TypeError, ValueError):
            created_at = _now_ms()

        moderation = moderate_text(text, is_encrypted=is_encrypted)
        existing = db.session.get(MeshMessage, message_id)

        initial_delivery_state = str(item.get("deliveryState") or "SENT").upper()
        if initial_delivery_state not in ("QUEUED", "SENT", "DELIVERED", "SEEN"):
            initial_delivery_state = "SENT"

        if existing is None:
            row = MeshMessage(
                message_id=message_id,
                channel_id=channel_id,
                sender_device_id=sender_device_id,
                sender_user_id=effective_sender_user_id,
                sender_display_name=str(item.get("senderDisplayName") or requester.name or "Campus Member")[:80],
                sender_role=sender_role,
                text=text[:2000],
                image_base64=image_b64 if isinstance(image_b64, str) and len(image_b64) <= 120000 else None,
                is_encrypted=is_encrypted,
                reply_to_message_id=item.get("replyToMessageId"),
                created_at=created_at,
                hop_count=int(item.get("hopCount", 0)),
                ttl=int(item.get("ttl", 7)),
                signature_base64=item.get("signatureBase64") or item.get("signature"),
                signature_verified=sig_check["verified"],
                verification_state="TRUSTED" if sig_check["verified"] else str(item.get("verificationState") or "UNVERIFIED"),
                moderation_status=moderation["moderationStatus"],
                moderation_severity=moderation["moderationSeverity"],
                moderation_category=moderation["category"],
                flag_reasons_json=json.dumps(moderation["flagReasons"]),
                synced_by_user_id=requester.id,
                synced_at=_now_ms(),
                delivery_state=initial_delivery_state,
            )
            db.session.add(row)
        else:
            if existing.moderation_status == "HIDDEN_BY_ADMIN":
                moderation["moderationStatus"] = "HIDDEN_BY_ADMIN"

        if channel_id.startswith("dm:"):
            parts = channel_id.split(":")[1:]
            if len(parts) >= 2 and not db.session.get(MeshChannel, channel_id):
                db.session.add(MeshChannel(
                    channel_id=channel_id,
                    name="Encrypted DM",
                    description="Private 1-to-1 encrypted mesh conversation",
                    is_direct_message=True,
                    participants_json=json.dumps(sorted(parts[:2])),
                    created_at=created_at,
                ))
            # Auto-mark prior messages in this DM from other sender as SEEN
            try:
                eff_sender_id_str = str(effective_sender_user_id) if effective_sender_user_id else None
                filter_conds = [
                    MeshMessage.channel_id == channel_id,
                    MeshMessage.created_at <= created_at,
                    MeshMessage.sender_device_id != sender_device_id,
                    MeshMessage.delivery_state != "SEEN",
                ]
                if eff_sender_id_str:
                    filter_conds.append(
                        db.or_(
                            MeshMessage.sender_user_id != eff_sender_id_str,
                            MeshMessage.sender_user_id.is_(None),
                        )
                    )
                MeshMessage.query.filter(*filter_conds).update(
                    {MeshMessage.delivery_state: "SEEN"}, synchronize_session=False
                )
            except Exception as e:
                print(f"[WARN] [MESH_CHAT] Auto-mark seen failed: {e}")

        if moderation["moderationStatus"] in ("FLAGGED", "QUARANTINED"):
            flag_id = f"auto_{message_id}"
            if not db.session.get(MeshModerationFlag, flag_id):
                db.session.add(MeshModerationFlag(
                    flag_id=flag_id,
                    message_id=message_id,
                    channel_id=channel_id,
                    reported_user_id=effective_sender_user_id,
                    reported_device_id=sender_device_id,
                    reporter_user_id="SYSTEM_MODERATOR",
                    source="AUTO_RULE",
                    category=moderation["category"],
                    severity=moderation["moderationSeverity"],
                    matched_patterns_json=json.dumps(moderation["flagReasons"]),
                    message_snapshot=text[:500],
                    sender_signature=item.get("signatureBase64") or item.get("signature"),
                    signature_verified=sig_check["verified"],
                    status="ESCALATED" if moderation["moderationSeverity"] == "CRITICAL" else "OPEN",
                    created_at=_now_ms(),
                ))

        synced_ids.append(message_id)
        verdicts[message_id] = {
            "moderationStatus": moderation["moderationStatus"],
            "moderationSeverity": moderation["moderationSeverity"],
            "flagReasons": moderation["flagReasons"],
            "signatureVerified": sig_check["verified"],
        }

    db.session.commit()
    return jsonify({
        "syncedIds": synced_ids,
        "rejected": rejected,
        "verdicts": verdicts,
    }), 200


@mesh_chat_bp.route("/mesh-chat/channels/<path:channel_id>/messages", methods=["GET"])
def get_channel_messages(channel_id: str):
    """
    Returns historical channel messages from SQLite for late-joining or offline-then-online devices.
    """
    requester, err_resp = _require_authenticated_user()
    if err_resp:
        return err_resp

    _ensure_tables()
    if channel_id.startswith("dm:"):
        participants = channel_id.split(":")[1:]
        if requester.id not in participants:
            return jsonify({"message": "Forbidden: Not a participant of this DM channel"}), 403

    try:
        since_ms = int(request.args.get("since", "0") or "0")
    except ValueError:
        since_ms = 0
    try:
        limit = min(max(int(request.args.get("limit", "100") or "100"), 1), 200)
    except ValueError:
        limit = 100

    query = MeshMessage.query.filter(
        MeshMessage.channel_id == channel_id,
        MeshMessage.moderation_status != "HIDDEN_BY_ADMIN",
    )
    if since_ms > 0:
        rows = query.filter(MeshMessage.created_at > since_ms).order_by(MeshMessage.created_at.asc()).limit(limit).all()
    else:
        # Fetch the latest `limit` messages in reverse order then reverse to chronological
        rows = query.order_by(MeshMessage.created_at.desc()).limit(limit).all()
        rows.reverse()
    messages = [r.to_dict() for r in rows]
    return jsonify({
        "channelId": channel_id,
        "messages": messages,
        "count": len(messages),
    }), 200


@mesh_chat_bp.route("/mesh-chat/flags", methods=["POST"])
def submit_moderation_flag():
    """
    Submits a user report or offline auto-detected moderation flag with cryptographic snapshot.
    """
    requester, err_resp = _require_authenticated_user()
    if err_resp:
        return err_resp

    _ensure_tables()
    data = request.json or {}
    message_id = str(data.get("messageId") or "").strip()
    channel_id = str(data.get("channelId") or "channel:general").strip()
    category = str(data.get("category") or "HARASSMENT").upper().strip()
    severity = str(data.get("severity") or "MODERATE").upper().strip()
    reason = str(data.get("reason") or "User reported inappropriate content").strip()[:300]
    snapshot = str(data.get("messageSnapshot") or "").strip()[:500]
    source = str(data.get("source") or "USER_REPORT").upper().strip()

    if not message_id:
        return jsonify({"message": "messageId is required"}), 400

    if category not in ("CRIME_THREAT", "HARASSMENT", "EXPLICIT", "SPAM", "OTHER"):
        category = "OTHER"
    if severity not in ("MODERATE", "HIGH", "CRITICAL"):
        severity = "CRITICAL" if category == "CRIME_THREAT" else "MODERATE"
    if source not in ("USER_REPORT", "AUTO_RULE", "AUTO_AI"):
        source = "USER_REPORT"

    flag_id = str(data.get("flagId") or f"flag_{uuid.uuid4().hex[:16]}")
    existing_flag = db.session.get(MeshModerationFlag, flag_id)
    if existing_flag:
        return jsonify({"flag": existing_flag.to_dict()}), 201

    existing_msg = db.session.get(MeshMessage, message_id)
    flag = MeshModerationFlag(
        flag_id=flag_id,
        message_id=message_id,
        channel_id=channel_id,
        reported_user_id=data.get("reportedUserId") or (existing_msg.sender_user_id if existing_msg else None),
        reported_device_id=data.get("reportedDeviceId") or (existing_msg.sender_device_id if existing_msg else None),
        reporter_user_id=requester.id,
        source=source,
        category=category,
        severity=severity,
        matched_patterns_json=json.dumps([reason]),
        message_snapshot=snapshot or (existing_msg.text if existing_msg else ""),
        sender_signature=data.get("senderSignature") or (existing_msg.signature_base64 if existing_msg else None),
        status="ESCALATED" if severity == "CRITICAL" else "OPEN",
        created_at=_now_ms(),
    )
    db.session.add(flag)

    if existing_msg and existing_msg.moderation_status != "HIDDEN_BY_ADMIN":
        existing_msg.moderation_status = "QUARANTINED" if severity in ("CRITICAL", "HIGH") else "FLAGGED"
        existing_msg.moderation_severity = severity
        existing_msg.moderation_category = category
        reasons = existing_msg.get_flag_reasons()
        if reason not in reasons:
            reasons.append(reason)
            existing_msg.flag_reasons_json = json.dumps(reasons)

    db.session.commit()
    return jsonify({"flag": flag.to_dict()}), 201


def _require_moderator():
    requester, err_resp = _require_authenticated_user()
    if err_resp:
        return None, err_resp
    if not (
        is_admin(requester)
        or is_warden(requester)
        or is_security_guard(requester)
        or (requester.role or "").lower() in ("staff", "dean")
    ):
        return None, (
            jsonify({"message": "Forbidden: Moderator/Admin/Security role required", "resultCode": "FORBIDDEN"}),
            403,
        )
    return requester, None


def _build_account_snapshot(user_id: Optional[str], flag_counts: Optional[Dict[str, int]] = None) -> Dict[str, Any]:
    if not user_id:
        return {
            "userId": None,
            "name": "Unknown User",
            "email": None,
            "role": "unknown",
            "registrationNumber": None,
            "keyStatus": "UNREGISTERED",
            "accountStatus": "ACTIVE",
            "restrictionReason": None,
            "totalFlags": 0,
        }

    user = db.session.get(User, user_id)
    latest_key = (
        DeviceIdentityKey.query.filter_by(user_id=user_id)
        .order_by(DeviceIdentityKey.created_at.desc())
        .first()
    )
    restriction = db.session.get(MeshAccountRestriction, user_id)
    total_flags = (
        flag_counts.get(user_id, 0)
        if flag_counts is not None
        else MeshModerationFlag.query.filter_by(reported_user_id=user_id).count()
    )

    account_status = "ACTIVE"
    if restriction and restriction.status in ("RESTRICTED", "REVOKED"):
        account_status = restriction.status
    elif latest_key and latest_key.status == "REVOKED":
        account_status = "REVOKED"

    return {
        "userId": user_id,
        "name": user.name if user else user_id,
        "email": user.email if user else None,
        "role": user.role if user else "student",
        "registrationNumber": getattr(user, "registration_number", None) if user else None,
        "keyStatus": latest_key.status if latest_key else "UNREGISTERED",
        "accountStatus": account_status,
        "restrictionReason": restriction.reason if restriction else None,
        "totalFlags": total_flags,
    }


@mesh_chat_bp.route("/mesh-chat/admin/flags", methods=["GET"])
def list_admin_moderation_flags():
    """
    Lists moderation flags for admin, warden, or campus security review,
    enriched with account details and why each account/message was flagged.
    """
    requester, err_resp = _require_moderator()
    if err_resp:
        return err_resp

    _ensure_tables()
    status_filter = (request.args.get("status") or "").upper().strip()
    user_filter = (request.args.get("userId") or "").strip()

    query = MeshModerationFlag.query
    if status_filter:
        query = query.filter(MeshModerationFlag.status == status_filter)
    if user_filter:
        query = query.filter(MeshModerationFlag.reported_user_id == user_filter)

    rows = query.order_by(MeshModerationFlag.created_at.desc()).limit(200).all()

    all_flags = MeshModerationFlag.query.all()
    flag_counts: Dict[str, int] = {}
    for f in all_flags:
        if f.reported_user_id:
            flag_counts[f.reported_user_id] = flag_counts.get(f.reported_user_id, 0) + 1

    account_cache: Dict[str, Dict[str, Any]] = {}
    reporter_cache: Dict[str, str] = {}

    enriched_flags = []
    for r in rows:
        d = r.to_dict()
        ruid = r.reported_user_id
        if ruid:
            if ruid not in account_cache:
                account_cache[ruid] = _build_account_snapshot(ruid, flag_counts)
            d["reportedUser"] = account_cache[ruid]
        else:
            d["reportedUser"] = _build_account_snapshot(None, flag_counts)

        rep_id = r.reporter_user_id
        if rep_id == "SYSTEM_MODERATOR":
            d["reporterName"] = "Auto Moderation Engine"
        elif rep_id:
            if rep_id not in reporter_cache:
                rep_user = db.session.get(User, rep_id)
                reporter_cache[rep_id] = rep_user.name if rep_user else rep_id
            d["reporterName"] = reporter_cache[rep_id]
        else:
            d["reporterName"] = "Unknown"

        enriched_flags.append(d)

    return jsonify({"flags": enriched_flags, "count": len(enriched_flags)}), 200


@mesh_chat_bp.route("/mesh-chat/admin/flags/<flag_id>", methods=["PATCH"])
def resolve_admin_moderation_flag(flag_id: str):
    """
    Resolves a moderation flag:
    DISMISS, HIDE_MESSAGE, ESCALATE, RESTRICT_ACCOUNT, REVOKE_KEY, or RESTORE_ACCOUNT.
    """
    requester, err_resp = _require_moderator()
    if err_resp:
        return err_resp

    _ensure_tables()
    data = request.json or {}
    action = str(data.get("action") or "").upper().strip()
    notes = str(data.get("notes") or "").strip()[:400]

    flag = db.session.get(MeshModerationFlag, flag_id)
    if not flag:
        return jsonify({"message": "Moderation flag not found"}), 404

    valid_actions = (
        "DISMISS",
        "HIDE_MESSAGE",
        "ESCALATE",
        "RESTRICT_ACCOUNT",
        "REVOKE_KEY",
        "RESTORE_ACCOUNT",
        "RESTRICT_CHANNEL",
        "DISMANTLE_CHANNEL",
    )
    if action not in valid_actions:
        return jsonify({"message": f"Invalid action. Expected one of: {', '.join(valid_actions)}"}), 400

    new_status = {
        "DISMISS": "DISMISSED",
        "HIDE_MESSAGE": "HIDDEN",
        "ESCALATE": "ESCALATED",
        "RESTRICT_ACCOUNT": "ESCALATED",
        "REVOKE_KEY": "ESCALATED",
        "RESTORE_ACCOUNT": "DISMISSED",
        "RESTRICT_CHANNEL": "ESCALATED",
        "DISMANTLE_CHANNEL": "ESCALATED",
    }[action]

    flag.status = new_status
    flag.resolution_notes = notes or f"Action {action} by {requester.name}"
    flag.resolved_at = _now_ms()

    msg = db.session.get(MeshMessage, flag.message_id) if flag.message_id else None
    if msg:
        if action in ("HIDE_MESSAGE", "RESTRICT_ACCOUNT", "REVOKE_KEY", "RESTRICT_CHANNEL", "DISMANTLE_CHANNEL"):
            msg.moderation_status = "HIDDEN_BY_ADMIN"
        elif action in ("DISMISS", "RESTORE_ACCOUNT"):
            msg.moderation_status = "CLEAN"
            msg.moderation_severity = "NONE"

    # Handle channel restriction / dismantling
    if action in ("RESTRICT_CHANNEL", "DISMANTLE_CHANNEL"):
        ch_id = flag.channel_id
        if ch_id:
            ch = db.session.get(MeshChannel, ch_id)
            if not ch:
                def_ch = next((c for c in DEFAULT_CHANNELS if c["channelId"] == ch_id), None)
                ch = MeshChannel(
                    channel_id=ch_id,
                    name=def_ch["name"] if def_ch else f"#{ch_id.replace('channel:', '')}",
                    description=def_ch["description"] if def_ch else "Campus mesh channel",
                    is_direct_message=ch_id.startswith("dm:"),
                    participants_json="[]",
                    created_by=requester.id,
                    created_at=_now_ms(),
                )
                db.session.add(ch)
            ch.status = "RESTRICTED"
            ch.restricted_reason = notes or f"Channel restricted/dismantled by moderator due to {flag.category} violation"
            ch.restricted_by = requester.id
            ch.restricted_at = _now_ms()

    target_user_id = flag.reported_user_id
    if target_user_id:
        reason_text = notes or ", ".join(flag.get_matched_patterns()) or f"{flag.severity} {flag.category} violation"
        if action in ("RESTRICT_ACCOUNT", "REVOKE_KEY"):
            restriction_status = "REVOKED" if action == "REVOKE_KEY" else "RESTRICTED"
            restriction = db.session.get(MeshAccountRestriction, target_user_id)
            if restriction is None:
                restriction = MeshAccountRestriction(
                    user_id=target_user_id,
                    status=restriction_status,
                    reason=reason_text,
                    flag_id=flag.flag_id,
                    restricted_by=requester.id,
                    updated_at=_now_ms(),
                )
                db.session.add(restriction)
            else:
                restriction.status = restriction_status
                restriction.reason = reason_text
                restriction.flag_id = flag.flag_id
                restriction.restricted_by = requester.id
                restriction.updated_at = _now_ms()

            if action == "REVOKE_KEY":
                keys = DeviceIdentityKey.query.filter_by(user_id=target_user_id, status="ACTIVE").all()
                for k in keys:
                    k.status = "REVOKED"

        elif action == "RESTORE_ACCOUNT":
            restriction = db.session.get(MeshAccountRestriction, target_user_id)
            if restriction is not None:
                restriction.status = "ACTIVE"
                restriction.reason = notes or "Restored by administrator"
                restriction.restricted_by = requester.id
                restriction.updated_at = _now_ms()
            keys = DeviceIdentityKey.query.filter_by(user_id=target_user_id, status="REVOKED").all()
            for k in keys:
                k.status = "ACTIVE"

    db.session.commit()
    out = flag.to_dict()
    out["reportedUser"] = _build_account_snapshot(target_user_id)
    return jsonify({"flag": out}), 200


@mesh_chat_bp.route("/mesh-chat/admin/accounts", methods=["GET"])
def list_flagged_mesh_accounts():
    """
    Lists all accounts with Mesh Chat moderation flags or restrictions,
    including aggregated reasons why each account was flagged.
    """
    requester, err_resp = _require_moderator()
    if err_resp:
        return err_resp

    _ensure_tables()
    flags = MeshModerationFlag.query.order_by(MeshModerationFlag.created_at.desc()).all()
    restrictions = MeshAccountRestriction.query.all()

    grouped: Dict[str, Dict[str, Any]] = {}
    for f in flags:
        uid = f.reported_user_id
        if not uid:
            continue
        entry = grouped.setdefault(uid, {
            "totalFlags": 0,
            "openFlags": 0,
            "criticalFlags": 0,
            "lastFlaggedAt": f.created_at,
            "reasons": [],
            "categories": [],
            "latestMessage": f.message_snapshot,
        })
        entry["totalFlags"] += 1
        if f.status in ("OPEN", "ESCALATED"):
            entry["openFlags"] += 1
        if f.severity in ("CRITICAL", "HIGH"):
            entry["criticalFlags"] += 1
        if f.created_at > entry["lastFlaggedAt"]:
            entry["lastFlaggedAt"] = f.created_at
            entry["latestMessage"] = f.message_snapshot
        if f.category and f.category not in entry["categories"]:
            entry["categories"].append(f.category)
        for p in f.get_matched_patterns():
            if p and p not in entry["reasons"]:
                entry["reasons"].append(p)

    for r in restrictions:
        grouped.setdefault(r.user_id, {
            "totalFlags": 0,
            "openFlags": 0,
            "criticalFlags": 0,
            "lastFlaggedAt": r.updated_at,
            "reasons": [r.reason] if r.reason else [],
            "categories": [],
            "latestMessage": "",
        })

    accounts = []
    for uid, agg in grouped.items():
        snap = _build_account_snapshot(uid, {uid: agg["totalFlags"]})
        accounts.append({
            **snap,
            **agg,
        })

    accounts.sort(key=lambda a: (a["accountStatus"] != "ACTIVE", a["criticalFlags"], a["totalFlags"]), reverse=True)
    return jsonify({"accounts": accounts, "count": len(accounts)}), 200


@mesh_chat_bp.route("/mesh-chat/admin/accounts/<user_id>", methods=["PATCH"])
def control_flagged_mesh_account(user_id: str):
    """
    Directly restricts, revokes, or restores an account's Mesh Chat access with an explicit reason.
    """
    requester, err_resp = _require_moderator()
    if err_resp:
        return err_resp

    _ensure_tables()
    data = request.json or {}
    action = str(data.get("action") or "").upper().strip()
    reason = str(data.get("reason") or "").strip()[:400]

    if action not in ("RESTRICT", "REVOKE_KEY", "RESTORE"):
        return jsonify({"message": "Invalid action. Expected RESTRICT, REVOKE_KEY, or RESTORE"}), 400

    target_status = {
        "RESTRICT": "RESTRICTED",
        "REVOKE_KEY": "REVOKED",
        "RESTORE": "ACTIVE",
    }[action]

    restriction = db.session.get(MeshAccountRestriction, user_id)
    if restriction is None:
        restriction = MeshAccountRestriction(
            user_id=user_id,
            status=target_status,
            reason=reason or (f"Account {target_status.lower()} by {requester.name}"),
            restricted_by=requester.id,
            updated_at=_now_ms(),
        )
        db.session.add(restriction)
    else:
        restriction.status = target_status
        restriction.reason = reason or restriction.reason or f"Account {target_status.lower()} by {requester.name}"
        restriction.restricted_by = requester.id
        restriction.updated_at = _now_ms()

    if action == "REVOKE_KEY":
        keys = DeviceIdentityKey.query.filter_by(user_id=user_id, status="ACTIVE").all()
        for k in keys:
            k.status = "REVOKED"
    elif action == "RESTORE":
        keys = DeviceIdentityKey.query.filter_by(user_id=user_id, status="REVOKED").all()
        for k in keys:
            k.status = "ACTIVE"

    db.session.commit()
    return jsonify({"account": _build_account_snapshot(user_id), "restriction": restriction.to_dict()}), 200


@mesh_chat_bp.route("/mesh-chat/admin/messages/<message_id>/moderate", methods=["POST"])
def moderate_channel_message(message_id: str):
    """
    Allows an admin/moderator to flag & hide any message directly from the live Channel Feed.
    """
    requester, err_resp = _require_moderator()
    if err_resp:
        return err_resp

    _ensure_tables()
    msg = db.session.get(MeshMessage, message_id)
    if not msg:
        return jsonify({"message": "Message not found"}), 404

    data = request.json or {}
    category = str(data.get("category") or "HARASSMENT").upper().strip()
    severity = str(data.get("severity") or "HIGH").upper().strip()
    reason = str(data.get("reason") or "Removed by administrator").strip()[:300]
    hide_message = bool(data.get("hideMessage", True))

    flag_id = f"adm_msg_{message_id}_{uuid.uuid4().hex[:6]}"
    flag = MeshModerationFlag(
        flag_id=flag_id,
        message_id=message_id,
        channel_id=msg.channel_id,
        reported_user_id=msg.sender_user_id or msg.sender_device_id,
        reported_device_id=msg.sender_device_id,
        reporter_user_id=requester.id,
        source="ADMIN_ACTION",
        category=category,
        severity=severity,
        matched_patterns_json=json.dumps([reason]),
        message_snapshot=msg.text[:500],
        sender_signature=msg.signature_base64,
        signature_verified=msg.signature_verified,
        status="HIDDEN" if hide_message else "OPEN",
        resolution_notes=reason,
        created_at=_now_ms(),
        resolved_at=_now_ms() if hide_message else None,
    )
    db.session.add(flag)

    if hide_message:
        msg.moderation_status = "HIDDEN_BY_ADMIN"
    else:
        msg.moderation_status = "QUARANTINED"
    msg.moderation_severity = severity
    msg.moderation_category = category
    reasons = msg.get_flag_reasons()
    if reason not in reasons:
        reasons.append(reason)
        msg.flag_reasons_json = json.dumps(reasons)

    db.session.commit()
    out = flag.to_dict()
    out["reportedUser"] = _build_account_snapshot(msg.sender_user_id or msg.sender_device_id)
    return jsonify({"flag": out, "message": msg.to_dict()}), 201


@mesh_chat_bp.route("/mesh-chat/admin/channels/<path:channel_id>/restrict", methods=["POST"])
def admin_restrict_channel(channel_id: str):
    """
    Directly restricts, dismantles, or restores a mesh chat channel so messaging can be shut down.
    """
    requester, err_resp = _require_moderator()
    if err_resp:
        return err_resp

    _ensure_tables()
    data = request.json or {}
    action = str(data.get("action") or "RESTRICT").upper().strip()
    reason = str(data.get("reason") or "").strip()[:250]

    ch = db.session.get(MeshChannel, channel_id)
    if not ch:
        def_ch = next((c for c in DEFAULT_CHANNELS if c["channelId"] == channel_id), None)
        ch = MeshChannel(
            channel_id=channel_id,
            name=def_ch["name"] if def_ch else f"#{channel_id.replace('channel:', '')}",
            description=def_ch["description"] if def_ch else "Campus mesh channel",
            is_direct_message=channel_id.startswith("dm:"),
            participants_json="[]",
            created_by=requester.id,
            created_at=_now_ms(),
        )
        db.session.add(ch)

    if action in ("RESTRICT", "DISMANTLE"):
        ch.status = "RESTRICTED"
        ch.restricted_reason = reason or f"Channel restricted/dismantled by {requester.name}"
        ch.restricted_by = requester.id
        ch.restricted_at = _now_ms()
    elif action == "RESTORE":
        ch.status = "ACTIVE"
        ch.restricted_reason = None
        ch.restricted_by = requester.id
        ch.restricted_at = _now_ms()
    else:
        return jsonify({"message": "Invalid action. Expected RESTRICT, DISMANTLE, or RESTORE"}), 400

    db.session.commit()
    return jsonify({"channel": ch.to_dict()}), 200


@mesh_chat_bp.route("/mesh-chat/channels/<path:channel_id>/read", methods=["POST"])
def mark_channel_read(channel_id: str):
    """
    Marks direct messages in channel_id as SEEN (blue ticks) by recipient.
    """
    requester, err_resp = _require_authenticated_user()
    if err_resp:
        return err_resp

    _ensure_tables()
    data = request.json or {}
    message_ids = data.get("messageIds")

    req_id_str = str(requester.id)
    query = MeshMessage.query.filter(
        MeshMessage.channel_id == channel_id,
        db.or_(
            MeshMessage.sender_user_id != req_id_str,
            MeshMessage.sender_user_id.is_(None),
        ),
        MeshMessage.sender_device_id != req_id_str,
    )
    if isinstance(message_ids, list) and message_ids:
        query = query.filter(MeshMessage.message_id.in_(message_ids))

    updated_count = query.update({MeshMessage.delivery_state: "SEEN"}, synchronize_session=False)
    db.session.commit()
    return jsonify({"channelId": channel_id, "seenCount": updated_count}), 200


@mesh_chat_bp.route("/mesh-chat/messages/receipt", methods=["POST"])
def record_message_receipt():
    """
    Updates delivery state (DELIVERED, SEEN) for specific messages.
    """
    requester, err_resp = _require_authenticated_user()
    if err_resp:
        return err_resp

    _ensure_tables()
    data = request.json or {}
    raw_ids = data.get("messageIds") or ([data.get("messageId")] if data.get("messageId") else [])
    message_ids = [str(mid) for mid in raw_ids if mid]
    state = str(data.get("deliveryState") or data.get("state") or "SEEN").upper().strip()
    if state not in ("SENT", "DELIVERED", "SEEN"):
        state = "SEEN"

    updated = 0
    if message_ids:
        updated = MeshMessage.query.filter(
            MeshMessage.message_id.in_(message_ids)
        ).update({MeshMessage.delivery_state: state}, synchronize_session=False)
        db.session.commit()

    return jsonify({"updated": updated, "deliveryState": state}), 200


@mesh_chat_bp.route("/mesh-chat/translate", methods=["POST"])
def translate_message():
    """
    Translates a chat message to Odia (or specified target language) using Gemini API.
    """
    requester, err_resp = _require_authenticated_user()
    if err_resp:
        return err_resp

    data = request.json or {}
    text = str(data.get("text") or "").strip()
    target_lang = str(data.get("targetLanguage") or data.get("language") or "auto").strip().lower()

    if not text:
        return jsonify({"message": "Text to translate is required"}), 400

    if target_lang == "auto":
        # Auto-detect script: If text contains Odia characters, translate to English; otherwise translate to Odia.
        has_odia = bool(re.search(r'[\u0b00-\u0b7f]', text))
        target_lang = "en" if has_odia else "or"

    lang_map = {
        "or": "Odia (ଓଡ଼ିଆ)",
        "odia": "Odia (ଓଡ଼ିଆ)",
        "hi": "Hindi (हिन्दी)",
        "hindi": "Hindi (हिन्दी)",
        "bn": "Bengali (বাংলা)",
        "bengali": "Bengali (বাংলা)",
        "en": "English",
        "english": "English",
    }
    target_lang_name = lang_map.get(target_lang, "Odia (ଓଡ଼ିଆ)")

    api_key = getattr(Config, "GEMINI_API_KEY", None) or os.environ.get("GEMINI_API_KEY")
    if not api_key:
        return jsonify({"message": "Gemini API key is not configured on the server"}), 503

    translated_text = ""
    prompt = (
        f"You are an expert native translator. Translate the following text accurately, naturally, "
        f"and idiomatically into {target_lang_name}.\n"
        f"Preserve standard emojis and proper campus terms (e.g. roll numbers, room numbers) appropriately.\n"
        f"CRITICAL: Return ONLY the direct translation in {target_lang_name} without any conversational remarks, "
        f"prefixes, notes, explanations, or wrapping quotes.\n\n"
        f"{text}"
    )

    try:
        from google import genai
        client = genai.Client(api_key=api_key)
        model_name = getattr(Config, "GEMINI_MODEL", None) or "gemini-2.5-flash"
        response = client.models.generate_content(
            model=model_name,
            contents=prompt,
        )
        translated_text = (response.text or "").strip()
    except Exception as e_genai:
        print(f"[WARN] [MESH_CHAT] google.genai translation attempt failed: {e_genai}, trying fallback")
        try:
            import google.generativeai as legacy_genai
            legacy_genai.configure(api_key=api_key)
            model = legacy_genai.GenerativeModel("gemini-1.5-flash")
            resp = model.generate_content(prompt)
            translated_text = (resp.text or "").strip()
        except Exception as e_legacy:
            print(f"[ERROR] [MESH_CHAT] Gemini translation fallback also failed: {e_legacy}")
            return jsonify({
                "message": f"Translation failed: {str(e_genai)}",
                "originalText": text,
            }), 500

    if not translated_text:
        translated_text = text

    return jsonify({
        "originalText": text,
        "translatedText": translated_text,
        "targetLanguage": target_lang,
        "targetLanguageName": target_lang_name,
        "model": "gemini",
    }), 200

