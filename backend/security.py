"""
Password hashing + login tokens.

NOTE: password hashing is SCRUM-17 (JI). These two functions are kept tiny
and in their own file so that version can replace them without touching auth.py.
"""
import os
from datetime import datetime, timedelta, timezone

import bcrypt
import jwt
from dotenv import load_dotenv

load_dotenv()

JWT_SECRET = os.getenv("JWT_SECRET", "dev-only-secret-change-me-please-0123456789")
JWT_ALGORITHM = "HS256"
TOKEN_LIFETIME_DAYS = 7


def hash_password(plain_password: str) -> str:
    """Turn 'mypassword123' into a one-way bcrypt hash we can store safely."""
    return bcrypt.hashpw(plain_password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_password(plain_password: str, stored_hash: str) -> bool:
    """Check a typed password against the stored hash."""
    try:
        return bcrypt.checkpw(plain_password.encode("utf-8"), stored_hash.encode("utf-8"))
    except ValueError:
        # Stored value isn't a valid bcrypt hash (e.g. old test rows) -> treat as wrong.
        return False


def create_access_token(user_id: int) -> str:
    """Token the Flutter app saves as 'auth_token' (used by the splash screen, SCRUM-12)."""
    payload = {
        "sub": str(user_id),
        "exp": datetime.now(timezone.utc) + timedelta(days=TOKEN_LIFETIME_DAYS),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)
