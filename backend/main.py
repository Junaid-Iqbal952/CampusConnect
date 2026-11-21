from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text

from auth import router as auth_router
from database import engine

app = FastAPI(title="CampusConnect API")

# The Flutter WEB app runs on a different port (e.g. localhost:54321) than this
# API (localhost:8000). Browsers block that unless we allow it with CORS.
# "*" is fine for development; lock it down before deploying.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router)


# test database connection
@app.get("/")
def read_root():
    try:
        with engine.connect() as connection:
            connection.execute(text("SELECT 1"))
            return {"message": "CampusConnect backend is running and database is connected"}
    except Exception as e:
        return {"message": f"Error connecting to database: {str(e)}"}
