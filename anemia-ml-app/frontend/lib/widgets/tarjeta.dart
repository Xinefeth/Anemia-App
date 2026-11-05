import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Tarjeta blanca de esquinas redondeadas (16 px) y sombra suave.
class Tarjeta extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margen;
  const Tarjeta({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margen = const EdgeInsets.only(bottom: 14),
  });

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: margen,
        padding: padding,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.sombra,
        ),
        child: child,
      );
}

/// Título de sección con acción opcional ("Ver todas").
class TituloSeccion extends StatelessWidget {
  final String texto;
  final String? accion;
  final VoidCallback? onAccion;
  const TituloSeccion(this.texto, {super.key, this.accion, this.onAccion});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 4, 2, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(texto,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
            ),
            if (accion != null)
              GestureDetector(
                onTap: onAccion,
                child: Text(accion!,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
              ),
          ],
        ),
      );
}
