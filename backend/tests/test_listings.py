"""
Tests for the "post a listing" user story (lender posts photo, name, description,
hourly rate, condition, rental duration, negotiable, campus).
The Cloudinary upload is faked, so no internet or account is needed.
Run from the backend folder with:   pytest -v
"""
from unittest.mock import patch

from listings import MSG_CAMPUS, MSG_PHOTO_REQUIRED, MSG_PHOTO_TYPE, MSG_RATE, MSG_UPLOAD_FAILED

FAKE_URL = "https://res.cloudinary.com/test/image/upload/fake.png"
PNG = b"\x89PNG\r\n\x1a\n" + b"0" * 50  # starts like a real PNG file


def login_token(client):
    res = client.post(
        "/auth/login",
        json={"identifier": "12345", "password": "secret123", "device_id": "device-A"},
    )
    assert res.status_code == 200
    return res.json()["token"]


def good_form(**changes):
    form = {
        "title": "Casio FX-991 calculator",
        "description": "Works great, new batteries",
        "hourly_rate": "20",
        "condition": "Good",
        "max_duration": "3",
        "negotiable": "true",
        "campus": "Main",
    }
    form.update(changes)
    return form


def post_listing(client, token, form=None, photo=PNG):
    headers = {"Authorization": f"Bearer {token}"} if token else {}
    files = {"photo": ("item.png", photo, "image/png")} if photo is not None else None
    return client.post("/listings", data=form or good_form(), files=files, headers=headers)


@patch("listings.upload_listing_photo", return_value=FAKE_URL)
def test_post_listing_success_and_it_shows_on_listings_page(_upload, client, registered_user):
    res = post_listing(client, login_token(client))
    assert res.status_code == 201
    assert res.json()["data"]["image_url"] == FAKE_URL

    items = client.get("/listings").json()["data"]["items"]
    assert len(items) == 1
    item = items[0]
    assert item["name"] == "Casio FX-991 calculator"
    assert item["hourly_rate"] == 20.0
    assert item["condition"] == "Good"
    assert item["max_duration"] == 3
    assert bool(item["negotiable"]) is True  # SQLite gives 1, Postgres gives True
    assert item["campus"] == "Main"
    assert item["image_url"] == FAKE_URL
    assert item["owner_username"] == "Ali Khan"


@patch("listings.upload_listing_photo", return_value=FAKE_URL)
def test_campus_spelling_is_fixed(_upload, client, registered_user):
    res = post_listing(client, login_token(client), good_form(campus="city"))
    assert res.status_code == 201
    assert client.get("/listings").json()["data"]["items"][0]["campus"] == "City"


@patch("listings.upload_listing_photo", return_value=FAKE_URL)
def test_must_be_logged_in(_upload, client, registered_user):
    assert post_listing(client, token=None).status_code == 401


@patch("listings.upload_listing_photo", return_value=FAKE_URL)
def test_bad_campus(_upload, client, registered_user):
    res = post_listing(client, login_token(client), good_form(campus="Moon"))
    assert res.status_code == 400
    assert res.json()["detail"] == MSG_CAMPUS


@patch("listings.upload_listing_photo", return_value=FAKE_URL)
def test_bad_rate(_upload, client, registered_user):
    for rate in ["0", "-5"]:
        res = post_listing(client, login_token(client), good_form(hourly_rate=rate))
        assert res.status_code == 400
        assert res.json()["detail"] == MSG_RATE


@patch("listings.upload_listing_photo", return_value=FAKE_URL)
def test_empty_name_or_duration_rejected(_upload, client, registered_user):
    token = login_token(client)
    assert post_listing(client, token, good_form(title="   ")).status_code == 400
    assert post_listing(client, token, good_form(max_duration="0")).status_code == 400
    assert post_listing(client, token, good_form(condition="")).status_code == 400


@patch("listings.upload_listing_photo", return_value=FAKE_URL)
def test_photo_is_required(_upload, client, registered_user):
    res = post_listing(client, login_token(client), photo=None)
    assert res.status_code == 400
    assert res.json()["detail"] == MSG_PHOTO_REQUIRED


@patch("listings.upload_listing_photo", return_value=FAKE_URL)
def test_photo_must_be_an_image(_upload, client, registered_user):
    res = post_listing(client, login_token(client), photo=b"this is just text")
    assert res.status_code == 400
    assert res.json()["detail"] == MSG_PHOTO_TYPE


@patch("listings.upload_listing_photo", side_effect=Exception("cloudinary down"))
def test_upload_failure_saves_nothing(_upload, client, registered_user):
    res = post_listing(client, login_token(client))
    assert res.status_code == 502
    assert res.json()["detail"] == MSG_UPLOAD_FAILED
    assert client.get("/listings").json()["data"]["items"] == []

    # ---------- My Listings (dashboard, SCRUM-51) ----------

OTHER_USER = {
    "name": "Sara Ahmed",
    "erp": "67890",
    "email": "s.ahmed.67890@khi.iba.edu.pk",
    "password": "secret456",
}


def other_user_token(client):
    assert client.post("/auth/signup", json=OTHER_USER).status_code == 201
    res = client.post(
        "/auth/login",
        json={"identifier": "67890", "password": "secret456", "device_id": "device-B"},
    )
    assert res.status_code == 200
    return res.json()["token"]


