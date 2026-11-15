import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../l10n/language.dart';
import '../models/health_knowledge.dart';
import '../models/hrp_catalog.dart';
import '../models/mission_environment.dart';
import '../models/telemetry.dart';
import 'api_service.dart';
import 'demo_history.dart';

/// Métricas que se miden de forma puntual en lugar de continua.
const spotMetrics = {
  'presion_sistolica',
  'presion_diastolica',
  'glucosa',
  'temperatura_corporal',
};

class EdgeController extends ChangeNotifier {
  EdgeController({this.demo = true}) {
    if (demo) _seedDemo();
  }
  final ApiService _api = ApiService();
  final Random _random = Random(42);
  Timer? _timer;
  bool demo, offline = false, _busy = false, connected = false;
  bool get busy => _busy || _polling;
  bool _disposed = false, _polling = false;
  T? error;
  int pending = 0;

  /// Horion Web: si el backend tiene URL y clave, y el último resultado del envío
  /// (`estado`, `detalle`, `ultimo_exito_utc`). Nunca se usa en modo demo.
  bool cloudConfigured = false;
  Map<String, dynamic> cloudSync = {};
  List<Telemetry> telemetry = [];
  List<Map<String, dynamic>> alerts = [], wellbeing = [];

  /// Última medición puntual de cada métrica.
  Map<String, Measurement> measurements = {};
  DateTime? missionStart;
  List<DailyPoint> _trendDays = [];
  DateTime? _trendsAt;

  // Solo modo demo: historial simulado y mediciones de hoy en memoria.
  List<DailyPoint> _demoDays = [];
  final List<Measurement> _demoToday = [];

  /// Entorno de misión elegido. Es una preferencia de esta sesión, no se guarda.
  MissionEnvironment environment = environments.first;
  void setEnvironment(MissionEnvironment value) {
    environment = value;
    _emit();
  }

  Telemetry? get latest => telemetry.isEmpty ? null : telemetry.last;

  int? get missionDay => missionStart == null
      ? null
      : DateTime.now().toUtc().difference(missionStart!).inDays + 1;

  /// Último valor de un indicador: telemetría continua, medición puntual
  /// (la más reciente gana) o registro de bienestar.
  double? valueOf(String id) {
    if (id == 'horas_sueno' || id == 'animo') {
      final value = wellbeing.isEmpty ? null : wellbeing.first[id];
      return (value as num?)?.toDouble();
    }
    final sensor = latest?[id];
    final manual = measurements[id];
    if (manual == null) return sensor;
    if (sensor == null || manual.time.isAfter(latest!.time)) {
      return manual.value;
    }
    return sensor;
  }

  HealthStatus statusOf(String id) => indicator(id).status(valueOf(id));

  /// Valor para mostrar; la presión arterial se muestra como sistólica/diastólica.
  String displayValue(String id) {
    final text = indicator(id).format(valueOf(id));
    final dia = id == 'presion_sistolica' ? valueOf('presion_diastolica') : null;
    return dia == null ? text : '$text/${dia.toStringAsFixed(0)}';
  }

  /// Estado para mostrar; la presión arterial toma el peor de sus dos valores.
  HealthStatus displayStatus(String id) => id == 'presion_sistolica'
      ? worstOf([statusOf(id), statusOf('presion_diastolica')])
      : statusOf(id);
  /// Síntomas marcados en la autoevaluación, por zona. Con backend se guardan
  /// en SQLite (tabla `autoevaluaciones`) y se recuperan al abrir la app; en
  /// modo demo viven solo en memoria.
  final Map<String, Set<String>> symptoms = {};

  /// Zonas cuya autoevaluación ya respondió el astronauta.
  final Set<String> checkedRegions = {};

  /// Las autoevaluaciones guardadas se cargan una sola vez por sesión: después
  /// manda lo que el astronauta toca, para que un sondeo no pise un cambio.
  bool _symptomsLoaded = false;

  void setSymptom(String regionId, String symptomId, bool present) {
    final set = symptoms.putIfAbsent(regionId, () => {});
    present ? set.add(symptomId) : set.remove(symptomId);
    checkedRegions.add(regionId);
    _emit();
    _saveSymptoms(regionId);
  }

