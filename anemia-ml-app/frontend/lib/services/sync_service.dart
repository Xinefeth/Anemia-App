import 'api_service.dart';
import 'db_service.dart';

/// Resultado de un intento de sincronización.
class ResultadoSync {
  final int enviadas;
  final int pendientes;
  final int conError;
  const ResultadoSync(this.enviadas, this.pendientes, this.conError);
}

/// Reenvía al servidor las valoraciones guardadas sin conexión.
class SyncService {
  static Future<ResultadoSync> sincronizar(int usuarioId) async {
    final db = DbService.instancia;
    var enviadas = 0;
    for (final p in await db.pendientes(usuarioId)) {
      if (p.error != null) continue;
      try {
        await ApiService.instancia.guardarValoracion(p.cuerpo);
        await db.borrarPendiente(p.id);
        enviadas++;
      } on ApiException catch (e) {
        if (e.sinConexion || e.status == 401 || (e.status ?? 0) >= 500) break;
        await db.marcarError(p.id, e.mensaje); // rechazado por el servidor: no reintentar
      }
    }
    final restantes = await db.pendientes(usuarioId);
    return ResultadoSync(enviadas, restantes.length, restantes.where((p) => p.error != null).length);
  }
}
