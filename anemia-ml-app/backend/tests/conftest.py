"""Fixtures: base de datos temporal y un modelo pequeño entrenado con datos sintéticos."""
import os
import sys

import pytest

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(RAIZ, "ml", "scripts"))


@pytest.fixture(scope="session")
def modelo_pkl(tmp_path_factory):
    from entrenar_modelo import entrenar
    ruta = str(tmp_path_factory.mktemp("modelo") / "modelo.pkl")
    entrenar(ruta_modelo=ruta, sintetico=True)
    return ruta


@pytest.fixture()
def client(tmp_path, monkeypatch, modelo_pkl):
    from app import db
    from app.services import predictor
    monkeypatch.setattr(db, "RUTA_DB", str(tmp_path / "test.db"))
    monkeypatch.setattr(predictor, "RUTA_MODELO", modelo_pkl)
    monkeypatch.setattr(predictor, "_paquete", None)
    from fastapi.testclient import TestClient
    from app.main import app
    with TestClient(app) as c:
        yield c


@pytest.fixture()
def auth(client):
    r = client.post("/api/auth/login", json={"usuario": "dr.jara", "contrasena": "anemia2026"})
    assert r.status_code == 200
    return {"Authorization": f"Bearer {r.json()['access_token']}"}
