import json
import time
from extensions import db


def _now_ms() -> int:
    return int(time.time() * 1000)


class MeshChannel(db.Model):
    __tablename__ = "mesh_channels"

    channel_id = db.Column(db.String(128), primary_key=True)
    name = db.Column(db.String(64), nullable=False)
    description = db.Column(db.String(256), nullable=True)
    is_direct_message = db.Column(db.Boolean, default=False, nullable=False)
    participants_json = db.Column(db.Text, default="[]", nullable=False)
    created_by = db.Column(db.String(64), nullable=True)
    created_at = db.Column(db.BigInteger, default=_now_ms, nullable=False)
    status = db.Column(db.String(32), default="ACTIVE", nullable=False)  # ACTIVE, RESTRICTED, DISMANTLED
    restricted_reason = db.Column(db.String(256), nullable=True)
    restricted_by = db.Column(db.String(64), nullable=True)
    restricted_at = db.Column(db.BigInteger, nullable=True)

    def get_participants(self):
        try:
            data = json.loads(self.participants_json or "[]")
            return [str(p) for p in data] if isinstance(data, list) else []
        except Exception:
            return []

    def to_dict(self):
        ch_status = self.status or "ACTIVE"
        return {
            "channelId": self.channel_id,
            "name": self.name,
            "description": self.description,
            "isDirectMessage": bool(self.is_direct_message),
            "participants": self.get_participants(),
            "createdBy": self.created_by,
            "createdAt": self.created_at,
            "status": ch_status,
            "isRestricted": bool(ch_status.upper() in ("RESTRICTED", "DISMANTLED")),
            "restrictedReason": self.restricted_reason,
            "restrictedBy": self.restricted_by,
            "restrictedAt": self.restricted_at,
        }


class MeshMessage(db.Model):
    __tablename__ = "mesh_messages"

    message_id = db.Column(db.String(64), primary_key=True)
    channel_id = db.Column(db.String(128), nullable=False, index=True)
    sender_device_id = db.Column(db.String(128), nullable=False)
    sender_user_id = db.Column(db.String(64), nullable=True, index=True)
    sender_display_name = db.Column(db.String(120), nullable=False)
    sender_role = db.Column(db.String(32), default="student", nullable=False)
    text = db.Column(db.Text, default="", nullable=False)
    image_base64 = db.Column(db.Text, nullable=True)
    is_encrypted = db.Column(db.Boolean, default=False, nullable=False)
    reply_to_message_id = db.Column(db.String(64), nullable=True)
    created_at = db.Column(db.BigInteger, nullable=False, index=True)
    hop_count = db.Column(db.Integer, default=0, nullable=False)
    ttl = db.Column(db.Integer, default=7, nullable=False)
    signature_base64 = db.Column(db.Text, nullable=True)
    signature_verified = db.Column(db.Boolean, default=False, nullable=False)
    verification_state = db.Column(db.String(32), default="UNVERIFIED", nullable=False)
    moderation_status = db.Column(db.String(32), default="CLEAN", nullable=False, index=True)
    moderation_severity = db.Column(db.String(16), default="NONE", nullable=False)
    moderation_category = db.Column(db.String(32), default="NONE", nullable=True)
    flag_reasons_json = db.Column(db.Text, default="[]", nullable=False)
    synced_by_user_id = db.Column(db.String(64), nullable=True)
    synced_at = db.Column(db.BigInteger, default=_now_ms, nullable=False)
    delivery_state = db.Column(db.String(32), default="SENT", nullable=False)  # SENT, DELIVERED, SEEN

    def get_flag_reasons(self):
        try:
            data = json.loads(self.flag_reasons_json or "[]")
            return [str(r) for r in data] if isinstance(data, list) else []
        except Exception:
            return []

    def to_dict(self):
        return {
            "messageId": self.message_id,
            "channelId": self.channel_id,
            "senderDeviceId": self.sender_device_id,
            "senderUserId": self.sender_user_id,
            "senderDisplayName": self.sender_display_name,
            "senderRole": self.sender_role,
            "text": self.text,
            "imageBase64": self.image_base64,
            "isEncrypted": bool(self.is_encrypted),
            "replyToMessageId": self.reply_to_message_id,
            "createdAt": self.created_at,
            "hopCount": self.hop_count,
            "ttl": self.ttl,
            "signatureBase64": self.signature_base64,
            "signatureVerified": bool(self.signature_verified),
            "verificationState": self.verification_state,
            "moderationStatus": self.moderation_status,
            "moderationSeverity": self.moderation_severity,
            "moderationCategory": self.moderation_category,
            "flagReasons": self.get_flag_reasons(),
            "syncedByUserId": self.synced_by_user_id,
            "syncedAt": self.synced_at,
            "deliveryState": self.delivery_state or "SENT",
        }


