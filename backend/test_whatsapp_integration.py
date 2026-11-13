import os
import sys
import uuid

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app import app, db, User
from services.whatsapp_service import (
    format_whatsapp_jid,
    extract_phone_digits,
    is_openwa_configured,
    send_gate_exit_alert,
    send_gate_entry_alert,
    send_leave_approval_alert,
    send_attendance_shortage_alert,
    send_fee_due_alert,
    send_visitor_pass_alert
)
from utils.crypto import create_access_token


def run_tests():
    print("==================================================")
    print("CAMPUSOS OPENWA INTEGRATION — UNIT & API TEST SUITE")
    print("==================================================")

    client = app.test_client()
    created_user_ids = []

    try:
        # 1. Test JID standardizer & phone cleaners
        print("[1/5] Testing WhatsApp JID formatting...")
        assert format_whatsapp_jid("9876543210") == "919876543210@c.us"
        assert format_whatsapp_jid("+91 98765-43210") == "919876543210@c.us"
        assert format_whatsapp_jid("09876543210") == "919876543210@c.us"
        assert format_whatsapp_jid("919876543210@c.us") == "919876543210@c.us"
        assert format_whatsapp_jid(None) is None
        assert format_whatsapp_jid("") is None
        assert extract_phone_digits("919876543210@c.us") == "919876543210"
        print("  -> JID formatting tests passed.")

        # 2. Test WhatsApp Status Endpoint
        print("[2/5] Testing /whatsapp/status endpoint...")
        res = client.get("/whatsapp/status")
        assert res.status_code == 200, res.get_json()
        data = res.get_json()
        assert data["status"] == "operational"
        assert "gatewayUrl" in data
        assert "sessionId" in data
        print("  -> WhatsApp status endpoint responded 200 OK.")

        # 3. Test Student Registration with Phone & Parent Phone
        print("[3/5] Testing student registration with contact fields...")
        with app.app_context():
            unique_hex = uuid.uuid4().hex[:6]
            test_student = User(
                id=f"test_wa_student_{unique_hex}",
                email=f"wa_student_{unique_hex}@campusos.test",
                password="hashed_pw_test",
                name=f"Rahul Sharma {unique_hex}",
                role="student",
                registration_number=f"REG-{unique_hex.upper()}",
                phone="9876543210",
                parent_phone="9123456789",
                parent_name="Ramesh Sharma",
                approval_status="APPROVED"
            )
            db.session.add(test_student)
            db.session.commit()
            created_user_ids.append(test_student.id)

            fetched = User.query.get(test_student.id)
            assert fetched.phone == "9876543210"
            assert fetched.parent_phone == "9123456789"
            assert fetched.parent_name == "Ramesh Sharma"

            user_dict = fetched.to_dict()
            assert user_dict["phone"] == "9876543210"
            assert user_dict["parentPhone"] == "9123456789"
            assert user_dict["parentName"] == "Ramesh Sharma"
            print("  -> Model fields & to_dict mapping passed.")

        # 4. Test Profile Contact Update Endpoint
        print("[4/5] Testing /auth/profile update endpoint...")
        with app.app_context():
            token = create_access_token(test_student)
        
        update_res = client.put(
            "/auth/profile",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "phone": "+91 9998887776",
                "parentPhone": "+91 8887776665",
                "parentName": "Sunita Sharma"
            }
        )
        assert update_res.status_code == 200, update_res.get_json()
        with app.app_context():
            re_fetched = User.query.get(test_student.id)
            assert re_fetched.phone == "+91 9998887776"
            assert re_fetched.parent_phone == "+91 8887776665"
            assert re_fetched.parent_name == "Sunita Sharma"
        print("  -> Profile contact update passed.")

        # 5. Test OpenWA Inbound Webhook Handling
        print("[5/5] Testing inbound webhook routing...")
        # 5a. Unrecognized sender phone
        webhook_res1 = client.post(
            "/whatsapp/webhook",
            json={
                "event": "message.received",
                "data": {
                    "chatId": "910000000000@c.us",
                    "body": "Hello who is this?"
                }
            }
        )
        assert webhook_res1.status_code == 200, webhook_res1.get_json()
        assert webhook_res1.get_json()["status"] == "unrecognized_phone_prompted"

        # 5b. Registered parent asking for gatepass / attendance
        parent_digits = "918887776665"
        webhook_res2 = client.post(
            "/whatsapp/webhook",
            json={
                "event": "message.received",
                "data": {
                    "chatId": f"{parent_digits}@c.us",
                    "body": "gatepass status please"
                }
            }
        )
        assert webhook_res2.status_code == 200, webhook_res2.get_json()
        assert webhook_res2.get_json()["status"] == "parent_inquiry_handled"

        # 5c. Outbound message ignored
        webhook_res3 = client.post(
            "/whatsapp/webhook",
            json={
                "event": "message.received",
                "data": {
                    "chatId": f"{parent_digits}@c.us",
                    "body": "Automated message from me",
                    "fromMe": True
                }
            }
        )
        assert webhook_res3.status_code == 200, webhook_res3.get_json()
        assert webhook_res3.get_json()["status"] == "ignored_outbound"

        # 5d. Template execution sanity check (non-blocking async)
        send_gate_exit_alert("918887776665", "Rahul", "REG-01", "Main Gate", "2026-11-12T22:00:00")
        send_gate_entry_alert("918887776665", "Rahul", "REG-01", "Main Gate", "2026-11-12T22:30:00")
        send_leave_approval_alert("918887776665", "Rahul", "Family visit", "2026-11-13", "2026-11-15")
        send_attendance_shortage_alert("918887776665", "Rahul", "Data Structures", 68.5, 20, 29)
        send_fee_due_alert("918887776665", "Rahul", "Semester 5 Tuition", 35000.0, "2026-11-30")
        send_visitor_pass_alert("918887776665", "Ramesh", "VP-TEST123", "Rahul", "2026-11-13")
        print("  -> Inbound webhook & async templates passed.")

        print("\nALL OPENWA WHATSAPP INTEGRATION TESTS PASSED SUCCESSFULLY!")

    finally:
        # Cleanup test entities
        with app.app_context():
            for uid in created_user_ids:
                u = User.query.get(uid)
                if u:
                    db.session.delete(u)
            db.session.commit()


if __name__ == "__main__":
    run_tests()
