"""
API REST para la valoración del riesgo de anemia (FastAPI).
Punto de entrada: uvicorn app.main:app
"""
from contextlib import asynccontextmanager

from fastapi import FastAPI

from app import db
from app.routers import auth, prediccion, reportes, valoraciones
from app.services.predictor import ModeloNoDisponible, cargar_modelo


@asynccontextmanager
async def ciclo_de_vida(app: FastAPI):
    db.inicializar()
    try:
        cargar_modelo()  # el modelo se carga una sola vez al iniciar
    except ModeloNoDisponible:
        pass  # la API arranca; /api/predict responderá 503 hasta que exista el .pkl
    yield


app = FastAPI(
    title="API AnemIA — Valoración de riesgo de anemia",
    description="Herramienta de APOYO al personal de salud; no reemplaza el diagnóstico clínico.",
    version="1.0.0",
    lifespan=ciclo_de_vida,
)

for r in (auth.router, prediccion.router, valoraciones.router, reportes.router):
    app.include_router(r)


@app.get("/", tags=["Estado"])
def inicio():
    """Verificación del estado de la API (pública, sin datos sensibles)."""
    try:
        cargar_modelo()
        modelo = True
    except ModeloNoDisponible:
        modelo = False
    return {"mensaje": "API de valoración de riesgo de anemia activa", "modelo_cargado": modelo}
