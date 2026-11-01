import sys
import os

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from app import app, db, Attendance

def fix_db():
    with app.app_context():
        absent_records = Attendance.query.filter_by(status='absent').all()
        for record in absent_records:
            db.session.delete(record)
        db.session.commit()
        print("Deleted absent records. Now attendance is based only on present rows.")

if __name__ == '__main__':
    fix_db()
