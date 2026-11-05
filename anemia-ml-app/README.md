# AnemIA — Valoración del riesgo de anemia infantil con Machine Learning

Sistema de **apoyo** al personal de salud para valorar el riesgo de anemia en niños menores
de cinco años (Trujillo, Perú). **No reemplaza el diagnóstico clínico.**

Tesis UPAO — Ingeniería de Computación y Sistemas · Autores: Diego Francesco Jara Tirado,
Pedro Leonardo Saldarriaga Urquizo · Asesor: Dr. Segundo Edwin Cieza Mostacero · 2026.

Mide tres indicadores: **PC** (% de clasificaciones correctas), **TR** (tiempo de respuesta)
y **TT** (tasa de tamizaje), comparando Grupo Control vs. Experimental.

## Arquitectura

```
Flutter (Android)  ──HTTP/JSON──>  FastAPI  ──>  Random Forest (.pkl)
 frontend/                          backend/  └─>  SQLite (anemia.db)
```

| Carpeta     | Contenido |
|-------------|-----------|
| `backend/`  | API REST FastAPI, acceso a BD, carga del modelo, pruebas, Dockerfile |
| `frontend/` | App Flutter: 6 pantallas, servicios (API, SQLite local, sesión, PDF) |
| `ml/`       | `scripts/entrenar_modelo.py`, generador de datos sintéticos, `models/*.pkl` |
| `data/`     | Dataset (`processed/dataset.csv`; los datos reales **no** se versionan) |

## ⚠️ Antes de usarlo con fines de la tesis

1. **Los datos de entrenamiento incluidos son SINTÉTICOS** (`--sintetico`). Sirven para que
   todo funcione y se pruebe, pero las métricas (≈91 % de exactitud) **no tienen valor
   clínico ni científico**. Reemplace por el dataset real anonimizado en
   `data/processed/dataset.csv` (columnas `edad_meses, hemoglobina, altitud, sexo, riesgo`)
   y reentrene. Ajuste las variables a las reales de su estudio.
2. La etiqueta sintética sigue la regla OMS/MINSA simplificada sobre hemoglobina ajustada
   por altitud (≥11 Bajo · 10–10.9 Medio · <10 Alto). Confirme los puntos de corte con su asesor.
3. Los **indicadores PC/TR/TT** usan definiciones provisionales (ver `backend/app/routers/reportes.py`):
   PC = coincidencia con la clasificación de referencia (campo opcional `riesgo_referencia`),
   TR = tiempo medio en segundos, TT = niños distintos tamizados por día. Alinéelas con la tesis.
4. Usuarios de **desarrollo** sembrados al primer arranque: `dr.jara` (médico) y `enf.rios`
   (enfermero), contraseña `anemia2026` (o `ANEMIA_SEED_PASSWORD`). **Cámbielas en producción.**

## Backend

Requiere Python 3.11+.

```bash
cd anemia-ml-app
python -m venv venv && source venv/bin/activate     # Windows: venv\Scripts\activate
pip install -r backend/requirements-dev.txt

# 1) Entrenar el modelo (genera ml/models/modelo_anemia_rf.pkl)
python ml/scripts/entrenar_modelo.py --sintetico      # pruebas
# python ml/scripts/entrenar_modelo.py                # con data/processed/dataset.csv real

# 2) Pruebas
cd backend && python -m pytest -q

# 3) Ejecutar la API  →  http://localhost:8000/docs
uvicorn app.main:app --reload --host 0.0.0.0
```

Variables de entorno: `ANEMIA_SECRET` (firma de tokens; **obligatoria en producción**),
`ANEMIA_DB` (ruta SQLite), `ANEMIA_MODELO` (ruta del .pkl), `ANEMIA_TOKEN_HORAS` (def. 12),
`ANEMIA_SEED_PASSWORD`.

**Docker** (entrenar el modelo antes, y construir desde la raíz `anemia-ml-app/`):

