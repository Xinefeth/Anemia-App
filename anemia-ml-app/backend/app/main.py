"""
API REST para la valoración del riesgo de anemia.
Punto de entrada de la aplicación backend (FastAPI).
"""
from fastapi import FastAPI
from app.routers import prediccion

app = FastAPI(
    title="API Valoración de Riesgo de Anemia",
    description="API REST que expone el modelo de Machine Learning "
                "para valorar el riesgo de anemia en niños.",
    version="1.0.0"
)

# Registro de rutas
app.include_router(prediccion.router)


@app.get("/")
def inicio():
    """Endpoint de verificación del estado de la API."""
    return {"mensaje": "API de valoración de riesgo de anemia activa"}
