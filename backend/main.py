import random
from datetime import datetime, timedelta
import os
import smtplib
from email.message import EmailMessage

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text
from dotenv import load_dotenv
from auth import router as auth_router
from database import engine
from security import hash_password
from listings import router as listings_router
from typing import Optional
from profile import router as profile_router

load_dotenv()
app = FastAPI(title="CampusConnect API")

# The Flutter WEB app runs on a different port than this API, so the browser
# needs CORS permission. "*" is fine for development; restrict before deploying.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Sign up + log in (SCRUM-7, 8, 9) live in auth.py
app.include_router(auth_router)
app.include_router(listings_router)
app.include_router(profile_router)


# test database connection
@app.get("/")
def read_root():
    try:
        with engine.connect() as connection:
            connection.execute(text("SELECT 1"))
            return {"message": "CampusConnect backend is running and database is connected"}
    except Exception as e:
        return {"message": f"Error connecting to database: {str(e)}"}

def send_verification_email(to_email: str, code: str, purpose: str = "password_reset") -> None:
    smtp_enabled = os.getenv("SMTP_ENABLED", "true").strip().lower() in ("1", "true", "yes")
    if not smtp_enabled:
        print(f"[DEV SMTP_ENABLED=false] Code for {to_email} ({purpose}): {code}")
        return

    smtp_host = os.getenv("SMTP_HOST", "smtp.gmail.com")
    smtp_port = int(os.getenv("SMTP_PORT", "587"))
    smtp_user = os.getenv("SMTP_USER")
    smtp_pass = os.getenv("SMTP_PASS")
    from_name = os.getenv("SMTP_FROM_NAME", "CampusConnect")

    if not smtp_user or not smtp_pass:
        raise RuntimeError("SMTP_USER and SMTP_PASS must be set in backend/.env")

    if purpose == "password_change":
        subject = "CampusConnect - Password Change Verification Code"
        action_text = "change your CampusConnect password"
    elif purpose == "signup":
        subject = "CampusConnect - Email Verification Code"
        action_text = "verify your @khi.iba.edu.pk email for CampusConnect"
    else:
        subject = "CampusConnect - Password Reset Code"
        action_text = "reset your CampusConnect password"

    msg = EmailMessage()
    msg["Subject"] = subject
    msg["From"] = f"{from_name} <{smtp_user}>"
    msg["To"] = to_email
    msg.set_content(
        f"Assalam-o-Alaikum / Hello,\n\n"
        f"Your 6-digit verification code to {action_text} is:\n\n"
        f"    {code}\n\n"
        f"This code expires in 5 minutes.\n"
        f"If you did not request this, please ignore this email.\n\n"
        f"- CampusConnect"
    )

    with smtplib.SMTP(smtp_host, smtp_port, timeout=15) as server:
        server.starttls()
        server.login(smtp_user, smtp_pass)
        server.send_message(msg)

# ---------- Forgot password (SCRUM-6/10/11) ----------

MAX_CODE_ATTEMPTS = 5


def _get_userid_by_email(connection, email: str) -> Optional[int]:
    row = connection.execute(
        text("SELECT userid FROM users WHERE email = :email"),
        {"email": email.strip().lower()},
    ).fetchone()
    return row[0] if row else None

