"""Endpoint de predicción del riesgo de anemia (HU04)."""
from fastapi import APIRouter, Depends, HTTPException

from app.deps import usuario_actual
from app.models.esquemas import DatosNino, ResultadoValoracion
from app.services.predictor import ModeloNoDisponible, info_modelo, predecir_riesgo

router = APIRouter(prefix="/api", tags=["Valoración"], dependencies=[Depends(usuario_actual)])


@router.post("/predict", response_model=ResultadoValoracion)
def predict(datos: DatosNino):
    """Recibe los datos clínicos y devuelve riesgo, probabilidad y tiempo de cálculo. No guarda nada."""
    try:
        return predecir_riesgo(datos)
    except ModeloNoDisponible as e:
        raise HTTPException(503, str(e))


@router.get("/modelo")
def modelo():
    """Metadatos del modelo cargado (métricas de entrenamiento, si es sintético)."""
    try:
        return info_modelo()
    except ModeloNoDisponible as e:
        raise HTTPException(503, str(e))
