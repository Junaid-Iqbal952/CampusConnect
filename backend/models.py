"""
SQLAlchemy models that map to the tables that ALREADY EXIST in Supabase.

We do NOT create tables from Python (no Base.metadata.create_all on the real DB).
The table was made in the Supabase dashboard, so we only describe the columns
we need. Columns we don't list (joineddate, aggregaterating, activedevice...)
are simply left alone and Postgres fills in their defaults / NULL.
"""
from sqlalchemy import Column, Integer, String
from sqlalchemy.orm import declarative_base

Base = declarative_base()


class User(Base):
    __tablename__ = "users"

    userid = Column(Integer, primary_key=True, autoincrement=True)
    erp = Column(String, unique=True, nullable=False)
    name = Column(String, nullable=False)
    email = Column(String, unique=True, nullable=False)
    passwordhash = Column(String, nullable=False)
