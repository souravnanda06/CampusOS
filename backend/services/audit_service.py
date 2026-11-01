import datetime
from extensions import db
from models.audit import RequestAudit, ComplaintStatusHistory

def log_audit(entity_type, entity_id, actor_id, action, remarks=None, ip_address=None):
    """
    Creates and records a RequestAudit entry.
    """
    try:
        audit = RequestAudit(
            entity_type=entity_type,
            entity_id=entity_id,
            actor_id=actor_id,
            action=action,
            remarks=remarks,
            ip_address=ip_address,
            timestamp=datetime.datetime.now().isoformat()
        )
        db.session.add(audit)
        return audit
    except Exception:
        return None

def log_complaint_history(complaint_id, changed_by, old_status, new_status, comment=None):
    """
    Creates and records a ComplaintStatusHistory entry.
    """
    try:
        history = ComplaintStatusHistory(
            complaint_id=complaint_id,
            changed_by=changed_by,
            old_status=old_status,
            new_status=new_status,
            comment=comment,
            timestamp=datetime.datetime.now().isoformat()
        )
        db.session.add(history)
        return history
    except Exception:
        return None
