import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:horion_edge/l10n/language.dart';
import 'package:horion_edge/main.dart';
import 'package:horion_edge/models/health_knowledge.dart';
import 'package:horion_edge/models/hrp_catalog.dart';
import 'package:horion_edge/screens/risks_screen.dart';
import 'package:horion_edge/models/telemetry.dart';
import 'package:horion_edge/screens/trends_screen.dart';

Future<void> _open(WidgetTester tester, {Size size = const Size(1440, 1000)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(const HorionApp(language: AppLanguage.es));
  await tester.pump();
}

void main() {
  testWidgets('Navegación, alerta y bienestar funcionan en demo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const HorionApp(language: AppLanguage.es));
    await tester.pump();
    expect(find.text('DEMO · DATOS SIMULADOS'), findsOneWidget);
    await tester.tap(find.text('Simular anomalía'));
    await tester.pump();
    // SpO₂ y HRV críticas, frecuencia cardíaca en vigilancia.
    expect(find.text('Marcar como atendida'), findsNWidgets(3));
    expect(find.text('Estado general: Crítico'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Marcar como atendida').first);
      await tester.pump();
    }
    expect(find.text('Marcar como atendida'), findsNothing);
    await tester.tap(find.text('Historial y sync'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar registro'));
    await tester.pump();
    expect(find.text('Registro guardado en memoria demo.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Mapa corporal y ficha educativa de indicador', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const HorionApp(language: AppLanguage.es));
    await tester.pump();
    await tester.tap(find.text('Glucosa en sangre'));
    await tester.pumpAndSettle();
    expect(find.text('¿Cómo medirlo a bordo?'), findsOneWidget);
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();
    // La figura se anima sin fin, así que se avanza con pump() en vez de pumpAndSettle().
    await tester.tap(find.text('Mapa corporal').first);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Corazón y circulación'), findsWidgets);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Huesos y músculos'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Sin sensor directo a bordo'), findsOneWidget);
    // Tocar la cabeza de la figura selecciona el cerebro.
    final figure = tester.getRect(find.byKey(const ValueKey('body-figure')));
    final scale = figure.width / 200 < figure.height / 440
        ? figure.width / 200
        : figure.height / 440;
    final top = figure.top + (figure.height - 440 * scale) / 2;
    await tester.tapAt(Offset(figure.center.dx, top + 34 * scale));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Función'), findsOneWidget);
    expect(find.textContaining('Controla el pensamiento'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('La línea base usa los 3 primeros días y compara con los 3 últimos', () {
    final hrv = indicator('hrv');
    DailyPoint day(int d, double? v) =>
        DailyPoint(DateTime.utc(2026, 1, d), {'hrv': ?v});
    final all = [day(1, 50), day(2, 52), day(3, 54), day(4, null), day(5, 40), day(6, 42), day(7, 44)];
    expect(BaselineComparison.of(hrv, all.take(4).toList(), all), isNull);
    final cmp = BaselineComparison.of(hrv, all, all.skip(4).toList())!;
    expect(cmp.baseline, 52);
    expect(cmp.recent, 42);
    expect(cmp.change, closeTo(-0.192, 0.001));
    expect(cmp.change.abs() > hrv.baselineTolerance, isTrue);
    expect(cmp.daysOutOfRange, 0); // 40–44 ms sigue en el rango normal.
  });

  testWidgets('Tendencias con historial demo, entorno y medición manual', (tester) async {
    await _open(tester);
    await tester.tap(find.text('Tendencias').first);
    await tester.pumpAndSettle();
    expect(find.text('Tu línea base'), findsOneWidget); // Leyenda del gráfico.
    await tester.scrollUntilVisible(
      find.text('Resumen frente a tu línea base'),
      400,
      scrollable: find
          .descendant(of: find.byType(TrendsScreen), matching: find.byType(Scrollable))
          .first,
    );
    expect(find.text('Resumen frente a tu línea base'), findsOneWidget);
    expect(find.textContaining('Base '), findsWidgets);
    expect(find.text('Se necesitan al menos 4 días con datos'), findsNothing);

    await tester.tap(find.text('Riesgos y entorno').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Estación espacial (órbita baja) · Día 14'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Base marciana'));
    await tester.pumpAndSettle();
    expect(find.text('4–24 min (solo de ida)'), findsOneWidget);
    expect(find.textContaining('Base marciana · Día 14'), findsOneWidget);
    expect(find.textContaining('del límite de carrera NASA'), findsOneWidget);

    await tester.tap(find.text('Monitor vital').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar medición'));
    await tester.pumpAndSettle();
    // Presión imposible: la sistólica no puede ser menor que la diastólica.
    await tester.enterText(find.byKey(const ValueKey('measure-presion_sistolica')), '80');
    await tester.enterText(find.byKey(const ValueKey('measure-presion_diastolica')), '90');
    await tester.pump();
    expect(find.text('La sistólica debe ser mayor que la diastólica.'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Guardar')).onPressed, isNull);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Glucosa')).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('measure-glucosa')), '50');
    await tester.pump();
    expect(find.text('Glucosa: Crítico'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Medición registrada.'), findsOneWidget);
    expect(find.text('50'), findsOneWidget); // Tarjeta de glucosa.
    expect(find.textContaining('ALERTA CRÍTICA · GLUCOSA EN SANGRE'), findsOneWidget);
    // En Marte la alerta crítica recuerda actuar sin esperar a Tierra.
    expect(find.textContaining('Base marciana: Tierra tarda'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('Catálogo NASA HRP: 17 riesgos (11/5/1) con referencias válidas', () {
    expect(hrpRisks, hasLength(17));
    int count(RiskCategory c) => hrpRisks.where((r) => r.category == c).length;
    expect(count(RiskCategory.physiology), 11);
    expect(count(RiskCategory.behavior), 5);
    expect(count(RiskCategory.radiation), 1);
    expect(hrpRisks.map((r) => r.officialName).toSet(), hasLength(17));
    final regionIds = bodyRegions.map((r) => r.id).toSet();
    final indicatorIds = indicators.map((i) => i.id).toSet();
    for (final r in hrpRisks) {
      expect(regionIds, containsAll(r.regionIds), reason: r.officialName);
      expect(indicatorIds, containsAll(r.indicatorIds), reason: r.officialName);
    }
    for (final s in researchStudies) {
      expect(regionIds, containsAll(s.regionIds), reason: s.name);
    }
    expect(researchFor('eyes').map((s) => s.name), containsAll(['Thigh Cuff', 'B-Complex']));
  });

  testWidgets('Autoevaluación de SANS: mapa corporal y riesgo HRP', (tester) async {
    await _open(tester);
    await tester.tap(find.text('Mapa corporal').first);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Ojos y visión (SANS)'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Responde la autoevaluación de síntomas'), findsOneWidget);
    expect(find.textContaining('Thigh Cuff'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('symptom-blurred_near')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Estado: Vigilar'), findsOneWidget);
    expect(find.textContaining('Visión de cerca borrosa'), findsOneWidget);
    // Una zona sin síntomas confirmados pasa a normal.
    await tester.tap(find.widgetWithText(ChoiceChip, 'Oído interno y equilibrio'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('No tengo ninguno'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Estado: Normal'), findsOneWidget);
    expect(find.textContaining('problemas de equilibrio'), findsOneWidget); // Beneficio en la Tierra.

    await tester.tap(find.text('Riesgos y entorno').first);
    await tester.pumpAndSettle();
    final list = find
        .descendant(of: find.byType(RisksScreen), matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(find.text('Los 5 peligros del vuelo espacial'), 400, scrollable: list);
    expect(find.text('Los 5 peligros del vuelo espacial'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Síndrome neuro-ocular (SANS)'), 400, scrollable: list);
    expect(find.text('Vigilado · Vigilar'), findsWidgets);
    await tester.drag(list, const Offset(0, -300)); // Deja espacio para el contenido expandido.
    await tester.pumpAndSettle();
    await tester.tap(find.text('Síndrome neuro-ocular (SANS)'));
    await tester.pumpAndSettle();
    expect(find.text('Risk of Spaceflight Associated Neuro-ocular Syndrome (SANS)'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Cáncer inducido por radiación'), 400, scrollable: list);
    expect(find.text('Informativo'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('Un texto traducible interpolado sin traducir falla en debug', () {
    const text = T('Hola', 'Hello');
    expect(text.of(AppLanguage.en), 'Hello');
    expect(() => '$text', throwsA(isA<AssertionError>()));
  });

  testWidgets('Cambiar a inglés traduce todas las pantallas en vivo', (tester) async {
    await _open(tester);
    expect(find.text('Monitor vital'), findsWidgets);
    await tester.tap(find.byIcon(Icons.translate));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();
    // Los datos y el estado se conservan; solo cambia el idioma.
    expect(find.text('Vital monitor'), findsWidgets);
    expect(find.text('Monitor vital'), findsNothing);
    expect(find.text('Log measurement'), findsOneWidget);
    expect(find.textContaining('Space station (low Earth orbit) · Day 14'), findsOneWidget);

    await tester.tap(find.text('Blood glucose'));
    await tester.pumpAndSettle();
    expect(find.text('How to measure it on board?'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log measurement'));
    await tester.pumpAndSettle();
    expect(find.text('Systolic (upper)'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Simulate anomaly'));
    await tester.pump();
    expect(find.text('CRITICAL ALERT · OXYGEN SATURATION · SIMULATION'), findsOneWidget);
    expect(find.textContaining('Oxygen saturation in the critical range.'), findsOneWidget);
    expect(find.text('Overall status: Critical'), findsOneWidget);

    await tester.tap(find.text('Body map').first);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Heart and circulation'), findsWidgets);
    expect(find.text('Prevention'), findsOneWidget);

    await tester.tap(find.text('Trends').first);
    await tester.pumpAndSettle();
    expect(find.text('Your baseline'), findsOneWidget);
    expect(find.text('14 days'), findsOneWidget);

    await tester.tap(find.text('Risks & environment').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Mars base'));
    await tester.pumpAndSettle();
    expect(find.text('4–24 min (one way)'), findsOneWidget);
    expect(find.textContaining('of the NASA career limit'), findsOneWidget);

    await tester.tap(find.text('Orbi assistant').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show my vital signs'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Demo reply:'), findsOneWidget);

    await tester.tap(find.text('History & sync').first);
    await tester.pumpAndSettle();
    expect(find.text('Wellbeing log'), findsOneWidget);
    expect(find.textContaining('Mood: Good'), findsOneWidget);

    // Y de vuelta a español.
    await tester.tap(find.byIcon(Icons.translate));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Español').last);
    await tester.pumpAndSettle();
    expect(find.text('Registro de bienestar'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Ventana compacta y chat bloqueado durante corte simulado', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const HorionApp(language: AppLanguage.es));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.auto_awesome_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver mis signos vitales'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Respuesta de demostración:'), findsOneWidget);
    await tester.tap(find.byType(Switch).at(1));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
