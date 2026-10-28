"""Configuración del backend.

Todo se lee de variables de entorno (o de un archivo .env en desarrollo).
Las llaves y contraseñas NUNCA van en el código ni en el repositorio.
"""

import os
import sys
from functools import lru_cache

from pydantic import ValidationError, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict
from sqlalchemy.engine import URL


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # --- Base de datos -------------------------------------------------
    # Opción A: una URL completa (por ejemplo la "Internal Connection URL"
    # que muestra el panel). Tiene prioridad si está definida.
    database_url: str | None = None
    # Opción B: por partes. Es más cómoda porque la contraseña puede tener
    # caracteres especiales sin que haya que codificarlos en una URL.
    db_user: str = "postgres"
    db_password: str = ""
    db_host: str = "localhost"
    db_port: int = 5432
    db_name: str = "postgres"

    # --- Seguridad -----------------------------------------------------
    secret_key: str  # obligatoria: firma los tokens de sesión
    jwt_expire_minutes: int = 60 * 24 * 7  # 7 días
    # Orígenes permitidos por CORS, separados por coma. Una app móvil nativa
    # NO necesita CORS; solo hace falta si se prueba una versión web.
    cors_origins: str = ""

    # --- Inicio de sesión (ADR-008) ----------------------------------------
    # ID de cliente "Aplicación web" de Google Cloud. NO es secreto: es el mismo que lleva la app
    # como serverClientId y sirve para comprobar que el token de Google se emitió para esta app.
    google_client_id: str = "566955966049-3jg8jd0omf7b90jk67mde5li4814hh2u.apps.googleusercontent.com"
    # El acceso con solo nombre y correo (sin verificar) permite entrar como otra persona:
    # queda apagado y solo se enciende para pruebas (ENABLE_BASIC_LOGIN=true).
    enable_basic_login: bool = False

    # --- Proveedores externos (las llaves las pones tú en el entorno) ----
    google_api_key: str = ""
    gemini_model: str = "gemini-3.6-flash"
    elevenlabs_api_key: str = ""
    elevenlabs_voice_id: str = "hpp4J3VqNfWAUOO0d1Us"  # voz de los cuentos en INGLÉS
    elevenlabs_voice_id_es: str = "LMOrpyqRBvYunxCf0zDX"  # voz de los cuentos en ESPAÑOL
    elevenlabs_tts_model: str = "eleven_multilingual_v2"
    elevenlabs_stt_model: str = "scribe_v2"

    # --- Límites y almacenamiento -------------------------------------
    audio_dir: str = "data/audio"  # carpeta de audios de historias (caché)
    max_audio_bytes: int = 5_000_000  # tamaño máximo del audio del niño
    daily_story_limit: int = 20  # historias por tutor y por día
    judge_hourly_limit: int = 120  # consultas al juez de IA por tutor y por hora

    @field_validator("secret_key")
    @classmethod
    def _secret_key_must_be_long(cls, value: str) -> str:
        if len(value) < 32:
            raise ValueError(
                "SECRET_KEY debe tener al menos 32 caracteres. Genera una con: "
                'python -c "import secrets; print(secrets.token_urlsafe(48))"'
            )
        return value

    @property
    def sqlalchemy_url(self) -> str | URL:
        if self.database_url:
            url = self.database_url
            # El panel entrega "postgresql://..."; usamos el driver psycopg 3.
            for prefix in ("postgres://", "postgresql://"):
                if url.startswith(prefix):
                    return "postgresql+psycopg://" + url[len(prefix):]
            return url
        return URL.create(
            "postgresql+psycopg",
            username=self.db_user,
            password=self.db_password,
            host=self.db_host,
            port=self.db_port,
            database=self.db_name,
        )

    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]


def _explain_config_error(exc: ValidationError) -> str:
    """Mensaje claro para el log del servidor. Muestra SOLO nombres, nunca valores."""
    problems = ", ".join(sorted({".".join(str(p) for p in e["loc"]).upper() for e in exc.errors()}))
    seen = sorted(os.environ)
    ours = [n for n in seen if n.upper().startswith(("SECRET", "DB_", "DATABASE", "GOOGLE", "ELEVEN", "GEMINI", "CORS"))]
    return (
        "\n=== ERROR DE CONFIGURACION ===\n"
        f"Faltan o son invalidas estas variables: {problems}\n"
        f"El contenedor ve {len(seen)} variables de entorno en total.\n"
        f"Archivo .env en {os.getcwd()}: {'SI existe' if os.path.exists('.env') else 'NO existe'}\n"
        f"Las que parecen de English-for-Kids (solo nombres, entre comillas para ver espacios ocultos): "
        f"{[repr(n) for n in ours] or 'NINGUNA'}\n"
        "Si aparece NINGUNA: el panel no esta pasando las variables al contenedor "
        "(revisa Environment > Save y luego Deploy).\n"
        "Si el nombre aparece con espacios o simbolos raros: corrige el nombre en el panel.\n"
    )


@lru_cache
def get_settings() -> Settings:
    try:
        return Settings()
    except ValidationError as exc:
        print(_explain_config_error(exc), file=sys.stderr, flush=True)
        # "from None": no repetir el error original de pydantic, que puede incluir valores.
        raise RuntimeError("Configuracion invalida: revisa el mensaje de arriba.") from None
