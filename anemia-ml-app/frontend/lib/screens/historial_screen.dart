// Pantalla 3: Historial de valoraciones (estructura base).
import 'package:flutter/material.dart';

class HistorialScreen extends StatelessWidget {
  const HistorialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial')),
      body: const Center(
        child: Text('Aquí se mostrará el historial de valoraciones'),
      ),
    );
  }
}
