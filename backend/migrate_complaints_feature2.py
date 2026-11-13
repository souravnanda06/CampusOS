"""
CampusOS Feature 2: Database Migration for Complaints Table
Adds closure_otp, otp_verified_at, escalation_level, escalated_at,
vendor_penalty_flag, vendor_penalty_amount, student_rating, student_feedback.
"""

import os
import sys
from sqlalchemy import inspect, text

sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))

from app import app, db

def migrate():
    with app.app_context():
        print("Migrating 'complaints' table for Feature 2...")
        
        columns = [
            ("closure_otp", "VARCHAR(6) NULL"),
            ("otp_verified_at", "VARCHAR(50) NULL"),
            ("escalation_level", "INTEGER NOT NULL DEFAULT 1"),
            ("escalated_at", "VARCHAR(50) NULL"),
            ("vendor_penalty_flag", "BOOLEAN NOT NULL DEFAULT 0"),
            ("vendor_penalty_amount", "FLOAT NOT NULL DEFAULT 0.0"),
            ("student_rating", "INTEGER NULL"),
            ("student_feedback", "TEXT NULL")
        ]

        # Check existing columns using SQLAlchemy inspector (works on SQLite & other dialects)
        existing_cols = set()
        try:
            inspector = inspect(db.engine)
            existing_cols = {c['name'].lower() for c in inspector.get_columns('complaints')}
        except Exception as e:
            print(f"Error inspecting columns: {e}")

        for col_name, col_type in columns:
            if col_name.lower() not in existing_cols:
                try:
                    alter_stmt = text(f"ALTER TABLE complaints ADD COLUMN {col_name} {col_type}")
                    db.session.execute(alter_stmt)
                    db.session.commit()
                    print(f"  [+] Added column: {col_name} ({col_type})")
                except Exception as ex:
                    db.session.rollback()
                    print(f"  [!] Skipped/Error adding {col_name}: {ex}")
            else:
                print(f"  [=] Column already exists: {col_name}")

        print("Migration complete!")

if __name__ == '__main__':
    migrate()
