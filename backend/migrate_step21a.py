import pymysql

def run_migration():
    conn = pymysql.connect(
        host='localhost',
        user='root',
        password='nandasourav766',
        database='attentify',
        autocommit=True
    )
    cursor = conn.cursor()

    def add_col_if_missing(table, col, col_def):
        cursor.execute(f"""
            SELECT COUNT(*) FROM information_schema.COLUMNS 
            WHERE TABLE_SCHEMA = 'attentify' AND TABLE_NAME = '{table}' AND COLUMN_NAME = '{col}';
        """)
        if cursor.fetchone()[0] == 0:
            print(f"Adding column '{col}' to table '{table}'...")
            cursor.execute(f"ALTER TABLE {table} ADD COLUMN {col} {col_def};")
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

    # Ensure existing content/title/body can accept null if only new fields are used
    cursor.execute("ALTER TABLE notices MODIFY COLUMN content TEXT NULL;")
    cursor.execute("ALTER TABLE notification_deliveries MODIFY COLUMN title VARCHAR(120) NULL;")
    cursor.execute("ALTER TABLE notification_deliveries MODIFY COLUMN body TEXT NULL;")
    cursor.execute("ALTER TABLE notification_deliveries MODIFY COLUMN notification_type VARCHAR(30) NULL DEFAULT 'NOTICE';")

    # Add FK for notification_deliveries.notice_id -> notices.id if not already present
    cursor.execute("""
        SELECT CONSTRAINT_NAME FROM information_schema.KEY_COLUMN_USAGE 
        WHERE TABLE_SCHEMA = 'attentify' 
          AND TABLE_NAME = 'notification_deliveries' 
          AND COLUMN_NAME = 'notice_id' 
          AND REFERENCED_TABLE_NAME IS NOT NULL;
    """)
    if not cursor.fetchall():
        print("Adding foreign key fk_notif_deliv_notice on notification_deliveries(notice_id)...")
        cursor.execute("ALTER TABLE notification_deliveries ADD CONSTRAINT fk_notif_deliv_notice FOREIGN KEY (notice_id) REFERENCES notices(id) ON DELETE CASCADE;")
    else:
        print("Foreign key on notification_deliveries(notice_id) already exists.")

    # Add FK for notices.created_by -> users.id if not already present
    cursor.execute("""
        SELECT CONSTRAINT_NAME FROM information_schema.KEY_COLUMN_USAGE 
        WHERE TABLE_SCHEMA = 'attentify' 
          AND TABLE_NAME = 'notices' 
          AND COLUMN_NAME = 'created_by' 
          AND REFERENCED_TABLE_NAME IS NOT NULL;
    """)
    if not cursor.fetchall():
        print("Adding foreign key fk_notices_created_by on notices(created_by)...")
        cursor.execute("ALTER TABLE notices ADD CONSTRAINT fk_notices_created_by FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL;")
    else:
        print("Foreign key on notices(created_by) already exists.")

    conn.close()
    print("Additive schema migration successfully executed!")

if __name__ == '__main__':
    run_migration()
