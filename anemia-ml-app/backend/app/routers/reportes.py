"""
Reportes de indicadores PC, TR y TT por grupo (HU09).

Definiciones usadas (ajustar a las de la tesis si difieren):
  PC = % de valoraciones cuyo riesgo coincide con la clasificación de referencia
       (solo cuenta las que tienen referencia registrada).
  TR = tiempo medio de valoración, en segundos.
  TT = niños distintos tamizados por día con actividad.
"""
import sqlite3
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query

from app import db
from app.deps import usuario_actual
from app.models.esquemas import IndicadoresGrupo, ReporteOut

router = APIRouter(prefix="/api", tags=["Reportes"], dependencies=[Depends(usuario_actual)])


def _calcular(conn: sqlite3.Connection, inicio: date, fin: date):
    """Devuelve (ReporteOut, ids de las valoraciones incluidas)."""
    if fin < inicio:
        raise HTTPException(422, "La fecha final no puede ser anterior a la inicial")
    filas = conn.execute(
        """SELECT idValoracion, idNino, riesgo, riesgoReferencia, tiempoMs, grupo, substr(fecha,1,10) AS dia
           FROM valoracion WHERE substr(fecha,1,10) BETWEEN ? AND ?""",
        (inicio.isoformat(), fin.isoformat())).fetchall()

    def indicadores(grupo: str) -> IndicadoresGrupo:
        g = [f for f in filas if f["grupo"] == grupo]
        con_ref = [f for f in g if f["riesgoReferencia"]]
        dias = {f["dia"] for f in g}
        return IndicadoresGrupo(
            total=len(g),
            pc=round(100 * sum(f["riesgo"] == f["riesgoReferencia"] for f in con_ref) / len(con_ref), 1)
            if con_ref else None,
            tr_segundos=round(sum(f["tiempoMs"] for f in g) / len(g) / 1000, 2) if g else None,
            tt=round(len({f["idNino"] for f in g}) / len(dias), 1) if g else None,
            distribucion={n: sum(f["riesgo"] == n for f in g) for n in ("Bajo", "Medio", "Alto")})

    r = ReporteOut(inicio=inicio.isoformat(), fin=fin.isoformat(), total=len(filas),
                   control=indicadores("control"), experimental=indicadores("experimental"))
    return r, [f["idValoracion"] for f in filas]


@router.get("/reporte", response_model=ReporteOut)
def reporte(inicio: date = Query(...), fin: date = Query(...),
            conn: sqlite3.Connection = Depends(db.get_conn)):
    """Calcula los indicadores del periodo sin guardar nada."""
    return _calcular(conn, inicio, fin)[0]


@router.post("/reporte", response_model=ReporteOut, status_code=201)
def generar_reporte(inicio: date = Query(...), fin: date = Query(...),
                    conn: sqlite3.Connection = Depends(db.get_conn),
                    usuario: sqlite3.Row = Depends(usuario_actual)):
    """Calcula los indicadores y registra el reporte con las valoraciones incluidas."""
    r, ids = _calcular(conn, inicio, fin)
    cur = conn.execute("INSERT INTO reporte (idUsuario, fechaInicio, fechaFin) VALUES (?,?,?)",
                       (usuario["idUsuario"], inicio.isoformat(), fin.isoformat()))
    conn.executemany("INSERT INTO reporte_valoracion (idReporte, idValoracion) VALUES (?,?)",
                     [(cur.lastrowid, i) for i in ids])
    conn.commit()
    r.id_reporte = cur.lastrowid
    return r
