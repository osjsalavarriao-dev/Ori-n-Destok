import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/language.dart';
import '../models/health_knowledge.dart';
import '../services/edge_controller.dart';

enum _Kind { pressure, glucose, temperature }

/// Campo de entrada con los límites que acepta el backend (descartan errores
/// de tecleo; no son rangos clínicos).
class _Field {
  const _Field(this.id, this.label, this.min, this.max, {this.decimal = false});
  final String id;
  final T label;
  final double min, max;
  final bool decimal;
}

const _fields = {
  _Kind.pressure: [
    _Field('presion_sistolica', T('Sistólica (alta)', 'Systolic (upper)'), 50, 260),
    _Field('presion_diastolica', T('Diastólica (baja)', 'Diastolic (lower)'), 30, 160),
  ],
  _Kind.glucose: [_Field('glucosa', T('Glucosa', 'Glucose'), 20, 600, decimal: true)],
  _Kind.temperature: [
    _Field('temperatura_corporal', T('Temperatura', 'Temperature'), 30, 43, decimal: true),
  ],
};

/// Abre el diálogo; devuelve true si se guardó la medición.
Future<bool?> showMeasurementDialog(BuildContext context, EdgeController controller) =>
    showDialog<bool>(
      context: context,
      builder: (_) => _MeasurementDialog(controller: controller),
    );

class _MeasurementDialog extends StatefulWidget {
  const _MeasurementDialog({required this.controller});
  final EdgeController controller;
  @override
  State<_MeasurementDialog> createState() => _MeasurementDialogState();
}

class _MeasurementDialogState extends State<_MeasurementDialog> {
  _Kind kind = _Kind.pressure;
  final _text = <String, TextEditingController>{
    for (final list in _fields.values)
      for (final f in list) f.id: TextEditingController(),
  };
  bool saving = false;

  @override
  void dispose() {
    for (final t in _text.values) {
      t.dispose();
    }
    super.dispose();
  }

  double? _value(_Field f) =>
      double.tryParse(_text[f.id]!.text.trim().replaceAll(',', '.'));

  String? _error(_Field f) {
    if (_text[f.id]!.text.trim().isEmpty) return null;
    final v = _value(f);
    if (v == null) return context.tr('Número no válido', 'Invalid number');
    if (v < f.min || v > f.max) {
      final lo = f.min.toStringAsFixed(0), hi = f.max.toStringAsFixed(0);
      return context.tr('Entre $lo y $hi', 'Between $lo and $hi');
    }
    return null;
  }

  /// Mensaje de validación del formulario, o null si se puede guardar.
  String? get _problem {
    final fields = _fields[kind]!;
    if (fields.any((f) => _value(f) == null || _error(f) != null)) {
      return context.tr('Completa los valores.', 'Fill in the values.');
    }
    if (kind == _Kind.pressure && _value(fields[0])! <= _value(fields[1])!) {
      return context.tr(
        'La sistólica debe ser mayor que la diastólica.',
        'Systolic must be higher than diastolic.',
      );
    }
    return null;
  }

  Future<void> _save() async {
    final c = widget.controller;
    setState(() => saving = true);
    final fields = _fields[kind]!;
    await c.addMeasurement({
      for (final f in fields)
        f.id: f.decimal ? _value(f)! : _value(f)!.round(),
    });
    if (!mounted) return;
    setState(() => saving = false);
    if (c.error == null) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final fields = _fields[kind]!;
    final ind = indicator(fields.first.id);
    final problem = _problem;
    final error = widget.controller.error;
    return AlertDialog(
      title: Text(context.tr('Registrar medición', 'Log measurement')),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<_Kind>(
                segments: [
                  ButtonSegment(
                    value: _Kind.pressure,
                    icon: const Icon(Icons.speed),
                    label: Text(context.tr('Presión', 'Pressure')),
                  ),
                  ButtonSegment(
                    value: _Kind.glucose,
                    icon: const Icon(Icons.bloodtype_outlined),
                    label: Text(context.tr('Glucosa', 'Glucose')),
                  ),
                  ButtonSegment(
                    value: _Kind.temperature,
                    icon: const Icon(Icons.thermostat_outlined),
                    label: Text(context.tr('Temperatura', 'Temperature')),
                  ),
                ],
                selected: {kind},
                onSelectionChanged: (v) => setState(() => kind = v.first),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF111D2D),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline, size: 18, color: Color(0xFF38BDF8)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${context.tr('Cómo medir', 'How to measure')}: ${context.t(ind.howToMeasure)}',
                        style: const TextStyle(fontSize: 13, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              for (final f in fields) ...[
                _input(f),
                const SizedBox(height: 12),
              ],
              if (problem == null)
                for (final f in fields) ...[
                  _preview(f),
                  const SizedBox(height: 6),
                ],
              if (problem != null &&
                  fields.every((f) => _text[f.id]!.text.trim().isNotEmpty) &&
                  fields.every((f) => _error(f) == null))
                Text(problem, style: TextStyle(color: HealthStatus.critical.color)),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(context.t(error), style: TextStyle(color: HealthStatus.critical.color)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context, false),
          child: Text(context.tr('Cancelar', 'Cancel')),
        ),
        FilledButton(
          onPressed: problem != null || saving || widget.controller.busy ? null : _save,
          child: Text(
            saving ? context.tr('Guardando…', 'Saving…') : context.tr('Guardar', 'Save'),
          ),
        ),
      ],
    );
  }

  Widget _input(_Field f) {
    final ind = indicator(f.id);
    return TextField(
      key: ValueKey('measure-${f.id}'),
      controller: _text[f.id],
      keyboardType: TextInputType.numberWithOptions(decimal: f.decimal),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(f.decimal ? r'[0-9.,]' : r'[0-9]')),
      ],
      decoration: InputDecoration(
        labelText: context.t(f.label),
        suffixText: context.t(ind.unit),
        helperText: 'Normal: ${context.t(ind.normalRange)}',
        errorText: _error(f),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  /// Vista previa del semáforo antes de guardar.
  Widget _preview(_Field f) {
    final status = indicator(f.id).status(_value(f));
    return Row(
      children: [
        Icon(status.icon, color: status.color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${context.t(f.label)}: ${context.t(status.label)}',
            style: TextStyle(color: status.color, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