def _validate_latest_reset_code(connection, userid: int, code: str, *, consume: bool = False):
    """
    Fetches the latest password_reset code for userid, enforces attemptcount & 5-minute expiry,
    and optionally deletes it when consume=True.
    """
    latest = connection.execute(
        text("""
            SELECT code, expiresat, attemptcount
            FROM verification_codes
            WHERE userid = :userid AND purpose = 'password_reset'
            ORDER BY expiresat DESC
            LIMIT 1
        """),
        {"userid": userid},
    ).fetchone()

    if not latest:
        raise HTTPException(status_code=400, detail="No active verification code found. Request a new code.")

    stored_code, expires_at, attempt_count = latest
    attempt_count = attempt_count or 0

    if attempt_count >= MAX_CODE_ATTEMPTS:
        raise HTTPException(
            status_code=400,
            detail="Too many failed attempts for this code. Request a new verification code.",
        )

    if datetime.utcnow() > expires_at:
        raise HTTPException(status_code=400, detail="Verification code has expired")

    if code.strip() != stored_code:
        new_attempts = attempt_count + 1
        connection.execute(
            text("""
                UPDATE verification_codes
                SET attemptcount = :attemptcount
                WHERE userid = :userid AND code = :code AND purpose = 'password_reset'
            """),
            {"attemptcount": new_attempts, "userid": userid, "code": stored_code},
        )
        connection.commit()

        remaining = MAX_CODE_ATTEMPTS - new_attempts
        if remaining <= 0:
            raise HTTPException(
                status_code=400,
                detail="Invalid verification code. Maximum attempts reached; request a new code.",
            )
        raise HTTPException(
            status_code=400,
            detail=f"Invalid verification code ({remaining} attempt(s) remaining)",
        )

    if consume:
        connection.execute(
            text("""
                DELETE FROM verification_codes
                WHERE userid = :userid AND code = :code AND purpose = 'password_reset'
            """),
            {"userid": userid, "code": stored_code},
        )


@app.post("/auth/request-reset")
def request_reset(email: str):
    normalized_email = email.strip().lower()
    now = datetime.utcnow()
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)

    with engine.connect() as connection:
        userid = _get_userid_by_email(connection, normalized_email)
        if not userid:
            raise HTTPException(status_code=404, detail="User with this email not found")

        daily_count = connection.execute(
            text("""
                SELECT COUNT(*) FROM verification_codes
                WHERE userid = :userid
                  AND purpose = 'password_reset'
                  AND (expiresat - INTERVAL '5 minutes') >= :today_start
            """),
            {"userid": userid, "today_start": today_start},
        ).scalar()

        if daily_count >= 5:
            raise HTTPException(
                status_code=429,
                detail="Daily code limit reached (max 5 codes per day)",
            )

        latest_code = connection.execute(
            text("""
                SELECT (expiresat - INTERVAL '5 minutes') AS created_at
                FROM verification_codes
                WHERE userid = :userid AND purpose = 'password_reset'
                ORDER BY expiresat DESC
                LIMIT 1
            """),
            {"userid": userid},
        ).fetchone()

        if latest_code and latest_code[0] is not None:
            seconds_since_last = (now - latest_code[0]).total_seconds()
            if seconds_since_last < 60:
                wait_seconds = int(60 - seconds_since_last) + 1
                raise HTTPException(
                    status_code=429,
                    detail=f"Wait {wait_seconds} seconds before requesting another code",
                )

        code = str(random.randint(100000, 999999))
        expires_at = now + timedelta(minutes=5)

        connection.execute(
            text("""
                INSERT INTO verification_codes (code, userid, purpose, expiresat, attemptcount)
                VALUES (:code, :userid, 'password_reset', :expiresat, 0)
            """),
            {"code": code, "userid": userid, "expiresat": expires_at},
        )
        connection.commit()

    try:
        send_verification_email(normalized_email, code, purpose="password_reset")
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to send verification email: {exc}",
        )

    return {"message": "Verification code sent to email successfully"}


@app.post("/auth/verify-code")
def verify_code(email: str, code: str):
    normalized_email = email.strip().lower()
    with engine.connect() as connection:
        userid = _get_userid_by_email(connection, normalized_email)
        if not userid:
            raise HTTPException(status_code=404, detail="User not found")

        _validate_latest_reset_code(connection, userid, code, consume=False)
        return {"message": "Verification code is valid"}


@app.post("/auth/reset-password")
def reset_password(email: str, code: str, new_password: str):
    normalized_email = email.strip().lower()
    with engine.connect() as connection:
        userid = _get_userid_by_email(connection, normalized_email)
        if not userid:
            raise HTTPException(status_code=404, detail="User not found")

        _validate_latest_reset_code(connection, userid, code, consume=True)

        connection.execute(
            text("UPDATE users SET passwordhash = :passwordhash WHERE userid = :userid"),
            {"passwordhash": hash_password(new_password), "userid": userid},
        )
        connection.commit()

        return {"message": "Password successfully reset"}