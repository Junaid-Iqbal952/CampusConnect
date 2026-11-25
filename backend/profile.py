import os
import jwt
from fastapi import APIRouter, Depends, HTTPException, Header
from sqlalchemy.orm import Session
from sqlalchemy import text
from typing import Optional

from database import get_db

router = APIRouter(tags=["profile"])

JWT_SECRET = os.getenv("JWT_SECRET", "dev-only-secret-change-me-please-0123456789")
JWT_ALGORITHM = "HS256"

def get_current_user_id(authorization: Optional[str] = Header(None)) -> int:
    """
    Extracts the user_id from the JWT token sent in the Authorization header.
    """
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Not authenticated. Please log in again.")
    
    token = authorization.split(" ")[1]
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        user_id = int(payload.get("sub"))
        return user_id
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid or expired token")

def get_profile_data(user_id: int, db: Session):
    # 1. Fetch user and AGGREGATE RATING directly from the users table
    user_row = db.execute(
        text("SELECT userid, name, joineddate, aggregaterating FROM users WHERE userid = :userid"), 
        {"userid": user_id}
    ).fetchone()
    
    if not user_row:
        raise HTTPException(status_code=404, detail="User not found")
        
    full_name = user_row[1]
    date_joined = str(user_row[2]) if user_row[2] else "Recently"
    
    # Use the stored aggregate rating, default to 0.0 if null
    average_rating = float(user_row[3]) if user_row[3] is not None else 0.0
    
    # 2. Count total items posted
    total_posted = db.execute(
        text("SELECT COUNT(*) FROM listings WHERE userid = :userid"), 
        {"userid": user_id}
    ).scalar() or 0
    
    # 3. Count completed rentals (from the rentals table)
    total_completed = db.execute(
        text("""
            SELECT COUNT(*) FROM rentals 
            WHERE (lenderid = :userid OR borrowerid = :userid) 
            AND status = 'complete'
        """), 
        {"userid": user_id}
    ).scalar() or 0
    
    # 4. Fetch real reviews (for the list below)
    reviews_result = db.execute(
        text("""
            SELECT r.stars, r.comment, r.isanonymous, r.submittedat, u.name as reviewer_name
            FROM reviews r
            JOIN users u ON r.reviewerid = u.userid
            WHERE r.revieweeid = :userid
            ORDER BY r.submittedat DESC
        """),
        {"userid": user_id}
    ).fetchall()
    
    reviews = []
    for row in reviews_result:
        reviews.append({
            "stars": row[0],
            "comment": row[1],
            "anonymous": row[2],
            "created_at": str(row[3]),
            "reviewer_name": "Anonymous" if row[2] else row[4]
        })

    return {
        "full_name": full_name,
        "date_joined": date_joined,
        "average_rating": average_rating,
        "total_items_posted": total_posted,
        "total_completed_rentals": total_completed,
        "reviews": reviews
    }

@router.get("/users/me/profile")
def get_my_profile(db: Session = Depends(get_db), user_id: int = Depends(get_current_user_id)):
    try:
        data = get_profile_data(user_id, db)
        return {"data": data}
    except HTTPException:
        raise
    except Exception as e:
        print(f"Database error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/users/{username}/profile")
def get_user_profile(username: str, db: Session = Depends(get_db)):
    try:
        user_row = db.execute(
            text("SELECT userid FROM users WHERE name = :username"), 
            {"username": username}
        ).fetchone()
        
        if not user_row:
            raise HTTPException(status_code=404, detail="User not found")
        
        data = get_profile_data(user_row[0], db)
        return {"data": data}
    except HTTPException:
        raise
    except Exception as e:
        print(f"Database error: {e}")
        raise HTTPException(status_code=500, detail=str(e))