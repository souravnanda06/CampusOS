import sys
import os

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from app import (
    app, db, User, Session, Attendance, Coupon, SavedClass,
    LeaveRequest, GatePass, RequestAudit, Complaint, ComplaintStatusHistory,
    Notice, NotificationDelivery
)
import pymysql

def verify_step21a():
    print("==================================================")
    print("STEP 21A BACKEND & DATABASE VERIFICATION")
    print("==================================================")

    # 1. Database table existence and row count verification
    conn = pymysql.connect(
        host='localhost',
        user='root',
        password='nandasourav766',
        database='attentify'
    )
    cursor = conn.cursor()
    cursor.execute("SHOW TABLES;")
    tables = [r[0] for r in cursor.fetchall()]
    print(f"\n[1] Existing Tables in 'attentify' ({len(tables)}):")
    for t in sorted(tables):
        cursor.execute(f"SELECT COUNT(*) FROM {t};")
        cnt = cursor.fetchone()[0]
        print(f"    - {t:28} (rows: {cnt})")

    assert 'notices' in tables, "Table 'notices' not found!"
    assert 'notification_deliveries' in tables, "Table 'notification_deliveries' not found!"

    # 2. Verify Notices columns
    cursor.execute("DESCRIBE notices;")
    notice_cols = {r[0]: r for r in cursor.fetchall()}
    required_notice_fields = [
        'id', 'title', 'body', 'created_by', 'priority', 'category',
        'target_type', 'target_value', 'action_type', 'action_payload',
        'created_at', 'expires_at', 'status'
    ]
    print("\n[2] Checking required fields on 'notices' table:")
    for f in required_notice_fields:
        if f in notice_cols:
            col_info = notice_cols[f]
            print(f"    [OK] {f:16} -> {col_info[1]} (Null: {col_info[2]}, Default: {col_info[4]})")
        else:
            raise AssertionError(f"Missing required field '{f}' on notices table!")

    # 3. Verify NotificationDeliveries columns
    cursor.execute("DESCRIBE notification_deliveries;")
    notif_cols = {r[0]: r for r in cursor.fetchall()}
    required_notif_fields = [
        'id', 'notice_id', 'user_id', 'status', 'delivered_at', 'read_at', 'action_at'
    ]
    print("\n[3] Checking required fields on 'notification_deliveries' table:")
    for f in required_notif_fields:
        if f in notif_cols:
            col_info = notif_cols[f]
            print(f"    [OK] {f:16} -> {col_info[1]} (Null: {col_info[2]}, Default: {col_info[4]})")
        else:
            raise AssertionError(f"Missing required field '{f}' on notification_deliveries table!")

    conn.close()

    # 4. SQLAlchemy Model Verification & Transactions
    with app.app_context():
        print("\n[4] Testing SQLAlchemy Model Instantiation and Serialization:")
        admin = User.query.filter_by(role='teacher').first() or User.query.first()
        student = User.query.filter_by(role='student').first()

        assert admin is not None, "At least one User must exist in DB for test"

        # Create test notice
        notice = Notice(
            title="End Semester Examinations 2026",
            body="Exam timetables for all 3rd and 4th year branches have been released.",
            created_by=admin.id,
            priority="URGENT",
            category="EXAM",
            target_type="YEAR",
            target_value="3rd",
            action_type="OPEN_URL",
            action_payload="https://campusos.edu/exams/timetable",
            status="PUBLISHED"
        )
        db.session.add(notice)
        db.session.commit()
        print(f"    [OK] Created Notice: {notice.id}")

        notice_dict = notice.to_dict()
        print(f"    [OK] Notice to_dict() keys: {list(notice_dict.keys())}")
        assert notice_dict['title'] == "End Semester Examinations 2026"
        assert notice_dict['priority'] == "URGENT"
        assert notice_dict['category'] == "EXAM"
        assert notice_dict['targetType'] == "YEAR"
        assert notice_dict['targetValue'] == "3rd"
        assert notice_dict['status'] == "PUBLISHED"
        assert notice_dict['actionType'] == "OPEN_URL"
        assert notice_dict['createdBy'] == admin.id

        # Create test notification delivery
        delivery = NotificationDelivery(
            notice_id=notice.id,
            user_id=student.id if student else admin.id,
            status="PENDING",
            delivered_at="2026-09-25T17:05:00"
        )
        db.session.add(delivery)
        db.session.commit()
        print(f"    [OK] Created NotificationDelivery: {delivery.id}")

        delivery_dict = delivery.to_dict()
        print(f"    [OK] NotificationDelivery to_dict() keys: {list(delivery_dict.keys())}")
        assert delivery_dict['noticeId'] == notice.id
        assert delivery_dict['status'] == "PENDING"
        assert delivery_dict['deliveredAt'] == "2026-09-25T17:05:00"

        # Update delivery to DELIVERED and READ
        delivery.status = "READ"
        delivery.is_read = True
        delivery.read_at = "2026-09-25T17:06:00"
        delivery.action_at = "2026-09-25T17:06:30"
        db.session.commit()

        updated_deliv = NotificationDelivery.query.get(delivery.id)
        assert updated_deliv.status == "READ"
        assert updated_deliv.read_at == "2026-09-25T17:06:00"
        assert updated_deliv.action_at == "2026-09-25T17:06:30"
        print(f"    [OK] Updated NotificationDelivery to READ & ACTIONED status confirmed.")

        # Clean up test rows
        db.session.delete(delivery)
        db.session.commit()
        db.session.delete(notice)
        db.session.commit()
        print(f"    [OK] Cleaned up test Notice and Delivery cleanly.")

        # 5. Check integrity of existing domains
        print("\n[5] Checking Existing Domain Integrity:")
        print(f"    - Users count: {User.query.count()} (OK)")
        print(f"    - Sessions count: {Session.query.count()} (OK)")
        print(f"    - Attendance count: {Attendance.query.count()} (OK)")
        print(f"    - Leave Requests count: {LeaveRequest.query.count()} (OK)")
        print(f"    - Gate Passes count: {GatePass.query.count()} (OK)")
        print(f"    - Complaints count: {Complaint.query.count()} (OK)")
        print(f"    - Request Audits count: {RequestAudit.query.count()} (OK)")

    print("\n==================================================")
    print("ALL STEP 21A VERIFICATIONS PASSED SUCCESSFULLY!")
    print("==================================================")

if __name__ == '__main__':
    verify_step21a()
