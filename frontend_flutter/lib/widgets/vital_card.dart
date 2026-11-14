import 'package:material_ui/material_ui.dart';

import '../l10n/language.dart';
import 'telemetry_motion.dart';
import '../models/health_knowledge.dart';

class VitalCard extends StatelessWidget {
  const VitalCard({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    this.color = const Color(0xFF38BDF8),
    this.status = HealthStatus.unknown,
    this.onTap,
    this.metric = '',
  });
  final String label, value, unit;
  final String metric;
  final IconData icon;
  final Color color;
  final HealthStatus status;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 400),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: status.color.withValues(alpha: .6), width: 1.5),
      boxShadow: status == HealthStatus.critical
          ? [
              BoxShadow(
                color: status.color.withValues(alpha: .35),
                blurRadius: 16,
              ),
            ]
          : null,
    ),
    child: Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  TelemetryMotion(
                    metric: metric,
                    value: double.tryParse(value),
                    status: status,
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(label)),
                  Tooltip(
                    message: context.t(status.label),
                    child: Icon(status.icon, color: status.color, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Consolas',
                  color: color,
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      unit,
                      style: const TextStyle(color: Color(0xFFA9BDCA)),
                    ),
                  ),
                  Text(
                    context.t(status.label).toUpperCase(),
                    style: TextStyle(
                      color: status.color,
                      fontSize: 12,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
