"""Tokens de sesión (JWT)."""

from datetime import datetime, timedelta, timezone

import jwt

from app.core.config import Settings

ALGORITHM = "HS256"


def create_access_token(tutor_id: int, settings: Settings) -> str:
    expires = datetime.now(timezone.utc) + timedelta(minutes=settings.jwt_expire_minutes)
    payload = {"sub": str(tutor_id), "exp": expires}
    return jwt.encode(payload, settings.secret_key, algorithm=ALGORITHM)


def decode_access_token(token: str, settings: Settings) -> int | None:
    """Devuelve el id del tutor, o None si el token no es válido o expiró."""
    try:
        payload = jwt.decode(token, settings.secret_key, algorithms=[ALGORITHM])
        return int(payload["sub"])
    except (jwt.PyJWTError, KeyError, ValueError):
        return None
