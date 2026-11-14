import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../l10n/language.dart';
import '../models/health_knowledge.dart';

/// Gráfico de promedios diarios de un indicador con la banda de rango normal,
/// la línea base personal (discontinua) y cada día coloreado según su estado.
class TrendChart extends StatelessWidget {
  const TrendChart({
    super.key,
    required this.indicator,
    required this.labels,
    required this.values,
    this.baseline,
    this.height = 240,
  });
  final HealthIndicator indicator;
  final List<String> labels;
  final List<double?> values;
  final double? baseline;
  final double height;

  @override
  Widget build(BuildContext context) {
    final points = values.whereType<double>().length;
    final name = context.t(indicator.name);
    final base = baseline == null
        ? ''
        : context.tr(
            ', línea base ${indicator.format(baseline)} ${context.t(indicator.unit)}',
            ', baseline ${indicator.format(baseline)} ${context.t(indicator.unit)}',
          );
    return Semantics(
      label: context.tr(
        'Tendencia de $name: $points días con datos$base',
        '$name trend: $points days with data$base',
      ),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: points == 0
            ? Center(child: Text(context.tr('Sin datos en este periodo.', 'No data in this period.')))
            : CustomPaint(
                painter: _TrendPainter(indicator, labels, values, baseline),
              ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.ind, this.labels, this.values, this.baseline);
  final HealthIndicator ind;
  final List<String> labels;
  final List<double?> values;
  final double? baseline;

  static const _left = 44.0, _bottom = 24.0, _top = 10.0, _right = 12.0;
  static const _text = TextStyle(color: Colors.white54, fontSize: 11);

  void _label(Canvas canvas, String text, Offset at, {bool alignRight = false, bool center = false}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: _text),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = alignRight ? at.dx - tp.width : center ? at.dx - tp.width / 2 : at.dx;
    tp.paint(canvas, Offset(dx, at.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final data = values.whereType<double>().toList();
    var lo = [...data, ?baseline].reduce(min);
    var hi = [...data, ?baseline].reduce(max);
    // Incluye el borde de la banda verde solo si está cerca de los datos; si no,
    // un rango amplio (p. ej. HRV hasta 200 ms) aplastaría la línea.
    final span = max(hi - lo, ind.decimals == 0 ? 2.0 : .5);
    if (ind.good.$1 >= lo - span) lo = min(lo, ind.good.$1);
    if (ind.good.$2 <= hi + span) hi = max(hi, ind.good.$2);
    final pad = max((hi - lo) * .12, ind.decimals == 0 ? 1.0 : .1);
    lo -= pad;
    hi += pad;

    final chart = Rect.fromLTRB(_left, _top, size.width - _right, size.height - _bottom);
    double y(double v) => chart.bottom - (v - lo) / (hi - lo) * chart.height;
    double x(int i) => values.length == 1
        ? chart.center.dx
        : chart.left + i / (values.length - 1) * chart.width;

    // Banda del rango normal.
    final bandTop = y(min(ind.good.$2, hi)), bandBottom = y(max(ind.good.$1, lo));
    if (bandBottom > bandTop) {
      canvas.drawRect(
        Rect.fromLTRB(chart.left, bandTop, chart.right, bandBottom),
        Paint()..color = HealthStatus.good.color.withValues(alpha: .08),
      );
    }
    // Rejilla y eje Y.
    final grid = Paint()
      ..color = const Color(0xFF223046)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final v = lo + (hi - lo) * i / 4;
      canvas.drawLine(Offset(chart.left, y(v)), Offset(chart.right, y(v)), grid);
      _label(canvas, v.toStringAsFixed(ind.decimals), Offset(chart.left - 6, y(v)), alignRight: true);
    }
    // Etiquetas X: como mucho unas 8 para que no se amontonen.
    final step = max(1, (labels.length / 8).ceil());
    for (var i = 0; i < labels.length; i += step) {
      _label(canvas, labels[i], Offset(x(i), size.height - _bottom / 2), center: true);
    }
    // Línea base personal, discontinua.
    if (baseline != null) {
      final paint = Paint()
        ..color = Colors.white70
        ..strokeWidth = 1.2;
      final by = y(baseline!);
      for (var dx = chart.left; dx < chart.right; dx += 10) {
        canvas.drawLine(Offset(dx, by), Offset(min(dx + 5, chart.right), by), paint);
      }
    }
    // Serie: se corta en los días sin datos.
    final line = Paint()
      ..color = ind.color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    var drawing = false;
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v == null) {
        drawing = false;
        continue;
      }
      drawing ? path.lineTo(x(i), y(v)) : path.moveTo(x(i), y(v));
      drawing = true;
    }
    canvas.drawPath(path, line);
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v == null) continue;
      final last = i == values.length - 1;
      final c = Offset(x(i), y(v));
      canvas.drawCircle(c, last ? 6 : 4, Paint()..color = const Color(0xFF060913));
      canvas.drawCircle(c, last ? 5 : 3, Paint()..color = ind.status(v).color);
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.values != values || old.baseline != baseline || old.ind != ind;
}
