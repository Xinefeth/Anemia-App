import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:anemia_ml_app/main.dart';
import 'package:anemia_ml_app/screens/resultado_screen.dart' show textoAlerta;
import 'package:anemia_ml_app/models/modelos.dart';
import 'package:anemia_ml_app/services/almacen_local.dart';
import 'package:anemia_ml_app/services/api.dart';
import 'package:anemia_ml_app/services/app_state.dart';
import 'package:anemia_ml_app/services/mock_api.dart';
import 'package:anemia_ml_app/widgets/comunes.dart';

Future<(AppState, MockApi)> _arrancar(WidgetTester t) async {
  SharedPreferences.setMockInitialValues({});
  t.view.physicalSize = const Size(1080, 2400);
  t.view.devicePixelRatio = 2.75;
  addTearDown(t.view.reset);
  final api = MockApi();
  // reintentoCada: null => sin temporizadores pendientes al terminar el test.
  final estado = AppState(apiPrueba: api, almacen: MemoriaAlmacen(), reintentoCada: null);
  await estado.iniciar();
  await t.pumpWidget(AnemiaApp(estado: estado));
  await t.pumpAndSettle();
  return (estado, api);
}

Future<void> _login(WidgetTester t) async {
  await t.enterText(find.byType(TextField).at(0), 'dra');
  await t.enterText(find.byType(TextField).at(1), 'demo');
  await t.tap(find.text('Iniciar sesión'));
  await t.pumpAndSettle();
}

Future<void> _irAFormulario(WidgetTester t) async {
  await t.tap(find.text('Valorar'));
  await t.pumpAndSettle();
}

/// Llena el formulario de valoración. Los campos de elección (sexo, CRED, suplementación)
/// no tienen valor por defecto: hay que elegirlos.
Future<void> _llenar(WidgetTester t,
    {String codigo = 'N-77',
    String edad = '24',
    String altitud = '34',
    String? sexo = 'Femenino',
    bool? cred = true,
    bool? supl = true}) async {
  await t.enterText(find.byType(TextFormField).at(0), codigo);
  await t.enterText(find.byType(TextFormField).at(1), edad);
  await t.enterText(find.byType(TextFormField).at(2), altitud);
  if (sexo != null) await t.tap(find.text(sexo));
  // Los botones "Sí"/"No" aparecen dos veces: primero CRED, luego suplementación.
  if (cred != null) await t.tap(find.text(cred ? 'Sí' : 'No').at(0));
  if (supl != null) await t.tap(find.text(supl ? 'Sí' : 'No').at(1));
  await t.pumpAndSettle();
}

Future<void> _evaluar(WidgetTester t) async {
  await t.tap(find.text('Evaluar riesgo'));
  await t.pumpAndSettle();
}

