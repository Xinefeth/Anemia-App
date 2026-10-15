"""
Esquemas de datos (entrada y salida) de la API, definidos con Pydantic.
"""
from pydantic import BaseModel, Field


class DatosNino(BaseModel):
    """Datos clínicos de entrada del niño."""
    edad_meses: int = Field(..., ge=0, le=60, description="Edad del niño en meses (0 a 60)")
    hemoglobina: float = Field(..., gt=0, description="Nivel de hemoglobina en g/dL")
    # Agregar aquí las demás variables clínicas del modelo

    model_config = {
        "json_schema_extra": {
            "example": {"edad_meses": 36, "hemoglobina": 10.2}
        }
    }


class ResultadoValoracion(BaseModel):
    """Resultado de la valoración del riesgo."""
    riesgo: str = Field(..., description="Nivel de riesgo: Bajo, Medio o Alto")
    probabilidad: float = Field(..., description="Probabilidad asociada al resultado")
