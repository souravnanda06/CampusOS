import sys
import os

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from app import app, db, User, Session, Attendance
from werkzeug.security import generate_password_hash
import uuid
from datetime import datetime, timedelta

def seed_db():
    with app.app_context():
        # Ensure all tables exist in the fresh database
        db.create_all()

        # Check or create a default student
        student = User.query.filter_by(role='student').first()
        if not student:
            student = User(
                id=str(uuid.uuid4()),
                name="Test Student",
                email="student@campusos.local",
                password=generate_password_hash("password123"),  # <-- Added password here
                role="student",
                course="B.Tech",
                branch="CSE",
                year="3"
            )
            db.session.add(student)
            db.session.commit()

        # Check or create a default teacher
        teacher = User.query.filter_by(role='teacher').first()
        if not teacher:
            teacher = User(
                id=str(uuid.uuid4()),
                name="Dr. Professor",
                email="teacher@campusos.local",
                password=generate_password_hash("password123"),  # <-- Added password here
                role="teacher"
            )
            db.session.add(teacher)
            db.session.commit()
        
        print(f"Student data: Course={student.course}, Branch={student.branch}, Year={student.year}")

        # Clear existing sessions & attendance
        Attendance.query.delete()
        Session.query.delete()

        subjects = ["Physics 101", "Advanced Calculus", "Data Structures", "Database Systems"]
        
        for i, subject in enumerate(subjects):
            start = datetime.now() - timedelta(days=i, hours=2)
            end = start + timedelta(hours=1)
            
            new_session = Session(
                id=str(uuid.uuid4()),
                name=f"{subject} Lecture",
                subject=subject,
                instructor_name=teacher.name,
                course=student.course,
                branch=student.branch,
                year=student.year,
                start_time=start.isoformat(),
                end_time=end.isoformat(),
                location=f"Room {100 + i}",
                is_active=False,
                attendance_count=1
            )
            db.session.add(new_session)
            
            status = 'present' if i < 3 else 'absent'
            
            new_attendance = Attendance(
                id=str(uuid.uuid4()),
                session_id=new_session.id,
                user_id=student.id,
                student_name=student.name,
                check_in_time=start.isoformat(),
                status=status
            )
            db.session.add(new_attendance)

        db.session.commit()
        print("Database seeded successfully with default users and test data!")

if __name__ == '__main__':
    seed_db()