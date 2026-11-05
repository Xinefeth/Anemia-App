import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Botón de acción. [secundario] usa el estilo suave azul claro.
class BotonPrincipal extends StatelessWidget {
  final String texto;
  final IconData? icono;
  final VoidCallback? onPressed;
  final bool cargando;
  final bool secundario;

  const BotonPrincipal({
    super.key,
    required this.texto,
    this.icono,
    required this.onPressed,
    this.cargando = false,
    this.secundario = false,
  });

  @override
  Widget build(BuildContext context) {
    final activo = onPressed != null && !cargando;
    final fg = secundario ? AppColors.primaryDark : Colors.white;
    return Opacity(
      opacity: onPressed == null && !cargando ? 0.55 : 1,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          gradient: secundario ? null : AppColors.gradiente,
          color: secundario ? AppColors.primaryLight : null,
          borderRadius: BorderRadius.circular(13),
          boxShadow: secundario
              ? null
              : [
                  BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6))
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: activo ? onPressed : null,
            child: Center(
              child: cargando
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: fg))
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icono != null) ...[Icon(icono, color: fg, size: 20), const SizedBox(width: 8)],
                        Text(texto,
                            style: TextStyle(color: fg, fontSize: 15, fontWeight: FontWeight.w600)),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
