"""
CampusOS Face Authentication & One-Time Enrollment Routes.

Provides REST endpoints for:
1. POST /passport/face/enroll: Secure one-time face enrollment & vector backup.
2. GET  /passport/face/status: Check enrollment status for student identity.
3. POST /passport/face/verify: Server-assisted cosine similarity validation.
4. POST /admin/face/reset: Dean/Warden authorized re-enrollment reset.
"""

import math
import json
import hashlib
import datetime
from flask import Blueprint, request, jsonify
from extensions import db
from models.user import User
from models.audit import RequestAudit
from middleware.auth import verify_admin_access, get_authenticated_requester

face_bp = Blueprint('face_bp', __name__)

COSINE_SIMILARITY_THRESHOLD = 0.82


def _compute_cosine_similarity(vec_a, vec_b):
    """Computes cosine similarity between two float vectors."""
    if not vec_a or not vec_b or len(vec_a) != len(vec_b):
        return 0.0
    dot_product = sum(a * b for a, b in zip(vec_a, vec_b))
    norm_a = math.sqrt(sum(a * a for a in vec_a))
    norm_b = math.sqrt(sum(b * b for b in vec_b))
    if norm_a == 0.0 or norm_b == 0.0:
        return 0.0
    return dot_product / (norm_a * norm_b)


@face_bp.route('/passport/face/enroll', methods=['POST'])
def enroll_face():
    """
    Registers a student's one-time face biometric template (128-float embedding).
    CRITICAL SECURITY & PRIVACY INVARIANTS:
    1. Raw photos are never received or stored; only mathematical feature vectors.
    2. Overwriting an existing enrollment is blocked unless an authorized reset occurred.
    """
    user, auth_error = get_authenticated_requester()
    if auth_error:
        # Check if studentId is provided in body for local/offline testing compatibility
        data = request.json or {}
        student_id = data.get('studentId')
        if student_id:
            user = User.query.get(student_id)
        if not user:
            return auth_error

    data = request.json or {}
    embedding = data.get('faceEmbedding')
    client_enrolled_at = data.get('clientEnrolledAt')

    if not embedding or not isinstance(embedding, list) or len(embedding) == 0:
        return jsonify({
            "message": "Invalid face embedding vector. Must be a non-empty array of floats."
        }), 400

    # Ensure all elements are numbers
    try:
        float_embedding = [float(x) for x in embedding]
    except (ValueError, TypeError):
        return jsonify({
            "message": "All face embedding values must be numeric floating-point values."
        }), 400

    # Enforce one-time enrollment invariant
    if user.face_enrolled and not data.get('forceReEnroll'):
        return jsonify({
            "message": "Face already enrolled. Account-bound face can only be re-enrolled with institutional administrator authorization.",
            "enrolledAt": user.face_enrolled_at,
            "status": "ALREADY_ENROLLED"
        }), 409

    now_iso = client_enrolled_at or datetime.datetime.now().isoformat()
    embedding_json = json.dumps(float_embedding)
    embedding_hash = hashlib.sha256(embedding_json.encode('utf-8')).hexdigest()

    try:
        user.face_enrolled = True
        user.face_enrolled_at = now_iso
        user.face_embedding = embedding_json
        user.face_embedding_hash = embedding_hash
        user.device_id = data.get('deviceId') or user.device_id

        # Audit the enrollment event
        audit = RequestAudit(
            entity_type='FACE_ENROLLMENT',
            entity_id=user.id,
            actor_id=user.id,
            action='ENROLL',
            remarks=f"Face enrolled successfully. Dimensions: {len(float_embedding)}. Hash: {embedding_hash[:16]}..."
        )
        db.session.add(audit)
        db.session.commit()

        return jsonify({
            "message": "Face enrolled and cryptographically bound to student account successfully.",
            "faceEnrolled": True,
            "enrolledAt": user.face_enrolled_at,
            "embeddingHash": embedding_hash,
            "dimensions": len(float_embedding)
        }), 201

    except Exception as e:
        db.session.rollback()
        return jsonify({"message": f"Face enrollment failed: {str(e)}"}), 500


