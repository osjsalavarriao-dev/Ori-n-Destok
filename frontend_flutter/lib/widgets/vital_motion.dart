import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../models/health_knowledge.dart';
import 'vital_icon.dart';

/// Microinteracciones y retroalimentación semántica del icono de un signo vital.
///
/// - Corazón: late (doble golpe) al ritmo exacto de las pulsaciones medidas.
/// - HRV: la onda se traza continuamente, como un electrocardiograma.
/// - Oxígeno: un anillo se llena suavemente hasta el % de saturación.
/// - Según el estado: nominal = cian con respiración lenta; advertencia = ámbar
///   con parpadeo sutil; crítico = rojo-magenta con vibración y ondas que se
///   expanden; sin datos = quieto.
///
/// Un solo reloj por tarjeta, local: no consulta la API ni reconstruye la
/// pantalla en cada fotograma. Con «Pausar animaciones» todo queda quieto.
class LiveVitalBadge extends StatefulWidget {
  const LiveVitalBadge({
    super.key,
    required this.glyph,
    required this.metric,
    required this.value,
    required this.status,
    this.size = 60,
    this.tint,
  });
  final VitalGlyph glyph;
  final String metric;
  final double? value;
  final HealthStatus status;
  final double size;

  /// Color propio del signo vital (identidad): pinta el icono y su recuadro
  /// siempre. El estado se ve en el borde, el brillo y el movimiento.
  /// Null: el icono toma el color del estado.
  final Color? tint;

  @override
  State<LiveVitalBadge> createState() => _LiveVitalBadgeState();
}

