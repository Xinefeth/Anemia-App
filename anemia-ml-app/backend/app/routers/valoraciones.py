"""Registro, historial y resumen de valoraciones (HU06, HU07, HU08)."""
import sqlite3
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query

from app import db
from app.deps import usuario_actual
from app.models.esquemas import DashboardOut, MesConteo, ValoracionIn, ValoracionOut
from app.services.predictor import ModeloNoDisponible, info_modelo, predecir_riesgo

router = APIRouter(prefix="/api", tags=["Valoraciones"], dependencies=[Depends(usuario_actual)])

_SELECT = """
SELECT v.*, n.codigo, n.sexo, u.nombre AS registrado_por
FROM valoracion v
JOIN nino n    ON n.idNino = v.idNino
JOIN usuario u ON u.idUsuario = v.idUsuario
"""


def _out(f: sqlite3.Row) -> ValoracionOut:
    return ValoracionOut(
        id_valoracion=f["idValoracion"], id_nino=f["idNino"], codigo=f["codigo"],
        edad_meses=f["edadMeses"], sexo=f["sexo"], hemoglobina=f["hemoglobina"],
        altitud=f["altitud"], riesgo=f["riesgo"], probabilidad=f["probabilidad"],
        fecha=f["fecha"], grupo=f["grupo"], tiempo_ms=f["tiempoMs"],
        riesgo_referencia=f["riesgoReferencia"], registrado_por=f["registrado_por"])


@router.post("/valoracion", response_model=ValoracionOut, status_code=201)
def guardar(datos: ValoracionIn, conn: sqlite3.Connection = Depends(db.get_conn),
            usuario: sqlite3.Row = Depends(usuario_actual)):
    """Guarda una valoración. El riesgo se recalcula en el servidor (no se confía en el cliente)."""
    try:
        res = predecir_riesgo(datos)
    except ModeloNoDisponible as e:
        raise HTTPException(503, str(e))

    nino = conn.execute("SELECT * FROM nino WHERE codigo = ?", (datos.codigo,)).fetchone()
    if nino is None:
        cur = conn.execute("INSERT INTO nino (codigo, sexo) VALUES (?, ?)", (datos.codigo, datos.sexo))
        id_nino = cur.lastrowid
    elif nino["sexo"] != datos.sexo:
        raise HTTPException(422, f"El código {datos.codigo} ya está registrado con otro sexo")
    else:
        id_nino = nino["idNino"]

    cur = conn.execute(
        """INSERT INTO valoracion (idNino, idUsuario, edadMeses, hemoglobina, altitud, riesgo,
                                   probabilidad, fecha, grupo, tiempoMs, riesgoReferencia)
           VALUES (?,?,?,?,?,?,?,?,?,?,?)""",
        (id_nino, usuario["idUsuario"], datos.edad_meses, datos.hemoglobina, datos.altitud,
         res.riesgo, res.probabilidad, db.ahora_peru(), datos.grupo,
         datos.tiempo_ms if datos.tiempo_ms is not None else res.tiempo_ms, datos.riesgo_referencia))
    conn.commit()
    return _out(conn.execute(_SELECT + " WHERE v.idValoracion = ?", (cur.lastrowid,)).fetchone())


@router.get("/historial", response_model=List[ValoracionOut])
def historial(nivel: Optional[str] = Query(None, pattern="^(Bajo|Medio|Alto)$"),
              q: Optional[str] = Query(None, max_length=30, description="Código o fecha (AAAA-MM-DD)"),
              limit: int = Query(50, ge=1, le=200), offset: int = Query(0, ge=0),
              conn: sqlite3.Connection = Depends(db.get_conn)):
    """Lista valoraciones, de la más reciente a la más antigua, con filtros por nivel y búsqueda."""
    sql, args = _SELECT + " WHERE 1=1", []
    if nivel:
        sql += " AND v.riesgo = ?"
        args.append(nivel)
    if q:
        patron = "%" + q.strip().replace("%", "").replace("_", "") + "%"
        sql += " AND (n.codigo LIKE ? OR v.fecha LIKE ?)"
        args += [patron, patron]
    sql += " ORDER BY v.fecha DESC, v.idValoracion DESC LIMIT ? OFFSET ?"
    args += [limit, offset]
    return [_out(f) for f in conn.execute(sql, args).fetchall()]


@router.get("/historial/{id_valoracion}", response_model=ValoracionOut)
def detalle(id_valoracion: int, conn: sqlite3.Connection = Depends(db.get_conn)):
    f = conn.execute(_SELECT + " WHERE v.idValoracion = ?", (id_valoracion,)).fetchone()
    if f is None:
        raise HTTPException(404, "Valoración no encontrada")
    return _out(f)


@router.get("/dashboard", response_model=DashboardOut)
def dashboard(conn: sqlite3.Connection = Depends(db.get_conn)):
    """Datos de la pantalla de inicio: totales, últimos 5 meses y valoraciones recientes."""
    total = conn.execute("SELECT COUNT(*) FROM valoracion").fetchone()[0]
    en_riesgo = conn.execute("SELECT COUNT(*) FROM valoracion WHERE riesgo != 'Bajo'").fetchone()[0]

    # Precisión: PC real si hay clasificaciones de referencia; si no, la del modelo en su prueba.
    ref = conn.execute("""SELECT COUNT(*), SUM(riesgo = riesgoReferencia) FROM valoracion
                          WHERE riesgoReferencia IS NOT NULL""").fetchone()
    if ref[0]:
        precision, origen = round(ref[1] / ref[0], 3), "valoraciones con referencia"
    else:
        try:
            m = info_modelo()
            precision = m["metricas"]["accuracy"]
            origen = "prueba del modelo (datos sintéticos)" if m["sintetico"] else "prueba del modelo"
        except ModeloNoDisponible:
            precision, origen = None, "no disponible"

    # Últimos 5 meses calendario (incluye meses sin datos, con total 0).
    hoy = db.ahora_peru()
    anio, mes = int(hoy[:4]), int(hoy[5:7])
    meses = []
    for k in range(4, -1, -1):
        m = mes - k
        a = anio + (m - 1) // 12
        m = (m - 1) % 12 + 1
        meses.append(f"{a:04d}-{m:02d}")
    cuentas = {r[0]: r[1] for r in conn.execute(
        "SELECT substr(fecha,1,7), COUNT(*) FROM valoracion WHERE substr(fecha,1,7) >= ? GROUP BY 1",
        (meses[0],))}
    recientes = conn.execute(_SELECT + " ORDER BY v.fecha DESC, v.idValoracion DESC LIMIT 3").fetchall()
    return DashboardOut(total=total, en_riesgo=en_riesgo, precision=precision, precision_origen=origen,
                        meses=[MesConteo(mes=m, total=cuentas.get(m, 0)) for m in meses],
                        recientes=[_out(f) for f in recientes])
