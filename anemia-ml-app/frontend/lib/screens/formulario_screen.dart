// Pantalla 1: Formulario de ingreso de datos del niño.
import 'package:flutter/material.dart';
import '../models/nino.dart';
import '../services/api_service.dart';
import 'resultado_screen.dart';

class FormularioScreen extends StatefulWidget {
  const FormularioScreen({super.key});

  @override
  State<FormularioScreen> createState() => _FormularioScreenState();
}

class _FormularioScreenState extends State<FormularioScreen> {
  final _formKey = GlobalKey<FormState>();
  final _edadCtrl = TextEditingController();
  final _hbCtrl = TextEditingController();
  final _api = ApiService();
  bool _cargando = false;

  Future<void> _evaluar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);
    try {
      final nino = Nino(
        edadMeses: int.parse(_edadCtrl.text),
        hemoglobina: double.parse(_hbCtrl.text),
      );
      final resultado = await _api.valorarRiesgo(nino);
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => ResultadoScreen(valoracion: resultado),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo completar la valoración')),
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Valoración de Anemia')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _edadCtrl,
                decoration: const InputDecoration(labelText: 'Edad (meses)'),
                keyboardType: TextInputType.number,
                validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _hbCtrl,
                decoration: const InputDecoration(labelText: 'Hemoglobina (g/dL)'),
                keyboardType: TextInputType.number,
                validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _cargando ? null : _evaluar,
                child: _cargando
                    ? const CircularProgressIndicator()
                    : const Text('Evaluar riesgo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
