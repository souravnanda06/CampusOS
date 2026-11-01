import sys
import os
from sqlalchemy import create_engine, text

def run_migration():
    engine = create_engine('mysql+pymysql://root:nandasourav766@localhost/attentify')
    with engine.connect() as con:
        print("[MIGRATE] Checking 'attendance' table columns...")
        rs = con.execute(text("SHOW COLUMNS FROM attendance;"))
        existing_cols = {row[0] for row in rs}

        additive_cols = [
            ("idempotency_key", "VARCHAR(128) UNIQUE NULL"),
            ("device_key_id", "VARCHAR(64) NULL"),
            ("response_nonce", "VARCHAR(64) NULL"),
            ("verification_mode", "VARCHAR(32) NULL DEFAULT 'LEGACY'"),
            ("proximity_tier", "VARCHAR(32) NULL"),
        ]

        for col_name, col_def in additive_cols:
            if col_name not in existing_cols:
                print(f"[MIGRATE] Adding column '{col_name}' to 'attendance'...")
                con.execute(text(f"ALTER TABLE attendance ADD COLUMN {col_name} {col_def};"))
            else:
                print(f"[MIGRATE] Column '{col_name}' already exists in 'attendance'.")

        print("[MIGRATE] Checking 'sessions' table columns...")
        rs = con.execute(text("SHOW COLUMNS FROM sessions;"))
        existing_session_cols = {row[0] for row in rs}

        session_additive_cols = [
            ("session_nonce", "VARCHAR(64) NULL"),
            ("teacher_key_id", "VARCHAR(64) NULL"),
            ("teacher_id", "VARCHAR(36) NULL"),
        ]

        for col_name, col_def in session_additive_cols:
            if col_name not in existing_session_cols:
                print(f"[MIGRATE] Adding column '{col_name}' to 'sessions'...")
                con.execute(text(f"ALTER TABLE sessions ADD COLUMN {col_name} {col_def};"))
            else:
                print(f"[MIGRATE] Column '{col_name}' already exists in 'sessions'.")

        con.commit()
        print("[MIGRATE] Migration completed successfully!")

if __name__ == '__main__':
    run_migration()
