"""
Test setup: tests run against a throwaway in-memory SQLite database,
NOT the real Supabase one, so they're fast and never create junk users.
"""
import os

# Must be set BEFORE database.py is imported (it reads DATABASE_URL on import).
os.environ["DATABASE_URL"] = "sqlite://"
os.environ["JWT_SECRET"] = "test-secret-that-is-at-least-32-bytes-long"

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from database import get_db
from main import app
from models import Base

test_engine = create_engine(
    "sqlite://",
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,  # one shared in-memory DB for the whole test
)
TestingSession = sessionmaker(bind=test_engine, autocommit=False, autoflush=False)


@pytest.fixture()
def client():
    Base.metadata.create_all(test_engine)  # fresh empty tables for each test

    def override_get_db():
        db = TestingSession()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[get_db] = override_get_db
    yield TestClient(app)
    app.dependency_overrides.clear()
    Base.metadata.drop_all(test_engine)


@pytest.fixture()
def db_session():
    db = TestingSession()
    yield db
    db.close()


VALID_USER = {
    "name": "Ali Khan",
    "erp": "12345",
    "email": "a.khan.12345@khi.iba.edu.pk",
    "password": "secret123",
}


@pytest.fixture()
def registered_user(client):
    res = client.post("/auth/signup", json=VALID_USER)
    assert res.status_code == 201
    return VALID_USER
