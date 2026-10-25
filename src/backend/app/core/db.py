"""Conexión a la base de datos (SQLAlchemy)."""

from collections.abc import Iterator
from functools import lru_cache

from sqlalchemy import create_engine
from sqlalchemy.engine import Engine, make_url
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from app.core.config import get_settings


class Base(DeclarativeBase):
    pass


@lru_cache
def get_engine() -> Engine:
    url = get_settings().sqlalchemy_url
    kwargs: dict = {"pool_pre_ping": True}
    if make_url(url).get_backend_name() == "sqlite":
        # SQLite solo se usa en desarrollo local y en las pruebas.
        kwargs["connect_args"] = {"check_same_thread": False}
    return create_engine(url, **kwargs)


@lru_cache
def get_sessionmaker() -> sessionmaker[Session]:
    return sessionmaker(bind=get_engine(), expire_on_commit=False)


def get_db() -> Iterator[Session]:
    """Dependencia de FastAPI: una sesión por petición, siempre cerrada."""
    db = get_sessionmaker()()
    try:
        yield db
    finally:
        db.close()
