import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../models/health_knowledge.dart';

/// Vector companion inspired by the supplied white, two-antenna character.
enum OrbinMood { idle, listening, happy, resting, concerned, reading, speaking }

class OrbinAvatar extends StatefulWidget {
  const OrbinAvatar({
    super.key,
    this.size = 80,
    this.status = HealthStatus.good,
    this.mood,
    this.onTap,
  });
  final double size;
  final HealthStatus status;
  final OrbinMood? mood;
  final VoidCallback? onTap;
  @override
  State<OrbinAvatar> createState() => _OrbinAvatarState();
}

class _OrbinAvatarState extends State<OrbinAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  );
  bool hovering = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      clock.stop();
      clock.value = 0;
    } else if (!clock.isAnimating) {
      clock.repeat();
    }
  }

  @override
  void dispose() {
    clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mood =
        widget.status == HealthStatus.critical ||
            widget.status == HealthStatus.watch
        ? OrbinMood.concerned
        : widget.status == HealthStatus.unknown
        ? OrbinMood.resting
        : hovering
        ? OrbinMood.happy
        : widget.mood ?? OrbinMood.idle;
    final drawing = RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(painter: _OrbinPainter(widget.status, clock, mood)),
      ),
    );
    return MouseRegion(
      onEnter: (_) => setState(() => hovering = true),
      onExit: (_) => setState(() => hovering = false),
      child: widget.onTap == null
          ? ExcludeSemantics(child: drawing)
          : Semantics(
              button: true,
              label: 'Orbin',
              child: InkWell(
                onTap: widget.onTap,
                customBorder: const CircleBorder(),
                child: drawing,
              ),
            ),
    );
  }
}

class _OrbinPainter extends CustomPainter {
  _OrbinPainter(this.status, this.clock, this.mood) : super(repaint: clock);
  final Animation<double> clock;
  final OrbinMood mood;
  final HealthStatus status;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 100);
    final phase = clock.value * math.pi * 2;
    canvas.translate(0, math.sin(phase) * 2);
    if (mood == OrbinMood.listening) {
      canvas.translate(50, 50);
      canvas.rotate(-.08);
      canvas.translate(-50, -50);
    }
    final p = Paint()..color = status.color.withValues(alpha: .12);
    canvas.drawCircle(const Offset(50, 57), 43, p);
    p
      ..color = const Color(0xFFD9E8ED)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final x in [28.0, 72.0]) {
      final end = Offset(
        x < 50 ? 20 : 80,
        mood == OrbinMood.resting
            ? 39
            : mood == OrbinMood.concerned
            ? 29
            : 13 + math.sin(phase) * 2,
      );
      canvas.drawLine(Offset(x, 34), end, p);
      canvas.drawCircle(end, 4, p);
    }
    canvas.drawOval(const Rect.fromLTWH(13, 27, 74, 65), p);
    p.color = const Color(0xFFF4FAFC);
    canvas.drawOval(const Rect.fromLTWH(14, 24, 72, 61), p);
    p
      ..color = const Color(0xFF09212C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    if (mood == OrbinMood.happy) {
      for (final x in [32.0, 57.0]) {
        canvas.drawArc(
          Rect.fromLTWH(x, 47, 12, 14),
          math.pi,
          math.pi,
          false,
          p,
        );
      }
    } else {
      p.style = PaintingStyle.fill;
      for (final x in [36.0, 63.0]) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(
              x + (mood == OrbinMood.reading ? math.sin(phase) * 3 : 0),
              53,
            ),
            width: 10,
            height: mood == OrbinMood.resting || clock.value > .96 ? 3 : 19,
          ),
          p,
        );
      }
    }
    p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    if (mood == OrbinMood.concerned) {
      canvas.drawArc(
        const Rect.fromLTWH(43, 65, 14, 7),
        math.pi,
        math.pi,
        false,
        p,
      );
      p.strokeWidth = 3;
      canvas.drawLine(const Offset(30, 39), const Offset(41, 43), p);
      canvas.drawLine(const Offset(59, 43), const Offset(70, 39), p);
    } else if (mood == OrbinMood.speaking) {
      canvas.drawOval(
        Rect.fromCenter(
          center: const Offset(50, 66),
          width: 12,
          height: 3 + 7 * math.sin(phase * 8).abs(),
        ),
        p,
      );
    } else {
      canvas.drawArc(const Rect.fromLTWH(43, 62, 14, 7), 0, math.pi, false, p);
    }
  }

  @override
  bool shouldRepaint(_OrbinPainter old) =>
      old.status != status || old.mood != mood;
}
