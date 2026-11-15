import 'package:material_ui/material_ui.dart';

import '../l10n/language.dart';
import '../models/health_knowledge.dart';
import '../models/telemetry.dart';
import '../services/edge_controller.dart';
import '../widgets/indicator_detail.dart';
import '../widgets/trend_chart.dart';
import '../widgets/viewport_board.dart';

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
    return ScreenBoard(
      title: context.tr('Tendencias', 'Trends'),
      subtitle: context.tr(
        'Promedio diario frente a tus 3 primeros días de misión$missionDay.',
        'Daily average against your first 3 mission days$missionDay.',
      ),
      controls: Row(
        children: [
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
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButton<String>(
              isExpanded: true,
              value: selected,
              items: [
                for (final i in indicators)
                  DropdownMenuItem(value: i.id, child: Text(context.t(i.name))),
              ],
              onChanged: (id) {
                if (id != null) setState(() => selected = id);
              },
            ),
          ),
        ],
      ),
      minColumnWidth: 380,
      children: [
        BoardSection(
          title: '${context.t(ind.name)} · ${context.t(ind.unit)}',
          children: [
            TrendChart(
              indicator: ind,
              labels: [for (final d in window) label(d.date)],
              values: [for (final d in window) d.values[ind.id]],
              baseline: cmp?.baseline,
              height: MediaQuery.sizeOf(context).height < 700 ? 90 : 150,
            ),
          ],
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
              icon: const Icon(Icons.info_outline, size: 18),
              label: Text(context.tr('¿Qué significa?', 'What does it mean?')),
            ),
          ],
        ),
        const BoardSection(children: [_ChartLegend()]),
        ..._interpretationSections(context, ind, cmp),
        for (var index = 0; index < indicators.length; index++)
          BoardSection(
            title: index == 0
                ? context.tr(
                    'Resumen frente a tu línea base',
                    'Summary against your baseline',
                  )
                : null,
            children: [
              _summaryRow(
                context,
                indicators[index],
                BaselineComparison.of(indicators[index], all, window),
              ),
            ],
          ),
      ],
    );
  }

  List<Widget> _interpretationSections(
    BuildContext context,
    HealthIndicator ind,
    BaselineComparison? cmp,
  ) {
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
    return [
      BoardSection(
        children: [
          StatusBanner(
            status: notable ? HealthStatus.watch : HealthStatus.good,
            text: notable
                ? context.tr(
                    'Cambio respecto a tu línea base',
                    'Change from your baseline',
                  )
                : context.tr('Sin cambios relevantes', 'No relevant changes'),
          ),
          const SizedBox(height: 8),
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
        ],
      ),
      if (notable) ...[
        BoardSection(children: [Text(context.t(ind.spaceEffect))]),
        BoardSection(
          title: context.tr('Qué puedes hacer', 'What you can do'),
          children: [for (final a in ind.actions) Text('• ${context.t(a)}')],
        ),
      ],
    ];
  }

  Widget _summaryRow(
    BuildContext context,
    HealthIndicator i,
    BaselineComparison? cmp,
  ) {
    final notable = cmp != null && cmp.change.abs() > i.baselineTolerance;
    final status = cmp == null ? HealthStatus.unknown : i.status(cmp.recent);
    final unit = context.t(i.unit);
    return ListTile(
      dense: true,
      selected: i.id == selected,
      onTap: () => setState(() => selected = i.id),
      leading: Icon(i.icon, color: i.color),
      title: Text(context.t(i.name)),
      subtitle: Text(
        cmp == null
            ? context.tr(
                'Se necesitan al menos 4 días con datos',
                'At least 4 days of data are needed',
              )
            : context.tr(
                'Base ${i.format(cmp.baseline)} → ahora ${i.format(cmp.recent)} $unit',
                'Baseline ${i.format(cmp.baseline)} → now ${i.format(cmp.recent)} $unit',
              ),
      ),
      trailing: cmp == null
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  cmp.change > 0.005
                      ? Icons.trending_up
                      : cmp.change < -0.005
                      ? Icons.trending_down
                      : Icons.trending_flat,
                  color: notable ? HealthStatus.watch.color : Colors.white54,
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 56,
                  child: Text(
                    '${cmp.change >= 0 ? '+' : ''}${(cmp.change * 100).toStringAsFixed(0)} %',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: 'Consolas',
                      color: notable ? HealthStatus.watch.color : null,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(status.icon, color: status.color, size: 18),
              ],
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
