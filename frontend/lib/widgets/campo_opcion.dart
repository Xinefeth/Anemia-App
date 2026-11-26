import 'package:flutter/material.dart';
import '../theme.dart';

/// Elección obligatoria entre opciones (Sí/No, F/M) SIN valor preseleccionado:
/// el usuario debe elegir. Así nunca se envía un dato clínico que nadie marcó.
class CampoOpcion<T> extends StatelessWidget {
  final String etiqueta;
  final List<(T, String)> opciones;
  final T? valor;
  final ValueChanged<T> alCambiar;
  final String mensajeFalta;

  const CampoOpcion({
    super.key,
    required this.etiqueta,
    required this.opciones,
    required this.valor,
    required this.alCambiar,
    this.mensajeFalta = 'Elige una opción',
  });

  @override
  Widget build(BuildContext context) {
    // La llave depende del valor: al elegir, el campo se reconstruye y desaparece el error.
    return FormField<T>(
      key: ValueKey('$etiqueta-$valor'),
      initialValue: valor,
      validator: (v) => v == null ? mensajeFalta : null,
      builder: (campo) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text('$etiqueta *',
              style: const TextStyle(fontSize: 13, color: Paleta.suave, fontWeight: FontWeight.w600)),
        ),
        SegmentedButton<T>(
          showSelectedIcon: false,
          emptySelectionAllowed: true,
          segments: [for (final o in opciones) ButtonSegment<T>(value: o.$1, label: Text(o.$2))],
          selected: valor == null ? <T>{} : {valor as T},
          onSelectionChanged: (s) {
            if (s.isNotEmpty) alCambiar(s.first);
          },
        ),
        if (campo.hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(campo.errorText!, style: const TextStyle(fontSize: 12, color: Paleta.alto)),
          ),
      ]),
    );
  }
}
