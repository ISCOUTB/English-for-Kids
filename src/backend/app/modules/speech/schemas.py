from typing import Literal

from pydantic import BaseModel


class SpeechCheckOut(BaseModel):
    # Resultado categórico a propósito: la app muestra refuerzo positivo, nunca porcentajes (RF-03).
    resultado: Literal["acierto", "intentar_de_nuevo"]
    # Solo para que el tutor o el equipo evalúen el reconocimiento; la app del niño no la muestra.
    transcripcion: str
