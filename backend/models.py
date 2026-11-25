"""
SQLAlchemy models that map to the tables that ALREADY EXIST in Supabase.

We do NOT create tables from Python (no Base.metadata.create_all on the real DB).
The table was made in the Supabase dashboard, so we only describe the columns
we need. Columns we don't list (joineddate, aggregaterating, activedevice...)
are simply left alone and Postgres fills in their defaults / NULL.
"""
from sqlalchemy import Boolean, Column, DateTime, Integer, Numeric, String, func
from sqlalchemy.orm import declarative_base

Base = declarative_base()


class User(Base):
    __tablename__ = "users"

    userid = Column(Integer, primary_key=True, autoincrement=True)
    erp = Column(String, unique=True, nullable=False)
    name = Column(String, nullable=False)
    email = Column(String, unique=True, nullable=False)
    passwordhash = Column(String, nullable=False)
    activedeviceid = Column(String, nullable=True)

class Listing(Base):
    __tablename__ = "listings"

    listingid = Column(Integer, primary_key=True, autoincrement=True)
    userid = Column(Integer, nullable=False)
    title = Column(String, nullable=False)
    description = Column(String, nullable=False)
    photourl = Column(String, nullable=False)
    hourlyrate = Column(Numeric(10, 2), nullable=False)
    condition = Column(String, nullable=False)
    maxduration = Column(Integer, nullable=False)
    negotiable = Column(Boolean, nullable=False)
    campus = Column(String, nullable=False)
    # We never set these two: the database fills them in (status = 'available').
    status = Column(String, server_default="available")
    postedat = Column(DateTime, server_default=func.now())