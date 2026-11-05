"""
Esquemas de datos (entrada y salida) de la API, definidos con Pydantic.
Aquí viven también las validaciones de rango (HU03).
"""
from typing import Dict, List, Literal, Optional

from pydantic import BaseModel, Field

Riesgo = Literal["Bajo", "Medio", "Alto"]
Grupo = Literal["control", "experimental"]


# ---------- Autenticación ----------
class LoginIn(BaseModel):
    usuario: str = Field(..., min_length=1, max_length=30)
    contrasena: str = Field(..., min_length=1, max_length=128)


class UsuarioOut(BaseModel):
    id_usuario: int
    nombre: str
    usuario: str
    rol: str


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    usuario: UsuarioOut


# ---------- Predicción ----------
class DatosNino(BaseModel):
    """Datos clínicos de entrada del niño."""
    edad_meses: int = Field(..., ge=0, le=60, description="Edad en meses (0 a 60)")
    hemoglobina: float = Field(..., ge=3.0, le=25.0, description="Hemoglobina en g/dL")
    altitud: int = Field(..., ge=0, le=5500, description="Altitud de residencia en msnm")
    sexo: Literal["M", "F"] = Field(..., description="M o F")

    model_config = {"json_schema_extra": {
        "example": {"edad_meses": 36, "hemoglobina": 8.9, "altitud": 34, "sexo": "M"}}}


class ResultadoValoracion(BaseModel):
    riesgo: Riesgo
    probabilidad: float = Field(..., ge=0, le=1)
    modelo: str
    tiempo_ms: int


# ---------- Valoraciones ----------
class ValoracionIn(DatosNino):
    """Datos para registrar una valoración. El servidor recalcula el riesgo."""
    codigo: str = Field(..., min_length=1, max_length=20, pattern=r"^[A-Za-z0-9\-]+$",
                        description="Código anónimo del niño (sin nombres ni DNI)")
    grupo: Grupo
    riesgo_referencia: Optional[Riesgo] = Field(
        None, description="Clasificación clínica de referencia, si se conoce (para el PC)")
    tiempo_ms: Optional[int] = Field(
        None, ge=0, le=3_600_000, description="Tiempo de la valoración medido por el cliente")


class ValoracionOut(BaseModel):
    id_valoracion: int
    id_nino: int
    codigo: str
    edad_meses: int
    sexo: str
    hemoglobina: float
    altitud: int
    riesgo: Riesgo
    probabilidad: float
    fecha: str
    grupo: Grupo
    tiempo_ms: int
    riesgo_referencia: Optional[Riesgo] = None
    registrado_por: str


class MesConteo(BaseModel):
    mes: str  # YYYY-MM
    total: int


class DashboardOut(BaseModel):
    total: int
    en_riesgo: int
    precision: Optional[float] = Field(None, description="Precisión del modelo (0-1)")
    precision_origen: str
    meses: List[MesConteo]
    recientes: List[ValoracionOut]


# ---------- Reportes ----------
class IndicadoresGrupo(BaseModel):
    total: int
    pc: Optional[float] = Field(None, description="% de clasificaciones correctas (vs. referencia)")
    tr_segundos: Optional[float] = Field(None, description="Tiempo medio de valoración (s)")
    tt: Optional[float] = Field(None, description="Niños tamizados por día con actividad")
    distribucion: Dict[str, int]


class ReporteOut(BaseModel):
    id_reporte: Optional[int] = None
    inicio: str
    fin: str
    total: int
    control: IndicadoresGrupo
    experimental: IndicadoresGrupo
