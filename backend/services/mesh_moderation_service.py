import base64
import re
import struct
import unicodedata
from typing import Any, Dict, List, Optional, Tuple
from cryptography.hazmat.primitives.asymmetric import ed25519
from cryptography.exceptions import InvalidSignature


# Zero-width & invisible characters often used to evade text filters
_INVISIBLE_RE = re.compile(r"[\u200b-\u200f\u202a-\u202e\ufeff]")
_NON_ALNUM_SPACE_RE = re.compile(r"[^a-z0-9\s]")
_MULTI_SPACE_RE = re.compile(r"\s+")

_LEET_MAP = str.maketrans({
    "0": "o",
    "1": "i",
    "3": "e",
    "4": "a",
    "5": "s",
    "7": "t",
    "8": "b",
    "@": "a",
    "$": "s",
    "!": "i",
})


def normalize_for_moderation(text: str) -> Tuple[str, str]:
    """
    Normalizes text to catch leetspeak, zero-width obfuscation, and symbol-separated words.
    Returns (spaced_normalized, compact_normalized).
    """
    if not text:
        return "", ""
    decomposed = unicodedata.normalize("NFKD", text)
    stripped = _INVISIBLE_RE.sub("", decomposed).lower().translate(_LEET_MAP)
    spaced = _NON_ALNUM_SPACE_RE.sub(" ", stripped)
    spaced = _MULTI_SPACE_RE.sub(" ", spaced).strip()
    compact = spaced.replace(" ", "")
    return spaced, compact


# Rule definitions: (category, severity, label, compiled_regex_on_spaced, compact_substrings)
_MODERATION_RULES: List[Tuple[str, str, str, re.Pattern, Tuple[str, ...]]] = [
    (
        "CRIME_THREAT",
        "CRITICAL",
        "Explosive / Bomb / Arson Threat",
        re.compile(
            r"\b(bomb|ied|explosive|detonate|blow\s+up|plant\s+a\s+bomb|burn\s+down|arson|pipe\s+bomb|grenade|molotov)\b"
        ),
        ("plantabomb", "pipebomb", "blowupthe"),
    ),
    (
        "CRIME_THREAT",
        "CRITICAL",
        "Armed Violence / Weapon / Murder Threat",
        re.compile(
            r"\b(gun|pistol|rifle|shotgun|firearm|weapon|knife|dagger|stab|shoot|shooting|mass\s+shoot|kill|murder|assassinate|slit|kidnap|abduct|hostage|rape|molest|sexual\s+assault|robbery)\b"
        ),
        ("shootupcampus", "bringagun", "killyou", "murderyou", "stabyou"),
    ),
    (
        "CRIME_THREAT",
        "CRITICAL",
        "Self-Harm / Suicide Risk",
        re.compile(
            r"\b(suicide|kill\s+myself|commit\s+suicide|end\s+my\s+life|want\s+to\s+die|self\s+harm)\b"
        ),
        ("killmyself", "commitsuicide", "endmylife", "selfharm"),
    ),
    (
        "CRIME_THREAT",
        "CRITICAL",
        "Illegal Drugs / Narcotics",
        re.compile(
            r"\b(weed|ganja|charas|marijuana|cocaine|meth|heroin|mdma|lsd|fentanyl|narcotics|drug\s+deal(?:er|ing)?|sell(?:ing)?\s+drugs|buy\s+drugs)\b"
        ),
        ("selldrugs", "drugdealer", "buycocaine", "buymeth"),
    ),
    (
        "CRIME_THREAT",
        "HIGH",
        "Extortion / Theft / Fraud",
        re.compile(
            r"\b(blackmail|extort|ransom|rob|theft|steal|burglary|assault|threaten|doxx|bribe|scam|fraud|leak\s+(?:your|her|his)\s+(?:nudes|photos|address)|pay\s+me\s+or\s+else)\b"
        ),
        ("blackmail", "extort", "leaknudes"),
    ),
    (
        "HARASSMENT",
        "HIGH",
        "Severe Harassment / Hate Slur",
        re.compile(
            r"\b(faggot|nigger|retard|kys|kill\s+yourself|die\s+bitch|worthless\s+piece\s+of\s+shit)\b"
        ),
        ("killyourself",),
    ),
    (
        "HARASSMENT",
        "MODERATE",
        "Abusive / Profane Language",
        re.compile(
            r"\b(fuck|fucking|fucker|motherfucker|shit|bullshit|asshole|bitch|bastard|slut|whore|cunt|dick|idiot|stupid|moron|chutiya|madarchod|behenchod|bhosdike|gandu|harami|kamina)\b"
        ),
        ("motherfucker", "madarchod", "behenchod"),
    ),
    (
        "EXPLICIT",
        "MODERATE",
        "Sexually Explicit Content",
        re.compile(
            r"\b(nudes|send\s+nudes|onlyfans|porn|xxx|sex\s+tape)\b"
        ),
        ("sendnudes", "sextape"),
    ),
    (
        "SPAM",
        "MODERATE",
        "Suspected Scam / Phishing",
        re.compile(
            r"\b(guaranteed\s+crypto\s+profit|double\s+your\s+money|send\s+otp|share\s+your\s+password|click\s+to\s+claim\s+prize)\b"
        ),
        ("sendotp", "doubleyourmoney"),
    ),
]

