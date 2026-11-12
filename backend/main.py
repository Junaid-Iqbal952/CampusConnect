from fastapi import FastAPI
from database import engine
from sqlalchemy import text

app = FastAPI()
@app.get("/")

# test database connection
def read_root():
    try:
        with engine.connect() as connection:
            result = connection.execute(text("SELECT 1"))
            return {"message": "CampusConnect backend is running and database is connected"}
    except Exception as e:
        return {"message": f"Error connecting to database: {str(e)}"}