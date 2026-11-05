# Construir desde la raíz del repositorio (anemia-ml-app/):
#   docker build -f backend/Dockerfile -t anemia-api .
#   docker run -p 8000:8000 -e ANEMIA_SECRET=<secreto> -v anemia-data:/data anemia-api
# Requiere haber entrenado antes el modelo: ml/models/modelo_anemia_rf.pkl
FROM python:3.11-slim
WORKDIR /app
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY backend/app ./app
COPY ml/models/modelo_anemia_rf.pkl /app/modelo/modelo_anemia_rf.pkl
ENV ANEMIA_MODELO=/app/modelo/modelo_anemia_rf.pkl \
    ANEMIA_DB=/data/anemia.db
RUN mkdir /data && useradd -m api && chown api /data
USER api
VOLUME /data
EXPOSE 8000
# HTTPS: publique este contenedor detrás de un proxy inverso con TLS (nginx, Caddy, etc.)
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
