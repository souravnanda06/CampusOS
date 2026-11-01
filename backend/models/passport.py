import uuid
import datetime
from extensions import db

class DeviceIdentityKey(db.Model):
    """
    CampusOS Passport Device Identity Key (Phase 1C).
    Stores only the public Ed25519 key registered by a student's device.
    CRITICAL SECURITY INVARIANT:
    The backend NEVER receives, stores, or handles private cryptographic keys.
    """
    __tablename__ = 'device_identity_keys'

    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = db.Column(db.String(36), db.ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True)
    public_key_b64 = db.Column(db.String(128), unique=True, nullable=False, index=True)
    key_type = db.Column(db.String(32), default='ED25519', nullable=False)
    status = db.Column(db.String(32), default='ACTIVE', nullable=False, index=True)  # ACTIVE, REVOKED, SUSPENDED
    created_at = db.Column(db.String(50), default=lambda: datetime.datetime.now().isoformat())
    activated_at = db.Column(db.String(50), default=lambda: datetime.datetime.now().isoformat())
    revoked_at = db.Column(db.String(50), nullable=True)
    last_seen_at = db.Column(db.String(50), nullable=True)

    user = db.relationship('User', backref=db.backref('device_identity_keys', cascade='all, delete-orphan', lazy='dynamic'))

    def to_dict(self):
        return {
            "id": self.id,
            "keyId": self.id,
            "userId": self.user_id,
            "publicKey": self.public_key_b64,
            "keyType": self.key_type,
            "status": self.status,
            "createdAt": self.created_at,
            "activatedAt": self.activated_at,
            "revokedAt": self.revoked_at,
            "lastSeenAt": self.last_seen_at
        }

    def get_active_certificate(self):
        return self.certificates.filter_by(status='ACTIVE').first()


class DeviceCertificate(db.Model):
    """
    CampusOS Passport Institutional Certificate (Phase 1C).
    An institutional cryptographic assertion that public_key X belongs to CampusOS user Y.
    Signed by the institution Ed25519 private key.
    """
    __tablename__ = 'device_certificates'

    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    key_id = db.Column(db.String(36), db.ForeignKey('device_identity_keys.id', ondelete='CASCADE'), nullable=False, index=True)
    certificate_version = db.Column(db.String(16), default='1.0', nullable=False)
    issuer = db.Column(db.String(64), default='CampusOS', nullable=False)
    issuer_key_id = db.Column(db.String(64), nullable=False)
    subject_user_id = db.Column(db.String(36), nullable=False, index=True)
    subject_public_key_b64 = db.Column(db.String(128), nullable=False)
    algorithm = db.Column(db.String(32), default='Ed25519', nullable=False)
    valid_from = db.Column(db.String(50), nullable=False)
    valid_to = db.Column(db.String(50), nullable=False)
    signature = db.Column(db.Text, nullable=False)
    status = db.Column(db.String(32), default='ACTIVE', nullable=False, index=True)  # ACTIVE, REVOKED, EXPIRED
    created_at = db.Column(db.String(50), default=lambda: datetime.datetime.now().isoformat())
    revoked_at = db.Column(db.String(50), nullable=True)

    device_key = db.relationship('DeviceIdentityKey', backref=db.backref('certificates', cascade='all, delete-orphan', lazy='dynamic'))

    def to_dict(self):
        payload = {
            "algorithm": self.algorithm,
            "certificateVersion": self.certificate_version,
            "issuer": self.issuer,
            "keyId": self.key_id,
            "publicKey": self.subject_public_key_b64,
            "userId": self.subject_user_id,
            "validFrom": self.valid_from,
            "validTo": self.valid_to
        }
        return {
            "id": self.id,
            "keyId": self.key_id,
            "certificateVersion": self.certificate_version,
            "issuer": self.issuer,
            "issuerKeyId": self.issuer_key_id,
            "userId": self.subject_user_id,
            "publicKey": self.subject_public_key_b64,
            "algorithm": self.algorithm,
            "validFrom": self.valid_from,
            "validTo": self.valid_to,
            "signature": self.signature,
            "status": self.status,
            "createdAt": self.created_at,
            "revokedAt": self.revoked_at,
            "payload": payload
        }
