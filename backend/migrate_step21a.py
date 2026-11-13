from sqlalchemy import inspect, text
from app import app, db


def run_migration():
    with app.app_context():
        inspector = inspect(db.engine)

        def add_col_if_missing(table, col, col_def):
            existing = {c['name'] for c in inspector.get_columns(table)}
            if col not in existing:
                print(f"Adding column '{col}' to table '{table}'...")
                db.session.execute(text(f"ALTER TABLE {table} ADD COLUMN {col} {col_def}"))
                db.session.commit()
            else:
                print(f"Column '{col}' already exists in table '{table}'.")

        # Additive fields for notices
        add_col_if_missing('notices', 'body', 'TEXT NULL')
        add_col_if_missing('notices', 'created_by', 'VARCHAR(36) NULL')
        add_col_if_missing('notices', 'priority', "VARCHAR(20) DEFAULT 'NORMAL'")
        add_col_if_missing('notices', 'target_type', "VARCHAR(30) DEFAULT 'ALL'")
        add_col_if_missing('notices', 'target_value', 'VARCHAR(100) NULL')
        add_col_if_missing('notices', 'action_type', 'VARCHAR(50) NULL')
        add_col_if_missing('notices', 'action_payload', 'TEXT NULL')
        add_col_if_missing('notices', 'status', "VARCHAR(20) DEFAULT 'PUBLISHED'")

        # Additive fields for notification_deliveries
        add_col_if_missing('notification_deliveries', 'notice_id', 'VARCHAR(36) NULL')
        add_col_if_missing('notification_deliveries', 'status', "VARCHAR(20) DEFAULT 'PENDING'")
        add_col_if_missing('notification_deliveries', 'delivered_at', 'VARCHAR(50) NULL')
        add_col_if_missing('notification_deliveries', 'action_at', 'VARCHAR(50) NULL')

    print("Additive schema migration successfully executed!")


if __name__ == '__main__':
    run_migration()
