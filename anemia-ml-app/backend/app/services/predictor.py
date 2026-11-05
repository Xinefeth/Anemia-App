"""
Servicio de predicción: carga el modelo Random Forest (.pkl) una sola vez y valora el riesgo.
"""
import os
import time

import joblib
import pandas as pd

from app.models.esquemas import DatosNino, ResultadoValoracion

RUTA_MODELO = os.getenv(
    "ANEMIA_MODELO",
    os.path.join(os.path.dirname(__file__), "..", "..", "..", "ml", "models", "modelo_anemia_rf.pkl"))

_paquete = None


class ModeloNoDisponible(RuntimeError):
    """El archivo .pkl no existe o no se pudo cargar."""


def cargar_modelo(forzar: bool = False) -> dict:
    """Carga el paquete {modelo, features, metricas, ...} generado por entrenar_modelo.py."""
    global _paquete
    if _paquete is None or forzar:
        if not os.path.exists(RUTA_MODELO):
            raise ModeloNoDisponible(
                "Modelo no encontrado. Ejecute ml/scripts/entrenar_modelo.py primero.")
        paquete = joblib.load(RUTA_MODELO)
        paquete["modelo"].n_jobs = 1  # en una sola fila, los hilos solo añaden latencia
        _paquete = paquete
    return _paquete


def info_modelo() -> dict:
    p = cargar_modelo()
    return {"modelo": "Random Forest", "metricas": p["metricas"],
            "sintetico": p.get("sintetico", False), "entrenado_en": p.get("entrenado_en")}


def predecir_riesgo(datos: DatosNino) -> ResultadoValoracion:
    """Aplica el modelo a los datos del niño y devuelve riesgo, probabilidad y tiempo."""
    p = cargar_modelo()
    inicio = time.perf_counter()
    fila = {"edad_meses": datos.edad_meses, "hemoglobina": datos.hemoglobina,
            "altitud": datos.altitud, "sexo_m": 1 if datos.sexo == "M" else 0}
    X = pd.DataFrame([fila])[p["features"]]
    probas = p["modelo"].predict_proba(X)[0]
    i = int(probas.argmax())
    tiempo_ms = max(1, round((time.perf_counter() - inicio) * 1000))
    return ResultadoValoracion(
        riesgo=str(p["modelo"].classes_[i]),
        probabilidad=round(float(probas[i]), 3),
        modelo="Random Forest",
        tiempo_ms=tiempo_ms)
