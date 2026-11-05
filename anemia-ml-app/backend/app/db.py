"""
Acceso a la base de datos (SQLite por defecto, según el MER del proyecto).

Se usa sqlite3 de la biblioteca estándar para no añadir dependencias. Para pasar a
PostgreSQL basta con reemplazar este módulo manteniendo las mismas funciones.

Variaciones respecto al MER original (necesarias para que el sistema funcione):
  * NINO guarda solo un código anónimo y el sexo; la edad, la hemoglobina y la
    altitud se guardan en VALORACION, porque cambian en cada control del mismo niño.
  * VALORACION agrega tiempo_ms (indicador TR) y riesgo_referencia (diagnóstico de
    referencia, opcional, para calcular el indicador PC).
"""
import os
import sqlite3
from datetime import datetime, timedelta, timezone

from app.services import seguridad

RUTA_DB = os.getenv("ANEMIA_DB", os.path.join(os.path.dirname(__file__), "..", "anemia.db"))

# Perú no tiene horario de verano: UTC-5 fijo.
ZONA_PERU = timezone(timedelta(hours=-5))

ESQUEMA = """
CREATE TABLE IF NOT EXISTS usuario (
    idUsuario   INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre      VARCHAR(80)  NOT NULL,
    usuario     VARCHAR(30)  NOT NULL UNIQUE,
    contrasena  TEXT         NOT NULL,              -- hash PBKDF2, nunca texto plano
    rol         VARCHAR(20)  NOT NULL CHECK (rol IN ('medico', 'enfermero'))
);
CREATE TABLE IF NOT EXISTS nino (
    idNino  INTEGER PRIMARY KEY AUTOINCREMENT,
    codigo  VARCHAR(20) NOT NULL UNIQUE,            -- código anónimo, sin datos personales
    sexo    VARCHAR(10) NOT NULL CHECK (sexo IN ('M', 'F'))
);
CREATE TABLE IF NOT EXISTS valoracion (
    idValoracion      INTEGER PRIMARY KEY AUTOINCREMENT,
    idNino            INTEGER NOT NULL REFERENCES nino(idNino),
    idUsuario         INTEGER NOT NULL REFERENCES usuario(idUsuario),
    edadMeses         INTEGER NOT NULL,
    hemoglobina       DECIMAL(4,1) NOT NULL,
    altitud           INTEGER NOT NULL,
    riesgo            VARCHAR(10) NOT NULL CHECK (riesgo IN ('Bajo', 'Medio', 'Alto')),
    probabilidad      DECIMAL(4,3) NOT NULL,
    fecha             DATETIME NOT NULL,
    grupo             VARCHAR(15) NOT NULL CHECK (grupo IN ('control', 'experimental')),
    tiempoMs          INTEGER NOT NULL,
    riesgoReferencia  VARCHAR(10) CHECK (riesgoReferencia IN ('Bajo', 'Medio', 'Alto'))
);
CREATE INDEX IF NOT EXISTS ix_valoracion_fecha ON valoracion(fecha);
CREATE TABLE IF NOT EXISTS reporte (
    idReporte    INTEGER PRIMARY KEY AUTOINCREMENT,
    idUsuario    INTEGER NOT NULL REFERENCES usuario(idUsuario),
    fechaInicio  DATE NOT NULL,
    fechaFin     DATE NOT NULL
);
CREATE TABLE IF NOT EXISTS reporte_valoracion (
    idReporte     INTEGER NOT NULL REFERENCES reporte(idReporte),
    idValoracion  INTEGER NOT NULL REFERENCES valoracion(idValoracion),
    PRIMARY KEY (idReporte, idValoracion)
);
"""


def ahora_peru() -> str:
    """Fecha y hora actual de Perú en ISO 8601 (sin zona), p. ej. 2026-11-05T09:12:00."""
    return datetime.now(ZONA_PERU).replace(tzinfo=None, microsecond=0).isoformat()


def conectar() -> sqlite3.Connection:
    conn = sqlite3.connect(RUTA_DB, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def get_conn():
    """Dependencia de FastAPI: una conexión por petición."""
    conn = conectar()
    try:
        yield conn
    finally:
        conn.close()


def inicializar() -> None:
    """Crea las tablas y, si no hay usuarios, siembra usuarios de DESARROLLO."""
    conn = conectar()
    try:
        conn.executescript(ESQUEMA)
        if conn.execute("SELECT COUNT(*) FROM usuario").fetchone()[0] == 0:
            clave = os.getenv("ANEMIA_SEED_PASSWORD", "anemia2026")
            for nombre, usuario, rol in [("Dr. Diego Jara", "dr.jara", "medico"),
                                         ("Enf. Rosa Ríos", "enf.rios", "enfermero")]:
                conn.execute(
                    "INSERT INTO usuario (nombre, usuario, contrasena, rol) VALUES (?,?,?,?)",
                    (nombre, usuario, seguridad.hashear(clave), rol))
            conn.commit()
    finally:
        conn.close()
