import pytest

from app.modules.speech.service import is_match
from app.providers.base import ProviderError
from conftest import make_child

AUDIO = {"audio": ("intento.m4a", b"fake-audio-bytes", "audio/mp4")}


@pytest.mark.parametrize(
    "target, heard, expected",
    [
        ("cat", "cat", True),
        ("cat", "The CAT!", True),            # mayúsculas y signos no importan
        ("cat", "cut", False),                # palabra corta: exacta
        ("elephant", "elefant", True),        # pronunciación aproximada en palabra larga
        ("horse", "house", False),            # palabras cortas: exactas
        ("yellow", "hello", False),           # palabras largas distintas no se confunden
        ("orange", "oranges", True),
        ("ice cream", "I want ice cream", True),
        ("ice cream", "ice", False),
        ("dog", "", False),
        ("", "dog", False),
        ("Árbol", "arbol", True),             # sin acentos
    ],
)
def test_is_match(target, heard, expected):
    assert is_match(target, heard) is expected


def _check(client, headers, child_id, palabra="cat", files=AUDIO):
    return client.post(
        "/speech/check", data={"nino_id": child_id, "palabra": palabra}, files=files, headers=headers
    )


def test_requires_consent(client, tutor_a, stt):
    child = make_child(client, tutor_a)
    r = _check(client, tutor_a, child)
    assert r.status_code == 403
    assert stt.calls == 0  # sin consentimiento, el audio no sale del servidor


def test_success_and_retry(client, tutor_a, stt):
    child = make_child(client, tutor_a)
    client.post("/consents", json={"tipo": "voz", "aceptado": True}, headers=tutor_a)

    stt.reply = "cat"
    ok = _check(client, tutor_a, child).json()
    assert ok == {"resultado": "acierto", "transcripcion": "cat"}

    stt.reply = "dog"
    assert _check(client, tutor_a, child).json()["resultado"] == "intentar_de_nuevo"


def test_revoked_consent_blocks_again(client, tutor_a, stt):
    child = make_child(client, tutor_a)
    client.post("/consents", json={"tipo": "voz", "aceptado": True}, headers=tutor_a)
    client.post("/consents", json={"tipo": "voz", "aceptado": False}, headers=tutor_a)
    assert _check(client, tutor_a, child).status_code == 403


def test_other_tutors_child_is_404(client, tutor_a, tutor_b, stt):
    child = make_child(client, tutor_a)
    client.post("/consents", json={"tipo": "voz", "aceptado": True}, headers=tutor_b)
    assert _check(client, tutor_b, child).status_code == 404


def test_rejects_empty_and_oversized_audio(client, tutor_a, stt):
    child = make_child(client, tutor_a)
    client.post("/consents", json={"tipo": "voz", "aceptado": True}, headers=tutor_a)
    assert _check(client, tutor_a, child, files={"audio": ("a.m4a", b"", "audio/mp4")}).status_code == 400
    big = {"audio": ("a.m4a", b"x" * 5_000_001, "audio/mp4")}
    assert _check(client, tutor_a, child, files=big).status_code == 413
    assert stt.calls == 0


def test_provider_failure_is_a_safe_502(client, tutor_a, stt):
    child = make_child(client, tutor_a)
    client.post("/consents", json={"tipo": "voz", "aceptado": True}, headers=tutor_a)
    stt.error = ProviderError("detalle interno con una llave sk-secreta")
    r = _check(client, tutor_a, child)
    assert r.status_code == 502
    assert "sk-secreta" not in r.text  # los detalles internos no llegan al cliente


def test_is_match_lenient_mode_is_more_tolerant():
    from app.modules.speech.service import is_match

    assert not is_match("pera", "pira")  # 4 letras: estricto no
    assert is_match("pera", "pira", lenient=True)
    assert not is_match("cat", "cut", lenient=True)  # palabras de 3 letras: eso lo decide la IA
    assert is_match("manzana", "mansana")
