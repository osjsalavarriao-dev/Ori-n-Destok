import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../models/health_knowledge.dart';

/// Local ticker: never polls the API or rebuilds the dashboard per frame.
class TelemetryMotion extends StatefulWidget {
  const TelemetryMotion({
    super.key,
    required this.metric,
    required this.value,
    required this.status,
    required this.child,
  });
  final String metric;
  final double? value;
  final HealthStatus status;
  final Widget child;
  @override
  State<TelemetryMotion> createState() => _TelemetryMotionState();
}

class _TelemetryMotionState extends State<TelemetryMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController clock = AnimationController(vsync: this);
  void sync() {
    final bpm = widget.metric == 'frecuencia_cardiaca' ? widget.value : null;
    clock.duration = Duration(
      milliseconds: bpm != null && bpm > 0
          ? (60000 / bpm).round()
          : widget.status == HealthStatus.critical
          ? 900
          : 1800,
    );
    if (MediaQuery.disableAnimationsOf(context) || widget.value == null) {
      clock.stop();
      clock.value = 0;
    } else {
      clock.repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    sync();
  }

  @override
  void didUpdateWidget(TelemetryMotion old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value || old.status != widget.status) sync();
  }

  @override
  void dispose() {
    clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: AnimatedBuilder(
      animation: clock,
      child: widget.child,
      builder: (context, child) {
        final pulse = math.pow(math.sin(clock.value * math.pi), 8).toDouble();
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.status.color.withValues(alpha: .08 + .12 * pulse),
          ),
          child: Transform.scale(
            scale: widget.metric == 'frecuencia_cardiaca' ? 1 + .16 * pulse : 1,
            child: widget.metric == 'spo2'
                ? SizedBox(
                    width: 28,
                    height: 28,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(
                            end: ((widget.value ?? 0) / 100).clamp(0, 1),
                          ),
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 700),
                          builder: (context, value, _) =>
                              CircularProgressIndicator(
                                value: value,
                                strokeWidth: 2,
                                color: widget.status.color,
                              ),
                        ),
                        child!,
                      ],
                    ),
                  )
                : child,
          ),
        );
      },
    ),
  );
}


/// Illustrative rhythm, not an acquired ECG signal.
class RhythmTrace extends StatefulWidget {
  const RhythmTrace({super.key, required this.bpm, required this.color});
  final int bpm;
  final Color color;
  @override
  State<RhythmTrace> createState() => _RhythmTraceState();
}
class _RhythmTraceState extends State<RhythmTrace> with SingleTickerProviderStateMixin {
  late final AnimationController clock = AnimationController(vsync: this, duration: const Duration(seconds: 4));
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) { clock.stop(); } else { clock.repeat(); }
  }
  @override
  void dispose() { clock.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => RepaintBoundary(child: SizedBox(height: 54, width: double.infinity,
    child: CustomPaint(painter: _RhythmPainter(clock, widget.bpm, widget.color))));
}
class _RhythmPainter extends CustomPainter {
  _RhythmPainter(this.clock, this.bpm, this.color): super(repaint: clock);
  final Animation<double> clock;
  final int bpm;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color.withValues(alpha: .2)..strokeWidth = 1;
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), p);
    final path = Path();
    for (double x = 0; x <= size.width; x += 2) {
      final phase = ((x / size.width * 4 + clock.value * 4) * bpm / 60) % 1;
      final spike = math.exp(-math.pow((phase - .45) * 40, 2)) - .4 * math.exp(-math.pow((phase - .51) * 40, 2));
      final y = size.height * (.5 - .4 * spike);
      if (x == 0) { path.moveTo(x, y); } else { path.lineTo(x, y); }
    }
    p..color = color..style = PaintingStyle.stroke..strokeWidth = 2;
    canvas.drawPath(path, p);
  }
  @override
  bool shouldRepaint(_RhythmPainter old) => old.bpm != bpm || old.color != color;
}
