"""Regla de consentimiento (RNF-04): sin consentimiento de voz no se usa el micrófono."""

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Consentimiento


def has_consent(db: Session, tutor_id: int, tipo: str) -> bool:
    """Vale la decisión MÁS RECIENTE del tutor para ese tipo de consentimiento."""
    latest = db.scalar(
        select(Consentimiento)
        .where(Consentimiento.tutor_id == tutor_id, Consentimiento.tipo == tipo)
        .order_by(Consentimiento.id.desc())
        .limit(1)
    )
    return bool(latest and latest.aceptado)
