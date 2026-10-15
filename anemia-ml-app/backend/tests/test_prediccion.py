"""
Pruebas unitarias del endpoint de predicción.
"""
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_api_activa():
    respuesta = client.get("/")
    assert respuesta.status_code == 200


def test_prediccion_valida():
    respuesta = client.post("/api/predict", json={"edad_meses": 36, "hemoglobina": 10.2})
    assert respuesta.status_code == 200
    datos = respuesta.json()
    assert datos["riesgo"] in ["Bajo", "Medio", "Alto"]
    assert 0 <= datos["probabilidad"] <= 1
