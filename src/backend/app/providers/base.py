"""Interfaces de los proveedores externos (ADR-004).

Los módulos de negocio (stories, speech) dependen SOLO de estas interfaces.
Para cambiar de proveedor se escribe un adaptador nuevo que las cumpla y se
cambia una línea en providers/__init__.py; nada más se toca (RNF-03).
"""

from typing import Protocol


class ProviderError(Exception):
    """Fallo de un servicio externo. El mensaje público nunca incluye detalles internos."""

    public_message = "El servicio externo no pudo completar la petición. Intenta de nuevo."

    def __init__(self, detail: str = "", public_message: str | None = None):
        super().__init__(detail or self.public_message)
        if public_message:
            self.public_message = public_message


class ProviderNotConfigured(ProviderError):
    public_message = "Este servicio todavía no está configurado en el servidor."


class TextGenerator(Protocol):
    def generate(self, prompt: str, system: str | None = None) -> str:
        """Devuelve el texto generado. Lanza ProviderError si falla o si se bloquea."""
        ...


class TextToSpeech(Protocol):
    def synthesize(self, text: str) -> bytes:
        """Devuelve el audio (mp3) del texto."""
        ...


class SpeechToText(Protocol):
    def transcribe(self, audio: bytes, content_type: str | None = None) -> str:
        """Devuelve la transcripción en inglés del audio."""
        ...