_SEVERITY_ORDER = {
    "NONE": 0,
    "MODERATE": 1,
    "HIGH": 2,
    "CRITICAL": 3,
}


def moderate_text(text: str, is_encrypted: bool = False) -> Dict[str, Any]:
    """
    Evaluates chat text for crime threats, harassment, explicit content, or scams.
    Encrypted DMs cannot be inspected server-side and return CLEAN (client-side checks apply before encryption).
    """
    if is_encrypted or not text or not text.strip():
        return {
            "moderationStatus": "CLEAN",
            "moderationSeverity": "NONE",
            "category": "NONE",
            "flagReasons": [],
        }

    spaced, compact = normalize_for_moderation(text)
    matched_reasons: List[str] = []
    highest_severity = "NONE"
    primary_category = "NONE"

    for category, severity, label, pattern, compact_terms in _MODERATION_RULES:
        hit = bool(pattern.search(spaced))
        if not hit and compact_terms:
            hit = any(term in compact for term in compact_terms)
        if hit:
            matched_reasons.append(label)
            if _SEVERITY_ORDER[severity] > _SEVERITY_ORDER[highest_severity]:
                highest_severity = severity
                primary_category = category

    if highest_severity == "NONE":
        status = "CLEAN"
    elif highest_severity in ("CRITICAL", "HIGH"):
        status = "QUARANTINED"
    else:
        status = "FLAGGED"

    return {
        "moderationStatus": status,
        "moderationSeverity": highest_severity,
        "category": primary_category,
        "flagReasons": matched_reasons,
    }


def build_mesh_packet_signable_bytes(
    *,
    packet_id_hex: str,
    packet_type_code: int,
    initial_hop_budget: int,
    timestamp_ms: int,
    sender_device_id: str,
    sender_role: str,
    payload_bytes: bytes,
    magic: int = 0xCA,
) -> bytes:
    """
    Reconstructs the exact canonical signable bytes produced by Dart's `MeshPacket.getSignableBytes()`.
    """
    packet_id = bytes.fromhex(packet_id_hex)
    if len(packet_id) != 16:
        raise ValueError("packetIdHex must decode to exactly 16 bytes")

    sender_bytes = sender_device_id.encode("latin1")
    role_bytes = sender_role.encode("latin1")

    buf = bytearray()
    buf.append(magic & 0xFF)
    buf.append(packet_type_code & 0xFF)
    buf.append(initial_hop_budget & 0xFF)
    buf.extend(packet_id)
    buf.extend(struct.pack(">q", int(timestamp_ms)))
    buf.append(len(sender_bytes) & 0xFF)
    buf.extend(sender_bytes)
    buf.append(len(role_bytes) & 0xFF)
    buf.extend(role_bytes)
    buf.extend(struct.pack(">H", len(payload_bytes)))
    buf.extend(payload_bytes)
    return bytes(buf)


def verify_mesh_packet_signature(
    *,
    public_key_b64: str,
    signature_b64: str,
    signable_bytes: bytes,
) -> Tuple[bool, str]:
    """
    Verifies an Ed25519 mesh packet signature against a registered 32-byte public key.
    """
    try:
        pub_raw = base64.b64decode(public_key_b64.strip())
        sig_raw = base64.b64decode(signature_b64.strip())
        if len(pub_raw) != 32:
            return False, "Invalid public key length"
        if len(sig_raw) != 64:
            return False, "Invalid signature length"
        pub_key = ed25519.Ed25519PublicKey.from_public_bytes(pub_raw)
        pub_key.verify(sig_raw, signable_bytes)
        return True, "Verified"
    except InvalidSignature:
        return False, "Invalid Ed25519 signature"
    except Exception as exc:
        return False, f"Signature verification error: {exc}"
