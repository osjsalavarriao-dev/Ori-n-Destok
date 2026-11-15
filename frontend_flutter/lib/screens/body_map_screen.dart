import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/language.dart';
import '../models/health_knowledge.dart';
import '../models/hrp_catalog.dart';
import '../services/edge_controller.dart';
import '../widgets/indicator_detail.dart';
import '../widgets/viewport_board.dart';

/// Figura humana interactiva: cada región muestra su función, cómo la afecta
/// el vuelo espacial, sus indicadores con semáforo y medidas de prevención.
class BodyMapScreen extends StatefulWidget {
  const BodyMapScreen({
    super.key,
    required this.controller,
    this.visible = true,
  });
  final EdgeController controller;

  /// Solo se anima mientras la pestaña está visible.
  final bool visible;
  @override
  State<BodyMapScreen> createState() => _BodyMapScreenState();
}

class _BodyMapScreenState extends State<BodyMapScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _seconds = ValueNotifier<double>(0);
  String selected = 'heart';

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(
      (elapsed) => _seconds.value = elapsed.inMicroseconds / 1e6,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTicker();
  }

  @override
  void didUpdateWidget(BodyMapScreen old) {
    super.didUpdateWidget(old);
    _syncTicker();
  }

  void _syncTicker() {
    // Respeta la preferencia del sistema de reducir animaciones.
    final animate = widget.visible && !MediaQuery.of(context).disableAnimations;
    if (animate && !_ticker.isActive) _ticker.start();
    if (!animate && _ticker.isActive) _ticker.stop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _seconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final statuses = {for (final r in bodyRegions) r.id: c.regionStatus(r)};
    final region = bodyRegions.firstWhere((r) => r.id == selected);
    final figure = _Figure(
      statuses: statuses,
      selected: selected,
      bpm: c.latest?.bpm ?? 60,
      seconds: _seconds,
      onSelect: (id) => setState(() => selected = id),
    );
    final panel = _RegionPanel(controller: c, region: region);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 820;
        final compact = constraints.maxHeight < 600;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('Mapa corporal', 'Body map'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (!compact)
              Text(
                context.tr(
                  'Toca una zona del cuerpo para ver cómo te afecta el espacio y qué puedes hacer.',
                  'Tap a body area to see how space affects you and what you can do.',
                ),
                style: const TextStyle(color: Colors.white60),
              ),
            const SizedBox(height: 8),
            if (!wide || compact)
              DropdownButton<String>(
                value: selected,
                isExpanded: true,
                items: [
                  for (final r in bodyRegions)
                    DropdownMenuItem(
                      value: r.id,
                      child: Text(context.t(r.name)),
                    ),
                ],
                onChanged: (id) {
                  if (id != null) setState(() => selected = id);
                },
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final r in bodyRegions)
                    ChoiceChip(
                      selected: r.id == selected,
                      onSelected: (_) => setState(() => selected = r.id),
                      avatar: Icon(
                        Icons.circle,
                        size: 12,
                        color: statuses[r.id]!.color,
                      ),
                      label: Text(context.t(r.name)),
                    ),
                ],
              ),
            const SizedBox(height: 8),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: wide ? 180 : 96,
                    child: RepaintBoundary(child: figure),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: panel),
                ],
              ),
            ),
            const SizedBox(height: 4),
            const _Legend(),
          ],
        );
      },
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 18,
    runSpacing: 8,
    children: [
      for (final s in HealthStatus.values)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 12, color: s.color),
            const SizedBox(width: 6),
            Text(context.t(s.label), style: const TextStyle(fontSize: 12)),
          ],
        ),
    ],
  );
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.statuses,
    required this.selected,
    required this.bpm,
    required this.seconds,
    required this.onSelect,
  });
  final Map<String, HealthStatus> statuses;
  final String selected;
  final int bpm;
  final ValueNotifier<double> seconds;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      return GestureDetector(
        key: const ValueKey('body-figure'),
        onTapUp: (d) {
          final id = _BodyGeometry(size).hitTest(d.localPosition);
          if (id != null) onSelect(id);
        },
        child: Semantics(
          label: context.tr(
            'Figura humana interactiva. Usa los botones de zona para seleccionarlas.',
            'Interactive human figure. Use the area buttons to select them.',
          ),
          child: CustomPaint(
            size: size,
            painter: _BodyPainter(
              statuses: statuses,
              selected: selected,
              bpm: bpm,
              seconds: seconds,
            ),
          ),
        ),
      );
    },
  );
}

