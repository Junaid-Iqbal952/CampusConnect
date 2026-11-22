"""
Core auth endpoints (SCRUM-7, SCRUM-8, SCRUM-9).

POST /auth/signup  -> create account with name, ERP, IBA email, password
POST /auth/login   -> log in with ERP *or* email + password

Every error comes back as {"detail": "<message to show the user>"} so the
Flutter app can display it directly.
"""
import re

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import or_
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from database import get_db
from models import User
from security import hash_password, verify_password
from session import create_session_token, get_current_user

router = APIRouter(prefix="/auth", tags=["auth"])

IBA_EMAIL_DOMAIN = "@khi.iba.edu.pk"
MIN_PASSWORD_LENGTH = 8
MAX_PASSWORD_LENGTH = 64  # bcrypt only looks at the first 72 bytes, so cap it

# Messages (taken from the SRS, deliverable 3). Keep them identical in Flutter.
MSG_WRONG_CREDENTIALS = "Wrong username or password"
MSG_NAME_REQUIRED = "Please enter your full name"
MSG_BAD_ERP = "ERP must be exactly 5 digits"
MSG_BAD_EMAIL = "Please enter your IBA email"
MSG_SHORT_PASSWORD = f"Password must be at least {MIN_PASSWORD_LENGTH} characters"
MSG_LONG_PASSWORD = f"Password must be at most {MAX_PASSWORD_LENGTH} characters"
MSG_ERP_TAKEN = "An account with this ERP already exists"
MSG_EMAIL_TAKEN = "An account with this email already exists"


# ---------- request / response shapes ----------

class SignupRequest(BaseModel):
    name: str
    erp: str
    email: str
    password: str
    device_id: str = ""


class LoginRequest(BaseModel):
    identifier: str
    password: str
    device_id: str = ""  


class ChangePasswordRequest(BaseModel):
    erp: str  # SCRUM-13 / FR-1.7: user confirms their ERP + current password
    current_password: str
    new_password: str


class UserOut(BaseModel):
    userid: int
    name: str
    erp: str
    email: str


class AuthResponse(BaseModel):
    token: str
    user: UserOut


# ---------- helpers ----------

def _bad_request(message: str):
    raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=message)


def validate_signup(data: SignupRequest) -> SignupRequest:
    """Server-side checks. Never trust the app alone - anyone can call the API."""
    name = data.name.strip()
    erp = data.erp.strip()
    email = data.email.strip().lower()

    if not name:
        _bad_request(MSG_NAME_REQUIRED)
    if not re.fullmatch(r"\d{5}", erp):
        _bad_request(MSG_BAD_ERP)
    if not email.endswith(IBA_EMAIL_DOMAIN) or len(email) == len(IBA_EMAIL_DOMAIN):
        _bad_request(MSG_BAD_EMAIL)
    if len(data.password) < MIN_PASSWORD_LENGTH:
        _bad_request(MSG_SHORT_PASSWORD)
    if len(data.password) > MAX_PASSWORD_LENGTH:
        _bad_request(MSG_LONG_PASSWORD)

    return SignupRequest(name=name, erp=erp, email=email, password=data.password)


def _to_response(user: User, device_id: str) -> AuthResponse:
    return AuthResponse(
        token=create_session_token(user.userid, device_id),
        user=UserOut(userid=user.userid, name=user.name, erp=user.erp, email=user.email),
    )


# ---------- endpoints ----------

@router.post("/signup", response_model=AuthResponse, status_code=status.HTTP_201_CREATED)
def signup(body: SignupRequest, db: Session = Depends(get_db)):
    data = validate_signup(body)

    if db.query(User).filter(User.erp == data.erp).first():
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=MSG_ERP_TAKEN)
    if db.query(User).filter(User.email == data.email).first():
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=MSG_EMAIL_TAKEN)

    user = User(
        name=data.name,
        erp=data.erp,
        email=data.email,
        passwordhash=hash_password(data.password),
        activedeviceid=body.device_id,
    )
    db.add(user)
    try:
        db.commit()
    except IntegrityError:
        # Two sign-ups with the same ERP at the same moment - the DB's UNIQUE rule catches it.
        db.rollback()
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=MSG_ERP_TAKEN)
    db.refresh(user)

    # TODO (SCRUM-6/10/11, FB's part): send the 6-digit email verification code here.
    return _to_response(user, body.device_id)


@router.post("/login", response_model=AuthResponse)
def login(body: LoginRequest, db: Session = Depends(get_db)):
    identifier = body.identifier.strip().lower()

    if not identifier or not body.password:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=MSG_WRONG_CREDENTIALS)

    user = db.query(User).filter(or_(User.erp == identifier, User.email == identifier)).first()

    # Same message whether the user doesn't exist or the password is wrong (FR-1.5),
    # so nobody can use the login form to find out which ERPs are registered.
    if user is None or not verify_password(body.password, user.passwordhash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=MSG_WRONG_CREDENTIALS)
    user.activedeviceid = body.device_id
    db.commit()

    return _to_response(user, body.device_id)

MSG_WRONG_CURRENT = "Wrong ERP or current password"
MSG_SAME_PASSWORD = "New password must be different from the current password"


@router.get("/me", response_model=UserOut)
def me(user: User = Depends(get_current_user)):
    """The app calls this on start to ask: is my saved token still good?"""
    return UserOut(userid=user.userid, name=user.name, erp=user.erp, email=user.email)


@router.post("/logout")
def logout(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    user.activedeviceid = None   # frees the slot
    db.commit()
    return {"message": "Logged out"}


@router.post("/change-password")
def change_password(
    body: ChangePasswordRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    # A wrong current password is a 400, not 401, because 401 means "log the user out".
    # ERP must belong to the logged-in account (Use Case 3). One message for both
    # checks, like login, so it doesn't reveal which part was wrong.
    if body.erp.strip() != user.erp or not verify_password(body.current_password, user.passwordhash):
        _bad_request(MSG_WRONG_CURRENT)
    if len(body.new_password) < MIN_PASSWORD_LENGTH:
        _bad_request(MSG_SHORT_PASSWORD)
    if len(body.new_password) > MAX_PASSWORD_LENGTH:
        _bad_request(MSG_LONG_PASSWORD)
    if body.new_password == body.current_password:
        _bad_request(MSG_SAME_PASSWORD)

    user.passwordhash = hash_password(body.new_password)
    db.commit()
    return {"message": "Password updated successfully"}
