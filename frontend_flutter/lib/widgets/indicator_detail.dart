import 'package:material_ui/material_ui.dart';

import '../l10n/language.dart';
import '../models/health_knowledge.dart';
import 'viewport_board.dart';

/// Ficha educativa de un indicador: qué es, cómo medirlo, efecto del espacio
/// y qué hacer según su estado actual.
Future<void> showIndicatorDetail(
  BuildContext context,
  HealthIndicator ind,
  String value,
  HealthStatus status,
) => showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: Row(
      children: [
        Icon(ind.icon, color: ind.color),
        const SizedBox(width: 10),
        Expanded(child: Text(context.t(ind.name))),
      ],
    ),
    content: SizedBox(
      width: 1000,
      height: MediaQuery.sizeOf(context).height * .65,
      child: IndicatorDetailBody(ind: ind, value: value, status: status),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.tr('Cerrar', 'Close')),
      ),
    ],
  ),
);

class IndicatorDetailBody extends StatelessWidget {
  const IndicatorDetailBody({
    super.key,
    required this.ind,
    required this.value,
    required this.status,
  });
  final HealthIndicator ind;
  final String value;
  final HealthStatus status;

  @override
  Widget build(BuildContext context) => ViewportBoard(
    children: [
      StatusBanner(
        status: status,
        text: '$value ${context.t(ind.unit)} · ${context.t(status.label)}',
      ),
      const SizedBox(height: 6),
      Text(
        '${context.tr('Rango de referencia', 'Reference range')}: ${context.t(ind.normalRange)}',
        style: const TextStyle(color: Colors.white60, fontSize: 12),
      ),
      _section(
        context.tr('¿Qué mide?', 'What does it measure?'),
        context.t(ind.what),
      ),
      _section(
        context.tr('¿Cómo medirlo a bordo?', 'How to measure it on board?'),
        context.t(ind.howToMeasure),
      ),
      _section(
        context.tr('¿Cómo le afecta el espacio?', 'How does space affect it?'),
        context.t(ind.spaceEffect),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [for (final r in ind.hazards) HazardChip(hazard: r)],
      ),
      if (status != HealthStatus.good) ...[
        const SizedBox(height: 14),
        Text(
          context.tr('Qué puedes hacer', 'What you can do'),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        for (final a in ind.actions)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  '),
                Expanded(child: Text(context.t(a))),
              ],
            ),
          ),
      ],
    ],
  );

  Widget _section(String title, String body) => BoardSection(
    title: title,
    children: [
      Text(body, style: const TextStyle(color: Colors.white70, height: 1.4)),
    ],
  );
}

/// Recuadro de estado con el texto de qué hacer (escalado) en el idioma actual.
class StatusBanner extends StatelessWidget {
  const StatusBanner({super.key, required this.status, required this.text});
  final HealthStatus status;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: status.color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: status.color.withValues(alpha: .5)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(status.icon, color: status.color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: status.color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          context.t(status.escalation),
          style: const TextStyle(fontSize: 13),
        ),
      ],
    ),
  );
}

/// Chip de uno de los 5 peligros del vuelo espacial (NASA HRP).
class HazardChip extends StatelessWidget {
  const HazardChip({super.key, required this.hazard});
  final SpaceHazard hazard;
  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(hazard.icon, size: 16),
    label: Text(context.t(hazard.label), style: const TextStyle(fontSize: 12)),
    visualDensity: VisualDensity.compact,
  );
}