/// Geometría del cuerpo en un lienzo lógico de 200×440, escalado al espacio
/// disponible y centrado.
class _BodyGeometry {
  _BodyGeometry(Size size)
    : scale = math.min(size.width / 200, size.height / 440),
      origin = Offset(
        (size.width - 200 * math.min(size.width / 200, size.height / 440)) / 2,
        (size.height - 440 * math.min(size.width / 200, size.height / 440)) / 2,
      );
  final double scale;
  final Offset origin;

  Rect _r(double l, double t, double r, double b) => Rect.fromLTRB(
    origin.dx + l * scale,
    origin.dy + t * scale,
    origin.dx + r * scale,
    origin.dy + b * scale,
  );
  Offset _p(double x, double y) => origin + Offset(x * scale, y * scale);

  Path get silhouette {
    final radius = Radius.circular(14 * scale);
    return Path()
      ..addOval(Rect.fromCircle(center: _p(100, 40), radius: 28 * scale))
      ..addRRect(RRect.fromRectAndRadius(_r(89, 64, 111, 86), radius))
      ..addRRect(
        RRect.fromRectAndRadius(
          _r(58, 82, 142, 236),
          Radius.circular(26 * scale),
        ),
      )
      ..addRRect(RRect.fromRectAndRadius(_r(30, 90, 56, 250), radius))
      ..addRRect(RRect.fromRectAndRadius(_r(144, 90, 170, 250), radius))
      ..addRRect(RRect.fromRectAndRadius(_r(62, 226, 98, 428), radius))
      ..addRRect(RRect.fromRectAndRadius(_r(102, 226, 138, 428), radius));
  }

  /// Regiones en orden de prioridad de selección (el corazón está sobre los
  /// pulmones; los ojos y los oídos, sobre el cerebro).
  Map<String, Path> regions({double heartScale = 1}) {
    final radius = Radius.circular(10 * scale);
    return {
      'heart': _heart(_p(108, 140), 15 * scale * heartScale),
      'eyes': Path()
        ..addOval(
          Rect.fromCenter(
            center: _p(89, 46),
            width: 14 * scale,
            height: 8 * scale,
          ),
        )
        ..addOval(
          Rect.fromCenter(
            center: _p(111, 46),
            width: 14 * scale,
            height: 8 * scale,
          ),
        ),
      'vestibular': Path()
        ..addOval(
          Rect.fromCenter(
            center: _p(72, 40),
            width: 9 * scale,
            height: 15 * scale,
          ),
        )
        ..addOval(
          Rect.fromCenter(
            center: _p(128, 40),
            width: 9 * scale,
            height: 15 * scale,
          ),
        ),
      'brain': Path()
        ..addOval(
          Rect.fromCenter(
            center: _p(100, 34),
            width: 42 * scale,
            height: 30 * scale,
          ),
        ),
      'lungs': Path()
        ..addOval(
          Rect.fromCenter(
            center: _p(81, 130),
            width: 28 * scale,
            height: 56 * scale,
          ),
        )
        ..addOval(
          Rect.fromCenter(
            center: _p(119, 130),
            width: 28 * scale,
            height: 56 * scale,
          ),
        ),
      'metabolism': Path()
        ..addOval(
          Rect.fromCenter(
            center: _p(100, 196),
            width: 60 * scale,
            height: 36 * scale,
          ),
        ),
      'immune': Path()
        ..addRRect(RRect.fromRectAndRadius(_r(34, 104, 52, 238), radius))
        ..addRRect(RRect.fromRectAndRadius(_r(148, 104, 166, 238), radius))
        ..addOval(
          Rect.fromCenter(
            center: _p(100, 76),
            width: 18 * scale,
            height: 12 * scale,
          ),
        ),
      'bones': Path()
        ..addRRect(RRect.fromRectAndRadius(_r(70, 246, 90, 416), radius))
        ..addRRect(RRect.fromRectAndRadius(_r(110, 246, 130, 416), radius)),
    };
  }

