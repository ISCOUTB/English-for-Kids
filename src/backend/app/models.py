"""Modelo de datos. Sigue el diagrama entidad-relación del proyecto (docs/diagramas/modelo-er.png).

Nota de privacidad: NO se guarda el audio de la voz del niño, solo el resultado.
"""

from datetime import datetime, timezone

from sqlalchemy import (
    Boolean,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.db import Base


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


class Tutor(Base):
    __tablename__ = "tutor"

    id: Mapped[int] = mapped_column(primary_key=True)
    nombre: Mapped[str] = mapped_column(String(80))
    correo: Mapped[str] = mapped_column(String(254), unique=True, index=True)  # en minúsculas
    creado_en: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    ninos: Mapped[list["Nino"]] = relationship(back_populates="tutor", cascade="all, delete-orphan")
    consentimientos: Mapped[list["Consentimiento"]] = relationship(
        back_populates="tutor", cascade="all, delete-orphan"
    )


class Nino(Base):
    __tablename__ = "nino"

    id: Mapped[int] = mapped_column(primary_key=True)
    tutor_id: Mapped[int] = mapped_column(ForeignKey("tutor.id", ondelete="CASCADE"), index=True)
    apodo: Mapped[str] = mapped_column(String(40))
    rango_edad: Mapped[str] = mapped_column(String(10))
    avatar: Mapped[str | None] = mapped_column(String(40), default=None)
    creado_en: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    tutor: Mapped[Tutor] = relationship(back_populates="ninos")
    intentos: Mapped[list["Intento"]] = relationship(back_populates="nino", cascade="all, delete-orphan")
    dominios: Mapped[list["Dominio"]] = relationship(back_populates="nino", cascade="all, delete-orphan")
    historias: Mapped[list["Historia"]] = relationship(back_populates="nino", cascade="all, delete-orphan")


class Consentimiento(Base):
    """Registro histórico: cada decisión del tutor es una fila nueva; vale la más reciente."""

    __tablename__ = "consentimiento"

    id: Mapped[int] = mapped_column(primary_key=True)
    tutor_id: Mapped[int] = mapped_column(ForeignKey("tutor.id", ondelete="CASCADE"), index=True)
    tipo: Mapped[str] = mapped_column(String(20))
    aceptado: Mapped[bool] = mapped_column(Boolean)
    fecha: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    tutor: Mapped[Tutor] = relationship(back_populates="consentimientos")


class Categoria(Base):
    __tablename__ = "categoria"

    id: Mapped[int] = mapped_column(primary_key=True)
    nombre_es: Mapped[str] = mapped_column(String(60))
    nombre_en: Mapped[str] = mapped_column(String(60))

    palabras: Mapped[list["Palabra"]] = relationship(back_populates="categoria")


class Palabra(Base):
    """Identificador estable de cada palabra del vocabulario (el contenido vive en la app)."""

    __tablename__ = "palabra"

    id: Mapped[int] = mapped_column(primary_key=True)
    categoria_id: Mapped[int] = mapped_column(ForeignKey("categoria.id"), index=True)
    texto_en: Mapped[str] = mapped_column(String(60), index=True)
    texto_es: Mapped[str] = mapped_column(String(60))
    imagen: Mapped[str | None] = mapped_column(String(200), default=None)
    audio: Mapped[str | None] = mapped_column(String(200), default=None)

    categoria: Mapped[Categoria] = relationship(back_populates="palabras")


class Intento(Base):
    __tablename__ = "intento"

    id: Mapped[int] = mapped_column(primary_key=True)
    nino_id: Mapped[int] = mapped_column(ForeignKey("nino.id", ondelete="CASCADE"), index=True)
    palabra_id: Mapped[int] = mapped_column(ForeignKey("palabra.id"), index=True)
    acierto: Mapped[bool] = mapped_column(Boolean)
    fecha: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    nino: Mapped[Nino] = relationship(back_populates="intentos")


class Dominio(Base):
    """Resumen por niño y palabra que usará el motor adaptativo (RF-04)."""

    __tablename__ = "dominio"

    nino_id: Mapped[int] = mapped_column(ForeignKey("nino.id", ondelete="CASCADE"), primary_key=True)
    palabra_id: Mapped[int] = mapped_column(ForeignKey("palabra.id"), primary_key=True)
    aciertos: Mapped[int] = mapped_column(Integer, default=0)
    errores: Mapped[int] = mapped_column(Integer, default=0)
    nivel_dominio: Mapped[float] = mapped_column(Float, default=0.0)
    ultima_practica: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), default=None)

    nino: Mapped[Nino] = relationship(back_populates="dominios")


class Historia(Base):
    __tablename__ = "historia"

    id: Mapped[int] = mapped_column(primary_key=True)
    nino_id: Mapped[int] = mapped_column(ForeignKey("nino.id", ondelete="CASCADE"), index=True)
    titulo: Mapped[str] = mapped_column(String(120))
    texto: Mapped[str] = mapped_column(Text)
    audio_ref: Mapped[str | None] = mapped_column(String(120), default=None)
    clave_cache: Mapped[str] = mapped_column(String(64), index=True)
    creada_en: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    nino: Mapped[Nino] = relationship(back_populates="historias")
    palabras: Mapped[list["HistoriaPalabra"]] = relationship(
        back_populates="historia", cascade="all, delete-orphan"
    )


class HistoriaPalabra(Base):
    __tablename__ = "historia_palabra"

    historia_id: Mapped[int] = mapped_column(
        ForeignKey("historia.id", ondelete="CASCADE"), primary_key=True
    )
    palabra_id: Mapped[int] = mapped_column(ForeignKey("palabra.id"), primary_key=True)

    historia: Mapped[Historia] = relationship(back_populates="palabras")
