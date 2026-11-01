import datetime
import json
import uuid
from app import app, db, User, MessMenu, MessMeal

def seed_menus():
    with app.app_context():
        admin = User.query.filter_by(role='admin').first()
        admin_id = admin.id if admin else None
        
        today = datetime.date.today()
        dates_to_seed = [
            (today - datetime.timedelta(days=1), "Yesterday"),
            (today, "Today"),
            (today + datetime.timedelta(days=1), "Tomorrow"),
        ]
        
        created_count = 0
        now_iso = datetime.datetime.now().isoformat()
        
        for date_obj, label in dates_to_seed:
            date_str = date_obj.strftime('%Y-%m-%d')
            existing = MessMenu.query.filter_by(menu_date=date_str, status='PUBLISHED').first()
            if existing:
                print(f"[SKIP] Published menu already exists for {date_str} ({label})")
                continue
                
            menu = MessMenu(
                id=str(uuid.uuid4()),
                menu_date=date_str,
                status='PUBLISHED',
                created_by=admin_id,
                updated_by=admin_id,
                created_at=now_iso,
                updated_at=now_iso,
            )
            db.session.add(menu)
            
            meals_data = [
                {
                    "meal_type": "BREAKFAST",
                    "title": f"Morning Breakfast ({label})",
                    "description": "Nutritious breakfast buffet with fresh fruits, eggs, hot beverages, and traditional items.",
                    "items": ["Idli & Medu Vada", "Coconut Chutney & Sambar", "Kanda Poha", "Boiled Eggs / Sprouts", "Masala Tea & Filter Coffee"],
                    "availability": "AVAILABLE",
                    "display_order": 1,
                },
                {
                    "meal_type": "LUNCH",
                    "title": f"Executive Lunch Thali ({label})",
                    "description": "Wholesome lunch with paneer curry, dal tadka, fresh breads, and dessert.",
                    "items": ["Jeera Basmati Rice", "Tawa Phulkas", "Paneer Butter Masala", "Dal Tadka", "Green Salad & Boondi Raita", "Gulab Jamun"],
                    "availability": "AVAILABLE",
                    "display_order": 2,
                },
                {
                    "meal_type": "SNACKS",
                    "title": f"Evening High Tea ({label})",
                    "description": "Freshly fried hot snacks served with mint chutney and tea.",
                    "items": ["Aloo Samosa (2 pcs)", "Mint & Sweet Tamarind Chutney", "Assorted Biscuits", "Special Adrak Chai", "Instant Coffee"],
                    "availability": "AVAILABLE",
                    "display_order": 3,
                },
                {
                    "meal_type": "DINNER",
                    "title": f"Wholesome Dinner Spread ({label})",
                    "description": "Light and comforting dinner to end the day on a healthy note.",
                    "items": ["Steamed Rice", "Wheat Chapati", "Mix Veg Korma", "Dal Makhani", "Curd / Spiced Chaas", "Vanilla Ice Cream"],
                    "availability": "AVAILABLE",
                    "display_order": 4,
                },
            ]
            
            for m in meals_data:
                meal = MessMeal(
                    id=str(uuid.uuid4()),
                    menu_id=menu.id,
                    meal_type=m["meal_type"],
                    title=m["title"],
                    description=m["description"],
                    items=json.dumps(m["items"]),
                    availability=m["availability"],
                    display_order=m["display_order"],
                    created_at=now_iso,
                    updated_at=now_iso,
                )
                db.session.add(meal)
            
            created_count += 1
            print(f"[OK] Created published menu for {date_str} ({label}) with 4 meals.")
            
        db.session.commit()
        print(f"[SUCCESS] Seeded {created_count} published menus.")

if __name__ == '__main__':
    seed_menus()
