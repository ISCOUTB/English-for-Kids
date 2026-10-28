"""Interfaces de los proveedores externos (ADR-004).

Los módulos de negocio (stories, speech) dependen SOLO de estas interfaces.
Para cambiar de proveedor se escribe un adaptador nuevo que las cumpla y se
cambia una línea en providers/__init__.py; nada más se toca (RNF-03).
"""

from dataclasses import dataclass
from typing import Protocol


class ProviderError(Exception):
    """Fallo de un servicio externo. El mensaje público nunca incluye detalles internos."""

    public_message = "El servicio externo no pudo completar la petición. Intenta de nuevo."

    def __init__(self, detail: str = "", public_message: str | None = None):
        super().__init__(detail or self.public_message)
        if public_message:
            self.public_message = public_message


class InvalidIdentityToken(Exception):
    """El token de inicio de sesión no es válido, está vencido o es de otra app."""


@dataclass(frozen=True)
class GoogleIdentity:
    email: str
    email_verified: bool
    name: str | None = None


class GoogleIdentityVerifier(Protocol):
    def verify(self, id_token: str) -> GoogleIdentity:
        """Comprueba con Google el token de identidad y devuelve quién es.

        Lanza `InvalidIdentityToken` si no es válido y `ProviderError` si Google no responde.
        """
        ...


class ProviderNotConfigured(ProviderError):
    public_message = "Este servicio todavía no está configurado en el servidor."


class TextGenerator(Protocol):
    def generate(self, prompt: str, system: str | None = None) -> str:
        """Devuelve el texto generado. Lanza ProviderError si falla o si se bloquea."""
        ...


class TextToSpeech(Protocol):
    def synthesize(self, text: str, language: str = "es") -> bytes:
        """Devuelve el audio (mp3) del texto. `language` ("es" o "en") elige la voz."""
        ...


class PronunciationJudge(Protocol):
    def judge(
        self, target: str, heard: list[str], language: str = "en", age_range: str = "3-4"
    ) -> bool:
        """¿Alguna de las transcripciones `heard` es un intento razonable de decir `target`?

        `language` es el idioma de la palabra objetivo ("en" o "es") y `age_range` el rango
        de edad del niño ("3-4" o "5-6"; a menor edad, más indulgente). Es una segunda
        opinión para niños de 3 a 6 años. Solo recibe texto.
        """
        ...


class SpeechToText(Protocol):
    def transcribe(self, audio: bytes, content_type: str | None = None) -> str:
        """Devuelve la transcripción en inglés del audio."""
        ...
