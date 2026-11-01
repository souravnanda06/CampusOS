"""
Seeds institutional Warden and Gate Security accounts if they don't already exist.
Institutional logins:
- Security: security@campusos.edu / password123
- Warden: warden@campusos.edu / password123
"""

import sys
import os
import uuid

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from app import app, db, User

def seed_security_and_warden():
    with app.app_context():
        # 1. Seed Security Guard
        security = User.query.filter_by(role='security').first()
        if not security:
            security = User(
                id=str(uuid.uuid4()),
                email="security@campusos.edu",
                password="password123",
                name="Officer Vikram Singh",
                role="security"
            )
            db.session.add(security)
            print("[OK] Created institutional Security user: security@campusos.edu")
        else:
            print(f"[INFO] Security user already exists: {security.email}")

        # 2. Seed Warden
        warden = User.query.filter_by(role='warden').first()
        if not warden:
            warden = User(
                id=str(uuid.uuid4()),
                email="warden@campusos.edu",
                password="password123",
                name="Chief Warden Dr. Rajesh Sharma",
                role="warden"
            )
            db.session.add(warden)
            print("[OK] Created institutional Warden user: warden@campusos.edu")
        else:
            print(f"[INFO] Warden user already exists: {warden.email}")

        db.session.commit()
        print("[SUCCESS] Institutional Security and Warden provisioning complete.")

if __name__ == '__main__':
    seed_security_and_warden()
