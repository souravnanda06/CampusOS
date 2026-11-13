import sqlite3
import os

db_path = os.path.join(os.path.dirname(__file__), 'app.db')
if os.path.exists(db_path):
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute("PRAGMA table_info(student_career_profiles)")
    cols = [r[1] for r in cursor.fetchall()]
    new_cols = [
        ('target_role', "VARCHAR(100) DEFAULT 'Software Engineer'"),
        ('bio', "TEXT DEFAULT ''"),
        ('projects_json', "TEXT DEFAULT '[]'"),
        ('certifications_json', "TEXT DEFAULT '[]'"),
        ('academic_records_json', "TEXT DEFAULT '{}'")
    ]
    for col_name, col_def in new_cols:
        if col_name not in cols:
            cursor.execute(f"ALTER TABLE student_career_profiles ADD COLUMN {col_name} {col_def}")
            print(f"[OK] Added column {col_name} to student_career_profiles")
    conn.commit()
    conn.close()
    print("[OK] Migration finished successfully.")
else:
    print("[WARN] app.db not found, skipping migration.")