  /// Corazón de ancho ≈ 2·s centrado en c.
  static Path _heart(Offset c, double s) => Path()
    ..moveTo(c.dx, c.dy + s)
    ..cubicTo(
      c.dx - s * 1.4,
      c.dy,
      c.dx - s * .9,
      c.dy - s * 1.1,
      c.dx,
      c.dy - s * .45,
    )
    ..cubicTo(
      c.dx + s * .9,
      c.dy - s * 1.1,
      c.dx + s * 1.4,
      c.dy,
      c.dx,
      c.dy + s,
    )
    ..close();

  String? hitTest(Offset position) {
    for (final entry in regions().entries) {
      if (entry.value.contains(position)) return entry.key;
    }
    return null;
  }
}

class _BodyPainter extends CustomPainter {
  _BodyPainter({
    required this.statuses,
    required this.selected,
    required this.bpm,
    required this.seconds,
  }) : super(repaint: seconds);
  final Map<String, HealthStatus> statuses;
  final String selected;
  final int bpm;
  final ValueNotifier<double> seconds;

  @override
  void paint(Canvas canvas, Size size) {
    final g = _BodyGeometry(size);
    final t = seconds.value;
    canvas.drawPath(
      g.silhouette,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x3338BDF8), Color(0x110B1120)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      g.silhouette,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0x6638BDF8),
    );

    // Latido: pico breve al inicio de cada ciclo, a la frecuencia cardíaca actual.
    final beat = (t * bpm / 60) % 1;
    final heartScale = 1 + .18 * math.exp(-beat * 12);
    final regions = g.regions(heartScale: heartScale);
    for (final id in regions.keys.toList().reversed) {
      final status = statuses[id] ?? HealthStatus.unknown;
      // Las zonas críticas parpadean; las de vigilancia respiran lento.
      final pulse = switch (status) {
        HealthStatus.critical => .5 + .5 * math.sin(t * 2 * math.pi * 1.5),
        HealthStatus.watch => .5 + .5 * math.sin(t * 2 * math.pi * .5),
        _ => .5,
      };
      final path = regions[id]!;
      final color = status.color;
      if (id == selected || status == HealthStatus.critical) {
        canvas.drawPath(
          path,
          Paint()
            ..color = color.withValues(alpha: .12 + .15 * pulse)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * g.scale),
        );
      }
      canvas.drawPath(
        path,
        Paint()..color = color.withValues(alpha: .35 + .25 * pulse),
      );
      // Contorno oscuro para separar zonas superpuestas (corazón sobre pulmones).
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xCC060913),
      );
      if (id == selected) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = Colors.white,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BodyPainter old) =>
      old.selected != selected || old.bpm != bpm || old.statuses != statuses;
}

class _RegionPanel extends StatelessWidget {
  const _RegionPanel({required this.controller, required this.region});
  final EdgeController controller;
  final BodyRegion region;

