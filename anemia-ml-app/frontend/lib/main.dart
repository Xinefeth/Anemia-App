// Punto de entrada de la aplicación móvil.
import 'package:flutter/material.dart';
import 'screens/formulario_screen.dart';

void main() {
  runApp(const AnemiaApp());
}

class AnemiaApp extends StatelessWidget {
  const AnemiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Valoración de Anemia',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const FormularioScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
