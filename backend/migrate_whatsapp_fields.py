from sqlalchemy import inspect, text
from app import app, db


def run_migration():
    """Adds phone, parent_phone, and parent_name columns to users table if missing."""
    with app.app_context():
        inspector = inspect(db.engine)
        existing_cols = {c['name'] for c in inspector.get_columns('users')}

        def add_col(col_name, col_def):
            if col_name not in existing_cols:
                print(f"Adding column '{col_name}' to 'users' table...")
                db.session.execute(text(f"ALTER TABLE users ADD COLUMN {col_name} {col_def}"))
                db.session.commit()
                print(f"Successfully added '{col_name}'.")
            else:
                print(f"Column '{col_name}' already exists in 'users' table.")

        add_col('phone', 'VARCHAR(20) NULL')
        add_col('parent_phone', 'VARCHAR(20) NULL')
        add_col('parent_name', 'VARCHAR(100) NULL')

    print("WhatsApp columns migration completed successfully.")


if __name__ == '__main__':
    run_migration()
