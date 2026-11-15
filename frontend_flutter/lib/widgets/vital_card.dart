import 'package:material_ui/material_ui.dart';

import '../l10n/language.dart';
import 'vital_icon.dart';
import 'vital_motion.dart';
import '../models/health_knowledge.dart';

/// Tarjeta de un signo vital con estética HUD: icono animado (qué es y cómo
/// está), valor monoespaciado que se desliza al cambiar y, para los sensores,
/// una mini gráfica en vivo de las últimas lecturas.
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
    this.history = const [],
  });
  final String label, value, unit;
  final String metric;

  /// Icono de respaldo para un indicador sin dibujo propio en [VitalGlyph].
  final IconData icon;

  /// Color propio del signo vital: icono, recuadro y mini gráfica. El estado
  /// (vigilar, crítico) se ve en el borde, el brillo, el movimiento y la etiqueta.
  final Color color;
  final HealthStatus status;
  final VoidCallback? onTap;

  /// Últimas lecturas del sensor, de la más antigua a la más reciente. Vacía
  /// para los indicadores que se registran a mano.
  final List<double> history;

  @override
  Widget build(BuildContext context) {
    final glyph = glyphFor(metric);
    final colors = badgeColors(status);
    final alarm =
        status == HealthStatus.watch || status == HealthStatus.critical;
    // Marco de la tarjeta: color del estado si hay alerta; si no, el propio.
    final accent = alarm
        ? colors.glow
        : status == HealthStatus.unknown
        ? const Color(0xFF64748B)
        : color;
    final statusColor = switch (status) {
      HealthStatus.good => const Color(0xFF4ADE80),
      HealthStatus.unknown => const Color(0xFF64748B),
      _ => colors.glow,
    };
    final badge = glyph == null
        ? Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 34, color: color),
          )
        : LiveVitalBadge(
            glyph: glyph,
            metric: metric,
            value: double.tryParse(value),
            status: status,
            tint: color,
          );
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        // Fondo oscuro profundo con un leve brillo superior (vidrio).
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(
              accent.withValues(alpha: .07),
              const Color(0xFF10232E),
            ),
            const Color(0xFF0B1A23),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accent.withValues(
            alpha: switch (status) {
              HealthStatus.critical => .9,
              HealthStatus.watch => .7,
              _ => .28,
            },
          ),
          width: status == HealthStatus.critical ? 1.5 : 1,
        ),
        boxShadow: status == HealthStatus.critical
            ? [BoxShadow(color: accent.withValues(alpha: .3), blurRadius: 18)]
            : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    badge,
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: AnimatedVitalValue(
                        value,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Consolas',
                          color: Color(0xFFE6EEF5),
                          height: 1.1,
                        ),
                      ),
                    ),
                    if (unit.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        unit,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF9FB3C3),
                        ),
                      ),
                    ],
                  ],
                ),
                if (history.length >= 2) ...[
                  const SizedBox(height: 8),
                  VitalSparkline(values: history, color: color),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withValues(alpha: .6),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.t(status.label),
                      style: TextStyle(
                        fontSize: 14,
                        color: switch (status) {
                          HealthStatus.good => const Color(0xFF86EFAC),
                          HealthStatus.unknown => const Color(0xFF9FB3C3),
                          _ => colors.foreground,
                        },
                        fontWeight: FontWeight.w500,
                        letterSpacing: .4,
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
}
