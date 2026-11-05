import 'package:flutter/foundation.dart';

/// Se incrementa al guardar una valoración o sincronizar, para que Inicio e
/// Historial vuelvan a cargar sus datos.
final ValueNotifier<int> datosCambiaron = ValueNotifier<int>(0);
