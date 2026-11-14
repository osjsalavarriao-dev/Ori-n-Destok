/// Lectura continua de los sensores (cada 5 s).
class Telemetry {
  const Telemetry({
    required this.time,
    required this.bpm,
    required this.spo2,
    required this.hrv,
    required this.temperature,
  });
  final DateTime time;
  final int bpm;
  final double spo2, hrv, temperature;

  factory Telemetry.fromJson(Map<String, dynamic> json) => Telemetry(
    time: DateTime.parse(json['timestamp_utc'] as String),
    bpm: json['frecuencia_cardiaca'] as int,
    spo2: (json['spo2'] as num).toDouble(),
    hrv: (json['hrv'] as num).toDouble(),
    temperature: (json['temperatura_corporal'] as num).toDouble(),
  );

  /// Valor por id de indicador (ver health_knowledge.dart).
  double? operator [](String id) => switch (id) {
    'frecuencia_cardiaca' => bpm.toDouble(),
    'spo2' => spo2,
    'hrv' => hrv,
    'temperatura_corporal' => temperature,
    _ => null,
  };
}

/// Medición puntual: tensiómetro, glucómetro o termómetro.
class Measurement {
  const Measurement({
    required this.time,
    required this.metric,
    required this.value,
    required this.manual,
  });
  final DateTime time;
  final String metric;
  final double value;
  final bool manual;

  factory Measurement.fromJson(Map<String, dynamic> json) => Measurement(
    time: DateTime.parse(json['timestamp_utc'] as String),
    metric: json['metrica'] as String,
    value: (json['valor'] as num).toDouble(),
    manual: json['origen'] == 'MANUAL',
  );
}

/// Promedio diario de cada indicador, para las tendencias.
class DailyPoint {
  const DailyPoint(this.date, this.values);
  final DateTime date;
  final Map<String, double> values;

  factory DailyPoint.fromJson(Map<String, dynamic> json) => DailyPoint(
    DateTime.parse(json['date'] as String),
    (json['values'] as Map).map(
      (k, v) => MapEntry(k as String, (v as num).toDouble()),
    ),
  );
}
