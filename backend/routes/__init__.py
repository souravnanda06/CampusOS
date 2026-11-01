from routes.auth import auth_bp
from routes.attendance import attendance_bp
from routes.leave import leave_bp
from routes.warden import warden_bp
from routes.gate_pass import gate_pass_bp
from routes.security import security_bp
from routes.complaints import complaints_bp
from routes.admin import admin_bp
from routes.notices import notices_bp
from routes.mess import mess_bp
from routes.passport import passport_bp
from routes.documents import documents_bp
from routes.fees import fees_bp
from routes.academic_updates import academic_updates_bp
from routes.hostel import hostel_bp
from routes.visitors import visitors_bp
from routes.notifications import notifications_bp
from routes.search import search_bp
from routes.face import face_bp

def register_routes(app):
    """
    Registers all application blueprints onto the Flask app instance.
    Preserves exact URL prefixes and endpoints for zero client breakage.
    """
    app.register_blueprint(auth_bp)
    app.register_blueprint(attendance_bp)
    app.register_blueprint(leave_bp)
    app.register_blueprint(warden_bp)
    app.register_blueprint(gate_pass_bp)
    app.register_blueprint(security_bp)
    app.register_blueprint(complaints_bp)
    app.register_blueprint(admin_bp)
    app.register_blueprint(notices_bp)
    app.register_blueprint(mess_bp)
    app.register_blueprint(passport_bp)
    app.register_blueprint(face_bp)
    app.register_blueprint(documents_bp)
    app.register_blueprint(fees_bp)
    app.register_blueprint(academic_updates_bp)
    app.register_blueprint(hostel_bp)
    app.register_blueprint(visitors_bp)
    app.register_blueprint(notifications_bp)
    app.register_blueprint(search_bp)
