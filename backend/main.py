import random
from datetime import datetime, timedelta

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text

from auth import router as auth_router
from database import engine
from security import hash_password
from listings import router as listings_router

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


# test database connection
@app.get("/")
def read_root():
    try:
        with engine.connect() as connection:
            connection.execute(text("SELECT 1"))
            return {"message": "CampusConnect backend is running and database is connected"}
    except Exception as e:
        return {"message": f"Error connecting to database: {str(e)}"}


# ---------- Forgot password (SCRUM-6/10/11) ----------

@app.post("/auth/request-reset")
def request_reset(email: str):
    now = datetime.utcnow()
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)

    with engine.connect() as connection:
        # 1. Check if user exists
        user_result = connection.execute(
            text("SELECT userid FROM users WHERE email = :email"),
            {"email": email}
        ).fetchone()

        if not user_result:
            raise HTTPException(status_code=404, detail="User with this email not found")

        userid = user_result[0]

        # 2. Max 5 codes per day check (created since 00:00:00 UTC today)
        daily_count = connection.execute(
            text("""
                SELECT COUNT(*) FROM verification_codes
                WHERE userid = :userid
                  AND purpose = 'password_reset'
                  AND (expiresat - INTERVAL '5 minutes') >= :today_start
            """),
            {"userid": userid, "today_start": today_start}
        ).scalar()

        if daily_count >= 5:
            raise HTTPException(
                status_code=429,
                detail="Daily code limit reached (max 5 codes per day)"
            )

        # 3. 60-second cooldown check against the most recent code
        latest_code = connection.execute(
            text("""
                SELECT (expiresat - INTERVAL '5 minutes') AS created_at
                FROM verification_codes
                WHERE userid = :userid AND purpose = 'password_reset'
                ORDER BY expiresat DESC
                LIMIT 1
            """),
            {"userid": userid}
        ).fetchone()

        if latest_code and latest_code[0] is not None:
            seconds_since_last = (now - latest_code[0]).total_seconds()
            if seconds_since_last < 60:
                wait_seconds = int(60 - seconds_since_last) + 1
                raise HTTPException(
                    status_code=429,
                    detail=f"Wait {wait_seconds} seconds before requesting another code"
                )

        # 4. Generate 6-digit code and set 5-minute expiration
        code = str(random.randint(100000, 999999))
        expires_at = now + timedelta(minutes=5)

        connection.execute(
            text("""
                INSERT INTO verification_codes (code, userid, purpose, expiresat, attemptcount)
                VALUES (:code, :userid, 'password_reset', :expiresat, 0)
            """),
            {"code": code, "userid": userid, "expiresat": expires_at}
        )
        connection.commit()

        return {"message": "Verification code sent to email successfully", "test_code": code}
    
@app.post("/auth/reset-password")
def reset_password(email: str, code: str, new_password: str):
    with engine.connect() as connection:
        # 1. Get user ID
        user_result = connection.execute(
            text("SELECT userid FROM users WHERE email = :email"),
            {"email": email}
        ).fetchone()
        
        if not user_result:
            raise HTTPException(status_code=404, detail="User not found")
        
        userid = user_result[0]

        # 2. Check if the code exists for this user and purpose
        code_result = connection.execute(
            text("""
                SELECT expiresat FROM verification_codes 
                WHERE userid = :userid AND code = :code AND purpose = 'password_reset'
            """),
            {"userid": userid, "code": code}
        ).fetchone()

        if not code_result:
            raise HTTPException(status_code=400, detail="Invalid verification code")

        expires_at = code_result[0]

        # 3. Check if code has expired (5-minute rule)
        if datetime.utcnow() > expires_at:
            raise HTTPException(status_code=400, detail="Verification code has expired")

        # 4. Update password in database
        connection.execute(
            text("UPDATE users SET passwordhash = :passwordhash WHERE userid = :userid"),
            {"passwordhash": hash_password(new_password), "userid": userid}
        )

        # 5. Delete the used code so it cannot be reused
        connection.execute(
            text("DELETE FROM verification_codes WHERE code = :code AND userid = :userid"),
            {"code": code, "userid": userid}
        )
        connection.commit()

        return {"message": "Password successfully reset"}
