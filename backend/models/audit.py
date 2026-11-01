import uuid
import datetime
from extensions import db

class RequestAudit(db.Model):
    __tablename__ = 'request_audits'
    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    entity_type = db.Column(db.String(30), nullable=False, index=True)
    entity_id = db.Column(db.String(36), nullable=False, index=True)
    actor_id = db.Column(db.String(36), db.ForeignKey('users.id'), nullable=False)
    action = db.Column(db.String(50), nullable=False)
    remarks = db.Column(db.String(255), nullable=True)
    ip_address = db.Column(db.String(45), nullable=True)
    timestamp = db.Column(db.String(50), default=lambda: datetime.datetime.now().isoformat())

    def to_dict(self):
        return {
            "id": self.id,
            "entityType": self.entity_type,
            "entityId": self.entity_id,
            "actorId": self.actor_id,
            "action": self.action,
            "remarks": self.remarks,
            "ipAddress": self.ip_address,
            "timestamp": self.timestamp
        }

class ComplaintStatusHistory(db.Model):
    __tablename__ = 'complaint_status_history'
    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    complaint_id = db.Column(db.String(36), db.ForeignKey('complaints.id'), nullable=False, index=True)
    changed_by = db.Column(db.String(36), db.ForeignKey('users.id'), nullable=False)
    old_status = db.Column(db.String(25), nullable=True)
    new_status = db.Column(db.String(25), nullable=False)
    comment = db.Column(db.String(255), nullable=True)
    timestamp = db.Column(db.String(50), default=lambda: datetime.datetime.now().isoformat())

    def to_dict(self):
        return {
            "id": self.id,
            "complaintId": self.complaint_id,
            "changedBy": self.changed_by,
            "oldStatus": self.old_status,
            "newStatus": self.new_status,
            "comment": self.comment,
            "remarks": self.comment,
            "timestamp": self.timestamp
        }
