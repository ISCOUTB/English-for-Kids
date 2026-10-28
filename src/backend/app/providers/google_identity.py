"""Verificación del token de identidad de Google ("Continuar con Google")."""

import logging

from google.auth.exceptions import GoogleAuthError, TransportError
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token

from app.providers.base import (
    GoogleIdentity,
    InvalidIdentityToken,
    ProviderError,
    ProviderNotConfigured,
)

log = logging.getLogger(__name__)


class GoogleIdTokenVerifier:
    def __init__(self, client_id: str):
        self._client_id = client_id

    def verify(self, id_token: str) -> GoogleIdentity:
        if not self._client_id:
            raise ProviderNotConfigured("GOOGLE_CLIENT_ID no está definida")
        try:
            claims = google_id_token.verify_oauth2_token(
                id_token,
                google_requests.Request(),
                self._client_id,  # la "audiencia": el token debe haberse emitido para ESTA app
                clock_skew_in_seconds=10,
            )
        except TransportError as exc:  # no se pudo contactar a Google para obtener sus llaves
            log.exception("No se pudo contactar a Google para verificar el token")
            raise ProviderError(f"Google: {type(exc).__name__}") from exc
        except (ValueError, GoogleAuthError) as exc:
            # Firma inválida, token vencido, audiencia distinta, emisor desconocido...
            log.info("Token de Google rechazado: %s", exc)
            raise InvalidIdentityToken(str(exc)) from exc

        email = str(claims.get("email") or "").strip()
        if not email:
            raise InvalidIdentityToken("El token no trae correo")
        return GoogleIdentity(
            email=email,
            email_verified=claims.get("email_verified") is True,
            name=(claims.get("name") or None),
        )
