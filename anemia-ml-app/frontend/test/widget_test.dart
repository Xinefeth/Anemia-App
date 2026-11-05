import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:anemia_ml_app/main.dart';
import 'package:anemia_ml_app/models/modelos.dart';
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
