// Pantalla 2: Visualización del resultado de la valoración.
import 'package:flutter/material.dart';
import '../models/valoracion.dart';

class ResultadoScreen extends StatelessWidget {
  final Valoracion valoracion;
  const ResultadoScreen({super.key, required this.valoracion});

  Color _color() {
    switch (valoracion.riesgo) {
      case 'Bajo':
        return Colors.green;
      case 'Medio':
        return Colors.orange;
      case 'Alto':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resultado')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _color().withOpacity(0.15),
                border: Border.all(color: _color(), width: 3),
              ),
              child: Center(
                child: Text(
                  'Riesgo\n${valoracion.riesgo}',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _color()),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Probabilidad: ${(valoracion.probabilidad * 100).toStringAsFixed(1)}%',
                style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Nueva valoración'),
            ),
          ],
        ),
      ),
    );
  }
}
