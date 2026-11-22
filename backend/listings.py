from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from sqlalchemy import text
from typing import Optional

from database import get_db

router = APIRouter(tags=["listings"])

@router.get("/listings")
def get_listings(
    q: Optional[str] = None,           # Search keyword
    campus: Optional[str] = None,      # 'Main' or 'City'
    sort: Optional[str] = "newest",    # 'newest', 'oldest', 'price_asc', 'price_desc', 'alpha'
    db: Session = Depends(get_db)
):
    """
    Fetch available listings with optional search, campus filter, and sorting.
    """
    base_query = """
        SELECT l.listingid, l.title, l.description, l.hourlyrate, l.campus, 
               l.negotiable, l.photourl, l.condition, l.maxduration, l.postedat,
               u.name as owner_username
        FROM listings l
        JOIN users u ON l.userid = u.userid
        WHERE l.status = 'available'
    """
    
    params = {}
    
    # 1. SEARCH FILTER
    if q:
        base_query += " AND (LOWER(l.title) LIKE LOWER(:q) OR LOWER(l.description) LIKE LOWER(:q))"
        params["q"] = f"%{q}%"
        
    # 2. CAMPUS FILTER
    if campus and campus.lower() != "all":
        base_query += " AND LOWER(l.campus) = LOWER(:campus)"
        params["campus"] = campus
        
    # 3. SORTING
    # We use a match/case or if/elif to safely handle the sort string
    if sort == "price_asc":
        base_query += " ORDER BY l.hourlyrate ASC"
    elif sort == "price_desc":
        base_query += " ORDER BY l.hourlyrate DESC"
    elif sort == "alpha":
        base_query += " ORDER BY l.title ASC"
    elif sort == "oldest":
        base_query += " ORDER BY l.postedat ASC"
    else:
        # Default to newest
        base_query += " ORDER BY l.postedat DESC"
    
    result = db.execute(text(base_query), params).fetchall()
    
    listings = []
    for row in result:
        listings.append({
            "id": row[0],
            "name": row[1],
            "description": row[2],
            "hourly_rate": float(row[3]),
            "campus": row[4],
            "negotiable": row[5],
            "image_url": row[6] or "",
            "condition": row[7] or "Not specified",
            "max_duration": row[8] or 1,
            "posted_at": str(row[9]),
            "owner_username": row[10]
        })
        
    return {"data": {"items": listings}}