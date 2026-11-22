from tests.conftest import VALID_USER


def login(client, device):
    res = client.post("/auth/login", json={
        "identifier": VALID_USER["erp"],
        "password": VALID_USER["password"],
        "device_id": device,
    })
    assert res.status_code == 200
    return res.json()["token"]


def auth(token):
    return {"Authorization": f"Bearer {token}"}


def test_me_works_with_valid_token(client, registered_user):
    token = login(client, "device-A")
    res = client.get("/auth/me", headers=auth(token))
    assert res.status_code == 200
    assert res.json()["erp"] == VALID_USER["erp"]


def test_me_without_token_is_401(client):
    assert client.get("/auth/me").status_code == 401


def test_me_with_garbage_token_is_401(client):
    assert client.get("/auth/me", headers=auth("not-a-real-token")).status_code == 401


def test_login_on_new_device_kicks_out_old_device(client, registered_user):
    token_a = login(client, "device-A")
    token_b = login(client, "device-B")
    assert client.get("/auth/me", headers=auth(token_a)).status_code == 401
    assert client.get("/auth/me", headers=auth(token_b)).status_code == 200


def test_same_device_can_log_in_again(client, registered_user):
    t1 = login(client, "device-A")
    t2 = login(client, "device-A")
    assert client.get("/auth/me", headers=auth(t1)).status_code == 200
    assert client.get("/auth/me", headers=auth(t2)).status_code == 200


def test_logout_stops_the_token(client, registered_user):
    token = login(client, "device-A")
    assert client.post("/auth/logout", headers=auth(token)).status_code == 200
    assert client.get("/auth/me", headers=auth(token)).status_code == 401


def test_change_password_success(client, registered_user):
    token = login(client, "device-A")
    res = client.post("/auth/change-password", headers=auth(token), json={
        "erp": VALID_USER["erp"], "current_password": VALID_USER["password"], "new_password": "brandnew123"})
    assert res.status_code == 200
    old = client.post("/auth/login", json={"identifier": VALID_USER["erp"],
                      "password": VALID_USER["password"], "device_id": "device-A"})
    new = client.post("/auth/login", json={"identifier": VALID_USER["erp"],
                      "password": "brandnew123", "device_id": "device-A"})
    assert old.status_code == 401
    assert new.status_code == 200


def test_change_password_wrong_current(client, registered_user):
    token = login(client, "device-A")
    res = client.post("/auth/change-password", headers=auth(token), json={
        "erp": VALID_USER["erp"], "current_password": "wrong-one", "new_password": "brandnew123"})
    assert res.status_code == 400


def test_change_password_same_as_old(client, registered_user):
    token = login(client, "device-A")
    res = client.post("/auth/change-password", headers=auth(token), json={
        "erp": VALID_USER["erp"], "current_password": VALID_USER["password"], "new_password": VALID_USER["password"]})
    assert res.status_code == 400


def test_change_password_too_short(client, registered_user):
    token = login(client, "device-A")
    res = client.post("/auth/change-password", headers=auth(token), json={
        "erp": VALID_USER["erp"], "current_password": VALID_USER["password"], "new_password": "short"})
    assert res.status_code == 400