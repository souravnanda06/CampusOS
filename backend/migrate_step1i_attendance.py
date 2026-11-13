from sqlalchemy import create_engine, inspect, text
from config import Config


def run_migration():
    engine = create_engine(Config.SQLALCHEMY_DATABASE_URI)
    inspector = inspect(engine)
    is_sqlite = engine.dialect.name == 'sqlite'

    with engine.connect() as con:
        print("[MIGRATE] Checking 'attendance' table columns...")
        existing_cols = {c['name'] for c in inspector.get_columns('attendance')}

        additive_cols = [
            ("idempotency_key", "VARCHAR(128) NULL" if is_sqlite else "VARCHAR(128) UNIQUE NULL"),
            ("device_key_id", "VARCHAR(64) NULL"),
            ("response_nonce", "VARCHAR(64) NULL"),
            ("verification_mode", "VARCHAR(32) NULL DEFAULT 'LEGACY'"),
            ("proximity_tier", "VARCHAR(32) NULL"),
            ("router_bssid", "VARCHAR(64) NULL"),
        ]

        for col_name, col_def in additive_cols:
            if col_name not in existing_cols:
                print(f"[MIGRATE] Adding column '{col_name}' to 'attendance'...")
                con.execute(text(f"ALTER TABLE attendance ADD COLUMN {col_name} {col_def}"))
            else:
                print(f"[MIGRATE] Column '{col_name}' already exists in 'attendance'.")

        if is_sqlite:
            con.execute(text(
                "CREATE UNIQUE INDEX IF NOT EXISTS uq_attendance_idempotency_key ON attendance (idempotency_key)"
            ))

        print("[MIGRATE] Checking 'sessions' table columns...")
        existing_session_cols = {c['name'] for c in inspector.get_columns('sessions')}

        session_additive_cols = [
            ("session_nonce", "VARCHAR(64) NULL"),
            ("teacher_key_id", "VARCHAR(64) NULL"),
            ("teacher_id", "VARCHAR(36) NULL"),
        ]

        for col_name, col_def in session_additive_cols:
            if col_name not in existing_session_cols:
                print(f"[MIGRATE] Adding column '{col_name}' to 'sessions'...")
                con.execute(text(f"ALTER TABLE sessions ADD COLUMN {col_name} {col_def}"))
            else:
                print(f"[MIGRATE] Column '{col_name}' already exists in 'sessions'.")

        con.commit()
        print("[MIGRATE] Migration completed successfully!")


if __name__ == '__main__':
    run_migration()
