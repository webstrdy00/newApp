from fastapi import APIRouter

from app.api.routes import auth, files, records

api_router = APIRouter()
api_router.include_router(auth.router)
api_router.include_router(files.router)
api_router.include_router(records.router)
