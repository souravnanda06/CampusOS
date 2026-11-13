import base64
import os
import sys
import time
import uuid
from cryptography.hazmat.primitives.asymmetric import ed25519

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app import app, db, User, DeviceIdentityKey
from models.mesh_chat import MeshChannel, MeshMessage, MeshModerationFlag, MeshAccountRestriction
from services.mesh_moderation_service import build_mesh_packet_signable_bytes, moderate_text
from utils.crypto import create_access_token


def run_tests():
    print("==================================================")
    print("CAMPUSOS MESH CHAT — SQLITE SYNC & ADMIN CONTROL")
    print("==================================================")

    client = app.test_client()
    created_user_ids = []
    created_key_ids = []
    created_msg_ids = []
    created_channel_ids = []
    created_flag_ids = []

    try:
        # 1. Moderation rules checks
        clean = moderate_text("Anyone up for DBMS study session at library?")
        assert clean["moderationStatus"] == "CLEAN", clean

        bomb = moderate_text("I will plant a b0mb in block b")
        assert bomb["moderationStatus"] == "QUARANTINED", bomb
        assert bomb["moderationSeverity"] == "CRITICAL", bomb

        gun = moderate_text("bringing a gun")
        assert gun["moderationStatus"] == "QUARANTINED", gun

        # 2. Health check uses SQLite directly
        health = client.get("/mesh-chat/health")
        assert health.status_code == 200, health.get_json()
        assert health.get_json()["connected"] is True
        assert health.get_json()["storage"] == "sqlite"

        with app.app_context():
            alice = User(
                id=f"test_alice_{uuid.uuid4().hex[:6]}",
                email=f"alice_{uuid.uuid4().hex[:6]}@campusos.test",
                password="pw",
                name="Alice Mesh",
                role="student",
            )
            bob = User(
                id=f"test_bob_{uuid.uuid4().hex[:6]}",
                email=f"bob_{uuid.uuid4().hex[:6]}@campusos.test",
                password="pw",
                name="Bob Mesh",
                role="student",
            )
            admin = User(
                id=f"test_admin_{uuid.uuid4().hex[:6]}",
                email=f"admin_{uuid.uuid4().hex[:6]}@campusos.test",
                password="pw",
                name="Admin Mesh",
                role="admin",
            )
            db.session.add_all([alice, bob, admin])
            db.session.commit()
            created_user_ids.extend([alice.id, bob.id, admin.id])

            alice_priv = ed25519.Ed25519PrivateKey.generate()
            alice_pub_b64 = base64.b64encode(alice_priv.public_key().public_bytes_raw()).decode("ascii")
            alice_key = DeviceIdentityKey(
                id=f"key_{uuid.uuid4().hex[:10]}",
                user_id=alice.id,
                public_key_b64=alice_pub_b64,
                key_type="ED25519",
                status="ACTIVE",
            )
            db.session.add(alice_key)
            db.session.commit()
            created_key_ids.append(alice_key.id)

            alice_token = create_access_token(alice)
            bob_token = create_access_token(bob)
            admin_token = create_access_token(admin)

            now_ms = int(time.time() * 1000)
            msg_id_1 = uuid.uuid4().hex
            created_msg_ids.append(msg_id_1)
            payload_bytes = b'{"cid":"channel:general","txt":"Notes uploaded for OS lab!"}'
            signable = build_mesh_packet_signable_bytes(
                packet_id_hex=msg_id_1,
                packet_type_code=0x01,
                initial_hop_budget=7,
                timestamp_ms=now_ms,
                sender_device_id=alice.id,
                sender_role="student",
                payload_bytes=payload_bytes,
            )
            sig_b64 = base64.b64encode(alice_priv.sign(signable)).decode("ascii")

            res = client.post(
                "/mesh-chat/sync",
                headers={"Authorization": f"Bearer {alice_token}"},
                json={
                    "messages": [
                        {
                            "messageId": msg_id_1,
                            "channelId": "channel:general",
                            "senderDeviceId": alice.id,
                            "senderUserId": alice.id,
                            "senderDisplayName": "Alice Mesh",
                            "senderRole": "student",
                            "text": "Notes uploaded for OS lab!",
                            "createdAt": now_ms,
                            "hopCount": 0,
                            "ttl": 7,
                            "payloadBase64": base64.b64encode(payload_bytes).decode("ascii"),
                            "signatureBase64": sig_b64,
                        }
                    ]
                },
            )
            assert res.status_code == 200, res.get_json()
            assert res.get_json()["verdicts"][msg_id_1]["signatureVerified"] is True

            # Relayed public mesh message from uncertified peer (honest data-mule relay)
            relayed_id = uuid.uuid4().hex
            created_msg_ids.append(relayed_id)
            res_relay = client.post(
                "/mesh-chat/sync",
                headers={"Authorization": f"Bearer {bob_token}"},
                json={
                    "messages": [
                        {
                            "messageId": relayed_id,
                            "channelId": "channel:general",
                            "senderDeviceId": "peer_device_12345",
                            "senderUserId": "peer_user_12345",
                            "senderDisplayName": "Charlie Peer",
                            "senderRole": "student",
                            "text": "Anyone seen my calculator in lab?",
                            "createdAt": now_ms + 50,
                            "hopCount": 1,
                            "ttl": 6,
                        }
                    ]
                },
            )
            assert res_relay.status_code == 200, res_relay.get_json()
            assert relayed_id in res_relay.get_json()["syncedIds"]
            assert res_relay.get_json()["verdicts"][relayed_id]["signatureVerified"] is False

            # Crime / threat message is auto-flagged & enriched with reportedUser + matchedPatterns
            threat_id = uuid.uuid4().hex
            created_msg_ids.append(threat_id)
            created_flag_ids.append(f"auto_{threat_id}")
            res_threat = client.post(
                "/mesh-chat/sync",
                headers={"Authorization": f"Bearer {bob_token}"},
                json={
                    "messages": [
                        {
                            "messageId": threat_id,
                            "channelId": "channel:general",
                            "senderDeviceId": bob.id,
                            "senderUserId": bob.id,
                            "senderDisplayName": "Bob Mesh",
                            "senderRole": "student",
                            "text": "going to bring a gun to campus tomorrow",
                            "createdAt": now_ms + 100,
                        }
                    ]
                },
            )
            assert res_threat.status_code == 200
            assert res_threat.get_json()["verdicts"][threat_id]["moderationStatus"] == "QUARANTINED"

            flags_res = client.get(
                "/mesh-chat/admin/flags",
                headers={"Authorization": f"Bearer {admin_token}"},
            )
            assert flags_res.status_code == 200
            flags_payload = flags_res.get_json()["flags"]
            target_flag = next(f for f in flags_payload if f["messageId"] == threat_id)
            assert target_flag["reportedUser"]["name"] == "Bob Mesh"
            assert len(target_flag["matchedPatterns"]) >= 1

            # Flagged Accounts listing + Restrict + Block check + Restore
            accounts_res = client.get(
                "/mesh-chat/admin/accounts",
                headers={"Authorization": f"Bearer {admin_token}"},
            )
            assert accounts_res.status_code == 200
            bob_acct = next(a for a in accounts_res.get_json()["accounts"] if a["userId"] == bob.id)
            assert bob_acct["totalFlags"] >= 1
            assert bob_acct["accountStatus"] == "ACTIVE"

            restrict_res = client.patch(
                f"/mesh-chat/admin/flags/{target_flag['flagId']}",
                headers={"Authorization": f"Bearer {admin_token}"},
                json={"action": "RESTRICT_ACCOUNT", "notes": "Weapon threat in #general"},
            )
            assert restrict_res.status_code == 200
            assert restrict_res.get_json()["flag"]["reportedUser"]["accountStatus"] == "RESTRICTED"

            blocked_res = client.post(
                "/mesh-chat/sync",
                headers={"Authorization": f"Bearer {bob_token}"},
                json={
                    "messages": [
                        {
                            "messageId": uuid.uuid4().hex,
                            "channelId": "channel:general",
                            "text": "Should be rejected",
                            "createdAt": now_ms + 300,
                        }
                    ]
                },
            )
            assert blocked_res.status_code == 200
            assert len(blocked_res.get_json()["rejected"]) == 1

            restore_res = client.patch(
                f"/mesh-chat/admin/accounts/{bob.id}",
                headers={"Authorization": f"Bearer {admin_token}"},
                json={"action": "RESTORE", "reason": "Reviewed and cleared"},
            )
            assert restore_res.status_code == 200
            assert restore_res.get_json()["account"]["accountStatus"] == "ACTIVE"

            # Admin moderates a message directly from channel feed
            mod_msg_res = client.post(
                f"/mesh-chat/admin/messages/{msg_id_1}/moderate",
                headers={"Authorization": f"Bearer {admin_token}"},
                json={"category": "SPAM", "severity": "MODERATE", "reason": "Off-topic test", "hideMessage": True},
            )
            assert mod_msg_res.status_code == 201
            created_flag_ids.append(mod_msg_res.get_json()["flag"]["flagId"])

        print("[PASS] All Mesh Chat SQLite + Admin Moderation Control tests passed!")
    finally:
        with app.app_context():
            for fid in created_flag_ids:
                f = db.session.get(MeshModerationFlag, fid)
                if f:
                    db.session.delete(f)
            for mid in created_msg_ids:
                m = db.session.get(MeshMessage, mid)
                if m:
                    db.session.delete(m)
            for cid in created_channel_ids:
                c = db.session.get(MeshChannel, cid)
                if c:
                    db.session.delete(c)
            for kid in created_key_ids:
                k = db.session.get(DeviceIdentityKey, kid)
                if k:
                    db.session.delete(k)
            for uid in created_user_ids:
                r = db.session.get(MeshAccountRestriction, uid)
                if r:
                    db.session.delete(r)
                u = db.session.get(User, uid)
                if u:
                    db.session.delete(u)
            db.session.commit()


if __name__ == "__main__":
    run_tests()
