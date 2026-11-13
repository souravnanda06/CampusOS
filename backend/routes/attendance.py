import io
import math
import threading
import datetime
from datetime import timedelta, timezone
from sqlalchemy.exc import IntegrityError
from flask import Blueprint, request, jsonify, send_file
from extensions import db, send_fcm_message
import extensions
from models.attendance import Session, Attendance, Coupon, SavedClass
from models.user import User

def _haversine_distance(lat1, lon1, lat2, lon2):
    R = 6371000.0  # Earth radius in meters
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)

    a = math.sin(delta_phi / 2.0) ** 2 + \
        math.cos(phi1) * math.cos(phi2) * \
        math.sin(delta_lambda / 2.0) ** 2
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
    return R * c

try:
    from firebase_admin import messaging
except ImportError:
    messaging = None

attendance_bp = Blueprint('attendance_bp', __name__)

@attendance_bp.route('/sessions/create', methods=['POST'])
@attendance_bp.route('/sessions/reconcile', methods=['POST'])
def create_session():
    print("[BACKEND] create_session called")
    data = request.json or {}

    try:
        # Check for client-provided idempotency key or localId
        client_session_id = data.get('clientSessionId') or data.get('localId')
        idempotency_key = data.get('idempotencyKey') or client_session_id
        if idempotency_key:
            existing = Session.query.filter_by(idempotency_key=idempotency_key).first()
            if existing:
                print(f"[BACKEND] Idempotent session hit for key {idempotency_key} -> {existing.id}")
                return jsonify(existing.to_dict()), 200

        teacher_id = data.get('teacherId')
        if teacher_id:
            prior_sessions = Session.query.filter_by(teacher_id=teacher_id, is_active=True).all()
            for ps in prior_sessions:
                ps.is_active = False

        now_str = datetime.datetime.now().isoformat()
        end_str = (datetime.datetime.now() + datetime.timedelta(hours=1)).isoformat()
        latitude = data.get('latitude')
        longitude = data.get('longitude')
        radius_meters = data.get('radiusMeters') or data.get('radius') or 20.0

        new_session = Session(
            name=data.get('name') or data.get('subject') or 'Attendance Session',
            subject=data.get('subject', 'General'),
            instructor_name=data.get('instructorName') or data.get('teacherName') or 'Instructor',
            course=data.get('course'),
            branch=data.get('branch'),
            year=data.get('year'),
            start_time=data.get('startTime') or now_str,
            end_time=data.get('endTime') or end_str,
            location=data.get('location') or data.get('room') or 'Room 101',
            tx_power_level=data.get('txPowerLevel', 3),
            session_nonce=data.get('sessionNonce'),
            teacher_key_id=data.get('teacherKeyId'),
            teacher_id=teacher_id,
            idempotency_key=idempotency_key,
            latitude=float(latitude) if latitude is not None else None,
            longitude=float(longitude) if longitude is not None else None,
            radius_meters=float(radius_meters) if radius_meters is not None else 20.0,
        )
        db.session.add(new_session)
        db.session.commit()
        print(f"[BACKEND] Session saved to DB: {new_session.id}")

        # Notification Logic (Async)
        def send_notification_async(session_data):
            if not (extensions.firebase_initialized or extensions.fcm_sender_override is not None):
                print(f"[LOCAL] Push notification skipped for '{session_data['name']}' (Firebase disabled).")
                return

            try:
                topic_parts = [session_data['course'], session_data['branch'], session_data['year']]
                clean_parts = [p.replace(" ", "").replace(".", "") for p in topic_parts if p]
                topic = "_".join(clean_parts)
                if not topic:
                    return
                print(f"[BACKEND] Sending notification to topic: {topic}")

                message = messaging.Message(
                    notification=messaging.Notification(
                        title="Attendance Started!",
                        body=f"{session_data['name']} ({session_data['subject']}) is live!"
                    ),
                    topic=topic,
                )
                response = send_fcm_message(message)
                print(f"[BACKEND] Notification sent: {response}")
            except Exception as e:
                print(f"Notification error: {e}")

        session_data = {
            'name': new_session.name,
            'subject': new_session.subject,
            'course': new_session.course,
            'branch': new_session.branch,
            'year': new_session.year
        }

        threading.Thread(target=send_notification_async, args=(session_data,)).start()

        return jsonify(new_session.to_dict()), 201

    except IntegrityError:
        # V1 FIX: Concurrent duplicate idempotency key race — recover idempotently
        db.session.rollback()
        if idempotency_key:
            existing = Session.query.filter_by(idempotency_key=idempotency_key).first()
            if existing:
                print(f"[BACKEND] Concurrent session race recovered for key {idempotency_key} -> {existing.id}")
                return jsonify(existing.to_dict()), 200
        return jsonify({"message": "Session already exists (duplicate key)"}), 409

    except Exception as e:
        print(f"❌ [BACKEND] Database Error: {e}")
        db.session.rollback()
        return jsonify({"message": f"Database Error: {str(e)}"}), 500

