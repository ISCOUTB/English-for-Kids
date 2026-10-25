from sqlalchemy import inspect

from app.core.db import get_engine
from conftest import register


def test_register_returns_token_and_tutor(client):
    r = client.post("/auth/register", json={"nombre": "  María   Pérez ", "correo": "Maria@Correo.com"})
    assert r.status_code == 201
    body = r.json()
    assert body["token_type"] == "bearer" and body["access_token"]
    assert body["tutor"]["nombre"] == "María Pérez"  # espacios normalizados
    assert body["tutor"]["correo"] == "maria@correo.com"  # correo en minúsculas


def test_register_duplicate_email_is_409(client):
    register(client)
    r = client.post("/auth/register", json={"nombre": "Otra Persona", "correo": "MARIA@correo.com"})
    assert r.status_code == 409


def test_register_validates_input(client):
    assert client.post("/auth/register", json={"nombre": "Ana", "correo": "no-es-correo"}).status_code == 422
    assert client.post("/auth/register", json={"nombre": "   ", "correo": "a@b.com"}).status_code == 422
    assert client.post("/auth/register", json={"correo": "a@b.com"}).status_code == 422


def test_login_accepts_case_accents_and_spaces(client):
    register(client, "María Pérez", "maria@correo.com")
    r = client.post("/auth/login", json={"nombre": "maria   PEREZ", "correo": "MARIA@correo.com"})
    assert r.status_code == 200
    assert r.json()["tutor"]["correo"] == "maria@correo.com"


def test_login_failures_share_the_same_message(client):
    register(client, "María Pérez", "maria@correo.com")
    wrong_name = client.post("/auth/login", json={"nombre": "Otra", "correo": "maria@correo.com"})
    unknown = client.post("/auth/login", json={"nombre": "María Pérez", "correo": "nadie@correo.com"})
    assert wrong_name.status_code == unknown.status_code == 401
    assert wrong_name.json() == unknown.json()  # no revela si el correo existe


def test_me_requires_valid_token(client, tutor_a):
    assert client.get("/auth/me").status_code == 401
    assert client.get("/auth/me", headers={"Authorization": "Bearer basura"}).status_code == 401
    r = client.get("/auth/me", headers=tutor_a)
    assert r.status_code == 200 and r.json()["correo"] == "maria@correo.com"


def test_tables_match_the_er_model(client):
    tables = set(inspect(get_engine()).get_table_names())
    assert {
        "tutor", "nino", "consentimiento", "categoria", "palabra",
        "intento", "dominio", "historia", "historia_palabra",
    } <= tables


def test_health(client):
    assert client.get("/health").json() == {"status": "ok"}
    assert client.get("/health/db").json()["database"] == "ok"
