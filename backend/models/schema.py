from sqlalchemy import text
from extensions import db

def init_db(app):
    """
    Initializes database tables and performs non-destructive additive column/table checks.
    """
    with app.app_context():
        db.create_all()
        # Safe additive schema check for Notice & NotificationDelivery & DeviceToken & Mess columns
        try:
            with db.engine.connect() as _conn:
                _db_uri = app.config.get('SQLALCHEMY_DATABASE_URI', '')
                if 'mysql' in _db_uri:
                    _db_name = _db_uri.split('/')[-1].split('?')[0] or 'attentify'
                    _res = _conn.execute(text(
                        f"SELECT COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = '{_db_name}' AND TABLE_NAME = 'notices'"
                    ))
                    _notice_cols = {row[0] for row in _res.fetchall()}
                    if _notice_cols:
                        _notice_additions = [
                            ('body', 'TEXT NULL'),
                            ('created_by', 'VARCHAR(36) NULL'),
                            ('priority', "VARCHAR(20) DEFAULT 'NORMAL'"),
                            ('target_type', "VARCHAR(30) DEFAULT 'ALL'"),
                            ('target_value', 'VARCHAR(100) NULL'),
                            ('action_type', 'VARCHAR(50) NULL'),
                            ('action_payload', 'TEXT NULL'),
                            ('status', "VARCHAR(20) DEFAULT 'PUBLISHED'")
                        ]
                        for col_name, col_def in _notice_additions:
                            if col_name not in _notice_cols:
                                _conn.execute(text(f"ALTER TABLE notices ADD COLUMN {col_name} {col_def}"))
                                _conn.commit()

                    _res2 = _conn.execute(text(
                        f"SELECT COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = '{_db_name}' AND TABLE_NAME = 'notification_deliveries'"
                    ))
                    _notif_cols = {row[0] for row in _res2.fetchall()}
                    if _notif_cols:
                        _notif_additions = [
                            ('notice_id', 'VARCHAR(36) NULL'),
                            ('status', "VARCHAR(20) DEFAULT 'PENDING'"),
                            ('delivered_at', 'VARCHAR(50) NULL'),
                            ('action_at', 'VARCHAR(50) NULL'),
                            ('push_attempted', 'TINYINT(1) DEFAULT 0'),
                            ('push_error', 'VARCHAR(255) NULL')
                        ]
                        for col_name, col_def in _notif_additions:
                            if col_name not in _notif_cols:
                                _conn.execute(text(f"ALTER TABLE notification_deliveries ADD COLUMN {col_name} {col_def}"))
                                _conn.commit()

                    _res3 = _conn.execute(text(
                        f"SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA = '{_db_name}' AND TABLE_NAME = 'device_tokens'"
                    ))
                    if not _res3.fetchall():
                        _conn.execute(text("""
                            CREATE TABLE device_tokens (
                                id VARCHAR(36) PRIMARY KEY,
                                user_id VARCHAR(36) NOT NULL,
                                token VARCHAR(255) NOT NULL UNIQUE,
                                device_type VARCHAR(50) DEFAULT 'android',
                                device_id VARCHAR(100) NULL,
                                is_active TINYINT(1) DEFAULT 1,
                                created_at VARCHAR(50),
                                updated_at VARCHAR(50),
                                INDEX idx_dt_user (user_id),
                                INDEX idx_dt_token (token)
                            )
                        """))
                        _conn.commit()

                    _res_menu = _conn.execute(text(
                        f"SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA = '{_db_name}' AND TABLE_NAME = 'mess_menus'"
                    ))
                    if not _res_menu.fetchall():
                        _conn.execute(text("""
                            CREATE TABLE mess_menus (
                                id VARCHAR(36) PRIMARY KEY,
                                menu_date VARCHAR(10) NOT NULL,
                                status VARCHAR(20) NOT NULL DEFAULT 'DRAFT',
                                created_by VARCHAR(36) NULL,
                                updated_by VARCHAR(36) NULL,
                                created_at VARCHAR(50),
                                updated_at VARCHAR(50),
                                INDEX idx_mm_date (menu_date),
                                INDEX idx_mm_status (status)
                            )
                        """))
                        _conn.commit()

                    _res_meals = _conn.execute(text(
                        f"SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA = '{_db_name}' AND TABLE_NAME = 'mess_meals'"
                    ))
                    if not _res_meals.fetchall():
                        _conn.execute(text("""
                            CREATE TABLE mess_meals (
                                id VARCHAR(36) PRIMARY KEY,
                                menu_id VARCHAR(36) NOT NULL,
                                meal_type VARCHAR(20) NOT NULL,
                                title VARCHAR(100) NULL,
                                description TEXT NULL,
                                items TEXT NOT NULL,
                                availability VARCHAR(20) NOT NULL DEFAULT 'AVAILABLE',
                                display_order INT NOT NULL DEFAULT 1,
                                created_at VARCHAR(50),
                                updated_at VARCHAR(50),
                                INDEX idx_meal_menu (menu_id),
                                INDEX idx_meal_type (meal_type),
                                CONSTRAINT fk_mess_meal_menu FOREIGN KEY (menu_id) REFERENCES mess_menus (id) ON DELETE CASCADE
                            )
                        """))
                        _conn.commit()

                    _res_fb = _conn.execute(text(
                        f"SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA = '{_db_name}' AND TABLE_NAME = 'mess_feedback'"
                    ))
                    if not _res_fb.fetchall():
                        _conn.execute(text("""
                            CREATE TABLE mess_feedback (
                                id VARCHAR(36) PRIMARY KEY,
                                menu_id VARCHAR(36) NOT NULL,
                                meal_id VARCHAR(36) NOT NULL,
                                student_id VARCHAR(36) NOT NULL,
                                rating INT NOT NULL,
                                category VARCHAR(32) NULL,
                                comment TEXT NULL,
                                created_at VARCHAR(50),
                                updated_at VARCHAR(50),
                                INDEX idx_mf_menu (menu_id),
                                INDEX idx_mf_meal (meal_id),
                                INDEX idx_mf_student (student_id),
                                INDEX idx_mf_rating (rating),
                                INDEX idx_mf_category (category),
                                UNIQUE KEY uq_mess_feedback_meal_student (meal_id, student_id),
                                CONSTRAINT fk_mf_menu FOREIGN KEY (menu_id) REFERENCES mess_menus (id) ON DELETE CASCADE,
                                CONSTRAINT fk_mf_meal FOREIGN KEY (meal_id) REFERENCES mess_meals (id) ON DELETE CASCADE,
                                CONSTRAINT fk_mf_student FOREIGN KEY (student_id) REFERENCES users (id) ON DELETE CASCADE
                            )
                        """))
                        _conn.commit()

                    _res_dik = _conn.execute(text(
                        f"SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA = '{_db_name}' AND TABLE_NAME = 'device_identity_keys'"
                    ))
                    if not _res_dik.fetchall():
                        _conn.execute(text("""
                            CREATE TABLE device_identity_keys (
                                id VARCHAR(36) PRIMARY KEY,
                                user_id VARCHAR(36) NOT NULL,
                                public_key_b64 VARCHAR(128) NOT NULL,
                                key_type VARCHAR(32) NOT NULL DEFAULT 'ED25519',
                                status VARCHAR(32) NOT NULL DEFAULT 'ACTIVE',
                                created_at VARCHAR(50),
                                activated_at VARCHAR(50),
                                revoked_at VARCHAR(50) NULL,
                                last_seen_at VARCHAR(50) NULL,
                                INDEX idx_dik_user (user_id),
                                INDEX idx_dik_status (status),
                                UNIQUE KEY uq_dik_public_key (public_key_b64),
                                CONSTRAINT fk_dik_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
                            )
                        """))
                        _conn.commit()

                    _res_dc = _conn.execute(text(
                        f"SELECT TABLE_NAME FROM information_schema.TABLES WHERE TABLE_SCHEMA = '{_db_name}' AND TABLE_NAME = 'device_certificates'"
                    ))
                    if not _res_dc.fetchall():
                        _conn.execute(text("""
                            CREATE TABLE device_certificates (
                                id VARCHAR(36) PRIMARY KEY,
                                key_id VARCHAR(36) NOT NULL,
                                certificate_version VARCHAR(16) NOT NULL DEFAULT '1.0',
                                issuer VARCHAR(64) NOT NULL DEFAULT 'CampusOS',
                                issuer_key_id VARCHAR(64) NOT NULL,
                                subject_user_id VARCHAR(36) NOT NULL,
                                subject_public_key_b64 VARCHAR(128) NOT NULL,
                                algorithm VARCHAR(32) NOT NULL DEFAULT 'Ed25519',
                                valid_from VARCHAR(50) NOT NULL,
                                valid_to VARCHAR(50) NOT NULL,
                                signature TEXT NOT NULL,
                                status VARCHAR(32) NOT NULL DEFAULT 'ACTIVE',
                                created_at VARCHAR(50),
                                revoked_at VARCHAR(50) NULL,
                                INDEX idx_dc_key (key_id),
                                INDEX idx_dc_user (subject_user_id),
                                INDEX idx_dc_status (status),
                                CONSTRAINT fk_dc_key FOREIGN KEY (key_id) REFERENCES device_identity_keys (id) ON DELETE CASCADE
                            )
                        """))
                        _conn.commit()

                    # Phase 6: Additive idempotency_key for complaints table
                    _res_comp = _conn.execute(text(
                        f"SELECT COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = '{_db_name}' AND TABLE_NAME = 'complaints'"
                    ))
                    _comp_cols = {row[0] for row in _res_comp.fetchall()}
                    if _comp_cols and 'idempotency_key' not in _comp_cols:
                        _conn.execute(text("ALTER TABLE complaints ADD COLUMN idempotency_key VARCHAR(100) NULL UNIQUE"))
                        _conn.commit()

                    # Phase 7: Additive face authentication columns for users table
                    _res_user = _conn.execute(text(
                        f"SELECT COLUMN_NAME FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = '{_db_name}' AND TABLE_NAME = 'users'"
                    ))
                    _user_cols = {row[0] for row in _res_user.fetchall()}
                    if _user_cols:
                        _user_additions = [
                            ('face_enrolled', "TINYINT(1) DEFAULT 0"),
                            ('face_enrolled_at', "VARCHAR(50) NULL"),
                            ('face_embedding_hash', "VARCHAR(128) NULL"),
                            ('face_embedding', "TEXT NULL")
                        ]
                        for col_name, col_def in _user_additions:
                            if col_name not in _user_cols:
                                _conn.execute(text(f"ALTER TABLE users ADD COLUMN {col_name} {col_def}"))
                                _conn.commit()

                # Phase 6: Additive check for SQLite databases
                if 'sqlite' in _db_uri or not _db_uri:
                    try:
                        _res_pragma_u = _conn.execute(text("PRAGMA table_info(users)"))
                        _sqlite_user_cols = {row[1] for row in _res_pragma_u.fetchall()}
                        if _sqlite_user_cols:
                            if 'face_enrolled' not in _sqlite_user_cols:
                                _conn.execute(text("ALTER TABLE users ADD COLUMN face_enrolled BOOLEAN DEFAULT 0"))
                            if 'face_enrolled_at' not in _sqlite_user_cols:
                                _conn.execute(text("ALTER TABLE users ADD COLUMN face_enrolled_at VARCHAR(50) NULL"))
                            if 'face_embedding_hash' not in _sqlite_user_cols:
                                _conn.execute(text("ALTER TABLE users ADD COLUMN face_embedding_hash VARCHAR(128) NULL"))
                            if 'face_embedding' not in _sqlite_user_cols:
                                _conn.execute(text("ALTER TABLE users ADD COLUMN face_embedding TEXT NULL"))
                            _conn.commit()
                    except Exception:
                        pass
                    try:
                        _res_pragma = _conn.execute(text("PRAGMA table_info(complaints)"))
                        _sqlite_comp_cols = {row[1] for row in _res_pragma.fetchall()}
                        if _sqlite_comp_cols and 'idempotency_key' not in _sqlite_comp_cols:
                            _conn.execute(text("ALTER TABLE complaints ADD COLUMN idempotency_key VARCHAR(100) NULL"))
                            _conn.execute(text("CREATE UNIQUE INDEX IF NOT EXISTS uq_complaints_idempotency_key ON complaints (idempotency_key)"))
                            _conn.commit()
                    except Exception:
                        pass

                    # ================================================================
                    # Phase 2: Non-destructive additive index creation for performance
                    # ================================================================
                    _perf_indexes = [
                        ('notification_deliveries', 'idx_nd_notice_user', ['notice_id', 'user_id']),
                        ('notices', 'idx_notices_status_created', ['status', 'created_at']),
                        ('complaints', 'idx_complaints_status_created', ['status', 'created_at']),
                        ('complaints', 'idx_complaints_category_location', ['category', 'location']),
                        ('meal_entries', 'idx_me_student_date_meal', ['student_id', 'entry_date', 'meal_type']),
                        ('meal_entries', 'idx_me_date_type_mode', ['entry_date', 'meal_type', 'verification_mode']),
                        ('attendance', 'idx_attendance_session_id', ['session_id']),
                        ('attendance', 'idx_attendance_user_id', ['user_id']),
                        ('sessions', 'idx_sessions_active_start', ['is_active', 'start_time']),
                        ('sessions', 'idx_sessions_course_branch_year', ['course', 'branch', 'year']),
                        ('gate_passes', 'idx_gp_student_status', ['student_id', 'status']),
                        ('document_requests', 'idx_doc_student_status', ['student_id', 'status']),
                        ('document_requests', 'idx_doc_type', ['document_type']),
                        ('fee_records', 'idx_fee_student_status', ['student_id', 'status']),
                        ('fee_records', 'idx_fee_due_date', ['due_date']),
                        ('class_updates', 'idx_cu_teacher_status', ['teacher_id', 'status']),
                        ('class_updates', 'idx_cu_branch_year', ['affected_branch', 'affected_year']),
                        ('class_updates', 'idx_cu_date', ['original_date']),
                        ('hostel_allocations', 'idx_ha_hostel_room', ['hostel_name', 'room_number']),
                        ('hostel_requests', 'idx_hr_student_status', ['student_id', 'status']),
                        ('hostel_assets', 'idx_h_assets_room', ['hostel_name', 'room_number']),
                        ('hostel_assets', 'idx_h_assets_student', ['assigned_student_id']),
                        ('asset_issues', 'idx_ai_asset_student', ['asset_id', 'student_id']),
                        ('asset_issues', 'idx_ai_status', ['status']),
                        ('visitor_requests', 'idx_vr_student_status', ['student_id', 'status']),
                        ('visitor_requests', 'idx_vr_date_status', ['visit_date', 'status']),
                        ('visitor_requests', 'idx_vr_pass_code', ['pass_code']),
                    ]
                    for table_name, index_name, columns in _perf_indexes:
                        try:
                            _idx_check = _conn.execute(text(
                                f"SELECT COUNT(*) FROM information_schema.STATISTICS "
                                f"WHERE TABLE_SCHEMA = '{_db_name}' AND TABLE_NAME = '{table_name}' "
                                f"AND INDEX_NAME = '{index_name}'"
                            ))
                            if _idx_check.scalar() == 0:
                                cols_str = ', '.join(columns)
                                _conn.execute(text(
                                    f"CREATE INDEX {index_name} ON {table_name} ({cols_str})"
                                ))
                                _conn.commit()
                        except Exception:
                            pass  # Table may not exist yet or index already exists under different name

        except Exception:
            # Schema verification gracefully falls back
            pass