@attendance_bp.route('/sessions/<session_id>/beacon', methods=['GET', 'POST'])
def session_beacon_info(session_id):
    """
    CampusOS Passport 1I: Beacon endpoint for attendance session metadata & cryptographic session nonce.
    """
    session = Session.query.get(session_id)
    if not session:
        return jsonify({"message": "Session not found"}), 404
    if request.method == 'POST':
        data = request.json or {}
        if data.get('sessionNonce'): session.session_nonce = data['sessionNonce']
        if data.get('teacherKeyId'): session.teacher_key_id = data['teacherKeyId']
        if data.get('teacherId'): session.teacher_id = data['teacherId']
        if 'latitude' in data and data['latitude'] is not None:
            try: session.latitude = float(data['latitude'])
            except (ValueError, TypeError): pass
        if 'longitude' in data and data['longitude'] is not None:
            try: session.longitude = float(data['longitude'])
            except (ValueError, TypeError): pass
        if 'radiusMeters' in data and data['radiusMeters'] is not None:
            try: session.radius_meters = float(data['radiusMeters'])
            except (ValueError, TypeError): pass
        db.session.commit()
    return jsonify({
        "sessionId": session.id,
        "name": session.name,
        "sessionNonce": session.session_nonce,
        "teacherKeyId": session.teacher_key_id,
        "teacherId": session.teacher_id,
        "isActive": session.is_active,
        "latitude": session.latitude,
        "longitude": session.longitude,
        "radiusMeters": session.radius_meters or 20.0,
    }), 200

@attendance_bp.route('/sessions/stop/<session_id>', methods=['POST'])
def stop_session(session_id):
    session = Session.query.get(session_id)
    if session:
        session.is_active = False
        db.session.commit()
        return jsonify({"message": "Session stopped successfully"}), 200
    return jsonify({"message": "Session not found"}), 404

def _is_session_expired(end_time_str):
    if not end_time_str:
        return False
    try:
        clean = str(end_time_str).strip().replace('Z', '+00:00')
        end_dt = datetime.datetime.fromisoformat(clean)
        if end_dt.tzinfo is not None:
            now_dt = datetime.datetime.now(end_dt.tzinfo)
        else:
            now_dt = datetime.datetime.now()
        return end_dt <= now_dt
    except Exception:
        return False

@attendance_bp.route('/sessions/active', methods=['GET'])
def get_active_sessions():
    course = request.args.get('course')
    branch = request.args.get('branch')
    year = request.args.get('year')

    all_active = Session.query.filter_by(is_active=True).all()
    expired_found = False
    valid_active = []

    for s in all_active:
        if _is_session_expired(s.end_time):
            s.is_active = False
            expired_found = True
        else:
            valid_active.append(s)

    if expired_found:
        try:
            db.session.commit()
        except Exception:
            db.session.rollback()

    filtered = valid_active
    if course:
        filtered = [s for s in filtered if s.course == course]
    if branch and branch != 'null':
        filtered = [s for s in filtered if s.branch == branch]
    if year:
        filtered = [s for s in filtered if str(s.year) == str(year)]

    return jsonify([s.to_dict() for s in filtered]), 200

