"""Zona del tutor: perfiles de niños y consentimientos."""

from fastapi import APIRouter, Depends, Response, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.db import get_db
from app.core.deps import get_current_tutor, get_owned_child
from app.models import Consentimiento, Nino, Tutor
from app.modules.family.schemas import ChildIn, ChildOut, ConsentIn, ConsentOut

router = APIRouter(tags=["family"])


@router.post("/children", response_model=ChildOut, status_code=status.HTTP_201_CREATED)
def create_child(
    data: ChildIn,
    tutor: Tutor = Depends(get_current_tutor),
    db: Session = Depends(get_db),
):
    nino = Nino(tutor_id=tutor.id, apodo=data.apodo, rango_edad=data.rango_edad, avatar=data.avatar)
    db.add(nino)
    db.commit()
    return nino


@router.get("/children", response_model=list[ChildOut])
def list_children(tutor: Tutor = Depends(get_current_tutor), db: Session = Depends(get_db)):
    return db.scalars(select(Nino).where(Nino.tutor_id == tutor.id).order_by(Nino.id)).all()


@router.delete("/children/{nino_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_child(
    nino_id: int,
    tutor: Tutor = Depends(get_current_tutor),
    db: Session = Depends(get_db),
):
    """Borra al niño y todo su progreso e historias (derecho del tutor a eliminar los datos)."""
    nino = get_owned_child(db, tutor, nino_id)
    db.delete(nino)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/consents", response_model=ConsentOut, status_code=status.HTTP_201_CREATED)
def set_consent(
    data: ConsentIn,
    tutor: Tutor = Depends(get_current_tutor),
    db: Session = Depends(get_db),
):
    """Registra una decisión (aceptar o revocar). Se conserva el historial; vale la última."""
    consent = Consentimiento(tutor_id=tutor.id, tipo=data.tipo, aceptado=data.aceptado)
    db.add(consent)
    db.commit()
    return consent


@router.get("/consents", response_model=list[ConsentOut])
def list_consents(tutor: Tutor = Depends(get_current_tutor), db: Session = Depends(get_db)):
    return db.scalars(
        select(Consentimiento)
        .where(Consentimiento.tutor_id == tutor.id)
        .order_by(Consentimiento.id.desc())
    ).all()
