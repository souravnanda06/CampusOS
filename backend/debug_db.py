from app import app, db, Session, User

with app.app_context():
    print("--- USERS ---")
    users = User.query.all()
    for u in users:
        print(f"User: {u.name} ({u.email}) - Role: {u.role}")

    print("\n--- SESSIONS ---")
    sessions = Session.query.all()
    if not sessions:
        print("No sessions found in DB.")
    for s in sessions:
        print(f"Session: {s.name}, Instructor: '{s.instructor_name}', Date: {s.start_time}, Active: {s.is_active}")
