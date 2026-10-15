"""
Router del endpoint de predicción del riesgo de anemia.
"""
from fastapi import APIRouter
from app.models.esquemas import DatosNino, ResultadoValoracion
from app.services.predictor import predecir_riesgo

router = APIRouter(prefix="/api", tags=["Valoración"])


@router.post("/predict", response_model=ResultadoValoracion)
def predict(datos: DatosNino):
    """
    Recibe los datos clínicos del niño y devuelve la valoración del riesgo.
    """
    resultado = predecir_riesgo(datos)
    return resultado
