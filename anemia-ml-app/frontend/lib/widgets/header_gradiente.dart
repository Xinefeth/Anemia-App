import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Encabezado azul con gradiente. Con [hijo] se reemplaza el contenido estándar.
class HeaderGradiente extends StatelessWidget {
  final String? titulo;
  final String? subtitulo;
  final VoidCallback? onBack;
  final Widget? trailing;
  final Widget? hijo;
  final double extraInferior;

  const HeaderGradiente({
    super.key,
    this.titulo,
    this.subtitulo,
    this.onBack,
    this.trailing,
    this.hijo,
    this.extraInferior = 0,
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        decoration: const BoxDecoration(gradient: AppColors.gradiente),
        padding: EdgeInsets.fromLTRB(18, 14, 18, 18 + extraInferior),
        child: SafeArea(
          bottom: false,
          child: hijo ??
              Row(
                children: [
                  if (onBack != null) ...[
                    Material(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: onBack,
                        child: const SizedBox(
                          width: 36,
                          height: 36,
                          child: Icon(Icons.chevron_left, color: Colors.white, size: 26),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(titulo ?? '',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                        if (subtitulo != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(subtitulo!,
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
                          ),
                      ],
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
        ),
      ),
    );
  }
}

/// Botón circular translúcido para el encabezado (buscar, descargar, etc.).
class BotonHeader extends StatelessWidget {
  final IconData icono;
  final VoidCallback? onTap;
  final String tooltip;
  const BotonHeader({super.key, required this.icono, required this.onTap, required this.tooltip});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.white.withValues(alpha: 0.22),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(width: 40, height: 40, child: Icon(icono, color: Colors.white, size: 20)),
          ),
        ),
      );
}
