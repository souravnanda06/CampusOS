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

def run_step22d_tests():
    print("==================================================")
    print("CAMPUSOS STEP 22D — MESS FEEDBACK, RATINGS & ANALYTICS TEST SUITE")
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

        # Ensure test fixtures: Admin, Student 1, Student 2, Teacher
        admin = User.query.filter_by(role='admin').first()
        if not admin:
            admin = User(
                id=str(uuid.uuid4()),
                email=f"admin_fb_{uuid.uuid4().hex[:6]}@campusos.test",
                password="password",
                name="Mess Admin FB",
                role="admin"
            )
            db.session.add(admin)
            db.session.commit()
            created_user_ids.append(admin.id)

        student1 = User.query.filter_by(role='student').first()
        if not student1:
            student1 = User(
                id=str(uuid.uuid4()),
                email=f"student1_fb_{uuid.uuid4().hex[:6]}@campusos.test",
                password="password",
                name="Student One FB",
                role="student"
            )
            db.session.add(student1)
            db.session.commit()
            created_user_ids.append(student1.id)

        student2 = User(
            id=str(uuid.uuid4()),
            email=f"student2_fb_{uuid.uuid4().hex[:6]}@campusos.test",
            password="password",
            name="Student Two FB",
            role="student"
        )
        db.session.add(student2)
        db.session.commit()
        created_user_ids.append(student2.id)

        teacher = User.query.filter_by(role='teacher').first()
        if not teacher:
            teacher = User(
                id=str(uuid.uuid4()),
                email=f"teacher_fb_{uuid.uuid4().hex[:6]}@campusos.test",
                password="password",
                name="Teacher FB",
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
        # Create a published menu with 2 meals for testing
        test_date = (datetime.date.today() + datetime.timedelta(days=20)).strftime('%Y-%m-%d')
        menu_payload = {
            "menuDate": test_date,
            "status": "PUBLISHED",
            "meals": [
                {
                    "mealType": "BREAKFAST",
                    "title": "South Indian Breakfast",
                    "description": "Crispy idli and hot vada",
                    "items": ["Idli", "Vada", "Sambar"],
                    "availability": "AVAILABLE",
                    "displayOrder": 1
                },
                {
                    "mealType": "LUNCH",
                    "title": "North Indian Thali",
                    "description": "Paneer and dal with rice",
                    "items": ["Rice", "Dal", "Paneer"],
                    "availability": "AVAILABLE",
                    "displayOrder": 2
                }
            ]
        }
        res = client.post('/mess/menus', json=menu_payload, headers={'X-User-Id': admin_id})
        assert res.status_code == 201, f"Failed to create test menu: {res.data}"
        menu_data = json.loads(res.data)
        menu_id = menu_data['id']
        created_menu_ids.append(menu_id)

        breakfast_meal = next(m for m in menu_data['meals'] if m['mealType'] == 'BREAKFAST')
        lunch_meal = next(m for m in menu_data['meals'] if m['mealType'] == 'LUNCH')
        breakfast_meal_id = breakfast_meal['id']
        lunch_meal_id = lunch_meal['id']

        print("\n--- Test 1: Create feedback successfully ---")
        fb_payload = {
            "menuId": menu_id,
            "mealId": breakfast_meal_id,
            "rating": 4,
            "category": "TASTE",
            "comment": "Crispy and delicious idli!"
        }
        res = client.post('/mess/feedback', json=fb_payload, headers={'X-User-Id': student1_id})
        assert res.status_code == 201, f"Expected 201, got {res.status_code}: {res.data}"
        fb_data = json.loads(res.data)
        assert fb_data['rating'] == 4
        assert fb_data['category'] == 'TASTE'
        assert fb_data['comment'] == 'Crispy and delicious idli!'
        assert fb_data['studentId'] == student1_id
        fb1_id = fb_data['id']
        created_feedback_ids.append(fb1_id)
        print("[PASS] Test 1: Student 1 successfully submitted feedback.")

        print("\n--- Test 2: Rating validation (1-5 only) ---")
        for invalid_rating in [0, 6, -1, 'five', None]:
            res = client.post('/mess/feedback', json={
                "menuId": menu_id,
                "mealId": lunch_meal_id,
                "rating": invalid_rating
            }, headers={'X-User-Id': student1_id})
            assert res.status_code == 400, f"Expected 400 for rating {invalid_rating}, got {res.status_code}"
        print("[PASS] Test 2: Invalid ratings rejected with 400.")

        print("\n--- Test 3: Category validation ---")
        res = client.post('/mess/feedback', json={
            "menuId": menu_id,
            "mealId": lunch_meal_id,
            "rating": 3,
            "category": "UNSUPPORTED_XYZ"
        }, headers={'X-User-Id': student1_id})
        assert res.status_code == 400, f"Expected 400 for invalid category, got {res.status_code}"
        print("[PASS] Test 3: Invalid category rejected with 400.")

        print("\n--- Test 4: Duplicate feedback prevention (1 student -> 1 rating per meal) ---")
        # Student 1 already rated breakfast
        res = client.post('/mess/feedback', json={
            "menuId": menu_id,
            "mealId": breakfast_meal_id,
            "rating": 5,
            "category": "FOOD_QUALITY"
        }, headers={'X-User-Id': student1_id})
        assert res.status_code == 409, f"Expected 409 Conflict, got {res.status_code}: {res.data}"
        err = json.loads(res.data)
        assert 'already submitted' in err['message'].lower()
        print("[PASS] Test 4: Duplicate feedback prevented with 409 Conflict.")

        print("\n--- Test 5: Update own feedback (PUT / PATCH) ---")
        update_payload = {
            "rating": 5,
            "category": "FOOD_QUALITY",
            "comment": "Updated: Best idli this semester!"
        }
        res = client.put(f'/mess/feedback/{fb1_id}', json=update_payload, headers={'X-User-Id': student1_id})
        assert res.status_code == 200, f"Expected 200, got {res.status_code}: {res.data}"
        updated_data = json.loads(res.data)
        assert updated_data['rating'] == 5
        assert updated_data['category'] == 'FOOD_QUALITY'
        assert updated_data['comment'] == 'Updated: Best idli this semester!'
        print("[PASS] Test 5: Student successfully updated own feedback.")

        print("\n--- Test 6: Student cannot update another student's feedback ---")
        res = client.put(f'/mess/feedback/{fb1_id}', json={"rating": 1}, headers={'X-User-Id': student2_id})
        assert res.status_code == 403, f"Expected 403 Forbidden, got {res.status_code}: {res.data}"
        print("[PASS] Test 6: Unauthorized update blocked with 403.")

        print("\n--- Test 7: Student cannot read another student's feedback ---")
        # Student 2 submits feedback for breakfast
        res = client.post('/mess/feedback', json={
            "menuId": menu_id,
            "mealId": breakfast_meal_id,
            "rating": 2,
            "category": "PORTION",
            "comment": "Portion size was too small"
        }, headers={'X-User-Id': student2_id})
        assert res.status_code == 201
        fb2_id = json.loads(res.data)['id']
        created_feedback_ids.append(fb2_id)

        # Student 1 fetches my feedback
        res = client.get('/mess/feedback/my', headers={'X-User-Id': student1_id})
        assert res.status_code == 200
        my_fbs = json.loads(res.data)
        assert all(f['studentId'] == student1_id for f in my_fbs)
        assert not any(f['id'] == fb2_id for f in my_fbs)

        # Student 2 fetches my feedback
        res = client.get('/mess/feedback/my', headers={'X-User-Id': student2_id})
        assert res.status_code == 200
        s2_fbs = json.loads(res.data)
        assert all(f['studentId'] == student2_id for f in s2_fbs)
        assert not any(f['id'] == fb1_id for f in s2_fbs)
        print("[PASS] Test 7: /mess/feedback/my strictly isolates student feedback.")

        print("\n--- Test 8: Admin summary aggregation ---")
        # Add 1 more feedback for lunch from student 1 (rating=1, category=CLEANLINESS)
        res = client.post('/mess/feedback', json={
            "menuId": menu_id,
            "mealId": lunch_meal_id,
            "rating": 1,
            "category": "CLEANLINESS",
            "comment": "Table was messy"
        }, headers={'X-User-Id': student1_id})
        assert res.status_code == 201
        fb3_id = json.loads(res.data)['id']
        created_feedback_ids.append(fb3_id)

        # We now have 3 feedbacks:
        # 1. Breakfast: 5★ (FOOD_QUALITY)
        # 2. Breakfast: 2★ (PORTION)
        # 3. Lunch: 1★ (CLEANLINESS)
        # Average: (5 + 2 + 1) / 3 = 8 / 3 = 2.67

        res = client.get(f'/mess/admin/feedback/summary?menuId={menu_id}', headers={'X-User-Id': admin_id})
        assert res.status_code == 200, f"Expected 200, got {res.status_code}: {res.data}"
        summary = json.loads(res.data)
        assert summary['totalRatings'] == 3
        assert summary['feedbackCount'] == 3
        assert summary['averageRating'] == 2.67
        assert summary['totalComments'] == 3
        print(f"[PASS] Test 8: Summary aggregation calculated accurately: {summary}")

        print("\n--- Test 9: Rating distribution calculation ---")
        dist = summary['ratingDistribution']
        assert dist['5'] == 1
        assert dist['4'] == 0
        assert dist['3'] == 0
        assert dist['2'] == 1
        assert dist['1'] == 1
        print(f"[PASS] Test 9: Rating distribution accurate: {dist}")

        print("\n--- Test 10: Trend aggregation ---")
        res = client.get('/mess/admin/feedback/trends', headers={'X-User-Id': admin_id})
        assert res.status_code == 200
        trends_data = json.loads(res.data)['trends']
        assert len(trends_data) >= 1
        trend_item = next(t for t in trends_data if t['date'] == test_date)
        assert trend_item['ratingCount'] == 3
        assert trend_item['averageRating'] == 2.67
        assert 'BREAKFAST' in trend_item['mealBreakdown']
        assert 'LUNCH' in trend_item['mealBreakdown']
        print(f"[PASS] Test 10: Trend aggregation verified: {trend_item}")

        print("\n--- Test 11: Category aggregation ---")
        res = client.get('/mess/admin/feedback/categories', headers={'X-User-Id': admin_id})
        assert res.status_code == 200
        cat_res = json.loads(res.data)
        categories = cat_res['categories']
        cleanliness = next(c for c in categories if c['category'] == 'CLEANLINESS')
        assert cleanliness['feedbackCount'] == 1
        assert cleanliness['averageRating'] == 1.0
        assert cleanliness['negativeCount'] == 1

        portion = next(c for c in categories if c['category'] == 'PORTION')
        assert portion['feedbackCount'] == 1
        assert portion['averageRating'] == 2.0
        print("[PASS] Test 11: Category statistics calculated accurately.")

        print("\n--- Test 12: Recurring negative signal calculation ---")
        # Let's add 1 more negative feedback for CLEANLINESS so count=2, avg=1.5 -> should be flagged!
        res = client.post('/mess/feedback', json={
            "menuId": menu_id,
            "mealId": lunch_meal_id,
            "rating": 2,
            "category": "CLEANLINESS",
            "comment": "Trays not sanitized"
        }, headers={'X-User-Id': student2_id})
        assert res.status_code == 201
        fb4_id = json.loads(res.data)['id']
        created_feedback_ids.append(fb4_id)

        res = client.get('/mess/admin/feedback/categories', headers={'X-User-Id': admin_id})
        assert res.status_code == 200
        signals = json.loads(res.data)['signals']
        cleanliness_signal = next(s for s in signals if s['category'] == 'CLEANLINESS')
        assert cleanliness_signal['feedbackCount'] == 2
        assert cleanliness_signal['averageRating'] == 1.5
        assert cleanliness_signal['negativeCount'] == 2
        assert cleanliness_signal['flagged'] is True
        assert 'low average' in cleanliness_signal['flagReason'].lower() or 'negative' in cleanliness_signal['flagReason'].lower()
        print(f"[PASS] Test 12: Recurring negative feedback signal correctly flagged: {cleanliness_signal}")

        print("\n--- Test 13: Date filtering on analytics ---")
        # Filter for exact date
        res = client.get(f'/mess/admin/feedback/summary?startDate={test_date}&endDate={test_date}', headers={'X-User-Id': admin_id})
        assert res.status_code == 200
        assert json.loads(res.data)['totalRatings'] == 4

        # Filter for future non-existent date
        future_date = '2030-01-01'
        res = client.get(f'/mess/admin/feedback/summary?startDate={future_date}', headers={'X-User-Id': admin_id})
        assert res.status_code == 200
        assert json.loads(res.data)['totalRatings'] == 0
        assert json.loads(res.data)['averageRating'] == 0.0
        print("[PASS] Test 13: Date range filtering verified.")

        print("\n--- Test 14: Meal filtering on analytics ---")
        # Filter by mealType=BREAKFAST
        res = client.get(f'/mess/admin/feedback/summary?mealType=BREAKFAST&menuId={menu_id}', headers={'X-User-Id': admin_id})
        assert res.status_code == 200
        data_bf = json.loads(res.data)
        assert data_bf['totalRatings'] == 2  # 5★ and 2★
        assert data_bf['averageRating'] == 3.5

        # Filter by mealType=LUNCH
        res = client.get(f'/mess/admin/feedback/summary?mealType=LUNCH&menuId={menu_id}', headers={'X-User-Id': admin_id})
        assert res.status_code == 200
        data_lunch = json.loads(res.data)
        assert data_lunch['totalRatings'] == 2  # 1★ and 2★
        assert data_lunch['averageRating'] == 1.5
        print("[PASS] Test 14: Meal type filtering verified.")

        print("\n--- Test 15: Role restrictions on admin analytics ---")
        # Teacher must be blocked
        res = client.get('/mess/admin/feedback/summary', headers={'X-User-Id': teacher_id})
        assert res.status_code == 403, f"Teacher should be blocked (403), got {res.status_code}"

        # Student must be blocked
        res = client.get('/mess/admin/feedback/summary', headers={'X-User-Id': student1_id})
        assert res.status_code == 403, f"Student should be blocked (403), got {res.status_code}"

        # Admin comments endpoint must anonymize studentId
        res = client.get('/mess/admin/feedback/comments', headers={'X-User-Id': admin_id})
        assert res.status_code == 200
        comments = json.loads(res.data)
        assert len(comments) >= 4
        for c in comments:
            assert 'studentId' not in c, f"Privacy violation: studentId leaked in admin comments feed: {c}"
            assert 'comment' in c and len(c['comment']) > 0
            assert 'rating' in c
            assert 'mealType' in c
        print("[PASS] Test 15: Role restrictions and privacy anonymization verified.")

    finally:
        print("\n--- Test 16: Database cleanup and baseline count verification ---")
        with app.app_context():
            # Delete created feedback
            for fid in created_feedback_ids:
                fb = MessFeedback.query.get(fid)
                if fb:
                    db.session.delete(fb)

            # Delete created menus (cascade deletes meals and any leftover feedback)
            for mid in created_menu_ids:
                m = MessMenu.query.get(mid)
                if m:
                    db.session.delete(m)

            # Delete created test users
            for uid in created_user_ids:
                u = User.query.get(uid)
                if u:
                    db.session.delete(u)

            db.session.commit()

            # Verify final counts
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

            mismatches = []
            for tbl, count in baseline_counts.items():
                if final_counts[tbl] != count:
                    mismatches.append(f"{tbl}: baseline={count}, final={final_counts[tbl]}")

            if mismatches:
                print(f"[FAIL] Table count mismatches: {mismatches}")
                sys.exit(1)
            else:
                print("[OK] Database safety check: All 14 tables returned to exact baseline counts with ZERO leftover test records!")

    print("\n==================================================")
    print("ALL 16/16 STEP 22D BACKEND TESTS PASSED SUCCESSFULLY!")
    print("==================================================")

if __name__ == '__main__':
    run_step22d_tests()
