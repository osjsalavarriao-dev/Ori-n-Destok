import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../l10n/language.dart';
import '../models/telemetry.dart';

class TelemetryChart extends StatelessWidget {
  const TelemetryChart({super.key, required this.samples});
  final List<Telemetry> samples;
  @override
  Widget build(BuildContext context) => Semantics(
    label: context.tr(
      'Gráfico de frecuencia cardíaca con ${samples.length} lecturas',
      'Heart rate chart with ${samples.length} readings',
    ),
    child: SizedBox(
      height: 190,
      width: double.infinity,
      child: samples.length < 2
          ? Center(
              child: Text(context.tr('Esperando nuevas lecturas…', 'Waiting for new readings…')),
            )
          : CustomPaint(painter: _Chart(samples)),
    ),
  );
}

class _Chart extends CustomPainter {
  _Chart(this.samples);
  final List<Telemetry> samples;
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0xFF223046)
      ..strokeWidth = 1;
    for (var i = 0; i < 5; i++) {
      final y = 12 + (size.height - 24) * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final minValue = min(55, samples.map((s) => s.bpm).reduce(min) - 5);
    final maxValue = max(85, samples.map((s) => s.bpm).reduce(max) + 5);
    final start = samples.first.time.millisecondsSinceEpoch;
    final duration = max(1, samples.last.time.millisecondsSinceEpoch - start);
    final path = Path();
    for (var i = 0; i < samples.length; i++) {
      final x =
          (samples[i].time.millisecondsSinceEpoch - start) /
          duration *
          size.width;
      final y =
          size.height -
          12 -
          (samples[i].bpm - minValue) /
              (maxValue - minValue) *
              (size.height - 24);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF38BDF8)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _Chart oldDelegate) => true;
}