  /// Confirma la autoevaluación sin síntomas.
  void confirmNoSymptoms(String regionId) {
    symptoms[regionId]?.clear();
    checkedRegions.add(regionId);
    _emit();
    _saveSymptoms(regionId);
  }

  Future<void> _saveSymptoms(String regionId) async {
    if (demo) return;
    try {
      await _api.request('/api/symptoms', {
        'zona': regionId,
        'sintomas': [...?symptoms[regionId]],
      });
    } catch (_) {
      if (_disposed) return;
      error = const T(
        'No se pudo guardar la autoevaluación. Comprueba el backend.',
        'The self-check could not be saved. Check the backend.',
      );
      _emit();
    }
  }

  /// Sin responder: sin datos. Con algún síntoma: vigilar. Sin síntomas: normal.
  HealthStatus symptomStatus(BodyRegion region) {
    if (region.symptoms.isEmpty || !checkedRegions.contains(region.id)) {
      return HealthStatus.unknown;
    }
    return (symptoms[region.id]?.isNotEmpty ?? false)
        ? HealthStatus.watch
        : HealthStatus.good;
  }

  HealthStatus regionStatus(BodyRegion region) => worstOf([
    ...region.indicatorIds.map(statusOf),
    symptomStatus(region),
  ]);

  /// Estado general: indicadores y autoevaluaciones de síntomas.
  HealthStatus get overallStatus => worstOf([
    ...indicators.map((i) => statusOf(i.id)),
    ...bodyRegions.map(symptomStatus),
  ]);

  HealthStatus get assistantStatus => worstOf([
    overallStatus,
    for (final alert in alerts.where((a) => a['atendida'] == 0))
      alert['nivel_severidad'] == 'CRITICAL' ? HealthStatus.critical : HealthStatus.watch,
  ]);

  /// Señal de salud de un peligro: peor estado de sus indicadores.
  HealthStatus hazardStatus(SpaceHazard hazard) => worstOf(
    indicators.where((i) => i.hazards.contains(hazard)).map((i) => statusOf(i.id)),
  );

  /// Señal de salud de un riesgo HRP: sus indicadores y la autoevaluación de
  /// sus zonas. Sin datos si la app no puede vigilarlo.
  HealthStatus hrpRiskStatus(HrpRisk risk) => worstOf([
    ...risk.indicatorIds.map(statusOf),
    ...risk.regionIds.map((id) => symptomStatus(bodyRegion(id))),
  ]);

  /// Si la app vigila el riesgo con indicadores o con una autoevaluación.
  static bool isMonitored(HrpRisk risk) =>
      risk.indicatorIds.isNotEmpty ||
      risk.regionIds.any((id) => bodyRegion(id).symptoms.isNotEmpty);

  /// Promedios diarios, del más antiguo al más reciente (incluye hoy).
  List<DailyPoint> get history => demo ? [..._demoDays, _demoTodayPoint()] : _trendDays;

