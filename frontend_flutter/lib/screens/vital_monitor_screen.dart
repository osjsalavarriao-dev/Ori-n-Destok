import 'package:material_ui/material_ui.dart';

import '../l10n/language.dart';
import '../models/health_knowledge.dart';
import '../services/edge_controller.dart';
import '../widgets/indicator_detail.dart';
import '../widgets/measurement_dialog.dart';
import '../widgets/vital_card.dart';
import '../widgets/orbin_avatar.dart';
import '../widgets/telemetry_motion.dart';
import '../widgets/telemetry_chart.dart';

class VitalMonitorScreen extends StatelessWidget {
  const VitalMonitorScreen({
    super.key,
    required this.controller,
    required this.openOrbi,
    required this.openBodyMap,
  });
  final EdgeController controller;
  final VoidCallback openOrbi, openBodyMap;

  // Indicadores mostrados como tarjeta; la diastólica va junto a la sistólica.
  static const _cards = [
    'frecuencia_cardiaca',
    'spo2',
    'hrv',
    'temperatura_corporal',
    'presion_sistolica',
    'glucosa',
    'horas_sueno',
    'animo',
  ];

  Widget _card(BuildContext context, String id) {
    final ind = indicator(id);
    final value = controller.displayValue(id);
    final status = controller.displayStatus(id);
    return VitalCard(
      metric: id,
      label: context.t(ind.name),
      value: value,
      unit: context.t(ind.unit),
      icon: ind.icon,
      color: ind.color,
      status: status,
      onTap: () => showIndicatorDetail(context, ind, value, status),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = controller.latest;
    final active = controller.alerts.where((a) => a['atendida'] == 0).toList();
    final overall = controller.overallStatus;
    return ListView(
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Monitor vital', 'Vital monitor'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr(
                    'Tu estado a bordo, de un vistazo. Toca un indicador para saber qué mide y qué hacer.',
                    'Check your status first. Then explore your indicators or record how you feel.',
                  ),
                  style: const TextStyle(color: Color(0xFFA9BDCA)),
                ),
              ],
            ),
            FilledButton.icon(
              onPressed:
                  controller.busy || (!controller.demo && !controller.connected)
                  ? null
                  : () async {
                      final saved = await showMeasurementDialog(
                        context,
                        controller,
                      );
                      if (saved == true && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              context.tr(
                                'Medición registrada.',
                                'Measurement saved.',
                              ),
                            ),
                          ),
                        );
                      }
                    },
              icon: const Icon(Icons.add),
              label: Text(context.tr('Registrar medición', 'Log measurement')),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: InkWell(
            onTap: openBodyMap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  OrbinAvatar(size: 64, status: overall, onTap: openOrbi),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${context.tr('Estado general', 'Overall status')}: ${context.t(overall.label)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: overall.color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(context.t(overall.escalation)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    context.tr('Ver mapa corporal  ›', 'View body map  ›'),
                    style: const TextStyle(color: Color(0xFF38BDF8)),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        for (final alert in active) _alertCard(context, alert),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth > 850
                ? 4
                : constraints.maxWidth > 420
                ? 2
                : 1;
            final width = (constraints.maxWidth - (columns - 1) * 14) / columns;
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final id in _cards)
                  SizedBox(width: width, child: _card(context, id)),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        Card(
          child: ExpansionTile(
            title: Text(
              context.tr('Ver historial de pulso', 'View pulse history'),
            ),
            leading: const Icon(Icons.show_chart),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(
                        'Frecuencia cardíaca · BPM',
                        'Heart rate · BPM',
                      ),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr(
                        '${controller.telemetry.length} lecturas · hasta 30 minutos · escala automática',
                        '${controller.telemetry.length} readings · up to 30 minutes · auto scale',
                      ),
                      style: const TextStyle(color: Color(0xFFA9BDCA)),
                    ),
                    const SizedBox(height: 12),
                    if (t != null) ...[
                      RhythmTrace(bpm: t.bpm, color: overall.color),
                      Text(
                        context.tr(
                          'Ritmo ilustrativo / no es un ECG medido',
                          'Illustrative rhythm / not a measured ECG',
                        ),
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TelemetryChart(samples: controller.telemetry),
                    if (t != null)
                      Text(
                        '${context.tr('Última lectura', 'Last reading')}: ${t.time.toLocal().toString().substring(11, 19)}',
                        style: const TextStyle(color: Color(0xFFA9BDCA)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 24,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OrbinAvatar(size: 64, status: overall, onTap: openOrbi),
                Text(
                  context.tr(
                    'Orbi, tu compañero a bordo',
                    'Orbi, your companion on board',
                  ),
                  style: const TextStyle(fontSize: 18),
                ),
                FilledButton(
                  onPressed: openOrbi,
                  child: Text(context.tr('Abrir Orbi', 'Open Orbi')),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _alertCard(BuildContext context, Map<String, dynamic> alert) {
    final critical = alert['nivel_severidad'] == 'CRITICAL';
    final status = critical ? HealthStatus.critical : HealthStatus.watch;
    final metric = alert['metrica_afectada'] as String?;
    final ind = indicators.where((i) => i.id == metric).firstOrNull;
    final env = controller.environment;
    final title = [
      critical
          ? context.tr('ALERTA CRÍTICA', 'CRITICAL ALERT')
          : context.tr('VIGILAR', 'WATCH'),
      if (ind != null) context.t(ind.name).toUpperCase(),
      context.tr('SIMULACIÓN', 'SIMULATION'),
    ].join(' · ');
    return Card(
      color: critical ? const Color(0xFF40222B) : const Color(0xFF3A3420),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(status.icon, color: status.color, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: TextStyle(color: status.color)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(EdgeController.alertMessage(alert, context.lang)),
            const SizedBox(height: 6),
            Text(
              context.t(status.escalation),
              style: const TextStyle(color: Color(0xFFA9BDCA), fontSize: 13),
            ),
            if (critical && env.escalationNote != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${context.t(env.name)}: ${context.t(env.escalationNote!)}',
                  style: const TextStyle(
                    color: Color(0xFFA9BDCA),
                    fontSize: 13,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: controller.busy
                  ? null
                  : () => controller.acknowledge(alert['id'] as int),
              child: Text(
                context.tr('Marcar como atendida', 'Mark as handled'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
