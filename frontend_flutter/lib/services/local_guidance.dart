import '../l10n/language.dart';
import '../models/health_knowledge.dart';
import 'edge_controller.dart';

enum LocalRequest { status, exercise, food, monitoring }

/// Deterministic, offline guidance. No free-form prompts or network requests.
class LocalGuidance {
  static T label(LocalRequest request) => switch (request) {
    LocalRequest.status => const T(
      'Ver mis signos vitales',
      'Show my vital signs',
    ),
    LocalRequest.exercise => const T(
      'Rutina de ejercicios',
      'Exercise routine',
    ),
    LocalRequest.food => const T('Comida e hidratacion', 'Food and hydration'),
    LocalRequest.monitoring => const T(
      'Estado del monitoreo',
      'Monitoring status',
    ),
  };
  static String answer(
    EdgeController c,
    LocalRequest request,
    AppLanguage language, {
    DateTime? now,
  }) {
    String tr(String es, String en) => T(es, en).of(language);
    final latest = c.latest;
    final stale =
        latest == null ||
        (now ?? DateTime.now()).toUtc().difference(latest.time.toUtc()) >
            const Duration(seconds: 30);
    final critical =
        c.overallStatus == HealthStatus.critical ||
        c.alerts.any(
          (a) => a['atendida'] == 0 && a['nivel_severidad'] == 'CRITICAL',
        );
    final prefix = [
      tr('Consulta local', 'Local guidance'),
      if (c.demo) tr('Datos simulados', 'Simulated data'),
      latest == null
          ? tr('Sin lecturas', 'No readings')
          : '${tr('Ultima lectura', 'Last reading')}: ${latest.time.toLocal()}',
      if (stale)
        tr(
          'Datos ausentes o antiguos; actualiza las mediciones antes de decidir.',
          'Missing or old data; update measurements before making decisions.',
        ),
    ];
    if (critical) {
      return [
        ...prefix,
        HealthStatus.critical.escalation.of(language),
        tr(
          'Alerta prioritaria. Las sugerencias de ejercicio y comida quedan suspendidas.',
          'Priority alert. Exercise and food suggestions are suspended.',
        ),
      ].join('\n\n');
    }
    if (stale && request != LocalRequest.monitoring) return prefix.join('\n\n');
    final details = switch (request) {
      LocalRequest.status => [
        '${tr('Estado', 'Status')}: ${c.overallStatus.label.of(language)}',
        for (final ind in indicators)
          '${ind.name.of(language)}: ${c.displayValue(ind.id)} ${ind.unit.of(language)} - ${c.displayStatus(ind.id).label.of(language)}',
        c.overallStatus.escalation.of(language),
      ].join('\n'),
      LocalRequest.exercise =>
        c.overallStatus == HealthStatus.watch
            ? HealthStatus.watch.escalation.of(language)
            : tr(
                'Consulta la rutina aprobada para tu mision. No hay un plan de ejercicios cargado: no se pueden calcular intensidad, cargas o duracion personalizadas.',
                'Consult your approved mission routine. No exercise plan is loaded: personalized intensity, loads or duration cannot be calculated.',
              ),
      LocalRequest.food => tr(
        'Consulta el menu y la pauta de hidratacion aprobados para tu mision. No hay un plan nutricional cargado. Registra agua y bienestar para mantener el seguimiento.',
        'Consult your approved mission menu and hydration plan. No nutrition plan is loaded. Log water and wellbeing to keep track.',
      ),
      LocalRequest.monitoring =>
        '${c.demo
            ? tr('Simulador activo', 'Simulator active')
            : c.connected
            ? tr('Backend local conectado', 'Local backend connected')
            : tr('Backend no disponible; se muestran los ultimos datos de esta sesion.', 'Backend unavailable; showing the last data from this session.')}\n${tr('Entorno', 'Environment')}: ${c.environment.name.of(language)}',
    };
    return [...prefix, details].join('\n\n');
  }
}
