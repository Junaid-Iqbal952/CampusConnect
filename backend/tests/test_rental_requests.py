"""
Tests for SCRUM-37: a borrower sends a rental request.
Run from the backend folder with:   pytest -v
"""
from models import Listing
from rental_requests import (
    MSG_ALREADY_REQUESTED,
    MSG_LISTING_NOT_FOUND,
    MSG_NOT_AVAILABLE,
    MSG_OWN_LISTING,
)
from tests.conftest import VALID_USER

OWNER = VALID_USER  # ERP 12345, "Ali Khan"
BORROWER = {**VALID_USER, "name": "Sara Ahmed", "erp": "23456", "email": "sara@khi.iba.edu.pk"}


def signup_and_login(client, person):
    client.post("/auth/signup", json=person)
    res = client.post(
        "/auth/login",
        json={"identifier": person["erp"], "password": person["password"], "device_id": "dev-" + person["erp"]},
    )
    assert res.status_code == 200
    body = res.json()
    return body["token"], body["user"]["userid"]


def auth(token):
    return {"Authorization": f"Bearer {token}"}


def add_listing(db, owner_id, title="Casio calculator", status="available"):
    listing = Listing(
        userid=owner_id, title=title, description="Works great", photourl="https://x/p.png",
        hourlyrate=20, condition="Good", maxduration=3, negotiable=True, campus="Main",
        status=status,
    )
    db.add(listing)
    db.commit()
    return listing.listingid


def setup(client, db):
    owner_token, owner_id = signup_and_login(client, OWNER)
    borrower_token, _ = signup_and_login(client, BORROWER)
    listing_id = add_listing(db, owner_id)
    return owner_token, borrower_token, listing_id


# ---------------- SCRUM-37: send a request ----------------

def test_borrower_can_request_a_listing(client, db_session):
    _, borrower, listing = setup(client, db_session)
    res = client.post(f"/listings/{listing}/request", headers=auth(borrower))
    assert res.status_code == 201
    assert res.json()["status"] == "pending"
    assert res.json()["request_id"]


def test_FR_3_2_cannot_request_own_listing(client, db_session):
    owner, _, listing = setup(client, db_session)
    res = client.post(f"/listings/{listing}/request", headers=auth(owner))
    assert res.status_code == 400
    assert res.json()["detail"] == MSG_OWN_LISTING


def test_cannot_request_same_item_twice(client, db_session):
    _, borrower, listing = setup(client, db_session)
    client.post(f"/listings/{listing}/request", headers=auth(borrower))
    res = client.post(f"/listings/{listing}/request", headers=auth(borrower))
    assert res.status_code == 409
    assert res.json()["detail"] == MSG_ALREADY_REQUESTED


def test_cannot_request_item_that_is_already_rented(client, db_session):
    _, owner_id = signup_and_login(client, OWNER)
    borrower, _ = signup_and_login(client, BORROWER)
    listing = add_listing(db_session, owner_id, status="active")
    res = client.post(f"/listings/{listing}/request", headers=auth(borrower))
    assert res.status_code == 409
    assert res.json()["detail"] == MSG_NOT_AVAILABLE


def test_request_for_missing_listing_is_404(client, db_session):
    _, borrower, _ = setup(client, db_session)
    res = client.post("/listings/9999/request", headers=auth(borrower))
    assert res.status_code == 404
    assert res.json()["detail"] == MSG_LISTING_NOT_FOUND


def test_must_be_logged_in_to_request(client, db_session):
    _, _, listing = setup(client, db_session)
    assert client.post(f"/listings/{listing}/request").status_code == 401


def test_request_status_for_borrower_before_and_after(client, db_session):
    _, borrower, listing = setup(client, db_session)
    before = client.get(f"/listings/{listing}/request-status", headers=auth(borrower)).json()
    assert before == {"is_owner": False, "already_requested": False, "listing_available": True}

    client.post(f"/listings/{listing}/request", headers=auth(borrower))
    after = client.get(f"/listings/{listing}/request-status", headers=auth(borrower)).json()
    assert after["already_requested"] is True


def test_request_status_for_owner(client, db_session):
    owner, _, listing = setup(client, db_session)
    res = client.get(f"/listings/{listing}/request-status", headers=auth(owner)).json()
    assert res["is_owner"] is True
