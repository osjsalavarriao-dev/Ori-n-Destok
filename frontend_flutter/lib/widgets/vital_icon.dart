import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../models/health_knowledge.dart';

/// Dibujo propio de cada signo vital. El dibujo dice QUÉ es (nunca cambia);
/// el color del recuadro dice CÓMO está (solo se colorea si no es normal).
enum VitalGlyph { heart, oxygen, hrv, thermometer, gauge, glucose, sleep, mood }

/// Glifo de un indicador por su id (`frecuencia_cardiaca`, `spo2`…), o null.
VitalGlyph? glyphFor(String metric) => switch (metric) {
  'frecuencia_cardiaca' => VitalGlyph.heart,
  'spo2' => VitalGlyph.oxygen,
  'hrv' => VitalGlyph.hrv,
  'temperatura_corporal' => VitalGlyph.thermometer,
  'presion_sistolica' || 'presion_diastolica' => VitalGlyph.gauge,
  'glucosa' => VitalGlyph.glucose,
  'horas_sueno' => VitalGlyph.sleep,
  'animo' => VitalGlyph.mood,
  _ => null,
};

/// Colores semánticos del recuadro: cian (nominal), ámbar (advertencia),
/// rojo-magenta (crítico) o gris (sin datos). `glow` es el color del brillo.
({Color background, Color foreground, Color glow}) badgeColors(
  HealthStatus status,
) => switch (status) {
  HealthStatus.good => (
    background: const Color(0xFF0B2E33),
    foreground: const Color(0xFF67E8F9),
    glow: const Color(0xFF22D3EE),
  ),
  HealthStatus.watch => (
    background: const Color(0xFF4A3510),
    foreground: const Color(0xFFFCD34D),
    glow: const Color(0xFFF59E0B),
  ),
  HealthStatus.critical => (
    background: const Color(0xFF5F1424),
    foreground: const Color(0xFFFECDD3),
    glow: const Color(0xFFF43F5E),
  ),
  HealthStatus.unknown => (
    background: const Color(0xFF17323F),
    foreground: const Color(0xFF9FB3C3),
    glow: const Color(0x00000000),
  ),
};

/// Icono de signo vital dentro de su recuadro redondeado.
class VitalBadge extends StatelessWidget {
  const VitalBadge({
    super.key,
    required this.glyph,
    this.status = HealthStatus.good,
    this.size = 60,
  });
  final VitalGlyph glyph;
  final HealthStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = badgeColors(status);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(size * .27),
      ),
      alignment: Alignment.center,
      child: VitalIcon(glyph, color: colors.foreground, size: size * .57),
    );
  }
}

/// El dibujo, sin recuadro. Equivale a un icono de 24×24 con trazo 2.
class VitalIcon extends StatelessWidget {
  const VitalIcon(
    this.glyph, {
    super.key,
    required this.color,
    this.size = 24,
    this.trace,
  });
  final VitalGlyph glyph;
  final Color color;
  final double size;

  /// Solo para [VitalGlyph.hrv]: fracción (0–1) de la onda ya dibujada, para
  /// el trazo continuo tipo electrocardiograma. Null: onda completa y quieta.
  final double? trace;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _VitalPainter(glyph, color, trace)),
  );
}

class _VitalPainter extends CustomPainter {
  _VitalPainter(this.glyph, this.color, this.trace);
  final VitalGlyph glyph;
  final Color color;
  final double? trace;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24; // Coordenadas en una rejilla de 24×24.
    canvas.scale(s);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;

