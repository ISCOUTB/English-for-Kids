"""Adaptador de Google AI Studio (Gemini) con el SDK actual `google-genai`.

El SDK anterior (`google-generativeai`) está en desuso desde noviembre de 2025.
"""

import logging

from google import genai
from google.genai import types

from app.providers.base import ProviderError, ProviderNotConfigured

log = logging.getLogger(__name__)

# Filtros de seguridad del propio modelo: bloquea desde el nivel más bajo de riesgo.
_SAFETY = [
    types.SafetySetting(category=category, threshold="BLOCK_LOW_AND_ABOVE")
    for category in (
        "HARM_CATEGORY_HARASSMENT",
        "HARM_CATEGORY_HATE_SPEECH",
        "HARM_CATEGORY_SEXUALLY_EXPLICIT",
        "HARM_CATEGORY_DANGEROUS_CONTENT",
    )
]


class GeminiTextGenerator:
    def __init__(self, api_key: str, model: str):
        self._api_key = api_key
        self._model = model
        self._client: genai.Client | None = None

    def _get_client(self) -> genai.Client:
        if not self._api_key:
            raise ProviderNotConfigured("GOOGLE_API_KEY no está definida")
        if self._client is None:
            self._client = genai.Client(api_key=self._api_key)
        return self._client

    def generate(self, prompt: str, system: str | None = None) -> str:
        config = types.GenerateContentConfig(
            system_instruction=system,
            temperature=0.8,
            max_output_tokens=1024,
            safety_settings=_SAFETY,
        )
        try:
            response = self._get_client().models.generate_content(
                model=self._model, contents=prompt, config=config
            )
        except ProviderError:
            raise
        except Exception as exc:  # el SDK lanza varios tipos de error
            log.exception("Fallo al llamar a Gemini")
            raise ProviderError(f"Gemini: {type(exc).__name__}") from exc

        text = (response.text or "").strip()
        if not text:
            # Respuesta vacía: normalmente la bloquearon los filtros de seguridad.
            raise ProviderError(
                "Gemini devolvió una respuesta vacía o bloqueada",
                public_message="No se pudo crear una historia con esas palabras. Prueba con otras.",
            )
        return text
