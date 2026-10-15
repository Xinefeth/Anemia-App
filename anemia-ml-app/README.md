# Aplicación Móvil con Machine Learning para la Valoración del Riesgo de Anemia

Aplicación móvil que, mediante técnicas de Machine Learning, apoya al personal de salud
en la valoración del riesgo de anemia en niños menores de cinco años en Trujillo.

## Tesis
**Universidad Privada Antenor Orrego (UPAO)** — Ingeniería de Computación y Sistemas
- Autores: Diego Francesco Jara Tirado — Pedro Leonardo Saldarriaga Urquizo
- Asesor: Dr. Segundo Edwin Cieza Mostacero
- Año: 2026

## Arquitectura
Cliente-servidor de 3 capas con un componente de Machine Learning:
- **Frontend:** aplicación móvil (Flutter / Dart)
- **Backend:** API REST (FastAPI / Python)
- **Machine Learning:** modelo Random Forest (scikit-learn)
- **Base de datos:** PostgreSQL / SQLite

## Estructura del repositorio
```
anemia-ml-app/
├── frontend/     → Aplicación móvil (Flutter)
├── backend/      → API REST (FastAPI)
├── ml/           → Entrenamiento y modelo de Machine Learning
├── data/         → Conjuntos de datos
├── docs/         → Documentación y diagramas
├── .gitignore
└── README.md
```

## Metodología
- **Mobile-D** para el desarrollo del software.
- **CRISP-DM** para el desarrollo del modelo de Machine Learning.

## Instalación

### Backend
```bash
cd backend
python -m venv venv
source venv/bin/activate        # En Windows: venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```

### Frontend
```bash
cd frontend
flutter pub get
flutter run
```

## Licencia
Proyecto académico — UPAO 2026.