  @override
  Widget build(BuildContext context) {
    final status = controller.regionStatus(region);
    final hasSensors = region.indicatorIds.isNotEmpty;
    final hasCheck = region.symptoms.isNotEmpty;
    final research = researchFor(region.id);
    return ViewportBoard(
      key: ValueKey(region.id),
      minColumnWidth: 310,
      children: [
        BoardSection(
          children: [
            StatusBanner(
              status: status,
              text: hasSensors || hasCheck && status != HealthStatus.unknown
                  ? '${context.tr('Estado', 'Status')}: ${context.t(status.label)}'
                  : hasCheck
                  ? context.tr(
                      'Responde la autoevaluación de síntomas',
                      'Answer the symptom self-check',
                    )
                  : context.tr(
                      'Sin sensor directo a bordo',
                      'No direct sensor on board',
                    ),
            ),
          ],
        ),
        BoardSection(
          children: [
            _section(
              context.tr('Función', 'Function'),
              context.t(region.function),
            ),
          ],
        ),
        BoardSection(
          title: context.tr(
            'Efecto del vuelo espacial',
            'Effect of spaceflight',
          ),
          children: [Text(context.t(region.spaceEffect))],
        ),
        BoardSection(
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final h in region.hazards) HazardChip(hazard: h)],
            ),
          ],
        ),
        if (hasCheck) ..._symptomSections(context, controller, region),
        if (hasSensors)
          for (var index = 0; index < region.indicatorIds.length; index++)
            BoardSection(
              title: index == 0
                  ? context.tr('Indicadores', 'Indicators')
                  : null,
              children: [_indicatorTile(context, region.indicatorIds[index])],
            ),
        for (var index = 0; index < region.prevention.length; index++)
          BoardSection(
            title: index == 0 ? context.tr('Prevención', 'Prevention') : null,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check, size: 16, color: Color(0xFF38BDF8)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(context.t(region.prevention[index]))),
                ],
              ),
            ],
          ),
        for (final s in research)
          BoardSection(
            title:
                '${context.tr('Investigación NASA', 'NASA research')} · ${s.name}',
            children: [
              Text(
                context.t(s.status.label),
                style: const TextStyle(color: Color(0xFFA99AFB)),
              ),
              const SizedBox(height: 6),
              Text(context.t(s.description)),
              const SizedBox(height: 6),
              Text(
                context.tr(
                  'Estudios del Programa de Investigación Humana: no son tratamientos probados.',
                  'Human Research Program studies: not proven treatments.',
                ),
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        if (region.earthBenefit != null)
          BoardSection(
            title: context.tr('Beneficio en la Tierra', 'Benefit on Earth'),
            children: [Text(context.t(region.earthBenefit!))],
          ),
      ],
    );
  }

  Widget _indicatorTile(BuildContext context, String id) {
    final ind = indicator(id);
    final value = ind.format(controller.valueOf(id));
    final status = controller.statusOf(id);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(ind.icon, color: ind.color),
      title: Text(context.t(ind.name)),
      subtitle: Text('Normal: ${context.t(ind.normalRange)}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$value ${context.t(ind.unit)}',
            style: const TextStyle(fontFamily: 'Consolas'),
          ),
          const SizedBox(width: 8),
          Icon(status.icon, color: status.color, size: 18),
        ],
      ),
      onTap: () => showIndicatorDetail(context, ind, value, status),
    );
  }

  Widget _section(String title, String body) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(body, style: const TextStyle(color: Colors.white70, height: 1.4)),
      ],
    ),
  );
}

/// Autoevaluación de síntomas de una zona sin sensor (visión, equilibrio, piel).
List<Widget> _symptomSections(
  BuildContext context,
  EdgeController controller,
  BodyRegion region,
) {
  final active = controller.symptoms[region.id] ?? const <String>{};
  final checked = controller.checkedRegions.contains(region.id);
  return [
    for (var index = 0; index < region.symptoms.length; index++)
      BoardSection(
        title: index == 0
            ? context.tr('Autoevaluación de síntomas', 'Symptom self-check')
            : null,
        children: [
          CheckboxListTile(
            key: ValueKey('symptom-${region.symptoms[index].id}'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: active.contains(region.symptoms[index].id),
            onChanged: (v) => controller.setSymptom(
              region.id,
              region.symptoms[index].id,
              v ?? false,
            ),
            title: Text(context.t(region.symptoms[index].question)),
          ),
          if (active.contains(region.symptoms[index].id))
            Text(
              context.t(region.symptoms[index].advice),
              style: TextStyle(color: HealthStatus.watch.color),
            ),
        ],
      ),
    if (active.isEmpty)
      OutlinedButton.icon(
        onPressed: () => controller.confirmNoSymptoms(region.id),
        icon: Icon(
          checked ? Icons.check : Icons.check_circle_outline,
          size: 18,
        ),
        label: Text(
          checked
              ? context.tr('Sin síntomas registrados', 'No symptoms recorded')
              : context.tr('No tengo ninguno', 'I have none of these'),
        ),
      ),
  ];
}
