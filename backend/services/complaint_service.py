import datetime
import hashlib
from models.user import User
from models.complaint import Complaint

COMPLAINT_AGEING_HOURS = 48
RECURRENCE_WINDOW_DAYS = 14
MIN_COMPLAINTS_FOR_RECURRENCE = 3
ESCALATION_ELEVATED_THRESHOLD = 4
ESCALATION_HIGH_THRESHOLD = 6

COMPLAINT_TRANSITIONS = {
    'ASSIGN': (['PENDING', 'REOPENED'], 'ASSIGNED'),
    'REJECT': (['PENDING'], 'REJECTED'),
    'START': (['ASSIGNED', 'REOPENED'], 'IN_PROGRESS'),
    'RESOLVE': (['IN_PROGRESS'], 'RESOLVED'),
    'CLOSE': (['RESOLVED'], 'CLOSED'),
    'REOPEN': (['RESOLVED', 'CLOSED'], 'REOPENED'),
}

def _format_admin_complaint(complaint, now_dt=None):
    if now_dt is None:
        now_dt = datetime.datetime.now()
    c_dict = complaint.to_dict()
    age_hours = 0.0
    if complaint.created_at:
        try:
            c_dt = datetime.datetime.fromisoformat(complaint.created_at)
            age_hours = round(max(0.0, (now_dt - c_dt).total_seconds() / 3600.0), 1)
        except Exception:
            pass
    c_dict['ageHours'] = age_hours
    is_active = complaint.status in ['PENDING', 'ASSIGNED', 'IN_PROGRESS', 'REOPENED']
    c_dict['isAgeing'] = is_active and (age_hours >= COMPLAINT_AGEING_HOURS)

    student = User.query.get(complaint.student_id)
    if student:
        c_dict['studentName'] = student.name
        c_dict['studentEmail'] = student.email
        c_dict['registrationNumber'] = student.registration_number
        c_dict['branch'] = student.branch
        c_dict['year'] = student.year
    else:
        c_dict['studentName'] = 'Unknown Student'

    if complaint.assigned_to:
        staff = User.query.get(complaint.assigned_to)
        if staff:
            c_dict['assignedToName'] = staff.name
            c_dict['assignedToEmail'] = staff.email
            c_dict['assignedToRole'] = staff.role
    else:
        c_dict['assignedToName'] = None

    return c_dict

def generate_recurrence_id(norm_category, norm_location, complaint_ids):
    sorted_ids = sorted(complaint_ids)
    raw_str = f"{norm_category}|{norm_location}|{','.join(sorted_ids)}"
    hash_val = hashlib.sha256(raw_str.encode('utf-8')).hexdigest()[:12]
    loc_slug = "".join(c if c.isalnum() else "_" for c in norm_location)[:15].strip("_")
    cat_slug = "".join(c if c.isalnum() else "_" for c in norm_category)[:10].strip("_")
    return f"rec_{cat_slug}_{loc_slug}_{hash_val}".lower()

from sqlalchemy import func