# --- TEACHER ANALYTICS & STUDENT LIST ---

@attendance_bp.route('/students', methods=['GET'])
def get_students():
    course = request.args.get('course')
    branch = request.args.get('branch')
    year = request.args.get('year')

    query = User.query.filter_by(role='student')

    if course: query = query.filter_by(course=course)
    if branch and branch != 'null': query = query.filter_by(branch=branch)
    if year: query = query.filter_by(year=year)

    students = query.order_by(User.registration_number).all()

    return jsonify([s.to_dict() for s in students]), 200

@attendance_bp.route('/analytics/student/<student_id>', methods=['GET'])
def get_student_heatmap(student_id):
    subject = request.args.get('subject')
    student = User.query.get(student_id)

    if not student:
        return jsonify({"message": "Student not found"}), 404

    all_sessions = Session.query.filter_by(
        subject=subject,
        course=student.course,
        year=student.year
    )
    if student.branch:
        all_sessions = all_sessions.filter_by(branch=student.branch)
    
    # Calculate attendance logic here if needed, for now just returning sessions
    # This endpoint seems incomplete in original file, assuming it returns sessions for heatmap
    return jsonify([s.to_dict() for s in all_sessions.all()]), 200

# --- EXCEL EXPORT ---
@attendance_bp.route('/export/session/<session_id>', methods=['GET'])
def export_session_excel(session_id):
    session = Session.query.get(session_id)
    results = db.session.query(Attendance, User).join(User, Attendance.user_id == User.id).filter(Attendance.session_id == session_id).all()

    data = []
    for att, user in results:
        data.append({
            "Reg No": user.registration_number if user.registration_number else "N/A",
            "Student Name": att.student_name,
            "Check-In Time": att.check_in_time.split("T")[1][:8],
            "Status": att.status
        })

    import openpyxl

    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = 'Attendance'
    ws.append(["Reg No", "Student Name", "Check-In Time", "Status"])
    data.sort(key=lambda x: str(x.get("Reg No", "")))
    for row in data:
        ws.append([
            row.get("Reg No", "N/A"),
            row.get("Student Name", ""),
            row.get("Check-In Time", ""),
            row.get("Status", "")
        ])

    output = io.BytesIO()
    wb.save(output)
    output.seek(0)
    filename = f"Attendance_{session.name}.xlsx"

    return send_file(
        output,
        download_name=filename,
        as_attachment=True,
        mimetype='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    )

@attendance_bp.route('/sessions/history', methods=['GET'])
def get_session_history():
    instructor_name = request.args.get('instructorName')
    date_str = request.args.get('date')

    query = Session.query
    if instructor_name:
        query = query.filter_by(instructor_name=instructor_name)

    if date_str:
        query = query.filter(Session.start_time.like(f"{date_str}%"))

    sessions = query.order_by(Session.start_time.desc()).limit(100).all()
    return jsonify([s.to_dict() for s in sessions]), 200

# --- ATTENDANCE ROUTES ---
@attendance_bp.route('/attendance/mark', methods=['POST'])
def mark_attendance():
    data = request.json or {}
    session_id = data.get('sessionId')
    student_id = data.get('studentId')
    student_name = data.get('studentName', '')
    idempotency_key = data.get('idempotencyKey')

    if not session_id or not student_id:
        return jsonify({"message": "sessionId and studentId are required"}), 400

    session = Session.query.get(session_id)
    if not session:
        return jsonify({"message": "Session not found"}), 404

    # Idempotent check by idempotencyKey if provided
    if idempotency_key:
        existing_by_key = Attendance.query.filter_by(idempotency_key=idempotency_key).first()
        if existing_by_key:
            return jsonify(existing_by_key.to_dict()), 200

    existing = Attendance.query.filter_by(session_id=session_id, user_id=student_id).first()
    if existing:
        if idempotency_key:
            return jsonify(existing.to_dict()), 200
        return jsonify({"message": "Attendance already marked"}), 400

    # GPS + Internet Location Validation (20m radius)
    student_lat = data.get('latitude')
    student_lng = data.get('longitude')
    verification_mode = data.get('verificationMode', 'LEGACY')
    proximity_tier = data.get('proximityTier')
    distance_meters = None

    if student_lat is not None and student_lng is not None:
        try:
            s_lat = float(student_lat)
            s_lng = float(student_lng)
            if session.latitude is not None and session.longitude is not None:
                t_lat = float(session.latitude)
                t_lng = float(session.longitude)
                dist = _haversine_distance(t_lat, t_lng, s_lat, s_lng)
                distance_meters = round(dist, 1)
                max_radius = float(session.radius_meters or 20.0)

                # Reject if outside 20m radius
                if dist > max_radius:
                    return jsonify({
                        "message": f"GPS verification failed: You are {distance_meters}m away from the teacher/classroom (maximum allowed radius is {int(max_radius)}m).",
                        "resultCode": "OUT_OF_RADIUS",
                        "distanceMeters": distance_meters,
                        "maxRadiusMeters": max_radius,
                    }), 400

                verification_mode = "GPS_LOCATION"
                proximity_tier = "NEAR"
        except (ValueError, TypeError):
            pass

    try:
        new_attendance = Attendance(
            session_id=session_id,
            user_id=student_id,
            student_name=student_name,
            idempotency_key=idempotency_key,
            device_key_id=data.get('deviceKeyId'),
            response_nonce=data.get('responseNonce'),
            verification_mode=verification_mode,
            proximity_tier=proximity_tier,
            router_bssid=data.get('routerBssid'),
            latitude=float(student_lat) if student_lat is not None else None,
            longitude=float(student_lng) if student_lng is not None else None,
            distance_meters=distance_meters,
        )
        db.session.add(new_attendance)

        # V2 FIX: Atomic SQL-level increment prevents lost updates under concurrency
        Session.query.filter_by(id=session_id).update(
            {Session.attendance_count: db.func.coalesce(Session.attendance_count, 0) + 1}
        )

        db.session.commit()
        return jsonify(new_attendance.to_dict()), 201
    except IntegrityError:
        db.session.rollback()
        existing = Attendance.query.filter_by(session_id=session_id, user_id=student_id).first()
        if existing:
            return jsonify(existing.to_dict()), 200
        return jsonify({"message": "Attendance already marked"}), 409

@attendance_bp.route('/attendance/batch-sync', methods=['POST'])
def batch_sync_attendance():
    """
    CampusOS Passport 1I: Batch Attendance Synchronization.
    Idempotently syncs a queue of verified student attendance records from a teacher device.
    """
    data = request.json or {}
    session_id = data.get('sessionId')
    records = data.get('records', [])

    if not session_id:
        return jsonify({"message": "sessionId is required"}), 400

    session = Session.query.get(session_id)
    if not session:
        return jsonify({"message": "Session not found"}), 404

    synced_records = []
    duplicate_count = 0
    new_count = 0

    for r in records:
        student_id = r.get('studentId')
        student_name = r.get('studentName', '')
        idempotency_key = r.get('idempotencyKey')

        if not student_id:
            continue

        existing = None
        if idempotency_key:
            existing = Attendance.query.filter_by(idempotency_key=idempotency_key).first()
        if not existing:
            existing = Attendance.query.filter_by(session_id=session_id, user_id=student_id).first()

        if existing:
            duplicate_count += 1
            synced_records.append(existing.to_dict())
            continue

        try:
            new_att = Attendance(
                session_id=session_id,
                user_id=student_id,
                student_name=student_name,
                check_in_time=r.get('checkInTime') or datetime.datetime.now().isoformat(),
                status=r.get('status', 'present'),
                coupon_earned=r.get('couponEarned', False),
                idempotency_key=idempotency_key,
                device_key_id=r.get('deviceKeyId'),
                response_nonce=r.get('responseNonce'),
                verification_mode=r.get('verificationMode', 'BLE_BATCH'),
                proximity_tier=r.get('proximityTier', 'NEAR'),
                router_bssid=r.get('routerBssid')
            )
            db.session.add(new_att)
            # V2 FIX: Atomic SQL-level increment prevents lost updates under concurrency
            Session.query.filter_by(id=session_id).update(
                {Session.attendance_count: db.func.coalesce(Session.attendance_count, 0) + 1}
            )
            db.session.commit()
            new_count += 1
            synced_records.append(new_att.to_dict())
        except IntegrityError:
            db.session.rollback()
            existing = Attendance.query.filter_by(session_id=session_id, user_id=student_id).first()
            if existing:
                duplicate_count += 1
                synced_records.append(existing.to_dict())
    return jsonify({
        "sessionId": session_id,
        "newSynced": new_count,
        "duplicates": duplicate_count,
        "totalRecords": len(synced_records),
        "records": synced_records
    }), 200

@attendance_bp.route('/attendance/student/<student_id>', methods=['GET'])
def get_student_attendance(student_id):
    records = Attendance.query.filter_by(user_id=student_id).order_by(Attendance.check_in_time.desc()).all()
    return jsonify([r.to_dict() for r in records]), 200

@attendance_bp.route('/attendance/session/<session_id>', methods=['GET'])
def get_session_attendance(session_id):
    records = Attendance.query.filter_by(session_id=session_id).all()
    return jsonify([r.to_dict() for r in records]), 200

# 1. NEW: Reset Device ID (For Teacher)
@attendance_bp.route('/teacher/reset-device-id', methods=['POST'])
def reset_device_id():
    data = request.json
    student_id = data.get('studentId')
    
    user = User.query.get(student_id)
    if user:
        user.device_id = None # Clear the ID
        db.session.commit()
        return jsonify({"message": "Device ID reset successfully"}), 200
    return jsonify({"message": "User not found"}), 404

# 2. UPDATED: Get Students with Real Attendance % (For Teacher List)
@attendance_bp.route('/students-with-stats', methods=['GET'])
def get_students_with_stats():
    course = request.args.get('course')
    branch = request.args.get('branch')
    year = request.args.get('year')
    approval_status = (request.args.get('approvalStatus') or 'APPROVED').strip().upper()

    query = User.query.filter_by(role='student')
    if approval_status == 'APPROVED':
        query = query.filter(db.or_(User.approval_status == 'APPROVED', User.approval_status.is_(None)))
    elif approval_status != 'ALL':
        query = query.filter(User.approval_status == approval_status)
    if course: query = query.filter_by(course=course)
    if branch and branch != 'null': query = query.filter_by(branch=branch)
    if year: query = query.filter_by(year=year)

    students = query.order_by(User.registration_number).all()
    if not students:
        return jsonify([]), 200

    result = []

    # Optimized: cache total_sessions per unique (course, branch, year) instead of querying per student
    from sqlalchemy import func
    session_count_cache = {}

    # Batch query attendance counts grouped by user_id
    student_ids = [s.id for s in students]
    att_counts = dict(
        db.session.query(Attendance.user_id, func.count(Attendance.id))
        .filter(Attendance.user_id.in_(student_ids))
        .group_by(Attendance.user_id).all()
    )

    for s in students:
        cache_key = (s.course, s.branch, s.year)
        if cache_key not in session_count_cache:
            session_count_cache[cache_key] = Session.query.filter_by(
                course=s.course,
                branch=s.branch,
                year=s.year
            ).count()

        total_sessions = session_count_cache[cache_key]
        attended = att_counts.get(s.id, 0)

        percentage = 0
        if total_sessions > 0:
            percentage = round((attended / total_sessions) * 100, 1)

        s_dict = s.to_dict()
        s_dict['attendancePercentage'] = percentage
        result.append(s_dict)

    return jsonify(result), 200

# 3. NEW: Student Analytics Dashboard (For Student Screen)
@attendance_bp.route('/analytics/dashboard/<student_id>', methods=['GET'])
def get_student_dashboard_stats(student_id):
    student = User.query.get(student_id)
    if not student: return jsonify({"message": "Not found"}), 404

    # 1. Overall Stats
    total_sessions = Session.query.filter_by(
        course=student.course, branch=student.branch, year=student.year
    ).count()
    attended_count = Attendance.query.filter_by(user_id=student_id).count()
    percentage = 0
    if total_sessions > 0:
        percentage = round((attended_count / total_sessions) * 100, 1)

    # 2. Subject Breakdown
    # Get all sessions for this class
    all_sessions = Session.query.filter_by(
        course=student.course, branch=student.branch, year=student.year
    ).all()
    
    # Optimized: build in-memory lookup instead of Session.query.get() per attendance record
    session_by_id = {s.id: s for s in all_sessions}

    # Group by subject
    subjects = {}
    for sess in all_sessions:
        sub = sess.subject
        if sub not in subjects: subjects[sub] = {'total': 0, 'attended': 0}
        subjects[sub]['total'] += 1

    # Count attended using in-memory lookup
    my_attendance = Attendance.query.filter_by(user_id=student_id).all()
    for att in my_attendance:
        sess = session_by_id.get(att.session_id)
        if sess and sess.subject in subjects:
            subjects[sess.subject]['attended'] += 1

    subject_list = []
    for sub, stats in subjects.items():
        if stats['total'] > 0:
            perc = (stats['attended'] / stats['total']) * 100
            subject_list.append({
                'subject': sub,
                'percentage': round(perc, 1),
                'trend': 'Stable' # Simple logic for now
            })

    return jsonify({
        "overallPercentage": percentage,
        "totalClasses": total_sessions,
        "attendedClasses": attended_count,
        "subjects": subject_list
    }), 200
# --- QUICK START ROUTES ---
@attendance_bp.route('/quick-start/<user_id>', methods=['GET'])
def get_quick_starts(user_id):
    tokens = SavedClass.query.filter_by(user_id=user_id).order_by(SavedClass.last_used.desc()).all()
    return jsonify([t.to_dict() for t in tokens]), 200

@attendance_bp.route('/analytics/student-comprehensive/<student_id>', methods=['GET'])
def get_student_comprehensive_stats(student_id):
    student = User.query.get(student_id)
    if not student: return jsonify({"message": "Not found"}), 404

    # 1. Overall Attendance %
    total_sessions = Session.query.filter_by(
        course=student.course, branch=student.branch, year=student.year
    ).count()
    attended_count = Attendance.query.filter_by(user_id=student_id).count()
    overall_percentage = 0
    if total_sessions > 0:
        overall_percentage = round((attended_count / total_sessions) * 100, 1)

    # 2. Risk Calculation
    consistency_status = "Good"
    if overall_percentage < 65: consistency_status = "Critical"
    elif overall_percentage < 75: consistency_status = "Low"
    elif overall_percentage > 90: consistency_status = "Excellent"

    # 3. Subject Breakdown
    all_sessions = Session.query.filter_by(
        course=student.course, branch=student.branch, year=student.year
    ).all()
    
    # Optimized: build in-memory lookup instead of Session.query.get() per attendance record
    session_by_id = {s.id: s for s in all_sessions}

    subject_map = {} # { "Math": {total: 10, attended: 8} }
    
    # Init map with sessions
    for s in all_sessions:
        if s.subject not in subject_map: subject_map[s.subject] = {'total': 0, 'attended': 0}
        subject_map[s.subject]['total'] += 1

    # Fill attended using in-memory lookup
    my_attendance = Attendance.query.filter_by(user_id=student_id).all()
    for att in my_attendance:
        session = session_by_id.get(att.session_id)
        if session and session.subject in subject_map:
            subject_map[session.subject]['attended'] += 1

    subject_list = []
    for sub, data in subject_map.items():
        perc = 0
        if data['total'] > 0:
            perc = round((data['attended'] / data['total']) * 100, 1)
        
        trend_label = "Stable"
        if perc < 50: trend_label = "Falling"
        elif perc > 85: trend_label = "Rising"

        subject_list.append({
            "subject": sub,
            "percentage": perc,
            "trend": trend_label
        })

    # 4. Weekly Activity (Heatmap Data) - Last 7 Days
    # Returns [0.2, 0.5, 1.0, 0.0, ...] intensity for last 7 days
    today = datetime.datetime.now().date()
    weekly_activity = []
    
    for i in range(6, -1, -1): # Last 7 days
        day = today - timedelta(days=i)
        day_str = day.isoformat()
        
        # Count classes attended on this day
        count = 0
        for att in my_attendance:
            if att.check_in_time.startswith(day_str):
                count += 1
        
        # Normalize: Assuming max 4 classes a day = 1.0 intensity
        intensity = min(count / 4.0, 1.0)
        weekly_activity.append(intensity)

    # 5. Trend Graph Data (Last 10 Sessions)
    # 1.0 = Present, 0.0 = Absent/Late
    # We look at the last 10 sessions available for this student's class
    recent_sessions = Session.query.filter_by(
        course=student.course, branch=student.branch, year=student.year
    ).order_by(Session.start_time.desc()).limit(10).all()
    
    # Reverse to show chronological order (Oldest -> Newest)
    recent_sessions.reverse()
    
    trend_points = []
    attended_session_ids = [a.session_id for a in my_attendance]

    if not recent_sessions:
        trend_points = [0.0] * 10 # Flat line if no data
    else:
        for s in recent_sessions:
            if s.id in attended_session_ids:
                trend_points.append(1.0) # Present
            else:
                trend_points.append(0.0) # Absent

    # 6. Consecutive Streak Calculation
    streak = 0
    all_recent_ordered = Session.query.filter_by(
        course=student.course, branch=student.branch, year=student.year
    ).order_by(Session.start_time.desc()).all()

    attended_set = set(attended_session_ids)
    for s in all_recent_ordered:
        if s.id in attended_set:
            streak += 1
        else:
            break

    if streak == 0 and attended_count > 0:
        streak = min(attended_count, 3)

    return jsonify({
        "overallPercentage": overall_percentage,
        "consistency": consistency_status,
        "subjects": subject_list,
        "weeklyActivity": weekly_activity, # List of floats
        "trendPoints": trend_points,       # List of floats
        "totalClasses": total_sessions,
        "attendedClasses": attended_count,
        "streak": streak
    }), 200

@attendance_bp.route('/quick-start', methods=['POST'])
def save_quick_start():
    data = request.json
    user_id = data['userId']

    existing = SavedClass.query.filter_by(
        user_id=user_id,
        course=data.get('course'),
        branch=data.get('branch'),
        year=data.get('year'),
        subject=data['subject']
    ).first()

    if existing:
        existing.last_used = datetime.datetime.utcnow()
        db.session.commit()
        return jsonify(existing.to_dict()), 200

    new_token = SavedClass(
        user_id=user_id,
        course=data.get('course'),
        branch=data.get('branch'),
        year=data.get('year'),
        subject=data['subject']
    )
    db.session.add(new_token)

    all_tokens = SavedClass.query.filter_by(user_id=user_id).order_by(SavedClass.last_used.desc()).all()
    if len(all_tokens) > 5:
        for old_token in all_tokens[5:]:
            db.session.delete(old_token)

    db.session.commit()
    return jsonify(new_token.to_dict()), 201

# --- COUPON ROUTES ---
@attendance_bp.route('/coupons/<user_id>', methods=['GET'])
def get_user_coupons(user_id):
    coupons = Coupon.query.filter_by(user_id=user_id).order_by(Coupon.earned_date.desc()).all()
    return jsonify([c.to_dict() for c in coupons]), 200

@attendance_bp.route('/coupons/use', methods=['POST'])
def use_coupon():
    data = request.json or {}
    coupon_id = data.get('couponId')
    if not coupon_id:
        return jsonify({"message": "couponId is required"}), 400

    coupon = Coupon.query.get(coupon_id)
    if not coupon:
        return jsonify({"message": "Coupon not found"}), 404

    if coupon.is_used:
        return jsonify({"message": "Coupon already used"}), 400

    coupon.is_used = True
    db.session.commit()
    return jsonify({"message": "Coupon redeemed successfully", "coupon": coupon.to_dict()}), 200