void main() {
  group('Reporte: "Sin datos" y tamaños de muestra', () {
    Map<String, dynamic> base() => {
          'desde': '2026-11-01',
          'hasta': '2026-11-05',
          'total': 1,
          'pc': {'control': 0.0, 'experimental': 0.0},
          'tr': {'control': 0.023, 'experimental': 0.0},
          'tt': {'control': 100.0, 'experimental': 0.0},
        };

    test('tolera la ausencia de los campos n_*', () {
      final r = Reporte.fromJson(base());
      expect(r.infoPc(false).sinDatos, isFalse);
      expect(r.infoPc(false).nota, isNull);
      expect(r.infoTt(true).sinDatos, isFalse);
    });

    test('aplica las reglas por grupo', () {
      final j = base()
        ..['n_valoraciones'] = {'control': 1, 'experimental': 0}
        ..['n_pc'] = {'control': 1, 'experimental': 0}
        ..['n_tt_valorados'] = {'control': 1, 'experimental': 0}
        ..['n_tt_registrados'] = {'control': 3, 'experimental': 0};
      final r = Reporte.fromJson(j);
      expect(r.infoPc(false).nota, 'n=1');
      expect(r.infoPc(true).sinDatos, isTrue);
      expect(r.infoTr(false).nota, 'n=1');
      expect(r.infoTr(true).sinDatos, isTrue);
      expect(r.infoTt(false).nota, 'n=1/3');
      expect(r.infoTt(true).sinDatos, isTrue);
    });
  });

  testWidgets('Reportes muestra "Sin datos" y n por grupo', (t) async {
    await _arrancar(t);
    await _login(t);
    await t.tap(find.text('Reportes'));
    await t.pumpAndSettle();
    expect(find.text('n=6'), findsWidgets);
    expect(find.text('n=6/11'), findsOneWidget); // TT control
    expect(find.text('n=6/7'), findsOneWidget); // TT experimental
  });

  testWidgets('login incorrecto muestra error', (t) async {
    await _arrancar(t);
    await t.enterText(find.byType(TextField).at(0), 'dra');
    await t.enterText(find.byType(TextField).at(1), 'mala');
    await t.tap(find.text('Iniciar sesión'));
    await t.pumpAndSettle();
    expect(find.text('Usuario o contraseña incorrectos'), findsOneWidget);
  });

  testWidgets('login correcto lleva al dashboard', (t) async {
    await _arrancar(t);
    await _login(t);
    expect(find.text('Nueva valoración'), findsOneWidget);
    expect(find.text('Valoraciones recientes'), findsOneWidget);
    expect(find.text('Hb prom.'), findsNothing); // ya no se captura hemoglobina
    expect(find.text('Riesgo medio'), findsOneWidget);
  });

  group('Formulario', () {
    testWidgets('no pide hemoglobina y pide las 5 variables + código y grupo', (t) async {
      await _arrancar(t);
      await _login(t);
      await _irAFormulario(t);
      expect(find.textContaining('Hemoglobina'), findsNothing);
      expect(find.text('ID del niño *'), findsOneWidget);
      expect(find.text('Edad (meses) *'), findsOneWidget);
      expect(find.text('Altitud (msnm) *'), findsOneWidget);
      expect(find.text('Sexo *'), findsOneWidget);
      expect(find.text('Asiste a control CRED *'), findsOneWidget);
      expect(find.text('Recibe suplementación con hierro *'), findsOneWidget);
      expect(find.text('Control'), findsOneWidget);
      expect(find.text('Experimental'), findsOneWidget);
    });

    testWidgets('sexo, CRED y suplementación no traen valor por defecto: hay que elegir', (t) async {
      await _arrancar(t);
      await _login(t);
      await _irAFormulario(t);
      await t.enterText(find.byType(TextFormField).at(0), 'N-1');
      await t.enterText(find.byType(TextFormField).at(1), '24');
      await t.enterText(find.byType(TextFormField).at(2), '34');
      await _evaluar(t);
      expect(find.text('Elige el sexo del niño'), findsOneWidget);
      expect(find.text('Indica si asiste a control CRED'), findsOneWidget);
      expect(find.text('Indica si recibe suplementación con hierro'), findsOneWidget);
      expect(find.text('Riesgo bajo'), findsNothing); // no se evaluó nada
    });

    testWidgets('valida en el cliente los mismos rangos que la API (edad 6-59, altitud 0-700)', (t) async {
      await _arrancar(t);
      await _login(t);
      await _irAFormulario(t);
      await _llenar(t, edad: '5', altitud: '3400');
      await _evaluar(t);
      expect(find.textContaining('La edad debe estar entre 6 y 59 meses'), findsOneWidget);
      expect(find.textContaining('La altitud debe estar entre 0 y 700 msnm'), findsOneWidget);
      expect(find.textContaining('Trujillo'), findsOneWidget);

      await t.enterText(find.byType(TextFormField).at(1), '60');
      await t.enterText(find.byType(TextFormField).at(2), '701');
      await _evaluar(t);
      expect(find.textContaining('La edad debe estar entre 6 y 59 meses'), findsOneWidget);
      expect(find.textContaining('La altitud debe estar entre 0 y 700 msnm'), findsOneWidget);

      // Límites válidos: 6 meses y 700 msnm pasan la validación del cliente.
      await t.enterText(find.byType(TextFormField).at(1), '6');
      await t.enterText(find.byType(TextFormField).at(2), '700');
      await _evaluar(t);
      expect(find.textContaining('La edad debe estar'), findsNothing);
      expect(find.text('Resultado'), findsOneWidget);
    });

    testWidgets('un 422 fuera_de_dominio_modelo del servidor se muestra tal cual', (t) async {
      final (_, api) = await _arrancar(t);
      await _login(t);
      await _irAFormulario(t);
      const msg =
          'altitud debe estar entre 0 y 700 msnm: el modelo solo es válido para establecimientos de Trujillo (entrenado con altitudes de 10 a 659 msnm)';
      api.falla = ErrorApi(msg, codigo: 422, tipo: tipoFueraDeDominio);
      await _llenar(t);
      await _evaluar(t);
      expect(find.text(msg), findsOneWidget); // texto íntegro, en un banner persistente
      expect(find.byIcon(Icons.error_outline), findsWidgets);
      expect(find.text('Resultado'), findsNothing);
      // los datos se conservan para corregir (se vuelve arriba: el formulario se desplazó al mensaje)
      await t.drag(find.byType(ListView).first, const Offset(0, 1500));
      await t.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'N-77'), findsOneWidget);
    });

    testWidgets('evaluar sin red conserva lo escrito y ofrece guardar en el teléfono', (t) async {
      final (estado, api) = await _arrancar(t);
      await _login(t);
      await _irAFormulario(t);
      api.caido = true;
      await _llenar(t, codigo: 'N-9');
      await _evaluar(t);
      expect(find.textContaining('Sin conexión'), findsWidgets);
      expect(find.text('Guardar en el teléfono'), findsOneWidget);
      await t.drag(find.byType(ListView).first, const Offset(0, 1500)); // volver arriba
      await t.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'N-9'), findsOneWidget); // lo escrito se conserva
      await t.drag(find.byType(ListView).first, const Offset(0, -1500)); // y de nuevo al mensaje
      await t.pumpAndSettle();
      expect(estado.pendientes, isEmpty); // aún no se guardó: lo decide el usuario

      await t.tap(find.text('Guardar en el teléfono'));
      await t.pumpAndSettle();
      expect(estado.pendientes.length, 1);
      expect(estado.pendientes.single.datos.codigo, 'N-9');
      expect(estado.pendientes.single.riesgo, isNull); // sin predicción: la calculará el servidor
      expect(find.widgetWithText(TextFormField, 'N-9'), findsNothing); // formulario limpio

      // al volver la conexión se envía sola y no se pierde nada
      api.caido = false;
      await estado.sincronizar();
      expect(estado.pendientes, isEmpty);
      final l = await api.listar(const Filtro());
      expect(l.first.datos.codigo, 'N-9');
    });
  });

  group('Resultado', () {
    testWidgets('alerta de tamizaje + probabilidades por clase + aviso + factores generales', (t) async {
      await _arrancar(t);
      await _login(t);
      await _irAFormulario(t);
      await _llenar(t, codigo: 'N-77', edad: '12', altitud: '137', cred: false, supl: false);
      await _evaluar(t);

      // Riesgo y frase de alerta (no diagnóstico)
      expect(find.textContaining('Riesgo '), findsWidgets);
      final alerta = t.widget<Text>(find.byKey(const Key('texto-alerta'))).data!;
      expect(alerta, startsWith('Alerta de tamizaje: probabilidad estimada de anemia'));
      expect(alerta, matches(RegExp(r'\d+%$')));

      // Probabilidades de las 3 clases
      expect(find.text('Probabilidad por clase'), findsOneWidget);
      expect(find.byKey(const Key('barra-bajo')), findsOneWidget);
      expect(find.byKey(const Key('barra-medio')), findsOneWidget);
      expect(find.byKey(const Key('barra-alto')), findsOneWidget);
      expect(find.textContaining('calibradas'), findsOneWidget);
      expect(find.textContaining('subestimar'), findsOneWidget);

      // Aviso obligatorio y rótulo de factores
      expect(find.text(avisoApoyo), findsOneWidget);
      expect(find.text('Herramienta de apoyo. No reemplaza el diagnóstico clínico ni la medición de hemoglobina.'),
          findsOneWidget);
      await t.scrollUntilVisible(find.text('Factores generales del modelo'), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Factores generales del modelo'), findsOneWidget);
      expect(find.text('Variables más importantes del modelo'), findsNothing);
      expect(find.textContaining('no explica el caso de este niño'), findsOneWidget);
      expect(find.textContaining('Hemoglobina'), findsNothing); // ya no es un dato de la valoración
    });

    test('la frase de alerta usa la probabilidad calibrada de la clase devuelta (ej. Alto 32 %)', () {
      // Caso real del backend: riesgo "Alto" con P(Alto)=0.3158 es correcto.
      final p = Prediccion.fromJson({
        'riesgo': 'Alto',
        'probabilidad': 0.3158,
        'probabilidades': {'Bajo': 0.6767, 'Medio': 0.0075, 'Alto': 0.3158},
        'modelo': 'Random Forest - Modelo B (sin hemoglobina)',
        'tiempo_ms': 36,
        'factores_influyentes': [
          {'factor': 'No asiste a control CRED', 'peso': 0.302}
        ],
      });
      expect(p.riesgo, Riesgo.alto);
      expect(p.probRiesgo, 0.3158);
      expect(textoAlerta(p), 'Alerta de tamizaje: probabilidad estimada de anemia moderada o severa 32%');
      expect(fmtPct(0.001), '<1%'); // nunca "0%": la API acota a >= 0.1 %
      expect(fmtPct(0.976), '98%');
    });
  });

  testWidgets('evaluar y guardar sin red deja la valoración pendiente y la envía luego', (t) async {
    final (estado, api) = await _arrancar(t);
    await _login(t);
    await _irAFormulario(t);
    await _llenar(t, codigo: 'N-9', edad: '24', cred: false, supl: false);
    await _evaluar(t);
    expect(find.text('Resultado'), findsOneWidget);

    api.caido = true;
    await t.tap(find.text('Guardar'));
    await t.pumpAndSettle();
    expect(estado.pendientes.length, 1);
    expect(estado.pendientes.single.riesgo, isNotNull); // se guardó también la predicción obtenida

    api.caido = false;
    await estado.sincronizar();
    expect(estado.pendientes, isEmpty);
    final l = await api.listar(const Filtro());
    expect(l.first.datos.codigo, 'N-9');
  });

  testWidgets('si el servidor rechaza un pendiente (422) no se pierde: queda marcado y visible', (t) async {
    final (estado, api) = await _arrancar(t);
    await _login(t);
    await estado.guardarSinConexion(const DatosNino(
        codigo: 'N-RECH',
        edadMeses: 20,
        sexo: 'F',
        altitud: 34,
        cred: true,
        suplementacion: true,
        grupo: 'control'));
    api.fallaAlGuardar = ErrorApi('edad_meses debe estar entre 6 y 59 meses', codigo: 422, tipo: tipoFueraDeDominio);
    await estado.sincronizar();
    expect(estado.pendientes.length, 1); // NO se descartó
    expect(estado.pendientes.single.error, contains('entre 6 y 59'));
    expect(estado.porEnviar, 0);
    expect(estado.rechazados, 1);

    await t.tap(find.text('Historial'));
    await t.pumpAndSettle();
    expect(find.text('N-RECH'), findsOneWidget);
    expect(find.textContaining('No se pudo enviar'), findsOneWidget);

    // el usuario decide descartarlo
    await t.tap(find.text('N-RECH'));
    await t.pumpAndSettle();
    await t.tap(find.text('Descartar esta valoración'));
    await t.pumpAndSettle();
    expect(estado.pendientes, isEmpty);
  });

  testWidgets('RF08-RF11: listar, buscar, registrar, editar y eliminar niños', (t) async {
    final (_, api) = await _arrancar(t);
    await _login(t);
    await t.tap(find.byType(PopupMenuButton<String>));
    await t.pumpAndSettle();
    await t.tap(find.text('Niños').last);
    await t.pumpAndSettle();
    expect(find.text('N-100'), findsOneWidget);

    // buscar
    await t.enterText(find.byType(TextField), 'N-103');
    await t.testTextInput.receiveAction(TextInputAction.search);
    await t.pumpAndSettle();
    expect(find.text('N-100'), findsNothing);
    expect(find.widgetWithText(ListTile, 'N-103'), findsOneWidget);
    await t.enterText(find.byType(TextField), '');
    await t.testTextInput.receiveAction(TextInputAction.search);
    await t.pumpAndSettle();

    // registrar (sin elegir sexo/CRED/suplementación no deja avanzar)
    await t.tap(find.text('Registrar niño'));
    await t.pumpAndSettle();
    expect(find.textContaining('Hemoglobina'), findsNothing);
    await t.enterText(find.byType(TextFormField).at(0), 'N-900');
    await t.enterText(find.byType(TextFormField).at(1), '30');
    await t.enterText(find.byType(TextFormField).at(2), '100');
    await t.tap(find.text('Registrar').last);
    await t.pumpAndSettle();
    expect(find.text('Elige el sexo del niño'), findsOneWidget);
    await t.tap(find.text('Femenino'));
    await t.tap(find.text('Sí').at(0));
    await t.tap(find.text('No').at(1));
    await t.pumpAndSettle();
    await t.tap(find.text('Registrar').last);
    await t.pumpAndSettle();
    expect(find.text('N-900'), findsOneWidget);

    // editar
    await t.tap(find.text('N-900'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField).at(1), '31');
    await t.tap(find.text('Guardar cambios'));
    await t.pumpAndSettle();
    expect((await api.listarNinos('N-900')).single.datos.edadMeses, 31);

    // eliminar
    await t.tap(find.text('N-900'));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Eliminar'));
    await t.pumpAndSettle();
    await t.tap(find.text('Eliminar').last);
    await t.pumpAndSettle();
    expect(await api.listarNinos('N-900'), isEmpty);
  });

  testWidgets('RF03-RF06: listar, registrar, modificar e inhabilitar usuarios', (t) async {
    final (_, api) = await _arrancar(t);
    await _login(t);
    await t.tap(find.byType(PopupMenuButton<String>));
    await t.pumpAndSettle();
    await t.tap(find.text('Usuarios').last);
    await t.pumpAndSettle();
    expect(find.text('Luis Enfermero'), findsOneWidget);

    // registrar
    await t.tap(find.text('Registrar usuario'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField).at(0), 'Ana Perez');
    await t.enterText(find.byType(TextFormField).at(1), 'ana');
    await t.enterText(find.byType(TextFormField).at(2), 'secreto1');
    await t.tap(find.text('Registrar').last);
    await t.pumpAndSettle();
    expect(find.text('Ana Perez'), findsOneWidget);

    // modificar
    await t.tap(find.text('Ana Perez'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField).at(0), 'Ana P.');
    await t.tap(find.text('Guardar cambios'));
    await t.pumpAndSettle();
    expect(find.text('Ana P.'), findsOneWidget);

    // inhabilitar
    await t.tap(find.text('Ana P.'));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Inhabilitar'));
    await t.pumpAndSettle();
    await t.tap(find.text('Inhabilitar').last);
    await t.pumpAndSettle();
    final ana = (await api.listarUsuarios()).firstWhere((u) => u.usuario == 'ana');
    expect(ana.activo, isFalse);
  });

  testWidgets('historial filtra por riesgo', (t) async {
    await _arrancar(t);
    await _login(t);
    await t.tap(find.text('Historial'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(ChoiceChip, 'Alto'));
    await t.pumpAndSettle();
    final insignias = t.widgetList<RiesgoBadge>(find.byType(RiesgoBadge));
    expect(insignias, isNotEmpty);
    expect(insignias.every((b) => b.riesgo == Riesgo.alto), isTrue);
  });
}
