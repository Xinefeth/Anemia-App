# AnemIA — App móvil para la valoración del riesgo de anemia infantil

Aplicación móvil (Flutter) que apoya al personal de salud en la valoración del riesgo de anemia
en niños menores de cinco años en Trujillo. Es una valoración de riesgo, no un diagnóstico.

## Tesis
**Universidad Privada Antenor Orrego (UPAO)** — Ingeniería de Computación y Sistemas
- Autores: Diego Francesco Jara Tirado — Pedro Leonardo Saldarriaga Urquizo
- Asesor: Dr. Segundo Edwin Cieza Mostacero
- Año: 2026

## Alcance de este repositorio
Solo el **frontend**. El backend (API FastAPI, base de datos PostgreSQL y modelo de Machine Learning)
vive en un repositorio aparte y la app lo consume por HTTP/JSON (contrato en `frontend/lib/services/api.dart`).

```
anemia-ml-app/
├── frontend/   → Aplicación móvil (Flutter)
├── docs/       → Documentación y diagramas
└── README.md
```

## Ejecución
```bash
cd frontend
flutter pub get
flutter run --dart-define=MOCK=true     # API simulada (contraseña demo: demo)
```
Para usar el backend real, configura la URL base en `frontend/lib/config.dart`.

## Metodología
Mobile-D para el desarrollo del software.

## Licencia
Proyecto académico — UPAO 2026.
