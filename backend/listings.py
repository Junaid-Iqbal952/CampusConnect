from typing import Optional

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from sqlalchemy import text
from sqlalchemy.orm import Session

from cloudinary_utils import upload_listing_photo
from database import get_db
from models import Listing, User
from session import get_current_user

router = APIRouter(tags=["listings"])

# Rules for a new listing. Keep ALLOWED_CAMPUSES the same as the Supabase CHECK
# constraint and the Flutter dropdown.
ALLOWED_CAMPUSES = ["Main", "City"]
MAX_TITLE_LENGTH = 100
MAX_DESCRIPTION_LENGTH = 1000
MAX_CONDITION_LENGTH = 50
MAX_HOURLY_RATE = 100000
MAX_DURATION_DAYS = 365
MAX_PHOTO_MB = 2
MAX_PHOTO_BYTES = MAX_PHOTO_MB * 1024 * 1024  # 2 MB

MSG_TITLE = f"Please enter a name (up to {MAX_TITLE_LENGTH} characters)"
MSG_DESCRIPTION = f"Please enter a description (up to {MAX_DESCRIPTION_LENGTH} characters)"
MSG_RATE = f"Hourly rate must be above 0 and at most {MAX_HOURLY_RATE}"
MSG_CONDITION = f"Please describe the condition (up to {MAX_CONDITION_LENGTH} characters)"
MSG_DURATION = f"Rental duration must be between 1 and {MAX_DURATION_DAYS} days"
MSG_CAMPUS = "Please choose a campus: " + " or ".join(ALLOWED_CAMPUSES)
MSG_PHOTO_REQUIRED = "Please add a photo"
MSG_PHOTO_TYPE = "Photo must be a JPG or PNG image"
MSG_PHOTO_SIZE = f"Photo must be {MAX_PHOTO_MB} MB or smaller"
MSG_UPLOAD_FAILED = "Could not upload the photo. Please try again"

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
    
# ---------- My Listings (dashboard) ----------

@router.get("/listings/mine")
def get_my_listings(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),  # must be logged in
):
    """Every listing the logged-in user posted, newest first (any status)."""
    rows = (
        db.query(Listing)
        .filter(Listing.userid == user.userid)  # only MY listings
        .order_by(Listing.postedat.desc(), Listing.listingid.desc())
        .all()
    )

    items = []
    for l in rows:
        items.append({
            "id": l.listingid,
            "name": l.title,
            "description": l.description,
            "hourly_rate": float(l.hourlyrate),
            "campus": l.campus,
            "negotiable": bool(l.negotiable),
            "image_url": l.photourl or "",
            "condition": l.condition or "Not specified",
            "max_duration": l.maxduration or 1,
            "posted_at": str(l.postedat),
            "owner_username": user.name,
            "status": l.status or "available",
        })

    return {"data": {"items": items}}

# ---------- Post a new listing ----------

def _bad_request(message: str):
    raise HTTPException(status_code=400, detail=message)


def _looks_like_image(data: bytes) -> bool:
    """Checks the first bytes of the file: JPG starts FF D8 FF, PNG starts 89 'PNG'."""
    is_jpeg = data[:3] == b"\xff\xd8\xff"
    is_png = data[:8] == b"\x89PNG\r\n\x1a\n"
    return is_jpeg or is_png


@router.post("/listings", status_code=201)
def create_listing(
    title: str = Form(""),
    description: str = Form(""),
    hourly_rate: float = Form(0),
    condition: str = Form(""),
    max_duration: int = Form(0),
    negotiable: bool = Form(False),
    campus: str = Form(""),
    photo: Optional[UploadFile] = File(None),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),  # must be logged in; gives us the owner
):
    """Create a listing for the logged-in user (lender)."""
    title = title.strip()
    description = description.strip()
    condition = condition.strip()

    # 1. Check every field. The first problem found is sent back as the error.
    if not title or len(title) > MAX_TITLE_LENGTH:
        _bad_request(MSG_TITLE)
    if not description or len(description) > MAX_DESCRIPTION_LENGTH:
        _bad_request(MSG_DESCRIPTION)
    if not (0 < hourly_rate <= MAX_HOURLY_RATE):
        _bad_request(MSG_RATE)
    if not condition or len(condition) > MAX_CONDITION_LENGTH:
        _bad_request(MSG_CONDITION)
    if not (1 <= max_duration <= MAX_DURATION_DAYS):
        _bad_request(MSG_DURATION)

    # "main", "MAIN" and "Main" all become "Main" (the database wants exact spelling).
    campus_by_lowercase = {c.lower(): c for c in ALLOWED_CAMPUSES}
    campus = campus_by_lowercase.get(campus.strip().lower())
    if campus is None:
        _bad_request(MSG_CAMPUS)

    # 2. Check the photo.
    photo_bytes = photo.file.read() if photo is not None else b""
    if not photo_bytes:
        _bad_request(MSG_PHOTO_REQUIRED)
    if len(photo_bytes) > MAX_PHOTO_BYTES:
        _bad_request(MSG_PHOTO_SIZE)
    if not _looks_like_image(photo_bytes):
        _bad_request(MSG_PHOTO_TYPE)

    # 3. Upload the photo. If this fails we stop BEFORE saving anything.
    try:
        photo_url = upload_listing_photo(photo_bytes)
    except Exception:
        raise HTTPException(status_code=502, detail=MSG_UPLOAD_FAILED)

    # 4. Save the listing. status and postedat are filled in by the database.
    listing = Listing(
        userid=user.userid,  # from the login token, never from the app
        title=title,
        description=description,
        photourl=photo_url,
        hourlyrate=round(hourly_rate, 2),
        condition=condition,
        maxduration=max_duration,
        negotiable=negotiable,
        campus=campus,
    )
    db.add(listing)
    db.commit()
    db.refresh(listing)

    return {"message": "Listing posted", "data": {"id": listing.listingid, "image_url": photo_url}}