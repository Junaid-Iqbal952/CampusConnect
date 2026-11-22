"""
Login tokens that remember WHICH device they were made for (SP1-08),
plus the check that every protected route uses.
"""
from datetime import datetime, timedelta, timezone
from typing import Optional

import jwt
from fastapi import Depends, Header, HTTPException, status
from sqlalchemy.orm import Session

from database import get_db
from models import User
from security import JWT_ALGORITHM, JWT_SECRET, TOKEN_LIFETIME_DAYS  # only reading, not editing

MSG_SESSION_EXPIRED = "Session expired. Please log in again"
MSG_OTHER_DEVICE = "You were logged in on another device"


def create_session_token(user_id: int, device_id: str) -> str:
    """Token = user id ("sub") + device id ("did") + expiry date ("exp")."""
    payload = {
        "sub": str(user_id),
        "did": device_id,
        "exp": datetime.now(timezone.utc) + timedelta(days=TOKEN_LIFETIME_DAYS),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def _unauthorized(message: str):
    raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=message)


def get_current_user(
    authorization: Optional[str] = Header(default=None),  # reads the "Authorization" header
    db: Session = Depends(get_db),
) -> User:
    """Put this in any route that needs a logged-in user: user = Depends(get_current_user)"""
    # 1. The header must look like:  Bearer <token>
    if not authorization or not authorization.startswith("Bearer "):
        _unauthorized(MSG_SESSION_EXPIRED)
    token = authorization[len("Bearer "):]

    # 2. Decode the token. A fake, broken or expired token raises an error.
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        user_id = int(payload["sub"])
    except (jwt.PyJWTError, KeyError, ValueError):
        _unauthorized(MSG_SESSION_EXPIRED)

    # 3. The user must still exist.
    user = db.get(User, user_id)
    if user is None:
        _unauthorized(MSG_SESSION_EXPIRED)

    # 4. THE ONE-DEVICE RULE: the token's device must be the user's current device.
    if (user.activedeviceid or "") != payload.get("did", ""):
        _unauthorized(MSG_OTHER_DEVICE)

    return user