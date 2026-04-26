from fastapi import APIRouter

from app.api.routes import files, records

api_router = APIRouter()
api_router.include_router(files.router)
api_router.include_router(records.router)
