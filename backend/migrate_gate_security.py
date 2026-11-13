from sqlalchemy import inspect, text
from app import app, db


def run_migration():
    with app.app_context():
        inspector = inspect(db.engine)
        is_sqlite = db.engine.dialect.name == 'sqlite'

        def add_col_if_missing(table, col, col_def):
            existing = {c['name'] for c in inspector.get_columns(table)}
            if col not in existing:
                print(f"Adding column '{col}' to table '{table}'...")
                db.session.execute(text(f"ALTER TABLE {table} ADD COLUMN {col} {col_def}"))
                db.session.commit()
            else:
                print(f"Column '{col}' already exists in table '{table}'.")

        # Add columns to leave_requests
        add_col_if_missing('leave_requests', 'parent_consent', "VARCHAR(20) DEFAULT 'GRANTED'")
        add_col_if_missing('leave_requests', 'parent_consent_at', "VARCHAR(50) NULL")
        add_col_if_missing('leave_requests', 'destination', "VARCHAR(150) NULL")

        # Add columns to gate_passes
        add_col_if_missing('gate_passes', 'gate_name', "VARCHAR(50) DEFAULT 'Main Gate'")
        add_col_if_missing('gate_passes', 'verification_mode', "VARCHAR(25) DEFAULT 'QR_FALLBACK'")
        add_col_if_missing('gate_passes', 'idempotency_key', "VARCHAR(100) NULL")

        # Add index on gate_passes(idempotency_key) if missing
        existing_indexes = {idx['name'] for idx in inspector.get_indexes('gate_passes')}
        if 'idx_gp_idempotency' not in existing_indexes:
            stmt = (
                "CREATE INDEX IF NOT EXISTS idx_gp_idempotency ON gate_passes (idempotency_key)"
                if is_sqlite
                else "CREATE INDEX idx_gp_idempotency ON gate_passes (idempotency_key)"
            )
            db.session.execute(text(stmt))
            db.session.commit()
            print("Created index idx_gp_idempotency.")

    print("Migration completed successfully.")


if __name__ == '__main__':
    run_migration()
