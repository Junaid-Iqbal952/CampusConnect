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