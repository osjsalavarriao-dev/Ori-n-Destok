import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Illustrative rhythm, not an acquired ECG signal.
class RhythmTrace extends StatefulWidget {
  const RhythmTrace({super.key, required this.bpm, required this.color});
  final int bpm;
  final Color color;
  @override
  State<RhythmTrace> createState() => _RhythmTraceState();
}

class _RhythmTraceState extends State<RhythmTrace>
    with SingleTickerProviderStateMixin {
  late final AnimationController clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      clock.stop();
    } else {
      clock.repeat();
    }
  }

  @override
  void dispose() {
    clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: SizedBox(
      height: 54,
      width: double.infinity,
      child: CustomPaint(
        painter: _RhythmPainter(clock, widget.bpm, widget.color),
      ),
    ),
  );
}

class _RhythmPainter extends CustomPainter {
  _RhythmPainter(this.clock, this.bpm, this.color) : super(repaint: clock);
  final Animation<double> clock;
  final int bpm;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color.withValues(alpha: .2)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      p,
    );
    final path = Path();
    for (double x = 0; x <= size.width; x += 2) {
      final phase = ((x / size.width * 4 + clock.value * 4) * bpm / 60) % 1;
      final spike =
          math.exp(-math.pow((phase - .45) * 40, 2)) -
          .4 * math.exp(-math.pow((phase - .51) * 40, 2));
      final y = size.height * (.5 - .4 * spike);
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    p
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_RhythmPainter old) =>
      old.bpm != bpm || old.color != color;
}
