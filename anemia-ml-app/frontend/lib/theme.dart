import 'package:flutter/material.dart';
import 'models/modelos.dart';

// Paleta provisional (los wireframes de alta fidelidad no están en la carpeta).
// Cambiar aquí actualiza toda la app.
class Paleta {
  static const primario = Color(0xFF0F766E);
  static const fondo = Color(0xFFF5F7F8);
  static const tinta = Color(0xFF1F2933);
  static const suave = Color(0xFF6B7780);
  static const borde = Color(0xFFD9DFE3);

  static const bajo = Color(0xFF2E9E5B);
  static const medio = Color(0xFFE8A200);
  static const alto = Color(0xFFD64545);

  static Color riesgo(Riesgo r) =>
      {Riesgo.bajo: bajo, Riesgo.medio: medio, Riesgo.alto: alto}[r]!;
}

ThemeData construirTema() {
  final esquema = ColorScheme.fromSeed(
    seedColor: Paleta.primario,
    primary: Paleta.primario,
    surface: Colors.white,
  );
  const radio = BorderRadius.all(Radius.circular(12));
  return ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    scaffoldBackgroundColor: Paleta.fondo,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Paleta.tinta,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
          borderRadius: radio, borderSide: const BorderSide(color: Paleta.borde)),
      enabledBorder: OutlineInputBorder(
          borderRadius: radio, borderSide: const BorderSide(color: Paleta.borde)),
      focusedBorder: OutlineInputBorder(
          borderRadius: radio,
          borderSide: const BorderSide(color: Paleta.primario, width: 2)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: radio),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: radio),
        side: const BorderSide(color: Paleta.borde),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
          borderRadius: radio, side: const BorderSide(color: Paleta.borde)),
    ),
  );
}
