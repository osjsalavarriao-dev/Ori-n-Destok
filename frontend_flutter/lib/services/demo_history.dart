import 'dart:math';

import '../models/telemetry.dart';

/// Historial sintético de los días previos de misión para el modo demo.
/// Mismas fórmulas que history() en backend_fastapi/app/sensor_simulator.py:
/// HRV y presión bajan, glucosa sube, sueño corto y bajón de ánimo a mitad.
class DemoHistory {
  DemoHistory({int days = 13, DateTime? now, int seed = 7}) {
    final rng = Random(seed);
    double noise(double a) => (rng.nextDouble() * 2 - 1) * a;
    final n = (now ?? DateTime.now()).toUtc();
    final today = DateTime.utc(n.year, n.month, n.day);
    for (var d = 0; d < days; d++) {
      final day = today.subtract(Duration(days: days - d));
      final p = d / max(1, days - 1);
      final sleep = d == days - 4
          ? 5.2
          : ((6.6 - .5 * p + noise(.5)) * 10).round() / 10;
      final mood = p >= .6 && p <= .85 ? 3 : 4;
      final values = {
        'frecuencia_cardiaca': (68 - 4 * p + noise(2)).roundToDouble(),
        'spo2': ((98 + noise(.5)) * 10).round() / 10,
        'hrv': ((55 - 11 * p + noise(3)) * 10).round() / 10,
        'temperatura_corporal': ((36.7 + .2 * p + noise(.1)) * 10).round() / 10,
        'presion_sistolica': (120 - 8 * p + noise(3)).roundToDouble(),
        'presion_diastolica': (78 - 5 * p + noise(2)).roundToDouble(),
        'glucosa': (88 + 8 * p + noise(3)).roundToDouble(),
        'horas_sueno': sleep,
        'animo': mood.toDouble(),
      };
      this.days.add(DailyPoint(day, values));
      for (final m in ['presion_sistolica', 'presion_diastolica', 'glucosa']) {
        measurements.add(
          Measurement(
            time: day.add(const Duration(hours: 7)),
            metric: m,
            value: values[m]!,
            manual: false,
          ),
        );
      }
      // Más reciente primero, como lo devuelve el backend.
      wellbeing.insert(0, {
        'timestamp_utc': day
            .add(const Duration(hours: 6, minutes: 30))
            .toIso8601String(),
        'horas_sueno': sleep,
        'agua_ml': 2000,
        'energia': mood,
        'animo': mood,
      });
    }
  }
  final List<DailyPoint> days = [];
  final List<Measurement> measurements = [];
  final List<Map<String, dynamic>> wellbeing = [];
}
