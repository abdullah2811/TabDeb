from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.api.speech_jobs import router as speech_jobs_router
from app.core.config import get_settings
from app.core.exceptions import ApiException

settings = get_settings()
app = FastAPI(title=settings.app_name)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.exception_handler(ApiException)
async def api_exception_handler(_: Request, exc: ApiException):
    return JSONResponse(status_code=exc.status_code, content=exc.to_response())


@app.exception_handler(Exception)
async def unhandled_exception_handler(_: Request, __: Exception):
    fallback = ApiException(
        error="internal_error",
        message="An unexpected error occurred; please try again later",
        status_code=500,
    )
    return JSONResponse(status_code=500, content=fallback.to_response())


@app.get("/health")
async def health_check():
    return {"status": "ok"}


app.include_router(speech_jobs_router, prefix=settings.api_prefix)
