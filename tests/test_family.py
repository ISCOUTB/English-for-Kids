from sqlalchemy import func, select

from app.core.db import get_sessionmaker
from app.models import Historia, Nino
from conftest import make_child


def test_create_and_list_children(client, tutor_a):
    child_id = make_child(client, tutor_a, "Lulú", "3-4")
    r = client.get("/children", headers=tutor_a)
    assert r.status_code == 200
    assert [c["id"] for c in r.json()] == [child_id]
    assert r.json()[0]["apodo"] == "Lulú"


def test_child_requires_valid_age_range(client, tutor_a):
    r = client.post("/children", json={"apodo": "Lulú", "rango_edad": "12-15"}, headers=tutor_a)
    assert r.status_code == 422


def test_children_require_login(client):
    assert client.get("/children").status_code == 401
    assert client.post("/children", json={"apodo": "x", "rango_edad": "3-4"}).status_code == 401


def test_tutors_cannot_see_or_touch_each_others_children(client, tutor_a, tutor_b, text_gen):
    child_a = make_child(client, tutor_a)
    assert client.get("/children", headers=tutor_b).json() == []
    assert client.delete(f"/children/{child_a}", headers=tutor_b).status_code == 404
    r = client.post("/stories", json={"nino_id": child_a, "palabras": ["cat"]}, headers=tutor_b)
    assert r.status_code == 404
    assert text_gen.calls == []  # ni siquiera se llamó a la IA


def test_delete_child_removes_their_stories(client, tutor_a, text_gen):
    child_id = make_child(client, tutor_a)
    client.post("/stories", json={"nino_id": child_id, "palabras": ["cat"]}, headers=tutor_a)
    assert client.delete(f"/children/{child_id}", headers=tutor_a).status_code == 204
    with get_sessionmaker()() as db:
        assert db.scalar(select(func.count(Nino.id))) == 0
        assert db.scalar(select(func.count(Historia.id))) == 0


def test_consent_history_latest_wins(client, tutor_a):
    assert client.post("/consents", json={"tipo": "voz", "aceptado": True}, headers=tutor_a).status_code == 201
    assert client.post("/consents", json={"tipo": "voz", "aceptado": False}, headers=tutor_a).status_code == 201
    rows = client.get("/consents", headers=tutor_a).json()
    assert [r["aceptado"] for r in rows] == [False, True]  # más reciente primero
    assert client.post("/consents", json={"tipo": "otro", "aceptado": True}, headers=tutor_a).status_code == 422
