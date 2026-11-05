import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Mensaje de error con botón para reintentar.
class ErrorReintentar extends StatelessWidget {
  final String mensaje;
  final VoidCallback onReintentar;
  final bool sinConexion;
  const ErrorReintentar(
      {super.key, required this.mensaje, required this.onReintentar, this.sinConexion = false});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(sinConexion ? Icons.cloud_off : Icons.error_outline,
                  size: 44, color: AppColors.muted),
              const SizedBox(height: 12),
              Text(mensaje,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.text, fontSize: 14)),
              const SizedBox(height: 14),
              TextButton.icon(
                  onPressed: onReintentar, icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
            ],
          ),
        ),
      );
}

/// Aviso en recuadro (ámbar por defecto) para mensajes no bloqueantes.
class AvisoCaja extends StatelessWidget {
  final String texto;
  final IconData icono;
  final Color color;
  final Color fondo;
  final Widget? accion;
  const AvisoCaja(
    this.texto, {
    super.key,
    this.icono = Icons.info_outline,
    this.color = const Color(0xFF8A5A00),
    this.fondo = AppColors.medioBg,
    this.accion,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: BorderRadius.circular(8),
          border: Border(left: BorderSide(color: color, width: 3)),
        ),
        child: Row(
          children: [
            Icon(icono, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(texto, style: TextStyle(fontSize: 12, color: color, height: 1.4))),
            if (accion != null) accion!,
          ],
        ),
      );
}