def compute_recurring_complaint_clusters(category_filter=None, location_filter=None, status_filter=None):
    query = Complaint.query.filter(
        Complaint.category.isnot(None),
        Complaint.location.isnot(None),
        Complaint.location != '',
        Complaint.location != 'NONE',
        Complaint.location != 'UNKNOWN',
        Complaint.location != 'NULL'
    )
    if category_filter:
        norm_cf = category_filter.strip().upper()
        query = query.filter(func.upper(Complaint.category) == norm_cf)
    if location_filter:
        norm_lf = location_filter.strip().upper()
        query = query.filter(func.upper(Complaint.location).like(f"%{norm_lf}%"))

    complaints = query.order_by(Complaint.created_at.desc()).all()

    grouped = {}
    for c in complaints:
        if not c.category or not c.location:
            continue
        norm_cat = c.category.strip().upper()
        norm_loc = c.location.strip().upper()
        if not norm_cat or not norm_loc or norm_loc in ['NONE', 'UNKNOWN', 'NULL', '']:
            continue
        key = (norm_cat, norm_loc)
        if key not in grouped:
            grouped[key] = []
        grouped[key].append(c)

    clusters = []

    for (norm_cat, norm_loc), c_list in grouped.items():
        if len(c_list) < MIN_COMPLAINTS_FOR_RECURRENCE:
            continue

        parsed_list = []
        for c in c_list:
            if c.created_at:
                try:
                    dt = datetime.datetime.fromisoformat(c.created_at)
                    parsed_list.append((dt, c))
                except Exception:
                    pass
        parsed_list.sort(key=lambda x: x[0], reverse=True)

        if len(parsed_list) < MIN_COMPLAINTS_FOR_RECURRENCE:
            continue

        idx = 0
        while idx <= len(parsed_list) - MIN_COMPLAINTS_FOR_RECURRENCE:
            anchor_dt, anchor_c = parsed_list[idx]
            window_cutoff = anchor_dt - datetime.timedelta(days=RECURRENCE_WINDOW_DAYS)

            cluster_items = [
                item for item in parsed_list[idx:]
                if item[0] >= window_cutoff
            ]

            if len(cluster_items) >= MIN_COMPLAINTS_FOR_RECURRENCE:
                cluster_complaints = [item[1] for item in cluster_items]
                cluster_dts = [item[0] for item in cluster_items]

                complaint_ids = [c.id for c in cluster_complaints]
                recurrence_id = generate_recurrence_id(norm_cat, norm_loc, complaint_ids)

                is_active = any(c.status not in ['CLOSED', 'REJECTED'] for c in cluster_complaints)
                rec_status = 'ACTIVE' if is_active else 'HISTORICAL'

                active_count = sum(1 for c in cluster_complaints if c.status in ['PENDING', 'ASSIGNED', 'IN_PROGRESS', 'REOPENED'])
                resolved_count = sum(1 for c in cluster_complaints if c.status in ['RESOLVED', 'CLOSED'])

                resolution_diffs = []
                for c in cluster_complaints:
                    if c.created_at and c.resolved_at:
                        try:
                            cdt = datetime.datetime.fromisoformat(c.created_at)
                            rdt = datetime.datetime.fromisoformat(c.resolved_at)
                            diff = (rdt - cdt).total_seconds() / 3600.0
                            resolution_diffs.append(max(0.0, diff))
                        except Exception:
                            pass

                avg_resolution_hours = round(sum(resolution_diffs) / len(resolution_diffs), 1) if resolution_diffs else 0.0

                c_count = len(cluster_complaints)
                if c_count >= ESCALATION_HIGH_THRESHOLD:
                    escalation_level = 'HIGH'
                elif c_count >= ESCALATION_ELEVATED_THRESHOLD:
                    escalation_level = 'ELEVATED'
                else:
                    escalation_level = 'NORMAL'

                priorities = [c.priority for c in cluster_complaints if c.priority]
                highest_priority = 'MEDIUM'
                for prio in ['URGENT', 'HIGH', 'MEDIUM', 'LOW']:
                    if prio in priorities:
                        highest_priority = prio
                        break

                cluster_dict = {
                    "recurrenceId": recurrence_id,
                    "category": norm_cat,
                    "location": norm_loc,
                    "complaintCount": c_count,
                    "firstComplaintAt": min(cluster_dts).isoformat(),
                    "latestComplaintAt": max(cluster_dts).isoformat(),
                    "windowDays": RECURRENCE_WINDOW_DAYS,
                    "complaintIds": complaint_ids,
                    "activeComplaintCount": active_count,
                    "resolvedComplaintCount": resolved_count,
                    "averageResolutionHours": avg_resolution_hours,
                    "highestPriority": highest_priority,
                    "escalationLevel": escalation_level,
                    "recurrenceStatus": rec_status,
                    "_complaints": cluster_complaints
                }

                clusters.append(cluster_dict)
                idx += len(cluster_items)
            else:
                idx += 1

    if category_filter:
        norm_cf = category_filter.strip().upper()
        clusters = [c for c in clusters if c['category'] == norm_cf]

    if location_filter:
        norm_lf = location_filter.strip().upper()
        clusters = [c for c in clusters if norm_lf in c['location']]

    if status_filter and status_filter.upper() != 'ALL':
        clusters = [c for c in clusters if c['recurrenceStatus'] == status_filter.upper()]

    return clusters
