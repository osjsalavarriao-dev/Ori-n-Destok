import 'package:flutter_test/flutter_test.dart';
import 'package:horion_edge/l10n/language.dart';
import 'package:horion_edge/models/health_knowledge.dart';
import 'package:horion_edge/widgets/vital_card.dart';
import 'package:horion_edge/widgets/vital_icon.dart';
import 'package:horion_edge/widgets/vital_motion.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('cada indicador del monitor tiene su propio dibujo', () {
    const monitor = [
      'frecuencia_cardiaca',
      'spo2',
      'hrv',
      'temperatura_corporal',
      'presion_sistolica',
      'glucosa',
      'horas_sueno',
      'animo',
    ];
    final glyphs = [for (final id in monitor) glyphFor(id)];
    expect(glyphs, everyElement(isNotNull));
    expect(glyphs.toSet().length, monitor.length); // Ninguno se repite.
    expect(glyphFor('presion_diastolica'), VitalGlyph.gauge);
  });

  test('cada signo vital tiene su propio color, distinto de los de estado', () {
    const monitor = [
      'frecuencia_cardiaca',
      'spo2',
      'hrv',
      'temperatura_corporal',
      'presion_sistolica',
      'glucosa',
      'horas_sueno',
      'animo',
    ];
    final colors = [for (final id in monitor) indicator(id).color];
    expect(colors.toSet().length, monitor.length);
    final statusColors = {
      for (final s in HealthStatus.values) ...[s.color, badgeColors(s).glow],
    };
    expect(colors.where(statusColors.contains), isEmpty);
    // La presión diastólica comparte color con la sistólica: es el mismo signo.
    expect(
      indicator('presion_diastolica').color,
      indicator('presion_sistolica').color,
    );
  });

  test('cada estado tiene su propio color semántico', () {
    final glows = {for (final s in HealthStatus.values) s: badgeColors(s).glow};
    expect(glows.values.toSet().length, HealthStatus.values.length);
    expect(glows[HealthStatus.good], const Color(0xFF22D3EE)); // Cian.
    expect(glows[HealthStatus.unknown]!.a, 0); // Sin datos: sin brillo.
  });

  Widget badge(
    String metric,
    double? value,
    HealthStatus status, {
    bool still = false,
  }) => MediaQuery(
    data: MediaQueryData(disableAnimations: still),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: LiveVitalBadge(
          glyph: glyphFor(metric)!,
          metric: metric,
          value: value,
          status: status,
        ),
      ),
    ),
  );

  testWidgets('los iconos se animan según el dato y el estado', (tester) async {
    for (final status in [
      HealthStatus.good,
      HealthStatus.watch,
      HealthStatus.critical,
    ]) {
      await tester.pumpWidget(badge('hrv', 45, status));
      expect(tester.hasRunningAnimations, isTrue, reason: '$status');
    }
    await tester.pumpWidget(
      badge('frecuencia_cardiaca', 120, HealthStatus.watch),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });

  testWidgets('sin datos o con animaciones en pausa, el icono queda quieto', (
    tester,
  ) async {
    await tester.pumpWidget(badge('hrv', null, HealthStatus.unknown));
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pumpWidget(
      badge('spo2', 89, HealthStatus.critical, still: true),
    );
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('las tarjetas muestran el dibujo grande de cada signo vital', (
    tester,
  ) async {
    const cards = [
      ('frecuencia_cardiaca', 'Pulso', '68', 'lpm', HealthStatus.good),
      ('spo2', 'Oxígeno en sangre', '89', '%', HealthStatus.critical),
      ('hrv', 'Recuperación (HRV)', '45', 'ms', HealthStatus.watch),
      ('temperatura_corporal', 'Temperatura', '36.7', '°C', HealthStatus.good),
      ('presion_sistolica', 'Presión', '118/76', 'mmHg', HealthStatus.good),
      ('glucosa', 'Glucosa', '94', 'mg/dL', HealthStatus.good),
      ('horas_sueno', 'Sueño', '—', 'h', HealthStatus.unknown),
      ('animo', 'Ánimo', '4', '/5', HealthStatus.good),
    ];
    tester.view.physicalSize = const Size(1240, 620);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      LanguageScope(
        controller: LanguageController(AppLanguage.es),
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            backgroundColor: const Color(0xFF0A1620),
            body: RepaintBoundary(
              key: const Key('cards'),
              child: GridView.count(
                crossAxisCount: 4,
                padding: const EdgeInsets.all(16),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.35,
                children: [
                  for (final (id, label, value, unit, status) in cards)
                    VitalCard(
                      metric: id,
                      label: label,
                      value: value,
                      unit: unit,
                      icon: Icons.circle,
                      status: status,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(VitalIcon), findsNWidgets(cards.length));
    expect(
      find.byIcon(Icons.circle),
      findsNothing,
    ); // Nunca el icono de respaldo.
    expect(tester.takeException(), isNull);
  });
}
