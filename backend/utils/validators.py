import datetime
import json

SUPPORTED_MEAL_TYPES = {'BREAKFAST', 'LUNCH', 'SNACKS', 'DINNER'}
SUPPORTED_MEAL_AVAILABILITIES = {'AVAILABLE', 'LIMITED', 'UNAVAILABLE'}
SUPPORTED_MENU_STATUSES = {'DRAFT', 'PUBLISHED', 'ARCHIVED'}
MEAL_ORDER_MAP = {
    'BREAKFAST': 1,
    'LUNCH': 2,
    'SNACKS': 3,
    'DINNER': 4
}

def parse_and_validate_menu_date(date_str):
    if not date_str or not isinstance(date_str, str):
        return None, "menuDate is required"
    date_str = date_str.strip()
    try:
        parsed = datetime.date.fromisoformat(date_str)
        return parsed.strftime('%Y-%m-%d'), None
    except Exception:
        return None, "Invalid menuDate format. Expected YYYY-MM-DD"

def validate_meals_payload(meals_data):
    if not isinstance(meals_data, list):
        return None, "meals must be a list of meal objects"

    seen_types = set()
    validated_meals = []

    for idx, meal in enumerate(meals_data):
        if not isinstance(meal, dict):
            return None, f"Meal at index {idx} must be a JSON object"

        raw_type = meal.get('mealType') or meal.get('meal_type')
        if not raw_type or not isinstance(raw_type, str):
            return None, f"mealType is required for meal at index {idx}"

        meal_type = raw_type.strip().upper()
        if meal_type not in SUPPORTED_MEAL_TYPES:
            return None, f"Invalid mealType '{meal_type}'. Must be one of: {sorted(list(SUPPORTED_MEAL_TYPES))}"

        if meal_type in seen_types:
            return None, f"Duplicate mealType '{meal_type}' is not allowed within the same menu"
        seen_types.add(meal_type)

        raw_items = meal.get('items')
        if raw_items is None:
            return None, f"items list is required for meal {meal_type}"

        if isinstance(raw_items, str):
            try:
                parsed_items = json.loads(raw_items)
            except Exception:
                parsed_items = [x.strip() for x in raw_items.split(',') if x.strip()]
        elif isinstance(raw_items, list):
            parsed_items = raw_items
        else:
            return None, f"items must be a list for meal {meal_type}"

        cleaned_items = [str(item).strip() for item in parsed_items if item is not None and str(item).strip()]
        if not cleaned_items:
            return None, f"items cannot be empty for meal {meal_type}"

        raw_avail = meal.get('availability', 'AVAILABLE')
        if not raw_avail or not isinstance(raw_avail, str):
            return None, f"Invalid availability for meal {meal_type}"
        availability = raw_avail.strip().upper()
        if availability not in SUPPORTED_MEAL_AVAILABILITIES:
            return None, f"Invalid availability '{availability}'. Must be one of: {sorted(list(SUPPORTED_MEAL_AVAILABILITIES))}"

        title = (meal.get('title') or meal_type.capitalize()).strip()
        description = (meal.get('description') or '').strip()

        display_order = meal.get('displayOrder') or meal.get('display_order')
        if display_order is None or not isinstance(display_order, int):
            display_order = MEAL_ORDER_MAP.get(meal_type, idx + 1)

        validated_meals.append({
            "meal_type": meal_type,
            "title": title,
            "description": description,
            "items": cleaned_items,
            "availability": availability,
            "display_order": display_order
        })

    return validated_meals, None
