"""
CampusOS Phase 4: Offline Session Reconciliation and Idempotency Tests.
"""

import os
import sys
import uuid
import datetime

sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))
from app import app, db, User, Session

def run_tests():
    print("=" * 60)
    print("CAMPUSOS PHASE 4: SESSION RECONCILIATION & IDEMPOTENCY TESTS")
    print("=" * 60)

    client = app.test_client()

    with app.app_context():
        # Setup temporary test teacher
        test_teacher = User.query.filter_by(role='teacher').first()
        if not test_teacher:
            test_teacher = User(name="Faculty Reconcile", email="fac.rec@campusos.edu", role="teacher")
            db.session.add(test_teacher)
            db.session.commit()

        # TEST 1: Standard session creation without idempotency key
        print("\n[TEST 1] Standard session creation without idempotency key...")
        res1 = client.post('/sessions/create', json={
            "name": "Standard Session",
            "instructorName": test_teacher.name,
            "course": "B.Tech",
            "branch": "CSE",
            "year": "3rd Year",
            "location": "Room 101"
        })
        assert res1.status_code == 201, f"Expected 201, got {res1.status_code}: {res1.data}"
        data1 = res1.get_json()
        assert data1["name"] == "Standard Session"
        assert "id" in data1
        print("[PASS] [TEST 1] Standard session created successfully.")

        # TEST 2: Reconciling offline session with clientSessionId / idempotencyKey
        print("\n[TEST 2] Offline session reconciliation with clientSessionId...")
        client_sess_id = f"sess_local_{int(datetime.datetime.now().timestamp())}_99999"
        res2 = client.post('/sessions/reconcile', json={
            "localId": client_sess_id,
            "idempotencyKey": client_sess_id,
            "name": "Offline Reconciled Class",
            "instructorName": test_teacher.name,
            "course": "B.Tech",
            "branch": "CSE",
            "year": "3rd Year",
            "location": "Lab 4B"
        })
        assert res2.status_code == 201, f"Expected 201, got {res2.status_code}: {res2.data}"
        data2 = res2.get_json()
        server_id_2 = data2["id"]
        assert data2["idempotencyKey"] == client_sess_id
        print(f"[PASS] [TEST 2] Offline session reconciled with server ID: {server_id_2}")

        # TEST 3: Retrying reconciliation with identical idempotencyKey returns 200 with same server ID
        print("\n[TEST 3] Retrying reconciliation with identical idempotencyKey (idempotency check)...")
        res3 = client.post('/sessions/reconcile', json={
            "localId": client_sess_id,
            "idempotencyKey": client_sess_id,
            "name": "Offline Reconciled Class",
            "instructorName": test_teacher.name,
            "course": "B.Tech",
            "branch": "CSE",
            "year": "3rd Year",
            "location": "Lab 4B"
        })
        assert res3.status_code == 200, f"Expected 200, got {res3.status_code}: {res3.data}"
        data3 = res3.get_json()
        assert data3["id"] == server_id_2, f"Expected server ID {server_id_2}, got {data3['id']}"
        print(f"[PASS] [TEST 3] Re-reconciliation is strictly idempotent: {data3['id']} == {server_id_2}")

        # Cleanup
        try:
            Session.query.filter(Session.id.in_([data1["id"], server_id_2])).delete()
            db.session.commit()
            print("\n[CLEANUP] Phase 4 test sessions cleaned up.")
        except Exception as e:
            db.session.rollback()
            print(f"[CLEANUP ERROR] {e}")

    print("=" * 60)
    print("ALL PHASE 4 BACKEND RECONCILIATION TESTS PASSED!")
    print("=" * 60)

if __name__ == '__main__':
    run_tests()
