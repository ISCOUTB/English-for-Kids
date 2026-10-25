import re
from typing import Literal

from pydantic import BaseModel, Field, field_validator

_CONTROL_AND_TAGS = re.compile(r"[\x00-\x1f\x7f<>]")


class SpeechCheckOut(BaseModel):
    # Resultado categórico a propósito: la app muestra refuerzo positivo, nunca porcentajes (RF-03).
    resultado: Literal["acierto", "intentar_de_nuevo"]
    # Solo para que el tutor o el equipo evalúen el reconocimiento; la app del niño no la muestra.
    transcripcion: str


class JudgeIn(BaseModel):
    """Lo que el reconocedor DEL TELÉFONO entendió. Nunca se envía audio a este endpoint."""

    nino_id: int
    palabra: str = Field(min_length=1, max_length=40, examples=["cat"])
    escuchado: list[str] = Field(
        max_length=5, description="Alternativas de transcripción, de la más a la menos probable"
    )

    @field_validator("palabra", "escuchado", mode="before")
    @classmethod
    def _sanitize(cls, value):
        # Lo que "escuchó" el reconocedor es texto NO confiable que acabará dentro de un prompt:
        # se quitan "<", ">" y caracteres de control para que no pueda cerrar las etiquetas.
        def clean(text: str) -> str:
            return " ".join(_CONTROL_AND_TAGS.sub(" ", str(text)).split())[:60]

        if isinstance(value, list):
            return [c for c in (clean(v) for v in value) if c]
        return clean(value)


class JudgeOut(BaseModel):
    resultado: Literal["acierto", "intentar_de_nuevo"]
