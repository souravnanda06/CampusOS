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

    # Add columns to leave_requests
    add_col_if_missing('leave_requests', 'parent_consent', "VARCHAR(20) DEFAULT 'GRANTED'")
    add_col_if_missing('leave_requests', 'parent_consent_at', "VARCHAR(50) NULL")
    add_col_if_missing('leave_requests', 'destination', "VARCHAR(150) NULL")

    # Add columns to gate_passes
    add_col_if_missing('gate_passes', 'gate_name', "VARCHAR(50) DEFAULT 'Main Gate'")
    add_col_if_missing('gate_passes', 'verification_mode', "VARCHAR(25) DEFAULT 'QR_FALLBACK'")
    add_col_if_missing('gate_passes', 'idempotency_key', "VARCHAR(100) NULL")

    # Add index on gate_passes(idempotency_key) if missing
    cursor.execute("""
        SELECT COUNT(*) FROM information_schema.STATISTICS 
        WHERE TABLE_SCHEMA = 'attentify' AND TABLE_NAME = 'gate_passes' AND INDEX_NAME = 'idx_gp_idempotency';
    """)
    if cursor.fetchone()[0] == 0:
        cursor.execute("CREATE INDEX idx_gp_idempotency ON gate_passes (idempotency_key);")
        print("Created index idx_gp_idempotency.")

    cursor.close()
    conn.close()
    print("Migration completed successfully.")

if __name__ == '__main__':
    run_migration()
