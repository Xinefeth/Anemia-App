import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:anemia_ml_app/main.dart';
import 'package:anemia_ml_app/models/modelos.dart';
import 'package:anemia_ml_app/services/api.dart';
import 'package:anemia_ml_app/services/app_state.dart';
import 'package:anemia_ml_app/services/mock_api.dart';
import 'package:anemia_ml_app/widgets/comunes.dart';
import 'package:anemia_ml_app/services/hemoglobina.dart';

Future<(AppState, MockApi)> _arrancar(WidgetTester t) async {
  SharedPreferences.setMockInitialValues({});
  t.view.physicalSize = const Size(1080, 2400);
  t.view.devicePixelRatio = 2.75;
  addTearDown(t.view.reset);
  final api = MockApi();
  final estado = AppState(apiPrueba: api);
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

void main() {
  test('Hb ajustada por altitud (OMS 2011)', () {
    expect(ajusteAltitud(34), 0);
    expect(ajusteAltitud(1000), closeTo(0.2, 1e-9));
    expect(ajusteAltitud(3000), closeTo(1.9, 1e-9));
    expect(ajusteAltitud(3250), closeTo(2.3, 1e-9)); // interpolado
    expect(ajusteAltitud(6000), 4.5);
    expect(sugiereAnemia(9.2, 34), isTrue);
    expect(sugiereAnemia(11.5, 34), isFalse);
    // 12.0 g/dL a 3200 msnm: ajustada 12.0-2.26=9.74 -> sugiere anemia
    expect(sugiereAnemia(12.0, 3200), isTrue);
    expect(sugiereAnemia(null, 3200), isFalse);
  });

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

  testWidgets('el resultado advierte si la Hb sugiere anemia', (t) async {
    await _arrancar(t);
    await _login(t);
    await t.tap(find.text('Valorar'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField).at(0), 'N-77');
    await t.enterText(find.byType(TextFormField).at(1), '24');
    await t.enterText(find.byType(TextFormField).at(2), '9.2');
    await t.enterText(find.byType(TextFormField).at(3), '34');
    await t.tap(find.text('Evaluar riesgo'));
    await t.pumpAndSettle();
    expect(find.text('La hemoglobina medida sugiere anemia'), findsOneWidget);
    expect(find.textContaining('no diagnostica'), findsOneWidget);
  });

  testWidgets('sin anemia por Hb no hay advertencia', (t) async {
    await _arrancar(t);
    await _login(t);
    await t.tap(find.text('Valorar'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField).at(0), 'N-78');
    await t.enterText(find.byType(TextFormField).at(1), '24');
    await t.enterText(find.byType(TextFormField).at(2), '12.5');
    await t.enterText(find.byType(TextFormField).at(3), '34');
    await t.tap(find.text('Evaluar riesgo'));
    await t.pumpAndSettle();
    expect(find.text('La hemoglobina medida sugiere anemia'), findsNothing);
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
  });

  testWidgets('formulario valida rangos (edad >= 60)', (t) async {
    await _arrancar(t);
    await _login(t);
    await t.tap(find.text('Valorar'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField).at(0), 'N-1');
    await t.enterText(find.byType(TextFormField).at(1), '70');
    await t.tap(find.text('Evaluar riesgo'));
    await t.pumpAndSettle();
    expect(find.textContaining('La edad debe estar entre'), findsOneWidget);
    expect(find.text('Ingresa la hemoglobina'), findsOneWidget);
  });

  testWidgets('evaluar sin red conserva lo escrito', (t) async {
    final (_, api) = await _arrancar(t);
    await _login(t);
    await t.tap(find.text('Valorar'));
    await t.pumpAndSettle();
    api.caido = true;
    await t.enterText(find.byType(TextFormField).at(0), 'N-9');
    await t.enterText(find.byType(TextFormField).at(1), '24');
    await t.enterText(find.byType(TextFormField).at(2), '9.5');
    await t.enterText(find.byType(TextFormField).at(3), '34');
    await t.tap(find.text('Evaluar riesgo'));
    await t.pumpAndSettle();
    expect(find.textContaining('Sin conexión'), findsWidgets);
    expect(find.widgetWithText(TextFormField, 'N-9'), findsOneWidget);
  });

  testWidgets('evaluar y guardar sin red deja la valoración pendiente y la envía luego', (t) async {
    final (estado, api) = await _arrancar(t);
    await _login(t);
    await t.tap(find.text('Valorar'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField).at(0), 'N-9');
    await t.enterText(find.byType(TextFormField).at(1), '24');
    await t.enterText(find.byType(TextFormField).at(2), '9.5');
    await t.enterText(find.byType(TextFormField).at(3), '34');
    await t.tap(find.text('Evaluar riesgo'));
    await t.pumpAndSettle();
    expect(find.text('Riesgo alto'), findsOneWidget);

    api.caido = true;
    await t.tap(find.text('Guardar'));
    await t.pumpAndSettle();
    expect(estado.pendientes.length, 1);

    api.caido = false;
    await estado.sincronizar();
    expect(estado.pendientes, isEmpty);
    final l = await api.listar(const Filtro());
    expect(l.first.datos.codigo, 'N-9');
    expect(l.first.riesgo, Riesgo.alto);
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

    // registrar
    await t.tap(find.text('Registrar niño'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField).at(0), 'N-900');
    await t.enterText(find.byType(TextFormField).at(1), '30');
    await t.enterText(find.byType(TextFormField).at(2), '11.2');
    await t.enterText(find.byType(TextFormField).at(3), '100');
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
