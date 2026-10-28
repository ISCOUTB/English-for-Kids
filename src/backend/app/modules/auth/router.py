"""Identificación del tutor (ADR-008).

Camino principal: "Continuar con Google". La app obtiene un token de identidad de Google y lo
envía a `POST /auth/google`; el servidor lo comprueba con Google, así que el correo está
verificado y nadie puede entrar con el correo de otra persona.

El acceso con solo nombre y correo (`/auth/register`, `/auth/login`) no verifica nada: quien
conozca esos datos entra como el tutor. Por eso está apagado por defecto y solo se enciende
para pruebas con ENABLE_BASIC_LOGIN=true.
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.config import Settings, get_settings
from app.core.db import get_db
from app.core.deps import get_current_tutor
from app.core.security import create_access_token
from app.core.text import fold
from app.models import Tutor
from app.modules.auth.schemas import GoogleLoginIn, TokenOut, TutorCredentials, TutorOut
from app.providers import get_google_verifier
from app.providers.base import GoogleIdentityVerifier, InvalidIdentityToken

router = APIRouter(prefix="/auth", tags=["auth"])

# Mismo mensaje si falla el correo o el nombre: no se revela cuál de los dos está mal.
_BAD_CREDENTIALS = "Nombre o correo incorrectos."


_BASIC_LOGIN_OFF = "Este método de inicio de sesión está desactivado. Usa tu cuenta de Google."


def _require_basic_login(settings: Settings) -> None:
    if not settings.enable_basic_login:
        raise HTTPException(status.HTTP_403_FORBIDDEN, _BASIC_LOGIN_OFF)


def _token_response(tutor: Tutor, settings: Settings) -> TokenOut:
    return TokenOut(
        access_token=create_access_token(tutor.id, settings),
        tutor=TutorOut.model_validate(tutor),
    )


@router.post("/register", response_model=TokenOut, status_code=status.HTTP_201_CREATED)
def register(
    data: TutorCredentials,
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings),
):
    _require_basic_login(settings)
    correo = data.correo.lower()
    if db.scalar(select(Tutor).where(Tutor.correo == correo)):
        raise HTTPException(status.HTTP_409_CONFLICT, "Ya existe una cuenta con ese correo.")
    tutor = Tutor(nombre=data.nombre, correo=correo)
    db.add(tutor)
    try:
        db.commit()
    except IntegrityError:  # dos registros simultáneos con el mismo correo
        db.rollback()
        raise HTTPException(status.HTTP_409_CONFLICT, "Ya existe una cuenta con ese correo.")
    return _token_response(tutor, settings)


@router.post("/login", response_model=TokenOut)
def login(
    data: TutorCredentials,
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings),
):
    _require_basic_login(settings)
    tutor = db.scalar(select(Tutor).where(Tutor.correo == data.correo.lower()))
    if tutor is None or fold(tutor.nombre) != fold(data.nombre):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, _BAD_CREDENTIALS)
    return _token_response(tutor, settings)


@router.post("/google", response_model=TokenOut)
def login_with_google(
    data: GoogleLoginIn,
    db: Session = Depends(get_db),
    settings: Settings = Depends(get_settings),
    verifier: GoogleIdentityVerifier = Depends(get_google_verifier),
):
    """Entra (o crea la cuenta) con una cuenta de Google. El correo viene verificado por Google."""
    try:
        identity = verifier.verify(data.id_token)
    except InvalidIdentityToken:
        raise HTTPException(
            status.HTTP_401_UNAUTHORIZED, "No pudimos verificar tu cuenta de Google. Intenta de nuevo."
        )
    if not identity.email_verified:
        raise HTTPException(
            status.HTTP_403_FORBIDDEN, "Tu correo de Google no está verificado."
        )

    correo = identity.email.lower()
    tutor = db.scalar(select(Tutor).where(Tutor.correo == correo))
    if tutor is None:
        nombre = " ".join((identity.name or correo.split("@")[0]).split())[:80] or "Tutor"
        tutor = Tutor(nombre=nombre, correo=correo)
        db.add(tutor)
        try:
            db.commit()
        except IntegrityError:  # dos inicios simultáneos con la misma cuenta
            db.rollback()
            tutor = db.scalar(select(Tutor).where(Tutor.correo == correo))
            if tutor is None:
                raise
    return _token_response(tutor, settings)


@router.get("/me", response_model=TutorOut)
def me(tutor: Tutor = Depends(get_current_tutor)):
    return tutor
