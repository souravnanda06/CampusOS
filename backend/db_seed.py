import sys
import os

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from app import app, db, User, Session, Attendance
import uuid
from datetime import datetime, timedelta

def seed_db():
    with app.app_context():
        student = User.query.filter_by(role='student').first()
        teacher = User.query.filter_by(role='teacher').first()
        
        print(f"Student data: Course={student.course}, Branch={student.branch}, Year={student.year}")

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
        print("Database seeded with exactly matching course/branch/year!")

if __name__ == '__main__':
    seed_db()
