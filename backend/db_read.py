from sqlalchemy import create_engine, text
from config import Config

engine = create_engine(Config.SQLALCHEMY_DATABASE_URI)
with engine.connect() as con:
    print("--- USERS ---")
    rs = con.execute(text('SELECT id, name, role FROM users LIMIT 5;'))
    for row in rs:
        print(dict(row._mapping))
    
    print("\n--- SESSIONS ---")
    rs = con.execute(text('SELECT id, name, is_active FROM sessions LIMIT 5;'))
    for row in rs:
        print(dict(row._mapping))

    print("\n--- ATTENDANCE ---")
    rs = con.execute(text('SELECT * FROM attendance LIMIT 5;'))
    for row in rs:
        print(dict(row._mapping))
