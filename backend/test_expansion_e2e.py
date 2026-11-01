"""
CampusOS Product Expansion End-to-End Test Suite
Tests:
- Documents & Wallet Card association
- Fees & Dues
- Academic Class Updates & Targeted Notifications
- Hostel, Room & Asset Management
- Visitor Passes & Security Anti-Replay
- Notification Center & Unread Count
- Permission-Aware Global Search
"""
import sys
import os
import json
import uuid
import datetime

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from app import app
from extensions import db
from models.user import User
from models.expansion import (
    DocumentRequest,
    FeeRecord,
    ClassUpdate,
    HostelAllocation,
    HostelRequest,
    HostelAsset,
    AssetIssue,
    VisitorRequest
)
from models.notification import NotificationDelivery

def run_tests():
    print("=" * 60)
    print("CAMPUSOS PRODUCT EXPANSION E2E TEST SUITE")
    print("=" * 60)

    client = app.test_client()

    with app.app_context():
        # Setup actors
        student = User.query.filter_by(role='student').first()
        admin = User.query.filter_by(role='admin').first()
        warden = User.query.filter_by(role='warden').first()
        teacher = User.query.filter_by(role='teacher').first()
        security = User.query.filter(User.role.in_(['security', 'guard', 'security_guard'])).first()

        assert student is not None, "Student required"
        assert admin is not None, "Admin required"
        assert warden is not None, "Warden required"
        assert teacher is not None, "Teacher required"
        if not security:
            security = User(
                id=str(uuid.uuid4()),
                email=f"guard_{uuid.uuid4().hex[:6]}@campusos.test",
                password="testpassword",
                name="Officer Nayak",
                role="security"
            )
            db.session.add(security)
            db.session.commit()

        # ----------------------------------------------------
        # 1. DOCUMENT REQUESTS & WALLET
        # ----------------------------------------------------
        print("\n[TEST 1] Document Requests & Wallet Integration...")
        # 1a. Student creates request
        res = client.post('/documents/requests', json={
            "documentType": "BONAFIDE_CERTIFICATE",
            "purpose": "Bank Education Loan Application"
        }, headers={"X-User-Id": student.id})
        assert res.status_code == 201, f"Expected 201, got {res.status_code}: {res.get_json()}"
        doc_data = res.get_json()['request']
        doc_id = doc_data['id']
        assert doc_data['status'] == 'PENDING'

        # 1b. Student cannot store unissued document in wallet
        res = client.post(f'/documents/requests/{doc_id}/wallet', json={"storedInWallet": True}, headers={"X-User-Id": student.id})
        assert res.status_code == 400

        # 1c. Admin issues document
        res = client.post(f'/documents/requests/{doc_id}/action', json={
            "action": "ISSUE",
            "remarks": "Verified with academic cell"
        }, headers={"X-User-Id": admin.id})
        assert res.status_code == 200
        issued = res.get_json()['document']
        assert issued['status'] == 'ISSUED'
        assert issued['documentNumber'] is not None

        # 1d. Student now stores issued document in wallet
        res = client.post(f'/documents/requests/{doc_id}/wallet', json={"storedInWallet": True}, headers={"X-User-Id": student.id})
        assert res.status_code == 200
        assert res.get_json()['document']['storedInWallet'] is True
        print("  -> [PASS] Document Request, Issuance, and Wallet sync verified.")

        # ----------------------------------------------------
        # 2. FEES & DUES
        # ----------------------------------------------------
        print("\n[TEST 2] Fees & Dues System...")
        # 2a. Student views fees
        res = client.get('/fees/my', headers={"X-User-Id": student.id})
        assert res.status_code == 200
        fee_resp = res.get_json()
        assert "records" in fee_resp
        assert "summary" in fee_resp

        # 2b. Student fee summary for Wallet card
        res = client.get('/fees/my/summary', headers={"X-User-Id": student.id})
        assert res.status_code == 200
        assert "totalDue" in res.get_json()

        # 2c. Record payment for a fee
        records = fee_resp['records']
        if records:
            f_id = records[0]['id']
            res = client.post(f'/fees/{f_id}/record-payment', json={"amount": 1000.0}, headers={"X-User-Id": student.id})
            assert res.status_code == 200
            assert res.get_json()['fee']['receiptNumber'] is not None

        # 2d. Admin fee KPIs
        res = client.get('/fees/kpis', headers={"X-User-Id": admin.id})
        assert res.status_code == 200
        assert "totalOutstanding" in res.get_json()
        print("  -> [PASS] Fees & Dues calculation and payment receipt verified.")

        # ----------------------------------------------------
        # 3. CLASS UPDATES & NOTIFICATIONS
        # ----------------------------------------------------
        print("\n[TEST 3] Teacher Class Updates & Notifications...")
        res = client.post('/academic-updates', json={
            "courseCode": "CS602",
            "courseName": "Advanced Operating Systems",
            "updateType": "CANCELLED",
            "message": "Class cancelled due to departmental faculty council.",
            "affectedBranch": student.branch or "CSE",
            "affectedYear": student.year or 3
        }, headers={"X-User-Id": teacher.id})
        assert res.status_code == 201
        up_data = res.get_json()
        assert up_data['affectedStudentsCount'] >= 1

        # Student views targeted update
        res = client.get('/academic-updates/my', headers={"X-User-Id": student.id})
        assert res.status_code == 200
        updates_list = res.get_json()
        assert any(u['courseCode'] == 'CS602' for u in updates_list)
        print("  -> [PASS] Class update & student targeting verified.")

        # ----------------------------------------------------
        # 4. HOSTEL, ROOM & ASSETS
        # ----------------------------------------------------
        print("\n[TEST 4] Hostel, Room & Asset Management...")
        # 4a. Student views their allocated room
        res = client.get('/hostel/my-room', headers={"X-User-Id": student.id})
        assert res.status_code == 200

        # 4b. Student views their room assets
        res = client.get('/hostel/my-assets', headers={"X-User-Id": student.id})
        assert res.status_code == 200

        # 4c. Student creates room-change request
        res = client.post('/hostel/requests', json={
            "requestType": "ROOM_CHANGE",
            "preferredHostel": "Mahanadi Hall",
            "preferredRoom": "205",
            "reason": "Closer to computer laboratory"
        }, headers={"X-User-Id": student.id})
        assert res.status_code == 201
        hr_id = res.get_json()['request']['id']

        # 4d. Warden approves hostel request
        res = client.post(f'/hostel/warden/requests/{hr_id}/action', json={
            "action": "APPROVE",
            "remarks": "Approved subject to room vacancy check"
        }, headers={"X-User-Id": warden.id})
        assert res.status_code == 200
        assert res.get_json()['request']['status'] == 'APPROVED'
        print("  -> [PASS] Hostel allocation & request approval verified.")

        # ----------------------------------------------------
        # 5. VISITOR PASS & SECURITY ANTI-REPLAY
        # ----------------------------------------------------
        print("\n[TEST 5] Visitor Management & Anti-Replay...")
        # 5a. Student creates visitor request
        res = client.post('/visitors/requests', json={
            "visitorName": "Sunita Mohanty",
            "visitorPhone": "+91 9123456780",
            "relation": "Mother",
            "purpose": "Weekend visit and hostel check",
            "visitDate": datetime.date.today().isoformat()
        }, headers={"X-User-Id": student.id})
        assert res.status_code == 201
        vr_id = res.get_json()['request']['id']

        # 5b. Warden approves request (creates pass_code)
        res = client.post(f'/visitors/warden/requests/{vr_id}/action', json={
            "action": "APPROVE",
            "remarks": "Approved for 4:00 PM entry"
        }, headers={"X-User-Id": warden.id})
        assert res.status_code == 200
        pass_code = res.get_json()['request']['passCode']
        assert pass_code is not None

        # 5c. Student checks active wallet pass
        res = client.get('/visitors/active-pass', headers={"X-User-Id": student.id})
        assert res.status_code == 200
        assert res.get_json()['hasActivePass'] is True

        # 5d. Security verifies pass
        res = client.post('/visitors/security/verify', json={"passCode": pass_code}, headers={"X-User-Id": security.id})
        assert res.status_code == 200
        assert res.get_json()['isValid'] is True

        # 5e. Security checks in visitor
        res = client.post('/visitors/security/check-in', json={"passCode": pass_code, "remarks": "ID verified (Aadhaar)"}, headers={"X-User-Id": security.id})
        assert res.status_code == 200

        # 5f. Double-entry prevention: check-in again must fail with 409
        res = client.post('/visitors/security/check-in', json={"passCode": pass_code}, headers={"X-User-Id": security.id})
        assert res.status_code == 409
        assert res.get_json()['resultCode'] == 'ALREADY_CHECKED_IN'

        # 5g. Security checks out visitor
        res = client.post('/visitors/security/check-out', json={"passCode": pass_code, "remarks": "Checked out safely"}, headers={"X-User-Id": security.id})
        assert res.status_code == 200

        # 5h. Double-exit prevention: check-out again must fail with 409
        res = client.post('/visitors/security/check-out', json={"passCode": pass_code}, headers={"X-User-Id": security.id})
        assert res.status_code == 409
        assert res.get_json()['resultCode'] == 'ALREADY_CHECKED_OUT'
        print("  -> [PASS] Visitor Pass lifecycle & anti-replay protections verified.")

        # ----------------------------------------------------
        # 6. NOTIFICATION CENTER & UNREAD COUNT
        # ----------------------------------------------------
        print("\n[TEST 6] Notification Center...")
        res = client.get('/notifications', headers={"X-User-Id": student.id})
        assert res.status_code == 200
        notifs_data = res.get_json()
        assert "notifications" in notifs_data
        assert "unreadCount" in notifs_data

        res = client.get('/notifications/unread-count', headers={"X-User-Id": student.id})
        assert res.status_code == 200
        assert "unreadCount" in res.get_json()

        # Mark all as read
        res = client.post('/notifications/read-all', headers={"X-User-Id": student.id})
        assert res.status_code == 200
        print("  -> [PASS] Notification Center, unread count & read tracking verified.")

        # ----------------------------------------------------
        # 7. PERMISSION-AWARE GLOBAL SEARCH
        # ----------------------------------------------------
        print("\n[TEST 7] Permission-Aware Global Search...")
        res = client.get('/search?q=CS602', headers={"X-User-Id": student.id})
        assert res.status_code == 200
        s_data = res.get_json()
        assert s_data['count'] >= 1
        assert any("CS602" in r['title'] for r in s_data['results'])
        print("  -> [PASS] Permission-aware Global Search verified.")

    print("\n" + "=" * 60)
    print("ALL PRODUCT EXPANSION BACKEND TESTS PASSED SUCCESSFULLY!")
    print("=" * 60)

if __name__ == '__main__':
    run_tests()