```bash
docker build -f backend/Dockerfile -t anemia-api .
docker run -p 8000:8000 -e ANEMIA_SECRET=cambia-esto -v anemia-data:/data anemia-api
```

### API (todo requiere `Authorization: Bearer <token>` salvo `/` y el login)

| Método y ruta | Descripción |
|---------------|-------------|
| `POST /api/auth/login` | `{usuario, contrasena}` → token + datos del usuario |
| `POST /api/predict` | `{edad_meses, hemoglobina, altitud, sexo}` → `{riesgo, probabilidad, modelo, tiempo_ms}` (no guarda) |
| `POST /api/valoracion` | Guarda una valoración (el riesgo se **recalcula en el servidor**) |
| `GET /api/historial?nivel=&q=` | Lista con filtro por nivel y búsqueda por código/fecha |
| `GET /api/historial/{id}` | Detalle |
| `GET /api/dashboard` | Totales, últimos 5 meses y recientes |
| `GET /api/reporte?inicio=&fin=` | Indicadores PC/TR/TT por grupo (`POST` además lo registra) |
| `GET /api/modelo` | Métricas del modelo cargado y si es sintético |

Validaciones: edad 0–60 meses, hemoglobina 3.0–25.0 g/dL, altitud 0–5500 msnm, sexo M/F,
código del niño alfanumérico (sin nombres).

### Modelo de datos

Sigue el MER, con dos ajustes necesarios: `NINO` guarda solo un **código anónimo** y el sexo
(edad, hemoglobina y altitud van en `VALORACION`, porque cambian en cada control del mismo
niño); `VALORACION` añade `tiempoMs` (TR) y `riesgoReferencia` (PC).

## Frontend (Flutter)

Requiere Flutter 3.x estable y Android SDK. La carpeta `android/` ya está incluida.

```bash
cd anemia-ml-app/frontend
flutter pub get
flutter analyze && flutter test

# Emulador Android (10.0.2.2 = localhost de tu PC):
flutter run --dart-define=API_URL=http://10.0.2.2:8000
# Teléfono físico: use la IP de tu PC, o la URL HTTPS del servidor
flutter run --dart-define=API_URL=http://192.168.1.50:8000

# APK de producción (exige HTTPS)
flutter build apk --release --dart-define=API_URL=https://tu-servidor
```

- **HTTP solo en debug.** Las compilaciones *release* bloquean `http://` (HU10): publique la
  API detrás de HTTPS (nginx/Caddy con TLS).
- **Sin conexión (HU04):** si falla la red al evaluar, los datos se conservan en el formulario;
  si falla al *Guardar*, la valoración queda en SQLite local y se envía sola al volver la
  conexión (banner en Historial). El Historial muestra la última copia local sin conexión.
- Al cerrar sesión se borra la copia local del historial. El token se guarda con
  `shared_preferences`; para endurecerlo, use `flutter_secure_storage`.
- Exportar PDF: crea el reporte en el servidor y abre el diálogo de compartir/guardar.

## Historias de usuario → dónde están

HU01 login/logout (`auth*`, `login_screen`, menú del avatar) · HU02–03 formulario y validación
(`formulario_screen`, `esquemas.py`) · HU04 predicción y manejo de fallos · HU05 `resultado_screen`
· HU06 guardar · HU07–08 `historial_screen` · HU09 `reportes_screen` + `pdf_service` · HU10 tokens,
hash PBKDF2, códigos anónimos, HTTPS en release.

## Pendiente / límites conocidos

- Dataset real y reentrenamiento (ver arriba).
- No hay recuperación de contraseña ni gestión de usuarios (se siembran 2 de desarrollo).
- No hay límite de intentos de login ni auditoría; añádalos antes de producción.
- Todo el personal autenticado ve todas las valoraciones (mismo establecimiento).
- Verificado: pruebas del backend (29) y del frontend (18), `flutter analyze`. **No** se
  compiló el APK ni se probó en dispositivo/emulador ni el contenedor Docker.
