import os
import uuid
import datetime
from app import app, db, User, LeaveRequest, GatePass, RequestAudit

def test_warden_backend_endpoints():
    client = app.test_client()

    with app.app_context():
        # Setup test users
        suffix = uuid.uuid4().hex[:6]
        warden = User(
            name=f"Warden Dr. Jena_{suffix}",
            email=f"warden_{suffix}@campusos.edu",
            password="password123",
            role="warden"
        )
        student = User(
            name=f"Student Amit_{suffix}",
            email=f"student_{suffix}@campusos.edu",
            password="password123",
            role="student",
            registration_number=f"REG_{suffix}",
            course="B.Tech",
            branch="Computer Science",
            year=3
        )
        teacher = User(
            name=f"Prof. Sharma_{suffix}",
            email=f"prof_{suffix}@campusos.edu",
            password="password123",
            role="teacher"
        )
        security = User(
            name=f"Guard Bahadur_{suffix}",
            email=f"guard_{suffix}@campusos.edu",
            password="password123",
            role="security"
        )
        db.session.add_all([warden, student, teacher, security])
        db.session.commit()

        # Create a pending leave request
        leave = LeaveRequest(
            student_id=student.id,
            leave_type="OUTING",
            start_date="2026-09-28",
            end_date="2026-09-29",
            reason="Visiting family for festival",
            destination="Bhubaneswar",
            status="PENDING"
        )
        db.session.add(leave)
        db.session.commit()

        print("[TEST 1] Role Authorization on /warden/summary...")
        # Unauthenticated
        res = client.get('/warden/summary')
        assert res.status_code == 401, f"Expected 401, got {res.status_code}"
        # Student unauthorized
        res = client.get('/warden/summary', headers={'X-User-Id': student.id})
        assert res.status_code == 403, f"Expected 403 for student, got {res.status_code}"
        # Teacher unauthorized
        res = client.get('/warden/summary', headers={'X-User-Id': teacher.id})
        assert res.status_code == 403, f"Expected 403 for teacher, got {res.status_code}"
        # Security unauthorized
        res = client.get('/warden/summary', headers={'X-User-Id': security.id})
        assert res.status_code == 403, f"Expected 403 for security, got {res.status_code}"
        # Warden authorized
        res = client.get('/warden/summary', headers={'X-User-Id': warden.id})
        assert res.status_code == 200, f"Expected 200 for warden, got {res.status_code}"
        data = res.get_json()
        assert "pendingRequests" in data
        assert "approvedToday" in data
        assert "activeGatePasses" in data
        assert "recentActivityCount" in data
        assert "pendingPreview" in data
        print("  -> Passed: /warden/summary strictly enforces Warden/Admin role.")

        print("[TEST 2] /warden/leave-requests endpoint...")
        # Student blocked
        res = client.get('/warden/leave-requests', headers={'X-User-Id': student.id})
        assert res.status_code == 403
        # Warden allowed
        res = client.get('/warden/leave-requests?status=PENDING', headers={'X-User-Id': warden.id})
        assert res.status_code == 200
        reqs = res.get_json()
        assert len(reqs) >= 1
        found = any(r['id'] == leave.id for r in reqs)
        assert found, "Leave request not found in pending list"
        first = next(r for r in reqs if r['id'] == leave.id)
        assert first['studentName'] == student.name
        assert first['registrationNumber'] == student.registration_number
        print("  -> Passed: /warden/leave-requests returns student metadata.")

        print("[TEST 3] /warden/leave-requests/<id> detail...")
        res = client.get(f'/warden/leave-requests/{leave.id}', headers={'X-User-Id': warden.id})
        assert res.status_code == 200
        detail = res.get_json()
        assert detail['id'] == leave.id
        assert detail['studentName'] == student.name
        assert detail['branch'] == "Computer Science"
        print("  -> Passed: /warden/leave-requests/<id> returned detailed student profile.")

        print("[TEST 4] /warden/leave-requests/<id>/action (Approve) & Gate Pass integration...")
        res = client.post(
            f'/warden/leave-requests/{leave.id}/action',
            headers={'X-User-Id': warden.id},
            json={'action': 'APPROVE', 'remarks': 'Approved by Warden'}
        )
        assert res.status_code == 200
        act_res = res.get_json()
        assert act_res['request']['status'] == 'APPROVED'
        print("  -> Passed: Leave request approved successfully.")

        print("[TEST 5] /warden/activity endpoint...")
        res = client.get('/warden/activity', headers={'X-User-Id': warden.id})
        assert res.status_code == 200
        acts = res.get_json()
        assert len(acts) >= 1
        assert any(a['entityId'] == leave.id and a['action'] == 'APPROVE' for a in acts)
        print("  -> Passed: /warden/activity records and serves audit trail.")

        # Cleanup test records
        RequestAudit.query.filter_by(entity_id=leave.id).delete()
        LeaveRequest.query.filter_by(id=leave.id).delete()
        User.query.filter(User.id.in_([warden.id, student.id, teacher.id, security.id])).delete()
        db.session.commit()
        print("All Warden backend endpoint tests passed successfully!")

if __name__ == '__main__':
    test_warden_backend_endpoints()
