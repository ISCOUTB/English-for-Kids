import re
from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, Field, field_validator

# Mismas reglas que las palabras de los cuentos: solo letras, con espacios, guiones o
# apóstrofes en medio.
_WORD_RE = re.compile(r"^[^\W\d_]+(?:[ '\-][^\W\d_]+)*$")


class AttemptIn(BaseModel):
    palabra: str = Field(min_length=1, max_length=40, examples=["apple"])
    idioma: Literal["en", "es"]
    acierto: bool
    asistido: bool = Field(default=False, description="Acierto con ayuda tras varios fallos")
    fecha: datetime | None = Field(
        default=None,
        description="Momento real del intento, si estuvo en cola sin conexión (opcional)",
    )

    @field_validator("palabra")
    @classmethod
    def _clean_word(cls, value: str) -> str:
        word = " ".join(value.split()).casefold()
        if not _WORD_RE.match(word):
            raise ValueError("La palabra solo puede tener letras")
        return word


class AttemptsIn(BaseModel):
    nino_id: int
    intentos: list[AttemptIn] = Field(min_length=1, max_length=50)


class AttemptsOut(BaseModel):
    guardados: int


class LangStats(BaseModel):
    intentos: int = 0
    aciertos: int = 0


class WordProgress(BaseModel):
    palabra: str
    estado: Literal["dominada", "practicando", "reforzar"]
    intentos: int
    aciertos: int
    asistidos: int
    en: LangStats
    es: LangStats
    ultima_practica: datetime


class DayStats(BaseModel):
    fecha: date
    intentos: int
    aciertos: int


class ProgressSummary(BaseModel):
    nino_id: int
    total_intentos: int
    total_aciertos: int
    aciertos_asistidos: int
    palabras_practicadas: int
    palabras_dominadas: int
    palabras_por_reforzar: int
    dias_activos_semana: int
    racha_dias: int
    ultimos_dias: list[DayStats]
    palabras: list[WordProgress]
