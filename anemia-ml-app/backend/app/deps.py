"""Dependencias compartidas: usuario autenticado a partir del token Bearer."""
import sqlite3

from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.db import get_conn
from app.services import seguridad

_esquema = HTTPBearer(auto_error=False)


def usuario_actual(cred: HTTPAuthorizationCredentials = Depends(_esquema),
                   conn: sqlite3.Connection = Depends(get_conn)) -> sqlite3.Row:
    """Exige un token válido (HU10: solo usuarios autenticados)."""
    uid = seguridad.leer_token(cred.credentials) if cred else None
    fila = conn.execute("SELECT * FROM usuario WHERE idUsuario = ?", (uid,)).fetchone() if uid else None
    if fila is None:
        raise HTTPException(401, "Sesión no válida o vencida",
                            headers={"WWW-Authenticate": "Bearer"})
    return fila
