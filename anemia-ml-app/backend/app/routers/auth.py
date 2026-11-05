"""Autenticación (HU01)."""
import sqlite3

from fastapi import APIRouter, Depends, HTTPException

from app.db import get_conn
from app.deps import usuario_actual
from app.models.esquemas import LoginIn, TokenOut, UsuarioOut
from app.services import seguridad

router = APIRouter(prefix="/api/auth", tags=["Autenticación"])

# Hash de relleno para que el tiempo de respuesta no revele si el usuario existe.
_HASH_FALSO = seguridad.hashear("relleno")


def _usuario_out(f: sqlite3.Row) -> UsuarioOut:
    return UsuarioOut(id_usuario=f["idUsuario"], nombre=f["nombre"], usuario=f["usuario"], rol=f["rol"])


@router.post("/login", response_model=TokenOut)
def login(datos: LoginIn, conn: sqlite3.Connection = Depends(get_conn)):
    fila = conn.execute("SELECT * FROM usuario WHERE usuario = ?", (datos.usuario,)).fetchone()
    ok = seguridad.verificar(datos.contrasena, fila["contrasena"] if fila else _HASH_FALSO)
    if not fila or not ok:
        raise HTTPException(401, "Usuario o contraseña incorrectos")
    return TokenOut(access_token=seguridad.crear_token(fila["idUsuario"]), usuario=_usuario_out(fila))


@router.get("/me", response_model=UsuarioOut)
def me(u: sqlite3.Row = Depends(usuario_actual)):
    return _usuario_out(u)