    switch (glyph) {
      case VitalGlyph.heart:
        canvas.drawPath(
          Path()
            ..moveTo(12, 20)
            ..cubicTo(4, 14.5, 2, 10.5, 3.2, 7.2)
            ..cubicTo(4.6, 3.6, 9.6, 3.2, 12, 6.8)
            ..cubicTo(14.4, 3.2, 19.4, 3.6, 20.8, 7.2)
            ..cubicTo(22, 10.5, 20, 14.5, 12, 20)
            ..close(),
          stroke,
        );
      case VitalGlyph.oxygen:
        canvas.drawPath(
          Path()
            ..moveTo(12, 2.5)
            ..cubicTo(14, 5, 18.5, 10.5, 18.5, 14.5)
            ..arcToPoint(
              const Offset(5.5, 14.5),
              radius: const Radius.circular(6.5),
            )
            ..cubicTo(5.5, 10.5, 10, 5, 12, 2.5)
            ..close(),
          stroke,
        );
        _text(canvas, 'O₂', const Offset(12, 15.2), 6.6);
      case VitalGlyph.hrv:
        final wave = Path()
          ..moveTo(2, 12)
          ..lineTo(6, 12)
          ..lineTo(8, 7)
          ..lineTo(12, 17)
          ..lineTo(15, 10)
          ..lineTo(17, 12)
          ..lineTo(22, 12);
        final t = trace;
        if (t == null) {
          canvas.drawPath(wave, stroke);
          break;
        }
        // Onda tenue de fondo + tramo ya trazado + cabeza brillante.
        canvas.drawPath(
          wave,
          Paint()
            ..color = color.withValues(alpha: .22)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
        final metric = wave.computeMetrics().first;
        final end = metric.length * t.clamp(0.0, 1.0);
        canvas.drawPath(metric.extractPath(0, end), stroke);
        final head = metric.getTangentForOffset(end)?.position;
        if (head != null) {
          canvas.drawCircle(head, 1.8, fill);
          canvas.drawCircle(
            head,
            3.4,
            Paint()..color = color.withValues(alpha: .28),
          );
        }
      case VitalGlyph.thermometer:
        final stem = Path()
          ..addRRect(
            RRect.fromLTRBR(10, 3, 14, 15.5, const Radius.circular(2)),
          );
        final bulb = Path()
          ..addOval(
            Rect.fromCircle(center: const Offset(12, 17.6), radius: 3.9),
          );
        canvas.drawPath(Path.combine(PathOperation.union, stem, bulb), stroke);
        canvas.drawLine(const Offset(12, 9), const Offset(12, 16), stroke);
      case VitalGlyph.gauge:
        canvas.drawArc(
          Rect.fromCircle(center: const Offset(12, 17), radius: 8),
          math.pi,
          math.pi,
          false,
          stroke,
        );
        canvas.drawLine(const Offset(12, 17), const Offset(16, 12), stroke);
        canvas.drawCircle(const Offset(12, 17), 1.4, fill);
      case VitalGlyph.glucose:
        canvas.drawPath(
          Path()
            ..moveTo(12, 3)
            ..lineTo(20, 7.5)
            ..lineTo(20, 16.5)
            ..lineTo(12, 21)
            ..lineTo(4, 16.5)
            ..lineTo(4, 7.5)
            ..close()
            ..moveTo(4, 7.5)
            ..lineTo(12, 12)
            ..lineTo(20, 7.5)
            ..moveTo(12, 12)
            ..lineTo(12, 21),
          stroke,
        );
      case VitalGlyph.sleep:
        final moon = Path.combine(
          PathOperation.difference,
          Path()..addOval(
            Rect.fromCircle(center: const Offset(11.5, 12.5), radius: 8.5),
          ),
          Path()..addOval(
            Rect.fromCircle(center: const Offset(17, 7.5), radius: 6.5),
          ),
        );
        canvas.drawPath(moon, stroke);
      case VitalGlyph.mood:
        canvas.drawCircle(const Offset(12, 12), 9, stroke);
        canvas.drawPath(
          Path()
            ..moveTo(8.5, 14.5)
            ..quadraticBezierTo(12, 18, 15.5, 14.5),
          stroke,
        );
        canvas.drawCircle(const Offset(9, 9.5), 1.2, fill);
        canvas.drawCircle(const Offset(15, 9.5), 1.2, fill);
    }
  }

  void _text(Canvas canvas, String text, Offset center, double fontSize) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(_VitalPainter old) =>
      old.glyph != glyph || old.color != color || old.trace != trace;
}
