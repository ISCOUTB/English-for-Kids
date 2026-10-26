"""Fábrica de proveedores.

ESTE es el único lugar que sabe qué proveedor concreto se usa. Para probar
Whisper o Azure en lugar de ElevenLabs, se cambia solo la función
correspondiente. En las pruebas se reemplazan con `app.dependency_overrides`.
"""

from functools import lru_cache

from app.core.config import get_settings
from app.core.ratelimit import RateLimiter
from app.providers.base import PronunciationJudge, SpeechToText, TextGenerator, TextToSpeech
from app.providers.elevenlabs import ElevenLabsSTT, ElevenLabsTTS
from app.providers.gemini import GeminiPronunciationJudge, GeminiTextGenerator


@lru_cache
def get_text_generator() -> TextGenerator:
    s = get_settings()
    return GeminiTextGenerator(api_key=s.google_api_key, model=s.gemini_model)


@lru_cache
def get_text_to_speech() -> TextToSpeech:
    s = get_settings()
    return ElevenLabsTTS(
        api_key=s.elevenlabs_api_key,
        voice_id=s.elevenlabs_voice_id,
        voice_id_es=s.elevenlabs_voice_id_es,
        model_id=s.elevenlabs_tts_model,
    )


@lru_cache
def get_speech_to_text() -> SpeechToText:
    s = get_settings()
    return ElevenLabsSTT(api_key=s.elevenlabs_api_key, model_id=s.elevenlabs_stt_model)


@lru_cache
def get_pronunciation_judge() -> PronunciationJudge:
    s = get_settings()
    return GeminiPronunciationJudge(api_key=s.google_api_key, model=s.gemini_model)


@lru_cache
def get_judge_limiter() -> RateLimiter:
    # Ventana de una hora por tutor: protege la cuota gratuita de la IA.
    return RateLimiter(limit=get_settings().judge_hourly_limit, window_seconds=3600)
