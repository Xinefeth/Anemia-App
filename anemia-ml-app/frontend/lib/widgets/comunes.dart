import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/modelos.dart';
import '../services/app_state.dart';
import '../services/api.dart';
import '../theme.dart';

/// Acceso al estado global desde cualquier pantalla.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState estado, required super.child})
      : super(notifier: estado);

  static AppState of(BuildContext c) =>
      c.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

String fmtFecha(DateTime d) => DateFormat('dd/MM/yyyy HH:mm').format(d);
String fmtDia(DateTime d) => DateFormat('dd/MM/yyyy').format(d);
String fmtPct(double p) => '${(p * 100).toStringAsFixed(0)}%';

String mensajeError(Object e) {
  if (e is SinConexion) return 'Sin conexión con el servidor.';
  if (e is ErrorApi) return e.mensaje;
  if (e is SesionExpirada) return 'La sesión expiró. Inicia sesión de nuevo.';
  return 'Ocurrió un error inesperado.';
}

/// Etiqueta con el color del nivel de riesgo (RNF04).
class RiesgoBadge extends StatelessWidget {
  final Riesgo riesgo;
  const RiesgoBadge(this.riesgo, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = Paleta.riesgo(riesgo);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
          color: c.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20)),
      child: Text(riesgo.texto,
          style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 13)),
    );
  }
}

/// Fila de una valoración (usada en dashboard e historial).
class ValoracionTile extends StatelessWidget {
  final Valoracion v;
  final VoidCallback? onTap;
  const ValoracionTile(this.v, {super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = Paleta.riesgo(v.riesgo);
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: c.withValues(alpha: 0.14),
          child: Icon(Icons.child_care, color: c),
        ),
        title: Text(v.datos.codigo,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
            '${fmtFecha(v.fecha)} · Hb ${v.datos.hemoglobina.toStringAsFixed(1)} g/dL'
            '${v.pendiente ? ' · pendiente de envío' : ''}'),
        trailing: RiesgoBadge(v.riesgo),
      ),
    );
  }
}

/// Aviso de modo sin conexión.
class AvisoSinConexion extends StatelessWidget {
  final String texto;
  const AvisoSinConexion(this.texto, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Paleta.medio.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          const Icon(Icons.cloud_off, size: 18, color: Paleta.medio),
          const SizedBox(width: 8),
          Expanded(child: Text(texto, style: const TextStyle(fontSize: 13))),
        ]),
      );
}

class EstadoError extends StatelessWidget {
  final Object error;
  final VoidCallback reintentar;
  const EstadoError(this.error, this.reintentar, {super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off, size: 40, color: Paleta.suave),
            const SizedBox(height: 12),
            Text(mensajeError(error), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size(160, 44)),
                onPressed: reintentar,
                child: const Text('Reintentar')),
          ]),
        ),
      );
}

class Titulo extends StatelessWidget {
  final String texto;
  const Titulo(this.texto, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(texto,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: Paleta.tinta)),
      );
}