  void start() {
    refresh();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => refresh());
  }

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  void _seedDemo() {
    final h = DemoHistory();
    _demoDays = h.days;
    wellbeing = h.wellbeing;
    measurements = {for (final m in h.measurements) m.metric: m};
    missionStart = h.days.first.date;
  }

  Future<void> refresh() async {
    if (_polling || busy || _disposed) return;
    _polling = true;
    _emit();
    try {
      if (demo) {
        _sample();
      } else {
        await _load();
      }
    } catch (_) {
      connected = false;
      error = const T(
        'Backend local no disponible. Inicia FastAPI en 127.0.0.1:8000 o usa el modo demo.',
        'Local backend unavailable. Start FastAPI on 127.0.0.1:8000 or use demo mode.',
      );
    } finally {
      _polling = false;
      _emit();
    }
  }

  Future<void> _load({bool trends = false}) async {
    final data = await _api.request('/api/state');
    // Los promedios diarios cambian despacio: se piden cada minuto o tras registrar algo.
    final now = DateTime.now();
    final loadTrends =
        trends ||
        _trendsAt == null ||
        now.difference(_trendsAt!) > const Duration(minutes: 1);
    final trendData = loadTrends ? await _api.request('/api/trends?days=30') : null;
    if (_disposed) return;
    telemetry = (data['telemetry'] as List)
        .map((e) => Telemetry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    alerts = (data['alerts'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    wellbeing = (data['wellbeing'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    measurements = {
      for (final e in data['measurements'] as List)
        (e as Map)['metrica'] as String: Measurement.fromJson(
          Map<String, dynamic>.from(e),
        ),
    };
    final start = data['mission_start'] as String?;
    missionStart = start == null ? null : DateTime.parse(start);
    if (trendData != null) {
      _trendDays = (trendData['days'] as List)
          .map((e) => DailyPoint.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      _trendsAt = now;
    }
    if (!_symptomsLoaded) {
      _symptomsLoaded = true;
      for (final check in data['symptom_checks'] as List? ?? const []) {
        final zone = (check as Map)['zona'] as String;
        // Se ignoran zonas o síntomas que esta versión de la app no conoce.
        final region = bodyRegions.where((r) => r.id == zone).firstOrNull;
        if (region == null || region.symptoms.isEmpty) continue;
        final known = {for (final s in region.symptoms) s.id};
        symptoms[zone] = {
          for (final id in check['sintomas'] as List)
            if (known.contains(id)) id as String,
        };
        checkedRegions.add(zone);
      }
    }
    pending = data['pending'] as int;
    cloudConfigured = data['cloud_configured'] as bool? ?? false;
    cloudSync = Map<String, dynamic>.from(data['cloud_sync'] as Map? ?? {});
    offline = data['offline'] as bool;
    connected = true;
    error = null;
  }

  /// Promedio de hoy en modo demo, calculado como lo hace /api/trends.
  DailyPoint _demoTodayPoint() {
    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    bool isToday(DateTime t) => !t.toUtc().isBefore(today);
    final values = <String, double>{};
    double? avg(Iterable<double> xs) =>
        xs.isEmpty ? null : xs.reduce((a, b) => a + b) / xs.length;
    final samples = telemetry.where((t) => isToday(t.time));
    for (final id in ['frecuencia_cardiaca', 'spo2', 'hrv', 'temperatura_corporal']) {
      final v = avg(samples.map((s) => s[id]!));
      if (v != null) values[id] = v;
    }
    for (final id in spotMetrics) {
      final v = avg(_demoToday.where((m) => m.metric == id).map((m) => m.value));
      if (v != null) values[id] = values[id] == null ? v : (values[id]! + v) / 2;
    }
    final todayWellbeing = wellbeing.where(
      (w) => isToday(DateTime.parse(w['timestamp_utc'] as String)),
    );
    for (final id in ['horas_sueno', 'animo']) {
      final v = avg(
        todayWellbeing
            .where((w) => w[id] != null)
            .map((w) => (w[id] as num).toDouble()),
      );
      if (v != null) values[id] = v;
    }
    return DailyPoint(today, values);
  }

  /// Alertas del modo demo con las mismas reglas que algorithms.py. El texto
  /// lo redacta la interfaz en el idioma actual (ver alertMessage).
  void _evaluate(Map<String, double?> values) {
    for (final ind in indicators) {
      final status = ind.status(values[ind.id]);
      if (status != HealthStatus.watch && status != HealthStatus.critical) {
        continue;
      }
      alerts.add({
        'id': DateTime.now().microsecondsSinceEpoch + alerts.length,
        'metrica_afectada': ind.id,
        'valor_detectado': values[ind.id],
        'nivel_severidad': status == HealthStatus.critical
            ? 'CRITICAL'
            : 'WARNING',
        'atendida': 0,
      });
      pending++;
    }
  }

  void _sample({bool anomaly = false}) {
    final sample = Telemetry(
      time: DateTime.now().toUtc(),
      bpm: anomaly ? 112 : 64 + _random.nextInt(9),
      spo2: anomaly ? 89 : 97 + _random.nextDouble() * 2,
      hrv: anomaly ? 24 : 45 + _random.nextDouble() * 10,
      temperature: 36.6 + _random.nextDouble() * .3,
    );
    telemetry.add(sample);
    if (telemetry.length > 360) telemetry.removeAt(0);
    pending++;
    _evaluate({
      for (final id in ['frecuencia_cardiaca', 'spo2', 'hrv', 'temperatura_corporal'])
        id: sample[id],
    });
  }

  Future<void> changeMode(bool value) async {
    if (busy || _polling) return;
    demo = value;
    telemetry = [];
    alerts = [];
    wellbeing = [];
    measurements = {};
    missionStart = null;
    _trendDays = [];
    _trendsAt = null;
    _demoDays = [];
    _demoToday.clear();
    symptoms.clear();
    checkedRegions.clear();
    _symptomsLoaded = false;
    pending = 0;
    cloudConfigured = false;
    cloudSync = {};
    offline = false;
    error = null;
    connected = false;
    if (demo) _seedDemo();
    await refresh();
  }

  Future<void> action(
    String path,
    Map<String, dynamic> body,
    void Function() local, {
    bool trends = false,
  }) async {
    if (busy || _polling) return;
    _busy = true;
    error = null;
    _emit();
    try {
      if (demo) {
        local();
      } else {
        await _api.request(path, body);
        await _load(trends: trends);
      }
    } catch (_) {
      error = const T(
        'No se pudo completar la operación. Comprueba el backend e inténtalo otra vez.',
        'The operation could not be completed. Check the backend and try again.',
      );
    } finally {
      _busy = false;
      _emit();
    }
  }

  /// Envía un lote a Horion Web sin esperar al intervalo del backend.
  Future<void> syncNow() => action('/api/sync/now', {}, () {});

  Future<void> toggleOffline(bool value) => action('/api/simulation/offline', {
    'enabled': value,
  }, () => offline = value);
  Future<void> anomaly() =>
      action('/api/simulation/anomaly', {}, () => _sample(anomaly: true));
  Future<void> acknowledge(int id) =>
      action('/api/alerts/$id/acknowledge', {}, () {
        alerts.firstWhere((a) => a['id'] == id)['atendida'] = 1;
      });
  Future<void> saveWellbeing(
    double sleep,
    int water,
    int energy, [
    int mood = 3,
  ]) => action(
    '/api/wellbeing',
    {'horas_sueno': sleep, 'agua_ml': water, 'energia': energy, 'animo': mood},
    () {
      wellbeing.insert(0, {
        'horas_sueno': sleep,
        'agua_ml': water,
        'energia': energy,
        'animo': mood,
        'timestamp_utc': DateTime.now().toUtc().toIso8601String(),
      });
      pending++;
    },
    trends: true,
  );

  /// Registra mediciones manuales, p. ej. {'glucosa': 92}. La presión arterial
  /// requiere sistólica y diastólica juntas; el backend lo valida.
  Future<void> addMeasurement(Map<String, num> values) => action(
    '/api/measurements',
    values,
    () {
      final now = DateTime.now().toUtc();
      for (final e in values.entries) {
        final m = Measurement(
          time: now,
          metric: e.key,
          value: e.value.toDouble(),
          manual: true,
        );
        measurements[e.key] = m;
        _demoToday.add(m);
        pending++;
      }
      _evaluate(values.map((k, v) => MapEntry(k, v.toDouble())));
    },
    trends: true,
  );

  /// Texto de una alerta en el idioma pedido, a partir de su métrica y nivel.
  /// Las alertas del backend guardan además un texto en español en SQLite.
  static String alertMessage(Map<String, dynamic> alert, AppLanguage language) {
    final metric = alert['metrica_afectada'] as String?;
    final ind = indicators.where((i) => i.id == metric).firstOrNull;
    if (ind == null) return (alert['recomendacion_entregada'] as String?) ?? '';
    final critical = alert['nivel_severidad'] == 'CRITICAL';
    final level = critical
        ? const T('en rango crítico', 'in the critical range')
        : const T('fuera del rango habitual', 'outside the usual range');
    return '${ind.name.of(language)} ${level.of(language)}. ${ind.actions.first.of(language)}';
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _api.dispose();
    super.dispose();
  }
}
