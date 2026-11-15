import 'package:material_ui/material_ui.dart';

import '../l10n/language.dart';
import '../models/health_knowledge.dart';
import '../models/telemetry.dart';
import '../services/edge_controller.dart';
import '../widgets/indicator_detail.dart';
import '../widgets/trend_chart.dart';
import '../widgets/viewport_board.dart';
import '../widgets/vital_icon.dart';

/// Comparación de un indicador con la línea base personal del astronauta.
class BaselineComparison {
  BaselineComparison._(
    this.baseline,
    this.recent,
    this.daysOutOfRange,
    this.daysWithData,
  );

  /// Línea base: promedio de los 3 primeros días de misión con datos.
  /// Reciente: promedio de los últimos 3 días con datos.
  /// Devuelve null si hay menos de 4 días (no habría con qué comparar).
  static BaselineComparison? of(
    HealthIndicator ind,
    List<DailyPoint> all,
    List<DailyPoint> window,
  ) {
    final series = [for (final d in all) ?d.values[ind.id]];
    if (series.length < 4) return null;
    double mean(List<double> xs) => xs.reduce((a, b) => a + b) / xs.length;
    final inWindow = [for (final d in window) ?d.values[ind.id]];
    return BaselineComparison._(
      mean(series.take(3).toList()),
      mean(series.skip(series.length - 3).toList()),
      inWindow.where((v) => ind.status(v) != HealthStatus.good).length,
      inWindow.length,
    );
  }

  final double baseline, recent;
  final int daysOutOfRange, daysWithData;
  double get change => baseline == 0 ? 0 : (recent - baseline) / baseline;
}

class TrendsScreen extends StatefulWidget {
  const TrendsScreen({super.key, required this.controller});
  final EdgeController controller;
  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  int days = 14;
  String selected = 'hrv';

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final all = c.history;
    final window = all.length > days ? all.sublist(all.length - days) : all;
    final start = c.missionStart;
    String label(DateTime d) {
      if (start == null) return '${d.day}/${d.month}';
      final s = DateTime.utc(start.year, start.month, start.day);
      return '${context.tr('D', 'D')}${d.difference(s).inDays + 1}';
    }