def get_mine(client, token):
    headers = {"Authorization": f"Bearer {token}"} if token else {}
    return client.get("/listings/mine", headers=headers)


@patch("listings.upload_listing_photo", return_value=FAKE_URL)
def test_my_listings_shows_only_my_own(_upload, client, registered_user):
    my_token = login_token(client)
    sara_token = other_user_token(client)
    post_listing(client, my_token, good_form(title="My calculator"))
    post_listing(client, sara_token, good_form(title="Sara's lab coat"))

    res = get_mine(client, my_token)
    assert res.status_code == 200
    items = res.json()["data"]["items"]
    assert [i["name"] for i in items] == ["My calculator"]
    assert items[0]["owner_username"] == "Ali Khan"
    assert items[0]["status"] == "available"


@patch("listings.upload_listing_photo", return_value=FAKE_URL)
def test_my_listings_newest_first(_upload, client, registered_user):
    token = login_token(client)
    post_listing(client, token, good_form(title="First"))
    post_listing(client, token, good_form(title="Second"))

    names = [i["name"] for i in get_mine(client, token).json()["data"]["items"]]
    assert names == ["Second", "First"]


def test_my_listings_empty_when_nothing_posted(client, registered_user):
    res = get_mine(client, login_token(client))
    assert res.status_code == 200
    assert res.json()["data"]["items"] == []


def test_my_listings_must_be_logged_in(client):
    assert get_mine(client, token=None).status_code == 401

# ---------- Edit a listing (SCRUM-24) ----------

from listings import MSG_NOT_AVAILABLE, MSG_NOT_FOUND, MSG_NOT_OWNER
from models import Listing

NEW_URL = "https://res.cloudinary.com/test/image/upload/new.png"


def put_listing(client, token, listing_id, form=None, photo=None):
    headers = {"Authorization": f"Bearer {token}"} if token else {}
    files = {"photo": ("new.png", photo, "image/png")} if photo is not None else None
    return client.put(f"/listings/{listing_id}", data=form or good_form(), files=files, headers=headers)


def post_and_get_id(client, token):
    with patch("listings.upload_listing_photo", return_value=FAKE_URL):
        res = post_listing(client, token)
    assert res.status_code == 201
    return res.json()["data"]["id"]


def test_edit_changes_fields_and_keeps_old_photo(client, registered_user):
    token = login_token(client)
    listing_id = post_and_get_id(client, token)

    form = good_form(title="Casio FX-991 (new cover)", hourly_rate="35", campus="city",
                     negotiable="false", max_duration="7")
    res = put_listing(client, token, listing_id, form)  # no photo sent
    assert res.status_code == 200
    assert res.json()["data"]["image_url"] == FAKE_URL  # old photo kept

    item = get_mine(client, token).json()["data"]["items"][0]
    assert item["name"] == "Casio FX-991 (new cover)"
    assert item["hourly_rate"] == 35.0
    assert item["campus"] == "City"
    assert item["max_duration"] == 7
    assert item["negotiable"] is False
    assert item["image_url"] == FAKE_URL


@patch("listings.upload_listing_photo", return_value=NEW_URL)
def test_edit_with_new_photo_replaces_it(_upload, client, registered_user):
    token = login_token(client)
    listing_id = post_and_get_id(client, token)

    res = put_listing(client, token, listing_id, photo=PNG)
    assert res.status_code == 200
    assert get_mine(client, token).json()["data"]["items"][0]["image_url"] == NEW_URL


def test_edit_missing_listing_is_404(client, registered_user):
    res = put_listing(client, login_token(client), 9999)
    assert res.status_code == 404
    assert res.json()["detail"] == MSG_NOT_FOUND


def test_edit_someone_elses_listing_is_403(client, registered_user):
    listing_id = post_and_get_id(client, login_token(client))  # Ali's listing
    res = put_listing(client, other_user_token(client), listing_id)  # Sara tries
    assert res.status_code == 403
    assert res.json()["detail"] == MSG_NOT_OWNER


def test_edit_not_available_is_409(client, db_session, registered_user):
    token = login_token(client)
    listing_id = post_and_get_id(client, token)

    # Pretend someone is renting it right now.
    listing = db_session.get(Listing, listing_id)
    listing.status = "rented"
    db_session.commit()

    res = put_listing(client, token, listing_id)
    assert res.status_code == 409
    assert res.json()["detail"] == MSG_NOT_AVAILABLE


def test_edit_bad_field_is_400_and_nothing_changes(client, registered_user):
    token = login_token(client)
    listing_id = post_and_get_id(client, token)

    res = put_listing(client, token, listing_id, good_form(hourly_rate="0"))
    assert res.status_code == 400
    assert res.json()["detail"] == MSG_RATE
    assert get_mine(client, token).json()["data"]["items"][0]["hourly_rate"] == 20.0


def test_edit_bad_photo_is_400(client, registered_user):
    token = login_token(client)
    listing_id = post_and_get_id(client, token)
    res = put_listing(client, token, listing_id, photo=b"this is just text")
    assert res.status_code == 400
    assert res.json()["detail"] == MSG_PHOTO_TYPE


def test_edit_must_be_logged_in(client, registered_user):
    listing_id = post_and_get_id(client, login_token(client))
    assert put_listing(client, None, listing_id).status_code == 401