class MeshModerationFlag(db.Model):
    __tablename__ = "mesh_moderation_flags"

    flag_id = db.Column(db.String(96), primary_key=True)
    message_id = db.Column(db.String(64), nullable=False, index=True)
    channel_id = db.Column(db.String(128), nullable=False)
    reported_user_id = db.Column(db.String(64), nullable=True)
    reported_device_id = db.Column(db.String(128), nullable=True)
    reporter_user_id = db.Column(db.String(64), nullable=False)
    source = db.Column(db.String(32), default="USER_REPORT", nullable=False)
    category = db.Column(db.String(32), default="OTHER", nullable=False)
    severity = db.Column(db.String(16), default="MODERATE", nullable=False)
    matched_patterns_json = db.Column(db.Text, default="[]", nullable=False)
    message_snapshot = db.Column(db.Text, default="", nullable=False)
    sender_signature = db.Column(db.Text, nullable=True)
    signature_verified = db.Column(db.Boolean, default=False, nullable=False)
    status = db.Column(db.String(32), default="OPEN", nullable=False, index=True)
    resolution_notes = db.Column(db.Text, nullable=True)
    created_at = db.Column(db.BigInteger, default=_now_ms, nullable=False, index=True)
    resolved_at = db.Column(db.BigInteger, nullable=True)

    def get_matched_patterns(self):
        try:
            data = json.loads(self.matched_patterns_json or "[]")
            return [str(p) for p in data] if isinstance(data, list) else []
        except Exception:
            return []

    def to_dict(self):
        return {
            "flagId": self.flag_id,
            "messageId": self.message_id,
            "channelId": self.channel_id,
            "reportedUserId": self.reported_user_id,
            "reportedDeviceId": self.reported_device_id,
            "reporterUserId": self.reporter_user_id,
            "source": self.source,
            "category": self.category,
            "severity": self.severity,
            "matchedPatterns": self.get_matched_patterns(),
            "messageSnapshot": self.message_snapshot,
            "senderSignature": self.sender_signature,
            "signatureVerified": bool(self.signature_verified),
            "status": self.status,
            "resolutionNotes": self.resolution_notes,
            "createdAt": self.created_at,
            "resolvedAt": self.resolved_at,
        }


class MeshAccountRestriction(db.Model):
    """Tracks admin-enforced Mesh Chat restrictions/bans for flagged accounts."""

    __tablename__ = "mesh_account_restrictions"

    user_id = db.Column(db.String(64), primary_key=True)
    status = db.Column(db.String(32), default="ACTIVE", nullable=False, index=True)  # ACTIVE, RESTRICTED, REVOKED
    reason = db.Column(db.Text, nullable=True)
    flag_id = db.Column(db.String(96), nullable=True)
    restricted_by = db.Column(db.String(64), nullable=True)
    updated_at = db.Column(db.BigInteger, default=_now_ms, nullable=False)

    def to_dict(self):
        return {
            "userId": self.user_id,
            "status": self.status,
            "reason": self.reason,
            "flagId": self.flag_id,
            "restrictedBy": self.restricted_by,
            "updatedAt": self.updated_at,
        }
