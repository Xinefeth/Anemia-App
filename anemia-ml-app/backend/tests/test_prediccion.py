"""Pruebas de autenticación, predicción, valoraciones y reportes."""
import pytest

NINO = {"edad_meses": 36, "hemoglobina": 8.9, "altitud": 34, "sexo": "M"}


def val(**kw):
    d = {**NINO, "codigo": "1042", "grupo": "experimental"}
    d.update(kw)
    return d


def test_api_activa(client):
    r = client.get("/")
    assert r.status_code == 200 and r.json()["modelo_cargado"] is True


# --- HU01 / HU10 ---
def test_login_incorrecto(client):
    r = client.post("/api/auth/login", json={"usuario": "dr.jara", "contrasena": "mal"})
    assert r.status_code == 401


def test_login_usuario_inexistente(client):
    assert client.post("/api/auth/login", json={"usuario": "nadie", "contrasena": "x"}).status_code == 401


@pytest.mark.parametrize("ruta", ["/api/historial", "/api/dashboard", "/api/modelo",
                                  "/api/reporte?inicio=2026-01-01&fin=2026-12-31"])
def test_endpoints_exigen_token(client, ruta):
    assert client.get(ruta).status_code == 401


def test_predict_exige_token(client):
    assert client.post("/api/predict", json=NINO).status_code == 401


def test_token_alterado_es_rechazado(client, auth):
    mal = {"Authorization": auth["Authorization"][:-3] + "abc"}
    assert client.get("/api/auth/me", headers=mal).status_code == 401


# --- HU03 / HU04 ---
def test_prediccion_alto(client, auth):
    r = client.post("/api/predict", json=NINO, headers=auth)
    assert r.status_code == 200
    d = r.json()
    assert d["riesgo"] == "Alto" and 0 <= d["probabilidad"] <= 1
    assert d["modelo"] == "Random Forest" and d["tiempo_ms"] >= 1


def test_prediccion_bajo(client, auth):
    r = client.post("/api/predict", json={**NINO, "hemoglobina": 13.0}, headers=auth)
    assert r.json()["riesgo"] == "Bajo"


@pytest.mark.parametrize("cambio", [
    {"edad_meses": 61}, {"edad_meses": -1}, {"hemoglobina": 1}, {"hemoglobina": 40},
    {"altitud": -5}, {"altitud": 9000}, {"sexo": "X"}])
def test_prediccion_rechaza_valores_fuera_de_rango(client, auth, cambio):
    assert client.post("/api/predict", json={**NINO, **cambio}, headers=auth).status_code == 422


def test_prediccion_rechaza_campos_faltantes(client, auth):
    assert client.post("/api/predict", json={"edad_meses": 12}, headers=auth).status_code == 422


# --- HU06 / HU07 / HU08 ---
def test_guardar_y_consultar_historial(client, auth):
    r = client.post("/api/valoracion", json=val(), headers=auth)
    assert r.status_code == 201
    g = r.json()
    assert g["riesgo"] == "Alto" and g["registrado_por"] == "Dr. Diego Jara" and g["fecha"]
    h = client.get("/api/historial", headers=auth).json()
    assert [x["codigo"] for x in h] == ["1042"]
    assert client.get(f"/api/historial/{g['id_valoracion']}", headers=auth).json()["codigo"] == "1042"


def test_servidor_ignora_riesgo_enviado_por_cliente(client, auth):
    r = client.post("/api/valoracion", json=val(riesgo="Bajo", probabilidad=1), headers=auth)
    assert r.json()["riesgo"] == "Alto"


def test_filtros_y_busqueda(client, auth):
    client.post("/api/valoracion", json=val(codigo="A1"), headers=auth)
    client.post("/api/valoracion", json=val(codigo="B2", hemoglobina=13.0), headers=auth)
    assert [x["codigo"] for x in client.get("/api/historial?nivel=Bajo", headers=auth).json()] == ["B2"]
    assert [x["codigo"] for x in client.get("/api/historial?q=A1", headers=auth).json()] == ["A1"]
    assert client.get("/api/historial?q=zzz", headers=auth).json() == []
    assert client.get("/api/historial?nivel=Otro", headers=auth).status_code == 422


def test_mismo_nino_dos_controles(client, auth):
    client.post("/api/valoracion", json=val(), headers=auth)
    client.post("/api/valoracion", json=val(hemoglobina=12.0, edad_meses=40), headers=auth)
    h = client.get("/api/historial", headers=auth).json()
    assert len(h) == 2 and h[0]["id_nino"] == h[1]["id_nino"]


def test_codigo_con_otro_sexo_se_rechaza(client, auth):
    client.post("/api/valoracion", json=val(), headers=auth)
    assert client.post("/api/valoracion", json=val(sexo="F"), headers=auth).status_code == 422


def test_codigo_invalido(client, auth):
    assert client.post("/api/valoracion", json=val(codigo="Juan Pérez"), headers=auth).status_code == 422


def test_dashboard(client, auth):
    d = client.get("/api/dashboard", headers=auth).json()
    assert d["total"] == 0 and len(d["meses"]) == 5
    client.post("/api/valoracion", json=val(), headers=auth)
    client.post("/api/valoracion", json=val(codigo="2", hemoglobina=13.0), headers=auth)
    d = client.get("/api/dashboard", headers=auth).json()
    assert d["total"] == 2 and d["en_riesgo"] == 1 and len(d["recientes"]) == 2
    assert d["meses"][-1]["total"] == 2 and d["precision"] is not None


# --- HU09 ---
def test_reporte_por_grupo(client, auth):
    client.post("/api/valoracion", json=val(codigo="1", riesgo_referencia="Alto", tiempo_ms=1200), headers=auth)
    client.post("/api/valoracion", json=val(codigo="2", grupo="control", riesgo_referencia="Medio",
                                            tiempo_ms=62000), headers=auth)
    r = client.get("/api/reporte?inicio=2000-01-01&fin=2100-01-01", headers=auth).json()
    assert r["total"] == 2
    assert r["experimental"]["pc"] == 100.0 and r["experimental"]["tr_segundos"] == 1.2
    assert r["control"]["pc"] == 0.0 and r["control"]["tr_segundos"] == 62.0
    assert r["control"]["distribucion"]["Alto"] == 1


def test_reporte_vacio_y_rango_invalido(client, auth):
    r = client.get("/api/reporte?inicio=2000-01-01&fin=2000-01-02", headers=auth).json()
    assert r["total"] == 0 and r["control"]["pc"] is None and r["control"]["tr_segundos"] is None
    assert client.get("/api/reporte?inicio=2026-02-01&fin=2026-01-01", headers=auth).status_code == 422


def test_generar_reporte_persiste(client, auth):
    client.post("/api/valoracion", json=val(), headers=auth)
    r = client.post("/api/reporte?inicio=2000-01-01&fin=2100-01-01", headers=auth)
    assert r.status_code == 201 and r.json()["id_reporte"] == 1