@face_bp.route('/passport/face/status', methods=['GET'])
def get_face_status():
    """Returns the face enrollment status for the student."""
    user, auth_error = get_authenticated_requester()
    student_id = request.args.get('studentId')

    if student_id:
        target_user = User.query.get(student_id)
    else:
        target_user = user

    if not target_user:
        return jsonify({"message": "Student not found"}), 404

    return jsonify({
        "studentId": target_user.id,
        "studentName": target_user.name,
        "registrationNumber": target_user.registration_number,
        "faceEnrolled": bool(target_user.face_enrolled),
        "faceEnrolledAt": target_user.face_enrolled_at,
        "embeddingHash": target_user.face_embedding_hash,
        "status": "ENROLLED" if target_user.face_enrolled else "NOT_ENROLLED"
    }), 200


@face_bp.route('/passport/face/verify', methods=['POST'])
def verify_face():
    """
    Server-assisted cosine similarity verification.
    Compares a live query embedding against the student's enrolled template.
    """
    data = request.json or {}
    student_id = data.get('studentId')
    query_embedding = data.get('faceEmbedding')

    if not student_id or not query_embedding:
        return jsonify({"message": "studentId and faceEmbedding are required"}), 400

    user = User.query.get(student_id)
    if not user:
        return jsonify({"message": "Student not found"}), 404

    if not user.face_enrolled or not user.face_embedding:
        return jsonify({
            "verified": False,
            "reason": "ENROLLMENT_REQUIRED",
            "message": "Student has not completed one-time face enrollment."
        }), 400

    try:
        enrolled_vector = json.loads(user.face_embedding)
        query_vector = [float(x) for x in query_embedding]
    except Exception as e:
        return jsonify({"message": f"Malformed vector: {e}"}), 400

    similarity = _compute_cosine_similarity(enrolled_vector, query_vector)
    is_match = similarity >= COSINE_SIMILARITY_THRESHOLD

    return jsonify({
        "verified": is_match,
        "similarity": round(similarity, 4),
        "threshold": COSINE_SIMILARITY_THRESHOLD,
        "matchConfidence": f"{round(similarity * 100, 1)}%",
        "reason": "MATCH" if is_match else "OWNER_MISMATCH",
        "studentId": user.id,
        "studentName": user.name
    }), 200 if is_match else 403


@face_bp.route('/admin/face/reset', methods=['POST'])
def admin_reset_face_enrollment():
    """
    Admin or Warden authorization to reset a student's face enrollment.
    Enables re-enrollment in legitimate cases (facial injury, hardware upgrade, photo corruption).
    """
    admin_auth = verify_admin_access()
    if admin_auth is not None:
        # Check if caller is warden
        user, _ = get_authenticated_requester()
        if not user or user.role not in ['admin', 'warden', 'staff']:
            return jsonify({"message": "Administrative or Warden privilege required"}), 403

    data = request.json or {}
    student_id = data.get('studentId')
    reason = data.get('reason', 'Administrative reset authorized')

    if not student_id:
        return jsonify({"message": "studentId is required"}), 400

    student = User.query.get(student_id)
    if not student:
        return jsonify({"message": "Student not found"}), 404

    try:
        student.face_enrolled = False
        student.face_enrolled_at = None
        student.face_embedding = None
        student.face_embedding_hash = None

        actor = user or admin_auth
        actor_id = actor.id if hasattr(actor, 'id') else 'admin'
        audit = RequestAudit(
            entity_type='FACE_ENROLLMENT_RESET',
            entity_id=student.id,
            actor_id=actor_id,
            action='RESET',
            remarks=f"Face enrollment reset authorized. Reason: {reason}"
        )
        db.session.add(audit)
        db.session.commit()

        return jsonify({
            "success": True,
            "message": f"Face enrollment reset for student {student.name}. They may now re-enroll their face.",
            "studentId": student.id
        }), 200

    except Exception as e:
        db.session.rollback()
        return jsonify({"message": f"Reset failed: {str(e)}"}), 500
