"""
Script de entrenamiento del modelo de Machine Learning (CRISP-DM: Modelado).
Entrena un modelo Random Forest para clasificar el riesgo de anemia y lo serializa.
"""
import os
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, confusion_matrix
import joblib

RUTA_DATOS = os.path.join("..", "..", "data", "processed", "dataset.csv")
RUTA_MODELO = os.path.join("..", "models", "modelo_anemia_rf.pkl")


def entrenar():
    # 1. Cargar datos (CRISP-DM: Preparación de datos)
    df = pd.read_csv(RUTA_DATOS)
    X = df.drop("riesgo", axis=1)
    y = df["riesgo"]

    # 2. División train/test (70-30)
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.30, random_state=42
    )

    # 3. Entrenamiento (CRISP-DM: Modelado)
    modelo = RandomForestClassifier(n_estimators=100, max_depth=10, random_state=42)
    modelo.fit(X_train, y_train)

    # 4. Evaluación (CRISP-DM: Evaluación)
    y_pred = modelo.predict(X_test)
    print("Matriz de confusión:")
    print(confusion_matrix(y_test, y_pred))
    print("\nReporte de clasificación:")
    print(classification_report(y_test, y_pred))

    # 5. Serialización del modelo (CRISP-DM: Despliegue)
    os.makedirs(os.path.dirname(RUTA_MODELO), exist_ok=True)
    joblib.dump(modelo, RUTA_MODELO)
    print(f"\nModelo guardado en: {RUTA_MODELO}")


if __name__ == "__main__":
    entrenar()
