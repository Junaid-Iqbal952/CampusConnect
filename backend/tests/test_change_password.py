"""
Tests for SCRUM-13: change password with ERP + current password (FR-1.7, Use Case 3).
Test IDs match Deliverable 5. Run from the backend folder with:   pytest -v
The general change-password tests (success, too short, same as old) are in test_session.py.
"""
from auth import MSG_SAME_PASSWORD, MSG_WRONG_CURRENT
from tests.conftest import VALID_USER

URL = "/auth/change-password"


def login_token(client, erp="12345", device="device-A"):
    res = client.post(
        "/auth/login",
        json={"identifier": erp, "password": "secret123", "device_id": device},
    )
    assert res.status_code == 200
    return res.json()["token"]


def change(client, token, erp="12345", current="secret123", new="newpass456"):
    return client.post(
        URL,
        json={"erp": erp, "current_password": current, "new_password": new},
        headers={"Authorization": f"Bearer {token}"},
    )


def test_TC_AUTH_POS_05_change_with_erp_and_current_password(client, registered_user):
    res = change(client, login_token(client))
    assert res.status_code == 200
    login_new = client.post(
        "/auth/login", json={"identifier": "12345", "password": "newpass456", "device_id": "device-A"}
    )
    assert login_new.status_code == 200


def test_TC_AUTH_NEG_04_new_password_same_as_old(client, registered_user):
    res = change(client, login_token(client), new="secret123")
    assert res.status_code == 400
    assert res.json()["detail"] == MSG_SAME_PASSWORD


def test_wrong_erp_rejected(client, registered_user):
    res = change(client, login_token(client), erp="54321")
    assert res.status_code == 400
    assert res.json()["detail"] == MSG_WRONG_CURRENT


def test_wrong_current_password_rejected(client, registered_user):
    res = change(client, login_token(client), current="notmypass")
    assert res.status_code == 400
    assert res.json()["detail"] == MSG_WRONG_CURRENT


def test_wrong_erp_does_not_log_user_out(client, registered_user):
    # 400, not 401: a typo in the form must not end the session.
    token = login_token(client)
    change(client, token, erp="54321")
    assert client.get("/auth/me", headers={"Authorization": f"Bearer {token}"}).status_code == 200


def test_missing_erp_rejected(client, registered_user):
    res = client.post(
        URL,
        json={"current_password": "secret123", "new_password": "newpass456"},
        headers={"Authorization": f"Bearer {login_token(client)}"},
    )
    assert res.status_code == 422  # FastAPI: required field missing


def test_cannot_change_someone_elses_password(client, registered_user):
    client.post("/auth/signup", json={**VALID_USER, "erp": "54321", "email": "other@khi.iba.edu.pk"})
    other_token = login_token(client, erp="54321", device="device-B")
    res = change(client, other_token, erp="12345")  # user 54321 tries user 12345's ERP
    assert res.status_code == 400
    assert login_token(client)  # user 12345's password unchanged
