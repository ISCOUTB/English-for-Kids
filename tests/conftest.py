"""Configuración de las pruebas: base SQLite temporal y proveedores simulados.

Las pruebas NUNCA llaman a Google ni a ElevenLabs: usan los dobles de abajo.
"""

import os
import shutil
import tempfile

# Estas variables deben fijarse ANTES de importar la app.
_TMP = tempfile.mkdtemp(prefix="efk-tests-")
os.environ["SECRET_KEY"] = "clave-de-pruebas-" + "x" * 32
os.environ["DATABASE_URL"] = f"sqlite:///{_TMP}/test.db"
os.environ["AUDIO_DIR"] = f"{_TMP}/audio"
os.environ["GOOGLE_API_KEY"] = ""
os.environ["ELEVENLABS_API_KEY"] = ""

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from app.core.db import Base, get_engine  # noqa: E402
from app.main import app  # noqa: E402
from app.providers import (  # noqa: E402
    get_judge_limiter,
    get_pronunciation_judge,
    get_speech_to_text,
    get_text_generator,
    get_text_to_speech,
)


class FakeTextGenerator:
    def __init__(self):
        self.calls: list[tuple[str, str | None]] = []
        self.reply = "**Había una vez** un cat y un dog.\n\n# Fueron amigos."
        self.error: Exception | None = None

    def generate(self, prompt, system=None):
        self.calls.append((prompt, system))
        if self.error:
            raise self.error
        return self.reply


class FakeTTS:
    def __init__(self):
        self.calls: list[str] = []

    def synthesize(self, text):
        self.calls.append(text)
        return b"ID3-audio-falso"


class FakeSTT:
    def __init__(self):
        self.reply = "cat"
        self.error: Exception | None = None
        self.calls = 0

    def transcribe(self, audio, content_type=None):
        self.calls += 1
        if self.error:
            raise self.error
        return self.reply


class FakeJudge:
    def __init__(self):
        self.verdict = True
        self.error: Exception | None = None
        self.calls: list[tuple[str, list[str]]] = []

    def judge(self, target, heard):
        self.calls.append((target, heard))
        if self.error:
            raise self.error
        return self.verdict


@pytest.fixture(autouse=True)
def fresh_state():
    """Cada prueba empieza con base de datos y caché de audio vacías."""
    engine = get_engine()
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)
    shutil.rmtree(os.environ["AUDIO_DIR"], ignore_errors=True)
    yield


@pytest.fixture
def text_gen():
    fake = FakeTextGenerator()
    app.dependency_overrides[get_text_generator] = lambda: fake
    yield fake
    app.dependency_overrides.pop(get_text_generator, None)


@pytest.fixture
def tts():
    fake = FakeTTS()
    app.dependency_overrides[get_text_to_speech] = lambda: fake
    yield fake
    app.dependency_overrides.pop(get_text_to_speech, None)


@pytest.fixture
def stt():
    fake = FakeSTT()
    app.dependency_overrides[get_speech_to_text] = lambda: fake
    yield fake
    app.dependency_overrides.pop(get_speech_to_text, None)


@pytest.fixture
def judge():
    fake = FakeJudge()
    app.dependency_overrides[get_pronunciation_judge] = lambda: fake
    # Cada prueba empieza con el contador de uso en cero.
    get_judge_limiter.cache_clear()
    yield fake
    app.dependency_overrides.pop(get_pronunciation_judge, None)
    get_judge_limiter.cache_clear()


@pytest.fixture
def client():
    with TestClient(app) as c:
        yield c


def register(client, nombre="María Pérez", correo="maria@correo.com"):
    """Registra un tutor y devuelve sus cabeceras de autenticación."""
    r = client.post("/auth/register", json={"nombre": nombre, "correo": correo})
    assert r.status_code == 201, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def make_child(client, headers, apodo="Lulú", rango_edad="3-4"):
    r = client.post("/children", json={"apodo": apodo, "rango_edad": rango_edad}, headers=headers)
    assert r.status_code == 201, r.text
    return r.json()["id"]


@pytest.fixture
def tutor_a(client):
    return register(client, "María Pérez", "maria@correo.com")


@pytest.fixture
def tutor_b(client):
    return register(client, "Carlos Gómez", "carlos@correo.com")