class _LiveVitalBadgeState extends State<LiveVitalBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController clock = AnimationController(vsync: this);

  bool get _heart => widget.metric == 'frecuencia_cardiaca';
  bool get _still =>
      MediaQuery.disableAnimationsOf(context) ||
      widget.status == HealthStatus.unknown ||
      widget.value == null;

  Duration get _period {
    final bpm = widget.value;
    if (_heart && bpm != null && bpm > 0) {
      return Duration(milliseconds: (60000 / bpm).round().clamp(300, 2000));
    }
    return switch (widget.status) {
      HealthStatus.critical => const Duration(milliseconds: 800),
      HealthStatus.watch => const Duration(milliseconds: 1400),
      _ => const Duration(milliseconds: 3600),
    };
  }

  void _sync() {
    clock.duration = _period;
    if (_still) {
      clock.stop();
      clock.value = 0;
    } else {
      clock.repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(LiveVitalBadge old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value || old.status != widget.status) _sync();
  }

  @override
  void dispose() {
    clock.dispose();
    super.dispose();
  }

  static double _bump(double t, double center, double width) =>
      math.exp(-math.pow(t - center, 2) / (2 * width * width));

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final colors = badgeColors(widget.status);
    final still = _still;
    final radius = BorderRadius.circular(size * .27);
    final tint = widget.tint;
    final alarm =
        widget.status == HealthStatus.watch ||
        widget.status == HealthStatus.critical;
    final iconColor = tint == null
        ? colors.foreground
        : widget.status == HealthStatus.unknown
        ? tint.withValues(alpha: .5)
        : tint;
    final background = tint == null
        ? colors.background
        : Color.alphaBlend(
            tint.withValues(alpha: .15),
            const Color(0xFF0E1C26),
          );
    // Nominal: brilla con su propio color. Alerta: con el color del estado.
    final glowColor = alarm || tint == null ? colors.glow : tint;
    final border = alarm
        ? Border.all(
            color: colors.glow,
            width: widget.status == HealthStatus.critical ? 2 : 1.5,
          )
        : Border.all(
            color: (tint ?? colors.glow).withValues(
              alpha: widget.status == HealthStatus.unknown ? .2 : .5,
            ),
          );
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            if (widget.status == HealthStatus.critical && !still)
              Positioned.fill(
                child: CustomPaint(
                  painter: _RipplePainter(clock, colors.glow, size * .27),
                ),
              ),
            if (widget.metric == 'spo2')
              Positioned(
                left: -9,
                top: -9,
                right: -9,
                bottom: -9,
                child: _OxygenRing(
                  value: widget.value,
                  color: alarm ? colors.glow : (tint ?? colors.foreground),
                  animate: !MediaQuery.disableAnimationsOf(context),
                ),
              ),
            AnimatedBuilder(
              animation: clock,
              builder: (context, _) {
                final t = clock.value;
                var glow = 0.0, scale = 1.0, opacity = 1.0, shake = 0.0;
                switch (widget.status) {
                  case HealthStatus.good:
                    final breath = still
                        ? .4
                        : (1 - math.cos(2 * math.pi * t)) / 2;
                    glow = .10 + .22 * breath;
                    scale = 1 + .03 * breath;
                  case HealthStatus.watch:
                    final p = still
                        ? .5
                        : math.pow(math.sin(math.pi * t), 4).toDouble();
                    glow = .15 + .45 * p;
                    opacity = 1 - .35 * p;
                  case HealthStatus.critical:
                    final p = still
                        ? .6
                        : math.pow(math.sin(math.pi * t), 2).toDouble();
                    glow = .35 + .40 * p;
                    if (!still && t < .3) {
                      shake = math.sin(t / .3 * 2 * math.pi * 3) * 2.5;
                    }
                  case HealthStatus.unknown:
                    break;
                }
                if (_heart && !still) {
                  // Doble golpe (sístole) dentro de cada periodo = 60 / BPM s.
                  final beat = math.max(
                    _bump(t, .10, .045),
                    .65 * _bump(t, .30, .045),
                  );
                  scale = 1 + .15 * beat;
                  glow = math.max(glow, .12 + .35 * beat);
                }
                return Transform.translate(
                  offset: Offset(shake, 0),
                  child: Container(
                    width: size,
                    height: size,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: background,
                      borderRadius: radius,
                      border: border,
                      boxShadow: [
                        BoxShadow(
                          color: glowColor.withValues(alpha: glow),
                          blurRadius: 6 + 16 * glow,
                        ),
                      ],
                    ),
                    child: Opacity(
                      opacity: opacity,
                      child: Transform.scale(
                        scale: scale,
                        child: VitalIcon(
                          widget.glyph,
                          color: iconColor,
                          size: size * .57,
                          trace: widget.glyph == VitalGlyph.hrv && !still
                              ? t
                              : null,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Ondas que se expanden desde el recuadro en estado crítico.
class _RipplePainter extends CustomPainter {
  _RipplePainter(this.clock, this.color, this.corner) : super(repaint: clock);
  final Animation<double> clock;
  final Color color;
  final double corner;

  @override
  void paint(Canvas canvas, Size size) {
    final base = Offset.zero & size;
    for (final phase in [clock.value, (clock.value + .5) % 1]) {
      final grow = 18 * phase;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          base.inflate(grow),
          Radius.circular(corner + grow),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * (1 - phase) + .5
          ..color = color.withValues(alpha: .55 * (1 - phase)),
      );
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) => old.color != color;
}

/// Anillo de saturación de oxígeno: se llena suavemente hasta el % medido.
class _OxygenRing extends StatelessWidget {
  const _OxygenRing({
    required this.value,
    required this.color,
    required this.animate,
  });
  final double? value;
  final Color color;
  final bool animate;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: ((value ?? 0) / 100).clamp(0.0, 1.0)),
    duration: animate ? const Duration(milliseconds: 1200) : Duration.zero,
    curve: Curves.easeOutCubic,
    builder: (context, fraction, _) =>
        CustomPaint(painter: _RingPainter(fraction, color)),
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.fraction, this.color);
  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(1.5);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      paint..color = color.withValues(alpha: .16),
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * fraction,
      false,
      paint..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.color != color;
}

/// Número que se desliza al nuevo valor en lugar de saltar. Cifras de ancho
/// fijo para que no bailen al cambiar.
class AnimatedVitalValue extends StatelessWidget {
  const AnimatedVitalValue(this.text, {super.key, required this.style});
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final fixed = style.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final number = double.tryParse(text);
    if (number == null) {
      return Text(text, style: fixed, overflow: TextOverflow.ellipsis);
    }
    final decimals = text.contains('.') ? text.split('.').last.length : 0;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: number, end: number),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, shown, _) => Text(
        shown.toStringAsFixed(decimals),
        style: fixed,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Mini gráfica en vivo de las últimas lecturas del sensor.
class VitalSparkline extends StatelessWidget {
  const VitalSparkline({
    super.key,
    required this.values,
    required this.color,
    this.height = 34,
  });
  final List<double> values;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: CustomPaint(painter: _SparklinePainter(values, color)),
  );
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.values, this.color);
  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    var low = values.reduce(math.min), high = values.reduce(math.max);
    if (high - low < 1e-6) {
      low -= 1;
      high += 1;
    }
    Offset point(int i) => Offset(
      size.width * i / (values.length - 1),
      size.height - 3 - (size.height - 6) * (values[i] - low) / (high - low),
    );
    final line = Path()..moveTo(point(0).dx, point(0).dy);
    for (var i = 1; i < values.length; i++) {
      line.lineTo(point(i).dx, point(i).dy);
    }
    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: .22), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round
        ..color = color.withValues(alpha: .9),
    );
    final last = point(values.length - 1);
    canvas.drawCircle(last, 5, Paint()..color = color.withValues(alpha: .25));
    canvas.drawCircle(last, 2.6, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.color != color || !_same(old.values, values);

  static bool _same(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
