import sqlite3
import os
from sqlalchemy import create_engine, inspect, text
from config import Config

def run_migration():
    print("[MIGRATE] Running CampusOS Upgradation Database Migration...")
    engine = create_engine(Config.SQLALCHEMY_DATABASE_URI)
    inspector = inspect(engine)
    is_sqlite = engine.dialect.name == 'sqlite'

    with engine.connect() as con:
        # 1. Update mesh_channels table
        print("[MIGRATE] Checking 'mesh_channels' table columns...")
        existing_mesh_channel_cols = {c['name'] for c in inspector.get_columns('mesh_channels')} if 'mesh_channels' in inspector.get_table_names() else set()
        
        channel_cols = [
            ("status", "VARCHAR(32) NOT NULL DEFAULT 'ACTIVE'"),
            ("restricted_reason", "VARCHAR(256) NULL"),
            ("restricted_by", "VARCHAR(64) NULL"),
            ("restricted_at", "BIGINT NULL"),
        ]
        for col_name, col_def in channel_cols:
            if col_name not in existing_mesh_channel_cols and 'mesh_channels' in inspector.get_table_names():
                print(f"[MIGRATE] Adding column '{col_name}' to 'mesh_channels'...")
                con.execute(text(f"ALTER TABLE mesh_channels ADD COLUMN {col_name} {col_def}"))

        # 2. Update mesh_messages table
        print("[MIGRATE] Checking 'mesh_messages' table columns...")
        existing_mesh_message_cols = {c['name'] for c in inspector.get_columns('mesh_messages')} if 'mesh_messages' in inspector.get_table_names() else set()
        
        if "delivery_state" not in existing_mesh_message_cols and 'mesh_messages' in inspector.get_table_names():
            print("[MIGRATE] Adding column 'delivery_state' to 'mesh_messages'...")
            con.execute(text("ALTER TABLE mesh_messages ADD COLUMN delivery_state VARCHAR(32) NOT NULL DEFAULT 'SENT'"))

        # 3. Update sessions table
        print("[MIGRATE] Checking 'sessions' table columns...")
        existing_session_cols = {c['name'] for c in inspector.get_columns('sessions')} if 'sessions' in inspector.get_table_names() else set()
        
        session_cols = [
            ("latitude", "REAL NULL"),
            ("longitude", "REAL NULL"),
            ("radius_meters", "REAL NULL DEFAULT 20.0"),
        ]
        for col_name, col_def in session_cols:
            if col_name not in existing_session_cols and 'sessions' in inspector.get_table_names():
                print(f"[MIGRATE] Adding column '{col_name}' to 'sessions'...")
                con.execute(text(f"ALTER TABLE sessions ADD COLUMN {col_name} {col_def}"))

        # 4. Update attendance table
        print("[MIGRATE] Checking 'attendance' table columns...")
        existing_attendance_cols = {c['name'] for c in inspector.get_columns('attendance')} if 'attendance' in inspector.get_table_names() else set()
        
        attendance_cols = [
            ("latitude", "REAL NULL"),
            ("longitude", "REAL NULL"),
            ("distance_meters", "REAL NULL"),
        ]
        for col_name, col_def in attendance_cols:
            if col_name not in existing_attendance_cols and 'attendance' in inspector.get_table_names():
                print(f"[MIGRATE] Adding column '{col_name}' to 'attendance'...")
                con.execute(text(f"ALTER TABLE attendance ADD COLUMN {col_name} {col_def}"))

        con.commit()
        print("[MIGRATE] Migration completed successfully!")

if __name__ == '__main__':
    run_migration()
