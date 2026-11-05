import 'package:flutter/material.dart';

/// Paleta de colores de AnemIA.
class AppColors {
  static const primary = Color(0xFF1E6FD9);
  static const primaryDark = Color(0xFF1550A8);
  static const primaryLight = Color(0xFFE8F1FD);
  static const accent = Color(0xFF16B8A6);
  static const bg = Color(0xFFF4F7FB);
  static const card = Color(0xFFFFFFFF);
  static const text = Color(0xFF1B2A41);
  static const muted = Color(0xFF6B7A90);
  static const border = Color(0xFFE3E9F2);

  static const riesgoBajo = Color(0xFF22B573);
  static const riesgoMedio = Color(0xFFF5A623);
  static const riesgoAlto = Color(0xFFE8503A);
  static const bajoBg = Color(0xFFE4F8EF);
  static const medioBg = Color(0xFFFDF2DF);
  static const altoBg = Color(0xFFFCE8E4);

  static const gradiente = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );
}

/// Color principal de un nivel de riesgo ("Bajo", "Medio", "Alto").
Color colorRiesgo(String riesgo) => switch (riesgo) {
      'Alto' => AppColors.riesgoAlto,
      'Medio' => AppColors.riesgoMedio,
      _ => AppColors.riesgoBajo,
    };

/// Color de fondo suave de un nivel de riesgo.
Color fondoRiesgo(String riesgo) => switch (riesgo) {
      'Alto' => AppColors.altoBg,
      'Medio' => AppColors.medioBg,
      _ => AppColors.bajoBg,
    };

class AppTheme {
  static final sombra = [
    BoxShadow(
      color: const Color(0xFF1B2A41).withValues(alpha: 0.10),
      blurRadius: 28,
      offset: const Offset(0, 8),
    ),
  ];

  static ThemeData get light {
    OutlineInputBorder borde(Color c, [double w = 1.5]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c, width: w),
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: AppColors.card,
      ),
      scaffoldBackgroundColor: AppColors.bg,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFAFCFF),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: borde(AppColors.border),
        enabledBorder: borde(AppColors.border),
        focusedBorder: borde(AppColors.primary),
        errorBorder: borde(AppColors.riesgoAlto),
        focusedErrorBorder: borde(AppColors.riesgoAlto),
      ),
    );
  }
}
