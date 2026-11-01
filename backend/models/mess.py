import uuid
import datetime
import json
from extensions import db

SUPPORTED_FEEDBACK_CATEGORIES = {
    'FOOD_QUALITY',
    'TASTE',
    'VARIETY',
    'PORTION',
    'CLEANLINESS',
    'TIMING',
    'AVAILABILITY',
    'OTHER'
}

class MessMenu(db.Model):
    __tablename__ = 'mess_menus'
    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    menu_date = db.Column(db.String(10), nullable=False, index=True)  # YYYY-MM-DD
    status = db.Column(db.String(20), nullable=False, default='DRAFT')  # DRAFT, PUBLISHED, ARCHIVED
    created_by = db.Column(db.String(36), db.ForeignKey('users.id'), nullable=True)
    updated_by = db.Column(db.String(36), db.ForeignKey('users.id'), nullable=True)
    created_at = db.Column(db.String(50), default=lambda: datetime.datetime.now().isoformat())
    updated_at = db.Column(db.String(50), default=lambda: datetime.datetime.now().isoformat())

    meals = db.relationship('MessMeal', backref='menu', cascade='all, delete-orphan', lazy='joined', order_by='MessMeal.display_order')

    def to_dict(self):
        sorted_meals = sorted(self.meals, key=lambda m: (m.display_order, m.meal_type))
        return {
            "id": self.id,
            "menuDate": self.menu_date,
            "status": self.status or "DRAFT",
            "createdBy": self.created_by,
            "updatedBy": self.updated_by,
            "createdAt": self.created_at,
            "updatedAt": self.updated_at,
            "meals": [m.to_dict() for m in sorted_meals]
        }

class MessMeal(db.Model):
    __tablename__ = 'mess_meals'
    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    menu_id = db.Column(db.String(36), db.ForeignKey('mess_menus.id', ondelete='CASCADE'), nullable=False, index=True)
    meal_type = db.Column(db.String(20), nullable=False)  # BREAKFAST, LUNCH, SNACKS, DINNER
    title = db.Column(db.String(100), nullable=True)
    description = db.Column(db.Text, nullable=True)
    items = db.Column(db.Text, nullable=False, default='[]')
    availability = db.Column(db.String(20), nullable=False, default='AVAILABLE')  # AVAILABLE, LIMITED, UNAVAILABLE
    display_order = db.Column(db.Integer, nullable=False, default=1)
    created_at = db.Column(db.String(50), default=lambda: datetime.datetime.now().isoformat())
    updated_at = db.Column(db.String(50), default=lambda: datetime.datetime.now().isoformat())

    def get_items_list(self):
        if not self.items:
            return []
        try:
            val = json.loads(self.items)
            return val if isinstance(val, list) else [str(val)]
        except Exception:
            return [x.strip() for x in self.items.split(',') if x.strip()]

    def to_dict(self):
        return {
            "id": self.id,
            "menuId": self.menu_id,
            "mealType": self.meal_type,
            "title": self.title or self.meal_type.capitalize(),
            "description": self.description or "",
            "items": self.get_items_list(),
            "availability": self.availability or "AVAILABLE",
            "displayOrder": self.display_order,
            "createdAt": self.created_at,
            "updatedAt": self.updated_at
        }

class MessFeedback(db.Model):
    __tablename__ = 'mess_feedback'
    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    menu_id = db.Column(db.String(36), db.ForeignKey('mess_menus.id', ondelete='CASCADE'), nullable=False, index=True)
    meal_id = db.Column(db.String(36), db.ForeignKey('mess_meals.id', ondelete='CASCADE'), nullable=False, index=True)
    student_id = db.Column(db.String(36), db.ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True)
    rating = db.Column(db.Integer, nullable=False, index=True)
    category = db.Column(db.String(32), nullable=True, index=True)
    comment = db.Column(db.Text, nullable=True)
    created_at = db.Column(db.String(50), default=lambda: datetime.datetime.now().isoformat())
    updated_at = db.Column(db.String(50), default=lambda: datetime.datetime.now().isoformat())

    __table_args__ = (
        db.UniqueConstraint('meal_id', 'student_id', name='uq_mess_feedback_meal_student'),
    )

    menu = db.relationship('MessMenu', backref=db.backref('feedbacks', cascade='all, delete-orphan', lazy='dynamic'))
    meal = db.relationship('MessMeal', backref=db.backref('feedbacks', cascade='all, delete-orphan', lazy='dynamic'))
    student = db.relationship('User', backref=db.backref('mess_feedbacks', cascade='all, delete-orphan', lazy='dynamic'))

    def to_dict(self, anonymize=False):
        d = {
            "id": self.id,
            "menuId": self.menu_id,
            "mealId": self.meal_id,
            "rating": self.rating,
            "category": self.category,
            "comment": self.comment or "",
            "createdAt": self.created_at,
            "updatedAt": self.updated_at
        }
        if not anonymize:
            d["studentId"] = self.student_id
        if self.meal:
            d["mealType"] = self.meal.meal_type
            d["mealTitle"] = self.meal.title or self.meal.meal_type.capitalize()
        if self.menu:
            d["menuDate"] = self.menu.menu_date
        return d

class MealEntry(db.Model):
    """
    CampusOS Mess Meal Entry Model.
    Tracks cryptographically verified student dining entries for batch and QR verification modes.
    Enforces idempotency and prevents double-check-in per student per meal per day.
    """
    __tablename__ = 'meal_entries'

    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    menu_id = db.Column(db.String(36), nullable=True)
    meal_id = db.Column(db.String(36), nullable=True)
    meal_type = db.Column(db.String(20), nullable=False)  # BREAKFAST, LUNCH, SNACKS, DINNER
    entry_date = db.Column(db.String(10), nullable=False, index=True)  # YYYY-MM-DD
    student_id = db.Column(db.String(36), db.ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True)
    student_name = db.Column(db.String(100), nullable=False)
    registration_number = db.Column(db.String(50), nullable=True)
    verified_by = db.Column(db.String(36), nullable=False)  # Verifier user ID
    verification_mode = db.Column(db.String(32), default='BATCH')  # BATCH, QR_FALLBACK
    idempotency_key = db.Column(db.String(128), unique=True, nullable=True, index=True)
    device_key_id = db.Column(db.String(64), nullable=True)
    response_nonce = db.Column(db.String(64), nullable=True)
    status = db.Column(db.String(20), default='VERIFIED')
    created_at = db.Column(db.String(50), default=lambda: datetime.datetime.now().isoformat())

    __table_args__ = (
        db.Index('idx_me_student_date_meal', 'student_id', 'entry_date', 'meal_type'),
        db.Index('idx_me_date_type_mode', 'entry_date', 'meal_type', 'verification_mode'),
    )

    student = db.relationship('User', foreign_keys=[student_id], backref=db.backref('meal_entries', cascade='all, delete-orphan', lazy='dynamic'))

    def to_dict(self):
        return {
            "id": self.id,
            "menuId": self.menu_id,
            "mealId": self.meal_id,
            "mealType": self.meal_type,
            "entryDate": self.entry_date,
            "studentId": self.student_id,
            "studentName": self.student_name,
            "registrationNumber": self.registration_number,
            "verifiedBy": self.verified_by,
            "verificationMode": self.verification_mode,
            "idempotencyKey": self.idempotency_key,
            "deviceKeyId": self.device_key_id,
            "responseNonce": self.response_nonce,
            "status": self.status,
            "createdAt": self.created_at
        }

