"""
Rental requests (SCRUM-37): a borrower asks to rent a listing.

POST /listings/{listing_id}/request        borrower sends a request ("I'm interested")
GET  /listings/{listing_id}/request-status  for the detail page button

Uses the existing Supabase table:
    rental_requests(requestid, listingid, borrowerid, status, requestedat)
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import text
from sqlalchemy.orm import Session

from database import get_db
from models import Listing, User
from session import get_current_user

router = APIRouter(tags=["rental requests"])

# Values of the Postgres enums. If Supabase uses different words, change them
# HERE only (they are put straight into the SQL, never user input).
REQUEST_PENDING = "pending"
LISTING_AVAILABLE = "available"

MSG_LISTING_NOT_FOUND = "Listing not found"
MSG_OWN_LISTING = "You can't request your own listing"
MSG_NOT_AVAILABLE = "This item is no longer available"
MSG_ALREADY_REQUESTED = "You have already requested this item"
MSG_REQUEST_SENT = "Request sent! The owner will see it on their dashboard"


def _get_listing_or_404(db: Session, listing_id: int) -> Listing:
    listing = db.get(Listing, listing_id)
    if listing is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=MSG_LISTING_NOT_FOUND)
    return listing


def _my_pending_request_id(db: Session, listing_id: int, borrower_id: int):
    return db.execute(
        text(f"""
            SELECT requestid FROM rental_requests
            WHERE listingid = :listing AND borrowerid = :borrower
              AND status = '{REQUEST_PENDING}'
        """),
        {"listing": listing_id, "borrower": borrower_id},
    ).scalar()



# ---------- SCRUM-37: send a request ----------

@router.post("/listings/{listing_id}/request", status_code=status.HTTP_201_CREATED)
def request_listing(
    listing_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    listing = _get_listing_or_404(db, listing_id)

    if listing.userid == user.userid:  # FR-3.2: no renting your own item
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=MSG_OWN_LISTING)
    if listing.status != LISTING_AVAILABLE:  # already rented out (Active)
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=MSG_NOT_AVAILABLE)
    if _my_pending_request_id(db, listing_id, user.userid) is not None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=MSG_ALREADY_REQUESTED)

    request_id = db.execute(
        text(f"""
            INSERT INTO rental_requests (listingid, borrowerid, status, requestedat)
            VALUES (:listing, :borrower, '{REQUEST_PENDING}', CURRENT_TIMESTAMP)
            RETURNING requestid
        """),
        {"listing": listing_id, "borrower": user.userid},
    ).scalar()
    db.commit()

    # TODO (Sprint 4, chat): FR-3.1 also opens a chat thread with an "interested" message.
    return {"request_id": request_id, "status": REQUEST_PENDING, "message": MSG_REQUEST_SENT}


@router.get("/listings/{listing_id}/request-status")
def request_status(
    listing_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Tells the detail page which button to show:
    owner -> no button, already requested -> "Requested", otherwise -> "Request for Rent"."""
    listing = _get_listing_or_404(db, listing_id)
    return {
        "is_owner": listing.userid == user.userid,
        "already_requested": _my_pending_request_id(db, listing_id, user.userid) is not None,
        "listing_available": listing.status == LISTING_AVAILABLE,
    }
