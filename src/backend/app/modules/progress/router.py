"""Progreso del niño: guardar intentos y consultar el resumen para el tutor."""

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Query, Response, status
from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.core.db import get_db
from app.core.deps import get_current_tutor, get_owned_child
from app.models import Intento, Tutor
from app.modules.progress.schemas import AttemptsIn, AttemptsOut, ProgressSummary
from app.modules.progress.service import build_summary, normalize_attempt_time

router = APIRouter(prefix="/progress", tags=["progress"])

# Tope de seguridad al calcular el resumen (los intentos más recientes).
MAX_ROWS = 20_000


@router.post("/attempts", response_model=AttemptsOut, status_code=status.HTTP_201_CREATED)
def save_attempts(
    data: AttemptsIn,
    tutor: Tutor = Depends(get_current_tutor),
    db: Session = Depends(get_db),
):
    """Guarda intentos de práctica. La app los envía en lotes (hasta 50) y reintenta si falla."""
    nino = get_owned_child(db, tutor, data.nino_id)
    now = datetime.now(timezone.utc)
    for item in data.intentos:
        db.add(
            Intento(
                nino_id=nino.id,
                palabra=item.palabra,
                idioma=item.idioma,
                acierto=item.acierto,
                # "Con ayuda" solo tiene sentido en un acierto.
                asistido=item.asistido and item.acierto,
                fecha=normalize_attempt_time(item.fecha, now),
            )
        )
    db.commit()
    return AttemptsOut(guardados=len(data.intentos))


@router.get("/{nino_id}/summary", response_model=ProgressSummary)
def progress_summary(
    nino_id: int,
    tz_offset_min: int = Query(
        default=0,
        ge=-840,
        le=840,
        description="Diferencia de la zona horaria del tutor con UTC, en minutos (Colombia: -300)",
    ),
    tutor: Tutor = Depends(get_current_tutor),
    db: Session = Depends(get_db),
):
    nino = get_owned_child(db, tutor, nino_id)
    rows = db.scalars(
        select(Intento)
        .where(Intento.nino_id == nino.id)
        .order_by(Intento.fecha.desc(), Intento.id.desc())
        .limit(MAX_ROWS)
    ).all()
    return build_summary(nino.id, list(rows), datetime.now(timezone.utc), tz_offset_min)


@router.delete("/{nino_id}", status_code=status.HTTP_204_NO_CONTENT)
def reset_progress(
    nino_id: int,
    tutor: Tutor = Depends(get_current_tutor),
    db: Session = Depends(get_db),
):
    """Borra todo el progreso del niño (derecho del tutor a eliminar los datos, RNF-04)."""
    nino = get_owned_child(db, tutor, nino_id)
    db.execute(delete(Intento).where(Intento.nino_id == nino.id))
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
