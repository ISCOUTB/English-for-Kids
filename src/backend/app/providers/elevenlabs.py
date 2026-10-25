"""Adaptadores de ElevenLabs: texto a voz (historias) y voz a texto (palabras del niño)."""

import io
import logging

from elevenlabs.client import ElevenLabs

from app.providers.base import ProviderError, ProviderNotConfigured

log = logging.getLogger(__name__)


class _ElevenLabsBase:
    def __init__(self, api_key: str):
        self._api_key = api_key
        self._client: ElevenLabs | None = None

    def _get_client(self) -> ElevenLabs:
        if not self._api_key:
            raise ProviderNotConfigured("ELEVENLABS_API_KEY no está definida")
        if self._client is None:
            self._client = ElevenLabs(api_key=self._api_key)
        return self._client


class ElevenLabsTTS(_ElevenLabsBase):
    def __init__(self, api_key: str, voice_id: str, model_id: str):
        super().__init__(api_key)
        self._voice_id = voice_id
        self._model_id = model_id

    def synthesize(self, text: str) -> bytes:
        try:
            chunks = self._get_client().text_to_speech.convert(
                voice_id=self._voice_id, model_id=self._model_id, text=text
            )
            audio = b"".join(chunks)
        except ProviderError:
            raise
        except Exception as exc:
            log.exception("Fallo al generar audio con ElevenLabs")
            raise ProviderError(f"ElevenLabs TTS: {type(exc).__name__}") from exc
        if not audio:
            raise ProviderError("ElevenLabs TTS devolvió audio vacío")
        return audio


class ElevenLabsSTT(_ElevenLabsBase):
    def __init__(self, api_key: str, model_id: str):
        super().__init__(api_key)
        self._model_id = model_id

    def transcribe(self, audio: bytes, content_type: str | None = None) -> str:
        try:
            result = self._get_client().speech_to_text.convert(
                file=io.BytesIO(audio),
                model_id=self._model_id,
                language_code="eng",  # el niño practica palabras en inglés
                tag_audio_events=False,
                diarize=False,
            )
        except ProviderError:
            raise
        except Exception as exc:
            log.exception("Fallo al transcribir con ElevenLabs")
            raise ProviderError(f"ElevenLabs STT: {type(exc).__name__}") from exc

        text = getattr(result, "text", None)
        if text is None:
            # Respuesta por canales: se unen las transcripciones.
            text = " ".join(getattr(t, "text", "") for t in getattr(result, "transcripts", []) or [])
        return (text or "").strip()
