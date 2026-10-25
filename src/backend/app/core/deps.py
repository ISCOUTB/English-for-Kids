"""Dependencias compartidas por los módulos: usuario actual y control de acceso."""

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.core.config import Settings, get_settings
from app.core.db import get_db
from app.core.security import decode_access_token
from app.models import Nino, Tutor

_bearer = HTTPBearer(auto_error=False)


def get_current_tutor(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings),
) -> Tutor:
    unauthorized = HTTPException(
        status.HTTP_401_UNAUTHORIZED,
        "Sesión no válida. Inicia sesión de nuevo.",
        headers={"WWW-Authenticate": "Bearer"},
    )
    if credentials is None:
        raise unauthorized
    tutor_id = decode_access_token(credentials.credentials, settings)
    tutor = db.get(Tutor, tutor_id) if tutor_id is not None else None
    if tutor is None:
        raise unauthorized
    return tutor


def get_owned_child(db: Session, tutor: Tutor, nino_id: int) -> Nino:
    """Devuelve el niño solo si pertenece al tutor. Si no, responde 404 (no revela que existe)."""
    nino = db.get(Nino, nino_id)
    if nino is None or nino.tutor_id != tutor.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Niño no encontrado.")
    return nino
