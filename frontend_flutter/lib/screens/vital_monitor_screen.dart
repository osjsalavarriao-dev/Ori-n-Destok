import 'package:material_ui/material_ui.dart';

import '../l10n/language.dart';
import '../models/health_knowledge.dart';
import '../services/edge_controller.dart';
import '../widgets/indicator_detail.dart';
import '../widgets/measurement_dialog.dart';
import '../widgets/vital_card.dart';
import '../widgets/viewport_board.dart';
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
    // Últimas 40 lecturas del sensor (~3 min); vacío para los registros manuales.
    final samples = controller.telemetry;
    final history = [
      for (final t in samples.skip(
        samples.length > 40 ? samples.length - 40 : 0,
      ))
        ?t[id],
    ];
    return VitalCard(
      metric: id,
      history: history,
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
    return ScreenBoard(
      key: ValueKey(active.length),
      title: context.tr('Monitor vital', 'Vital monitor'),
      controls: Row(
        children: [
          Expanded(
            child: Text(
              context.tr(
                'Tu estado a bordo, de un vistazo.',
                'Your health on board, at a glance.',
              ),
              style: const TextStyle(color: Colors.white60),
            ),
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
      minColumnWidth: 290,
      maxColumns: 4,
      children: [
        BoardSection(
          children: [
            Row(
              children: [
                OrbinAvatar(size: 48, status: overall, onTap: openOrbi),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${context.tr('Estado general', 'Overall status')}: ${context.t(overall.label)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: overall.color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(context.t(overall.escalation)),
            TextButton(
              onPressed: openBodyMap,
              child: Text(context.tr('Ver mapa corporal', 'View body map')),
            ),
          ],
        ),
        for (final alert in active) _alertCard(context, alert),
        if (active.any((a) => a['nivel_severidad'] == 'CRITICAL') &&
            controller.environment.escalationNote != null)
          BoardSection(
            children: [
              Text(
                '${context.t(controller.environment.name)}: ${context.t(controller.environment.escalationNote!)}',
              ),
            ],
          ),
        for (final id in _cards) _card(context, id),
        BoardSection(
          title: context.tr('Ver historial de pulso', 'View pulse history'),
          children: [
            Text(
              context.tr(
                '${controller.telemetry.length} lecturas · hasta 30 minutos · escala automática',
                '${controller.telemetry.length} readings · up to 30 minutes · auto scale',
              ),
              style: const TextStyle(fontSize: 12, color: Colors.white60),
            ),
            TelemetryChart(samples: controller.telemetry, height: 120),
            if (t != null)
              Text(
                '${context.tr('Última lectura', 'Last reading')}: ${t.time.toLocal().toString().substring(11, 19)}',
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        if (t != null)
          BoardSection(
            children: [
              RhythmTrace(bpm: t.bpm, color: overall.color),
              Text(
                context.tr(
                  'Ritmo ilustrativo / no es un ECG medido',
                  'Illustrative rhythm / not a measured ECG',
                ),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        BoardSection(
          children: [
            Row(
              children: [
                OrbinAvatar(size: 48, status: overall, onTap: openOrbi),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.tr(
                      'Orbi, tu compañero a bordo',
                      'Orbi, your companion on board',
                    ),
                  ),
                ),
              ],
            ),
            FilledButton(
              onPressed: openOrbi,
              child: Text(context.tr('Abrir Orbi', 'Open Orbi')),
            ),
          ],
        ),
      ],
    );
  }

  Widget _alertCard(BuildContext context, Map<String, dynamic> alert) {
    final critical = alert['nivel_severidad'] == 'CRITICAL';
    final status = critical ? HealthStatus.critical : HealthStatus.watch;
    final metric = alert['metrica_afectada'] as String?;
    final ind = indicators.where((i) => i.id == metric).firstOrNull;
    final title = [
      critical
          ? context.tr('ALERTA CRÍTICA', 'CRITICAL ALERT')
          : context.tr('VIGILAR', 'WATCH'),
      if (ind != null) context.t(ind.name).toUpperCase(),
      context.tr('SIMULACIÓN', 'SIMULATION'),
    ].join(' · ');
    return Card(
      margin: EdgeInsets.zero,
      color: critical ? const Color(0xFF40222B) : const Color(0xFF3A3420),
      child: Padding(
        padding: const EdgeInsets.all(10),
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
