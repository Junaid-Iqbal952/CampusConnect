"""
Backend tests for SCRUM-7, 8, 9. Test IDs match Deliverable 5 (Test Strategy).
Run from the backend folder with:   pytest -v
"""
import pytest

from auth import (
    MSG_BAD_EMAIL,
    MSG_BAD_ERP,
    MSG_EMAIL_TAKEN,
    MSG_ERP_TAKEN,
    MSG_NAME_REQUIRED,
    MSG_SHORT_PASSWORD,
    MSG_WRONG_CREDENTIALS,
)
from models import User
from tests.conftest import VALID_USER


# ---------------- Sign up ----------------

def test_signup_success_returns_token_and_user(client):
    res = client.post("/auth/signup", json=VALID_USER)
    assert res.status_code == 201
    body = res.json()
    assert body["token"]
    assert body["user"]["erp"] == "12345"
    assert body["user"]["email"] == VALID_USER["email"]
    assert "password" not in body["user"] and "passwordhash" not in body["user"]


def test_signup_stores_hashed_password_not_plain_text(client, db_session):  # SCRUM-7
    client.post("/auth/signup", json=VALID_USER)
    user = db_session.query(User).filter_by(erp="12345").one()
    assert user.passwordhash != VALID_USER["password"]
    assert user.passwordhash.startswith("$2")  # bcrypt hash


def test_signup_email_saved_lowercase(client):
    res = client.post("/auth/signup", json={**VALID_USER, "email": "A.Khan.12345@KHI.IBA.EDU.PK"})
    assert res.json()["user"]["email"] == "a.khan.12345@khi.iba.edu.pk"


def test_TC_AUTH_NEG_02_non_iba_email_rejected(client):
    res = client.post("/auth/signup", json={**VALID_USER, "email": "student@gmail.com"})
    assert res.status_code == 400
    assert res.json()["detail"] == MSG_BAD_EMAIL


@pytest.mark.parametrize("bad_erp", ["1234", "123456", "12a45", "", "     "])
def test_TC_AUTH_NEG_03_invalid_erp_rejected(client, bad_erp):
    res = client.post("/auth/signup", json={**VALID_USER, "erp": bad_erp})
    assert res.status_code == 400
    assert res.json()["detail"] == MSG_BAD_ERP


def test_short_password_rejected(client):  # SCRUM-7 / FR-1.2
    res = client.post("/auth/signup", json={**VALID_USER, "password": "1234567"})
    assert res.status_code == 400
    assert res.json()["detail"] == MSG_SHORT_PASSWORD


def test_empty_name_rejected(client):
    res = client.post("/auth/signup", json={**VALID_USER, "name": "   "})
    assert res.status_code == 400
    assert res.json()["detail"] == MSG_NAME_REQUIRED


def test_duplicate_erp_rejected(client, registered_user):
    res = client.post("/auth/signup", json={**VALID_USER, "email": "other@khi.iba.edu.pk"})
    assert res.status_code == 409
    assert res.json()["detail"] == MSG_ERP_TAKEN


def test_duplicate_email_rejected(client, registered_user):
    res = client.post("/auth/signup", json={**VALID_USER, "erp": "54321"})
    assert res.status_code == 409
    assert res.json()["detail"] == MSG_EMAIL_TAKEN


# ---------------- Log in (SCRUM-8) ----------------

def test_TC_AUTH_POS_03_login_with_erp(client, registered_user):
    res = client.post("/auth/login", json={"identifier": "12345", "password": "secret123"})
    assert res.status_code == 200
    assert res.json()["token"]
    assert res.json()["user"]["name"] == "Ali Khan"


def test_TC_AUTH_POS_02_login_with_email(client, registered_user):
    res = client.post(
        "/auth/login",
        json={"identifier": "A.KHAN.12345@khi.iba.edu.pk ", "password": "secret123"},
    )
    assert res.status_code == 200


# ---------------- Wrong credentials (SCRUM-9) ----------------

def test_TC_AUTH_NEG_01_wrong_password(client, registered_user):
    res = client.post("/auth/login", json={"identifier": "12345", "password": "wrongpass"})
    assert res.status_code == 401
    assert res.json()["detail"] == MSG_WRONG_CREDENTIALS


def test_unknown_erp_gives_same_message_as_wrong_password(client, registered_user):
    res = client.post("/auth/login", json={"identifier": "99999", "password": "secret123"})
    assert res.status_code == 401
    assert res.json()["detail"] == MSG_WRONG_CREDENTIALS


def test_empty_fields_rejected(client):
    res = client.post("/auth/login", json={"identifier": "", "password": ""})
    assert res.status_code == 401
    assert res.json()["detail"] == MSG_WRONG_CREDENTIALS


def test_password_is_case_sensitive(client, registered_user):
    res = client.post("/auth/login", json={"identifier": "12345", "password": "SECRET123"})
    assert res.status_code == 401