    final ind = indicator(selected);
    final cmp = BaselineComparison.of(ind, all, window);
    final missionDay = c.missionDay == null
        ? ''
        : context.tr(
            ' · Día ${c.missionDay} de misión',
            ' · Mission day ${c.missionDay}',
          );
    final tall = MediaQuery.sizeOf(context).height >= 700;
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('Tendencias', 'Trends'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              SizedBox(
                width: 260,
                child: SegmentedButton<int>(
                  segments: [
                    for (final n in [7, 14, 30])
                      ButtonSegment(
                        value: n,
                        label: Text(context.tr('$n días', '$n days')),
                      ),
                  ],
                  selected: {days},
                  onSelectionChanged: (v) => setState(() => days = v.first),
                ),
              ),
            ],
          ),
          if (tall)
            Text(
              context.tr(
                'Promedio diario frente a tus 3 primeros días de misión$missionDay.',
                'Daily average against your first 3 mission days$missionDay.',
              ),
              style: const TextStyle(color: Colors.white60),
            ),
          const SizedBox(height: 10),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Panel 1: un indicador por tarjeta. Tocar una cambia el panel 2.
                SizedBox(
                  width: (constraints.maxWidth * .34).clamp(250.0, 380.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BoardGroupHeader(
                        number: 1,
                        title: context.tr(
                          'Resumen frente a tu línea base',
                          'Summary against your baseline',
                        ),
                        color: const Color(0xFF38BDF8),
                      ),
                      if (tall)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            context.tr(
                              'Toca un indicador para ver su detalle a la derecha.',
                              'Tap an indicator to see its detail on the right.',
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white60,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ViewportBoard(
                          minColumnWidth: 200,
                          maxColumns: 1,
                          children: [
                            for (final i in indicators)
                              _IndicatorCard(
                                key: ValueKey('trend-${i.id}'),
                                indicator: i,
                                comparison: BaselineComparison.of(
                                  i,
                                  all,
                                  window,
                                ),
                                selected: i.id == selected,
                                onTap: () => setState(() => selected = i.id),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Panel 2: todo lo del indicador elegido, siempre en el mismo orden.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BoardGroupHeader(
                        number: 2,
                        title:
                            '${context.t(ind.name)} · ${context.t(ind.unit)}',
                        color: ind.color,
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ViewportBoard(
                          // Al cambiar de indicador vuelve a la primera página.
                          key: ValueKey('trend-detail-$selected'),
                          minColumnWidth: 340,
                          readingOrder: true,
                          children: [
                            ..._conclusion(context, ind, cmp, split: !tall),
                            BoardSection(
                              title: context.tr(
                                'Evolución · últimos $days días',
                                'Evolution · last $days days',
                              ),
                              children: [
                                TrendChart(
                                  indicator: ind,
                                  labels: [
                                    for (final d in window) label(d.date),
                                  ],
                                  values: [
                                    for (final d in window) d.values[ind.id],
                                  ],
                                  baseline: cmp?.baseline,
                                  height: tall ? 150 : 90,
                                ),
                                if (tall) ...[
                                  const SizedBox(height: 10),
                                  const _ChartLegend(),
                                ],
                              ],
                            ),
                            // En pantallas bajas la leyenda va aparte para que
                            // la gráfica quepa entera.
                            if (!tall)
                              const BoardSection(children: [_ChartLegend()]),
                            BoardSection(
                              title: context.tr(
                                'Por qué cambia en el espacio',
                                'Why it changes in space',
                              ),
                              children: [Text(context.t(ind.spaceEffect))],
                            ),
                            if (tall)
                              BoardSection(
                                title: context.tr(
                                  'Qué puedes hacer',
                                  'What you can do',
                                ),
                                children: [
                                  for (final a in ind.actions)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 2,
                                      ),
                                      child: Text('• ${context.t(a)}'),
                                    ),
                                ],
                              )
                            else
                              // Pantallas bajas: un consejo por tarjeta.
                              for (final (index, a) in ind.actions.indexed)
                                BoardSection(
                                  title: index == 0
                                      ? context.tr(
                                          'Qué puedes hacer',
                                          'What you can do',
                                        )
                                      : null,
                                  children: [Text('• ${context.t(a)}')],
                                ),
                            BoardSection(
                              children: [
                                TextButton.icon(
                                  onPressed: () => showIndicatorDetail(
                                    context,
                                    ind,
                                    ind.format(c.valueOf(ind.id)),
                                    c.statusOf(ind.id),
                                  ),
                                  icon: const Icon(
                                    Icons.info_outline,
                                    size: 18,
                                  ),
                                  label: Text(
                                    context.tr(
                                      '¿Qué significa? Ver la ficha completa',
                                      'What does it mean? See the full sheet',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Lo primero del detalle: la conclusión en una frase. Con [split] (pantallas
  /// bajas) el aviso y la frase van en dos tarjetas seguidas para que quepan.
  List<Widget> _conclusion(
    BuildContext context,
    HealthIndicator ind,
    BaselineComparison? cmp, {
    bool split = false,
  }) {
    if (cmp == null) {
      return [
        BoardSection(
          children: [
            Text(
              context.tr(
                'Aún no hay suficientes días para calcular tu línea base. Registra este indicador a diario.',
                'There are not enough days yet to calculate your baseline. Log this indicator daily.',
              ),
            ),
          ],
        ),
      ];
    }
    final notable = cmp.change.abs() > ind.baselineTolerance;
    final pct = (cmp.change * 100).abs().toStringAsFixed(0);
    final banner = StatusBanner(
      status: notable ? HealthStatus.watch : HealthStatus.good,
      text: notable
          ? context.tr(
              'Cambio respecto a tu línea base',
              'Change from your baseline',
            )
          : context.tr('Sin cambios relevantes', 'No relevant changes'),
    );
    final explanation = [
      Text(
        context.tr(
          'Tus últimos 3 días están un $pct % ${cmp.change >= 0 ? 'más alto' : 'más bajo'} que tu línea base (${ind.format(cmp.baseline)} ${context.t(ind.unit)}).',
          'Your last 3 days are $pct % ${cmp.change >= 0 ? 'higher' : 'lower'} than your baseline (${ind.format(cmp.baseline)} ${context.t(ind.unit)}).',
        ),
      ),
      if (cmp.daysOutOfRange > 0)
        Text(
          context.tr(
            '${cmp.daysOutOfRange} de ${cmp.daysWithData} días fuera del rango normal en este periodo.',
            '${cmp.daysOutOfRange} of ${cmp.daysWithData} days outside the normal range in this period.',
          ),
        ),
    ];
    return split
        ? [
            BoardSection(children: [banner]),
            BoardSection(children: explanation),
          ]
        : [
            BoardSection(
              children: [banner, const SizedBox(height: 8), ...explanation],
            ),
          ];
  }
}

/// Tarjeta de un indicador en el resumen: icono de su color, base → ahora, % de
/// cambio y estado. La seleccionada se resalta y apunta al panel de detalle.
class _IndicatorCard extends StatelessWidget {
  const _IndicatorCard({
    super.key,
    required this.indicator,
    required this.comparison,
    required this.selected,
    required this.onTap,
  });
  final HealthIndicator indicator;
  final BaselineComparison? comparison;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final i = indicator, cmp = comparison;
    final notable = cmp != null && cmp.change.abs() > i.baselineTolerance;
    final status = cmp == null ? HealthStatus.unknown : i.status(cmp.recent);
    final unit = context.t(i.unit);
    final glyph = glyphFor(i.id);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: selected
            ? Color.alphaBlend(
                i.color.withValues(alpha: .12),
                const Color(0xFF10232E),
              )
            : const Color(0xFF10232E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? i.color : const Color(0xFF1C3442),
          width: selected ? 2 : 1,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(selected ? 9 : 10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i.color.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: i.color.withValues(alpha: .4)),
                  ),
                  child: glyph == null
                      ? Icon(i.icon, color: i.color, size: 22)
                      : VitalIcon(glyph, color: i.color, size: 24),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t(i.name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        cmp == null
                            ? context.tr(
                                'Se necesitan al menos 4 días con datos',
                                'At least 4 days of data are needed',
                              )
                            : context.tr(
                                'Base ${i.format(cmp.baseline)} → ahora ${i.format(cmp.recent)} $unit',
                                'Baseline ${i.format(cmp.baseline)} → now ${i.format(cmp.recent)} $unit',
                              ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
                if (cmp != null) ...[
                  const SizedBox(width: 6),
                  Icon(
                    cmp.change > 0.005
                        ? Icons.trending_up
                        : cmp.change < -0.005
                        ? Icons.trending_down
                        : Icons.trending_flat,
                    size: 18,
                    color: notable ? HealthStatus.watch.color : Colors.white54,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${cmp.change >= 0 ? '+' : ''}${(cmp.change * 100).toStringAsFixed(0)} %',
                    style: TextStyle(
                      fontFamily: 'Consolas',
                      fontSize: 13,
                      color: notable ? HealthStatus.watch.color : null,
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Icon(Icons.circle, size: 9, color: status.color),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: selected ? i.color : Colors.transparent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend();
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 18,
    runSpacing: 6,
    children: [
      _item(
        Container(
          width: 16,
          height: 10,
          color: HealthStatus.good.color.withValues(alpha: .25),
        ),
        context.tr('Rango normal', 'Normal range'),
      ),
      _item(
        const SizedBox(
          width: 16,
          child: Divider(color: Colors.white70, thickness: 1.5),
        ),
        context.tr('Tu línea base', 'Your baseline'),
      ),
      _item(
        Icon(Icons.circle, size: 10, color: HealthStatus.good.color),
        context.tr('Día normal', 'Normal day'),
      ),
      _item(
        Icon(Icons.circle, size: 10, color: HealthStatus.watch.color),
        context.tr('Día a vigilar', 'Watch day'),
      ),
      _item(
        Icon(Icons.circle, size: 10, color: HealthStatus.critical.color),
        context.tr('Día crítico', 'Critical day'),
      ),
    ],
  );

  Widget _item(Widget mark, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      mark,
      const SizedBox(width: 6),
      Text(text, style: const TextStyle(fontSize: 12, color: Colors.white70)),
    ],
  );
}
