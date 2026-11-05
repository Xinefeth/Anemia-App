"""
Entrenamiento del modelo de Machine Learning (CRISP-DM: Modelado y Evaluación).

Entrena un Random Forest que clasifica el riesgo de anemia (Bajo/Medio/Alto)
y serializa el modelo con joblib para que el backend lo cargue.

Uso (desde la carpeta ml/scripts o desde cualquier otra):
    python entrenar_modelo.py                 # usa data/processed/dataset.csv
    python entrenar_modelo.py --sintetico     # genera datos de prueba (NO reales)

Columnas esperadas del CSV: edad_meses, hemoglobina, altitud, sexo (M/F), riesgo
"""
import argparse
import os
import sys
from datetime import datetime

import joblib
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import (accuracy_score, classification_report,
                             confusion_matrix, precision_recall_fscore_support)
from sklearn.model_selection import train_test_split

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.abspath(os.path.join(AQUI, "..", ".."))
RUTA_DATOS = os.path.join(RAIZ, "data", "processed", "dataset.csv")
RUTA_MODELO = os.path.join(RAIZ, "ml", "models", "modelo_anemia_rf.pkl")

# Orden de las variables: el backend debe usar EXACTAMENTE el mismo.
FEATURES = ["edad_meses", "hemoglobina", "altitud", "sexo_m"]
ETIQUETAS = ["Bajo", "Medio", "Alto"]


def preparar(df: pd.DataFrame):
    """Valida columnas y construye la matriz de variables X y el objetivo y."""
    requeridas = {"edad_meses", "hemoglobina", "altitud", "sexo", "riesgo"}
    faltan = requeridas - set(df.columns)
    if faltan:
        sys.exit(f"Al dataset le faltan columnas: {sorted(faltan)}")
    df = df.dropna(subset=list(requeridas)).copy()
    df["sexo_m"] = (df["sexo"].astype(str).str.upper().str[0] == "M").astype(int)
    desconocidas = set(df["riesgo"]) - set(ETIQUETAS)
    if desconocidas:
        sys.exit(f"Etiquetas de riesgo no válidas: {sorted(desconocidas)}")
    return df[FEATURES], df["riesgo"]


def entrenar(ruta_datos=RUTA_DATOS, ruta_modelo=RUTA_MODELO, sintetico=False):
    # 1. Carga de datos (CRISP-DM: Preparación de datos)
    if sintetico:
        sys.path.insert(0, AQUI)
        from generar_dataset_sintetico import generar
        print("AVISO: usando datos SINTÉTICOS; las métricas no tienen valor clínico.")
        df = generar()
    elif os.path.exists(ruta_datos):
        df = pd.read_csv(ruta_datos)
    else:
        sys.exit(f"No existe {ruta_datos}. Coloca el dataset real o usa --sintetico.")
    X, y = preparar(df)

    # 2. División train/test 70-30 estratificada
    X_tr, X_te, y_tr, y_te = train_test_split(
        X, y, test_size=0.30, random_state=42, stratify=y)

    # 3. Entrenamiento
    modelo = RandomForestClassifier(
        n_estimators=200, max_depth=10, class_weight="balanced",
        random_state=42, n_jobs=-1)
    modelo.fit(X_tr, y_tr)

    # 4. Evaluación
    y_pred = modelo.predict(X_te)
    print("Matriz de confusión (filas=real, columnas=predicho):", ETIQUETAS)
    print(confusion_matrix(y_te, y_pred, labels=ETIQUETAS))
    print("\nReporte de clasificación:")
    print(classification_report(y_te, y_pred, labels=ETIQUETAS, zero_division=0))
    prec, rec, f1, _ = precision_recall_fscore_support(
        y_te, y_pred, average="weighted", zero_division=0)
    metricas = {
        "accuracy": round(float(accuracy_score(y_te, y_pred)), 4),
        "precision": round(float(prec), 4),
        "recall": round(float(rec), 4),
        "f1": round(float(f1), 4),
        "n_entrenamiento": int(len(X_tr)),
        "n_prueba": int(len(X_te)),
    }
    print("Métricas:", metricas)

    # 5. Serialización (el backend lo carga una sola vez al iniciar)
    paquete = {
        "modelo": modelo,
        "features": FEATURES,
        "metricas": metricas,
        "sintetico": bool(sintetico),
        "entrenado_en": datetime.now().isoformat(timespec="seconds"),
    }
    os.makedirs(os.path.dirname(ruta_modelo), exist_ok=True)
    joblib.dump(paquete, ruta_modelo)
    print(f"\nModelo guardado en: {ruta_modelo}")
    return paquete


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description="Entrena el Random Forest de AnemIA")
    ap.add_argument("--datos", default=RUTA_DATOS)
    ap.add_argument("--salida", default=RUTA_MODELO)
    ap.add_argument("--sintetico", action="store_true",
                    help="genera y usa un dataset sintético (solo pruebas)")
    a = ap.parse_args()
    entrenar(a.datos, a.salida, a.sintetico)
