import sys
import os
import json
import datetime
import uuid

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from app import (
    app, db, User, Session, Attendance, LeaveRequest, GatePass,
    RequestAudit, Complaint, ComplaintStatusHistory, Notice, NotificationDelivery,
    DeviceToken, MessMenu, MessMeal, MessFeedback
)

def run_step22e_tests():
    print("==================================================")
    print("CAMPUSOS STEP 22E — MESS INTEGRATION & HARDENING TEST SUITE")
    print("==================================================")

    client = app.test_client()
    created_menu_ids = []
    created_user_ids = []
    created_feedback_ids = []

    # Record baseline counts of all tables
    baseline_counts = {}
    with app.app_context():
        baseline_counts = {
            'users': User.query.count(),
            'sessions': Session.query.count(),
            'attendance': Attendance.query.count(),
            'leave_requests': LeaveRequest.query.count(),
            'gate_passes': GatePass.query.count(),
            'complaints': Complaint.query.count(),
            'complaint_status_history': ComplaintStatusHistory.query.count(),
            'request_audits': RequestAudit.query.count(),
            'notices': Notice.query.count(),
            'notification_deliveries': NotificationDelivery.query.count(),
            'device_tokens': DeviceToken.query.count(),
            'mess_menus': MessMenu.query.count(),
            'mess_meals': MessMeal.query.count(),
            'mess_feedback': MessFeedback.query.count(),
        }
        print(f"[OK] Baseline database table counts recorded: {baseline_counts}")

        # Fixtures: Admin, Student 1, Student 2, Teacher
        admin = User.query.filter_by(role='admin').first()
        if not admin:
            admin = User(
                id=str(uuid.uuid4()),
                email=f"admin_22e_{uuid.uuid4().hex[:6]}@campusos.test",
                password="password",
                name="Mess Admin 22E",
                role="admin"
            )
            db.session.add(admin)
            db.session.commit()
            created_user_ids.append(admin.id)

        student1 = User.query.filter_by(role='student').first()
        if not student1:
            student1 = User(
                id=str(uuid.uuid4()),
                email=f"student1_22e_{uuid.uuid4().hex[:6]}@campusos.test",
                password="password",
                name="Student One 22E",
                role="student"
            )
            db.session.add(student1)
            db.session.commit()
            created_user_ids.append(student1.id)

        student2 = User(
            id=str(uuid.uuid4()),
            email=f"student2_22e_{uuid.uuid4().hex[:6]}@campusos.test",
            password="password",
            name="Student Two 22E",
            role="student"
        )
        db.session.add(student2)
        db.session.commit()
        created_user_ids.append(student2.id)

        teacher = User.query.filter_by(role='teacher').first()
        if not teacher:
            teacher = User(
                id=str(uuid.uuid4()),
                email=f"teacher_22e_{uuid.uuid4().hex[:6]}@campusos.test",
                password="password",
                name="Teacher 22E",
                role="teacher"
            )
            db.session.add(teacher)
            db.session.commit()
            created_user_ids.append(teacher.id)

        admin_id = admin.id
        student1_id = student1.id
        student2_id = student2.id
        teacher_id = teacher.id

    try:
        # ----------------------------------------------------
        # Test 1: Draft -> Publish Lifecycle
        # ----------------------------------------------------
        print("\n--- Test 1: Draft -> Publish Lifecycle ---")
        date_str = "2026-11-20"
        draft_payload = {
            "menuDate": date_str,
            "status": "DRAFT",
            "meals": [
                {
                    "mealType": "BREAKFAST",
                    "title": "Aloo Paratha & Curd",
                    "description": "Hot parathas",
                    "items": ["Paratha", "Curd", "Pickle"],
                    "availability": "AVAILABLE"
                },
                {
                    "mealType": "LUNCH",
                    "title": "North Indian Thali",
                    "description": "Nutritious lunch",
                    "items": ["Rice", "Dal Makhani", "Paneer", "Roti"],
                    "availability": "AVAILABLE"
                }
            ]
        }
        res = client.post(
            "/mess/menus",
            headers={"X-User-Id": admin_id},
            json=draft_payload
        )
        assert res.status_code == 201, f"Expected 201, got {res.status_code}: {res.data}"
        data = res.get_json()
        menu_id = data["id"]
        created_menu_ids.append(menu_id)
        assert data["status"] == "DRAFT"
        breakfast_id = [m["id"] for m in data["meals"] if m["mealType"] == "BREAKFAST"][0]
        lunch_id = [m["id"] for m in data["meals"] if m["mealType"] == "LUNCH"][0]
        print(f"[PASS] Test 1A: Staff created DRAFT menu ({menu_id}).")

        # Publish the menu
        pub_res = client.post(f"/mess/menus/{menu_id}/publish", headers={"X-User-Id": admin_id})
        assert pub_res.status_code == 200, f"Expected 200, got {pub_res.status_code}: {pub_res.data}"
        pub_data = pub_res.get_json()
        assert pub_data["status"] == "PUBLISHED"
        print("[PASS] Test 1B: Staff transitioned DRAFT -> PUBLISHED successfully.")

        # ----------------------------------------------------
        # Test 2: Published Menu Visible to Student
        # ----------------------------------------------------
        print("\n--- Test 2: Published Menu Visible to Student ---")
        s_res = client.get(f"/mess/menus?date={date_str}", headers={"X-User-Id": student1_id})
        assert s_res.status_code == 200
        s_menus = s_res.get_json()
        assert len(s_menus) == 1
        assert s_menus[0]["id"] == menu_id
        assert s_menus[0]["status"] == "PUBLISHED"
        assert len(s_menus[0]["meals"]) == 2
        print("[PASS] Test 2: Student can query and see published menu.")

        # ----------------------------------------------------
        # Test 3: Draft Hidden from Student
        # ----------------------------------------------------
        print("\n--- Test 3: Draft Hidden from Student ---")
        draft_date = "2026-11-21"
        draft2_res = client.post(
            "/mess/menus",
            headers={"X-User-Id": admin_id},
            json={
                "menuDate": draft_date,
                "status": "DRAFT",
                "meals": [{"mealType": "DINNER", "title": "Secret Draft Dinner", "items": ["Soup"]}]
            }
        )
        assert draft2_res.status_code == 201
        draft2_id = draft2_res.get_json()["id"]
        created_menu_ids.append(draft2_id)

        # Student queries for the draft date
        s_draft_res = client.get(f"/mess/menus?date={draft_date}", headers={"X-User-Id": student1_id})
        assert s_draft_res.status_code == 200
        assert len(s_draft_res.get_json()) == 0, "Draft menu must never appear in student feed!"

        # Direct student lookup of draft menu ID must also return 404
        s_direct_res = client.get(f"/mess/menus/{draft2_id}", headers={"X-User-Id": student1_id})
        assert s_direct_res.status_code == 404, "Direct lookup of draft by student must return 404!"
        print("[PASS] Test 3: DRAFT menus are strictly hidden from students (in listing & direct ID lookup).")

        # ----------------------------------------------------
        # Test 4: Duplicate Published Date Rejection (409 Conflict)
        # ----------------------------------------------------
        print("\n--- Test 4: Duplicate Published Date Rejection (409) ---")
        dup_pub_res = client.post(
            "/mess/menus",
            headers={"X-User-Id": admin_id},
            json={
                "menuDate": date_str, # Same date as menu 1 which is PUBLISHED
                "status": "PUBLISHED",
                "meals": [{"mealType": "BREAKFAST", "title": "Conflicting Breakfast", "items": ["Toast"]}]
            }
        )
        assert dup_pub_res.status_code == 409, f"Expected 409, got {dup_pub_res.status_code}"
        msg = dup_pub_res.get_json().get("message", "") or dup_pub_res.get_json().get("error", "")
        assert "already exists" in msg.lower(), f"Expected 'already exists' in error message, got: {msg}"
        print("[PASS] Test 4: Duplicate published menu on same date rejected with 409 Conflict.")

        # ----------------------------------------------------
        # Test 5: Feedback on Valid Published Meal
        # ----------------------------------------------------
        print("\n--- Test 5: Feedback on Valid Published Meal ---")
        fb_res = client.post(
            "/mess/feedback",
            headers={"X-User-Id": student1_id},
            json={
                "menuId": menu_id,
                "mealId": breakfast_id,
                "rating": 5,
                "category": "TASTE",
                "comment": "Crispy and fresh parathas!"
            }
        )
        assert fb_res.status_code == 201, f"Expected 201, got {fb_res.status_code}: {fb_res.data}"
        fb_data = fb_res.get_json()
        fb1_id = fb_data["id"]
        created_feedback_ids.append(fb1_id)
        assert fb_data["rating"] == 5
        assert fb_data["category"] == "TASTE"
        print("[PASS] Test 5: Student 1 submitted valid feedback on published breakfast.")

        # ----------------------------------------------------
        # Test 6: Feedback Ownership & Duplicate Prevention
        # ----------------------------------------------------
        print("\n--- Test 6: Feedback Ownership & Duplicate Prevention ---")
        # Duplicate submission by same student on same meal -> 409
        dup_fb_res = client.post(
            "/mess/feedback",
            headers={"X-User-Id": student1_id},
            json={
                "menuId": menu_id,
                "mealId": breakfast_id,
                "rating": 4,
                "comment": "Trying to rate twice"
            }
        )
        assert dup_fb_res.status_code == 409, f"Expected 409 duplicate rating, got {dup_fb_res.status_code}"

        # Student 2 cannot update Student 1's feedback
        s2_edit_res = client.put(
            f"/mess/feedback/{fb1_id}",
            headers={"X-User-Id": student2_id},
            json={"rating": 1}
        )
        assert s2_edit_res.status_code == 403, f"Expected 403 unauthorized edit, got {s2_edit_res.status_code}"
        print("[PASS] Test 6: Duplicate rating rejected (409) and cross-student edit blocked (403).")

        # ----------------------------------------------------
        # Test 7: Feedback Update by Owner
        # ----------------------------------------------------
        print("\n--- Test 7: Feedback Update by Owner ---")
        s1_update_res = client.put(
            f"/mess/feedback/{fb1_id}",
            headers={"X-User-Id": student1_id},
            json={
                "rating": 4,
                "category": "FOOD_QUALITY",
                "comment": "Good quality, updated rating."
            }
        )
        assert s1_update_res.status_code == 200
        updated_fb = s1_update_res.get_json()
        assert updated_fb["rating"] == 4
        assert updated_fb["category"] == "FOOD_QUALITY"

        # Check /mess/feedback/my reflects updated feedback
        my_fb_res = client.get(f"/mess/feedback/my?menuId={menu_id}", headers={"X-User-Id": student1_id})
        assert my_fb_res.status_code == 200
        my_fbs = my_fb_res.get_json()
        assert len(my_fbs) == 1
        assert my_fbs[0]["rating"] == 4
        print("[PASS] Test 7: Student successfully updated feedback and /mess/feedback/my returns updated state.")

        # Student 2 also submits feedback on lunch
        s2_fb_res = client.post(
            "/mess/feedback",
            headers={"X-User-Id": student2_id},
            json={
                "menuId": menu_id,
                "mealId": lunch_id,
                "rating": 2,
                "category": "PORTION",
                "comment": "Portion size was small"
            }
        )
        assert s2_fb_res.status_code == 201
        created_feedback_ids.append(s2_fb_res.get_json()["id"])

        # ----------------------------------------------------
        # Test 8: Invalid Meal / Menu Relationship Rejected
        # ----------------------------------------------------
        print("\n--- Test 8: Invalid Meal / Menu Relationship Rejected ---")
        # Meal ID belongs to menu_id, but we specify draft2_id as the menuId
        mismatch_res = client.post(
            "/mess/feedback",
            headers={"X-User-Id": student1_id},
            json={
                "menuId": draft2_id,
                "mealId": breakfast_id,
                "rating": 3
            }
        )
        assert mismatch_res.status_code in (400, 404), f"Expected 400 or 404 for meal mismatch, got {mismatch_res.status_code}"
        print("[PASS] Test 8: Mismatched meal/menu relationship rejected.")

        # ----------------------------------------------------
        # Test 9: Feedback Analytics Reflects Real Feedback
        # ----------------------------------------------------
        print("\n--- Test 9: Feedback Analytics Reflects Real Feedback ---")
        sum_res = client.get(f"/mess/admin/feedback/summary?startDate={date_str}&endDate={date_str}", headers={"X-User-Id": admin_id})
        assert sum_res.status_code == 200
        summary = sum_res.get_json()
        assert summary["totalRatings"] == 2
        # Ratings: 4 (breakfast) and 2 (lunch) -> avg = 3.0
        assert summary["averageRating"] == 3.0
        assert summary["ratingDistribution"]["4"] == 1
        assert summary["ratingDistribution"]["2"] == 1
        print(f"[PASS] Test 9: Analytics summary accurately computed: totalRatings={summary['totalRatings']}, avg={summary['averageRating']}.")

        # ----------------------------------------------------
        # Test 10: Role Security Review (Direct API Access)
        # ----------------------------------------------------
        print("\n--- Test 10: Role Security Review (Direct API Access) ---")
        # Student cannot create menus
        s_create_res = client.post(
            "/mess/menus",
            headers={"X-User-Id": student1_id},
            json=draft_payload
        )
        assert s_create_res.status_code == 403, "Student must receive 403 on menu create"

        # Teacher cannot create menus
        t_create_res = client.post(
            "/mess/menus",
            headers={"X-User-Id": teacher_id},
            json=draft_payload
        )
        assert t_create_res.status_code == 403, "Teacher must receive 403 on menu create"

        # Student cannot view analytics
        s_analytics_res = client.get("/mess/admin/feedback/summary", headers={"X-User-Id": student1_id})
        assert s_analytics_res.status_code == 403, "Student must receive 403 on analytics"

        # Teacher cannot view analytics
        t_analytics_res = client.get("/mess/admin/feedback/summary", headers={"X-User-Id": teacher_id})
        assert t_analytics_res.status_code == 403, "Teacher must receive 403 on analytics"

        # Non-student (Admin or Teacher) cannot submit feedback
        admin_fb_res = client.post(
            "/mess/feedback",
            headers={"X-User-Id": admin_id},
            json={
                "menuId": menu_id,
                "mealId": breakfast_id,
                "rating": 5
            }
        )
        assert admin_fb_res.status_code == 403, "Admin must receive 403 on feedback submission"
        print("[PASS] Test 10: Role security verified across all roles (403 for unauthorized API endpoints).")

        # ----------------------------------------------------
        # Test 11: Menu Archiving & Immutability Behavior
        # ----------------------------------------------------
        print("\n--- Test 11: Menu Archiving & Immutability Behavior ---")
        arch_res = client.post(f"/mess/menus/{menu_id}/archive", headers={"X-User-Id": admin_id})
        assert arch_res.status_code == 200
        arch_menu = arch_res.get_json()
        assert arch_menu["status"] == "ARCHIVED"

        # Archived menu is now hidden from active student feed
        s_after_arch = client.get(f"/mess/menus?date={date_str}", headers={"X-User-Id": student1_id})
        assert s_after_arch.status_code == 200
        assert len(s_after_arch.get_json()) == 0, "Archived menu must not appear in active student feed"

        # Archived menu cannot be edited
        edit_arch_res = client.put(
            f"/mess/menus/{menu_id}",
            headers={"X-User-Id": admin_id},
            json={
                "menuDate": date_str,
                "meals": [{"mealType": "DINNER", "title": "Dinner edit", "items": ["Soup"]}]
            }
        )
        assert edit_arch_res.status_code == 409, "Archived menu cannot be edited (409)"

        # Archived menu cannot be published again
        repub_res = client.post(f"/mess/menus/{menu_id}/publish", headers={"X-User-Id": admin_id})
        assert repub_res.status_code == 409, "Archived menu cannot be republished (409)"

        # Feedback on archived menu cannot be edited
        fb_arch_edit_res = client.put(
            f"/mess/feedback/{fb1_id}",
            headers={"X-User-Id": student1_id},
            json={"rating": 5}
        )
        assert fb_arch_edit_res.status_code == 409, "Feedback on archived menu cannot be edited (409)"

        # Historical feedback remains safe and intact in the database
        with app.app_context():
            saved_fb = db.session.get(MessFeedback, fb1_id)
            assert saved_fb is not None
            assert saved_fb.rating == 4
        print("[PASS] Test 11: Archived menu is immutable (409), hidden from students, and historical feedback is safely preserved.")

    finally:
        # ----------------------------------------------------
        # Test 12: Database Cleanup and Safety Verification
        # ----------------------------------------------------
        print("\n--- Test 12: Database Cleanup and Safety Verification ---")
        with app.app_context():
            for fid in created_feedback_ids:
                fb = db.session.get(MessFeedback, fid)
                if fb:
                    db.session.delete(fb)
            db.session.commit()

            for mid in created_menu_ids:
                m = db.session.get(MessMenu, mid)
                if m:
                    for meal in m.meals:
                        db.session.delete(meal)
                    db.session.delete(m)
            db.session.commit()

            for uid in created_user_ids:
                u = db.session.get(User, uid)
                if u:
                    db.session.delete(u)
            db.session.commit()

            final_counts = {
                'users': User.query.count(),
                'sessions': Session.query.count(),
                'attendance': Attendance.query.count(),
                'leave_requests': LeaveRequest.query.count(),
                'gate_passes': GatePass.query.count(),
                'complaints': Complaint.query.count(),
                'complaint_status_history': ComplaintStatusHistory.query.count(),
                'request_audits': RequestAudit.query.count(),
                'notices': Notice.query.count(),
                'notification_deliveries': NotificationDelivery.query.count(),
                'device_tokens': DeviceToken.query.count(),
                'mess_menus': MessMenu.query.count(),
                'mess_meals': MessMeal.query.count(),
                'mess_feedback': MessFeedback.query.count(),
            }
            print(f"[CLEANUP] Final counts: {final_counts}")
            for table, count in baseline_counts.items():
                assert final_counts[table] == count, (
                    f"Table {table} count mismatch! Baseline: {count}, Final: {final_counts[table]}"
                )
            print("[OK] Database safety check: All tables returned to exact baseline counts with ZERO leftover test records!")

    print("\n==================================================")
    print("ALL 12/12 STEP 22E INTEGRATION TESTS PASSED SUCCESSFULLY!")
    print("==================================================")

if __name__ == '__main__':
    run_step22e_tests()
