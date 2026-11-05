import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Barra inferior de 4 ítems: Inicio, Evaluar, Historial, Reportes.
class BarraNavegacion extends StatelessWidget {
  final int indice;
  final ValueChanged<int> onTap;
  const BarraNavegacion({super.key, required this.indice, required this.onTap});

  static const _items = [
    (Icons.home_outlined, Icons.home, 'Inicio'),
    (Icons.add_circle_outline, Icons.add_circle, 'Evaluar'),
    (Icons.list_alt_outlined, Icons.list_alt, 'Historial'),
    (Icons.bar_chart_outlined, Icons.bar_chart, 'Reportes'),
  ];

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 6),
            child: Row(
              children: [
                for (var i = 0; i < _items.length; i++)
                  Expanded(
                    child: InkWell(
                      onTap: () => onTap(i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(i == indice ? _items[i].$2 : _items[i].$1,
                                size: 24, color: i == indice ? AppColors.primary : AppColors.muted),
                            const SizedBox(height: 3),
                            Text(_items[i].$3,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: i == indice ? AppColors.primary : AppColors.muted)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
}
