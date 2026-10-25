"""Identificación del tutor con nombre y correo (ADR-008).

IMPORTANTE: sin contraseña ni código de verificación, quien conozca el nombre
y el correo de un tutor puede entrar como él. Es una decisión consciente para el
prototipo; la mejora prevista es un código de un solo uso enviado al correo.
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
from app.modules.auth.schemas import TokenOut, TutorCredentials, TutorOut

router = APIRouter(prefix="/auth", tags=["auth"])

# Mismo mensaje si falla el correo o el nombre: no se revela cuál de los dos está mal.
_BAD_CREDENTIALS = "Nombre o correo incorrectos."


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
    tutor = db.scalar(select(Tutor).where(Tutor.correo == data.correo.lower()))
    if tutor is None or fold(tutor.nombre) != fold(data.nombre):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, _BAD_CREDENTIALS)
    return _token_response(tutor, settings)


@router.get("/me", response_model=TutorOut)
def me(tutor: Tutor = Depends(get_current_tutor)):
    return tutor
