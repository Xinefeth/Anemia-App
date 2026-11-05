# Datos del proyecto

- **raw/**: datos originales sin procesar (no se versionan por privacidad).
- **processed/**: datos limpios para el entrenamiento. El entrenamiento lee
  `processed/dataset.csv` con columnas `edad_meses, hemoglobina, altitud, sexo (M/F), riesgo (Bajo/Medio/Alto)`.

Por tratarse de datos de salud de menores, los datos reales NO se suben al repositorio
(solo anonimizados y fuera de git). Para pruebas, `python ml/scripts/entrenar_modelo.py --sintetico`
genera datos ficticios: no usarlos para conclusiones de la tesis.
