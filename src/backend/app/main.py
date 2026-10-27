"""English-for-Kids — backend (monolito modular, ADR-001)."""

import logging
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy import text
from sqlalchemy.orm import Session

from app import models  # noqa: F401  (registra las tablas antes de crearlas)
from app.core.config import get_settings
from app.core.db import Base, get_db, get_engine
from app.core.migrations import upgrade_schema
from app.modules.auth.router import router as auth_router
from app.modules.family.router import router as family_router
from app.modules.progress.router import router as progress_router
from app.modules.speech.router import router as speech_router
from app.modules.stories.router import router as stories_router
from app.providers.base import ProviderError, ProviderNotConfigured

logging.basicConfig(level=logging.INFO)
log = logging.getLogger("english_for_kids")


@asynccontextmanager
async def lifespan(_: FastAPI):
    # Crea las tablas que falten. Para cambios futuros del esquema habrá que usar
    # migraciones (Alembic): create_all no modifica tablas que ya existen.
    Base.metadata.create_all(get_engine())
    upgrade_schema(get_engine())
    yield


app = FastAPI(
    title="English-for-Kids API",
    version="0.1.0",
    description="Backend de la app de aprendizaje de inglés para niños de 3 a 6 años.",
    lifespan=lifespan,
)

_origins = get_settings().cors_origin_list
if _origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=_origins,
        allow_credentials=False,  # se usa token en cabecera, no cookies
        allow_methods=["*"],
        allow_headers=["*"],
    )


@app.exception_handler(ProviderError)
async def provider_error_handler(request: Request, exc: ProviderError):
    log.warning("Fallo de proveedor en %s: %s", request.url.path, exc)
    code = 503 if isinstance(exc, ProviderNotConfigured) else 502
    # Al cliente solo le llega un mensaje seguro; los detalles quedan en el registro del servidor.
    return JSONResponse(status_code=code, content={"detail": exc.public_message})


app.include_router(auth_router)
app.include_router(family_router)
app.include_router(stories_router)
app.include_router(speech_router)
app.include_router(progress_router)


@app.get("/health", tags=["health"])
def health():
    return {"status": "ok"}


@app.get("/health/db", tags=["health"])
def health_db(db: Session = Depends(get_db)):
    db.execute(text("SELECT 1"))
    return {"status": "ok", "database": "ok"}
