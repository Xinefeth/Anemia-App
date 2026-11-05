"""
Seguridad: hash de contraseñas (PBKDF2) y tokens de acceso firmados (HMAC).

Solo usa la biblioteca estándar. En producción defina ANEMIA_SECRET (si no, se genera
uno aleatorio por proceso y los tokens dejan de valer al reiniciar) y publique la API
detrás de HTTPS.
"""
import base64
import hashlib
import hmac
import json
import os
import secrets
import time

ITERACIONES = 200_000
DURACION_TOKEN_S = int(os.getenv("ANEMIA_TOKEN_HORAS", "12")) * 3600
_SECRETO = os.getenv("ANEMIA_SECRET") or secrets.token_hex(32)


def hashear(contrasena: str) -> str:
    sal = secrets.token_hex(16)
    h = hashlib.pbkdf2_hmac("sha256", contrasena.encode(), sal.encode(), ITERACIONES)
    return f"pbkdf2${ITERACIONES}${sal}${h.hex()}"


def verificar(contrasena: str, almacenado: str) -> bool:
    try:
        _, it, sal, esperado = almacenado.split("$")
        h = hashlib.pbkdf2_hmac("sha256", contrasena.encode(), sal.encode(), int(it))
        return hmac.compare_digest(h.hex(), esperado)
    except (ValueError, TypeError):
        return False


def _b64(datos: bytes) -> str:
    return base64.urlsafe_b64encode(datos).rstrip(b"=").decode()


def _firma(cuerpo: str) -> str:
    return _b64(hmac.new(_SECRETO.encode(), cuerpo.encode(), hashlib.sha256).digest())


def crear_token(id_usuario: int) -> str:
    cuerpo = _b64(json.dumps({"uid": id_usuario, "exp": int(time.time()) + DURACION_TOKEN_S}).encode())
    return f"{cuerpo}.{_firma(cuerpo)}"


def leer_token(token: str):
    """Devuelve el id de usuario si el token es válido y no venció; si no, None."""
    try:
        cuerpo, firma = token.split(".")
        if not hmac.compare_digest(firma, _firma(cuerpo)):
            return None
        datos = json.loads(base64.urlsafe_b64decode(cuerpo + "=" * (-len(cuerpo) % 4)))
        return datos["uid"] if datos["exp"] > time.time() else None
    except (ValueError, KeyError, TypeError):
        return None
