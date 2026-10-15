"""
Servicio de predicción: carga el modelo de Machine Learning y realiza la valoración.
"""
import os
import joblib
from app.models.esquemas import DatosNino, ResultadoValoracion

RUTA_MODELO = os.path.join(os.path.dirname(__file__), "..", "..", "..", "ml", "models", "modelo_anemia_rf.pkl")

# Carga del modelo (se realiza una sola vez al iniciar el servicio)
_modelo = None


def cargar_modelo():
    """Carga el modelo serializado desde disco."""
    global _modelo
    if _modelo is None and os.path.exists(RUTA_MODELO):
        _modelo = joblib.load(RUTA_MODELO)
    return _modelo


def predecir_riesgo(datos: DatosNino) -> ResultadoValoracion:
    """
    Aplica el modelo a los datos del niño y devuelve el nivel de riesgo.
    Mientras el modelo no esté entrenado, se usa una regla provisional de ejemplo.
    """
    modelo = cargar_modelo()
    etiquetas = {0: "Bajo", 1: "Medio", 2: "Alto"}

    if modelo is not None:
        X = [[datos.edad_meses, datos.hemoglobina]]  # ajustar a las features reales
        pred = int(modelo.predict(X)[0])
        proba = float(max(modelo.predict_proba(X)[0]))
        return ResultadoValoracion(riesgo=etiquetas.get(pred, "Desconocido"), probabilidad=proba)

    # Regla provisional de ejemplo (hasta integrar el modelo entrenado)
    if datos.hemoglobina >= 11:
        return ResultadoValoracion(riesgo="Bajo", probabilidad=0.90)
    elif datos.hemoglobina >= 10:
        return ResultadoValoracion(riesgo="Medio", probabilidad=0.75)
    else:
        return ResultadoValoracion(riesgo="Alto", probabilidad=0.85)
