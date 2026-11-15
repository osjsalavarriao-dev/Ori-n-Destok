import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:horion_edge/l10n/language.dart';
import 'package:horion_edge/services/edge_controller.dart';
import 'package:horion_edge/services/orbi_assistant.dart';

void main() {
  test('El contexto para la IA lleva datos y estados, sin identidad', () {
    final controller = EdgeController();
    controller.setSymptom('brain', 'headache', true);
    final context = OrbiAssistant.buildContext(controller, AppLanguage.es);
    final json = jsonEncode(context);

    expect(context['datos_simulados'], isTrue);
    expect(context['estado_general'], isNotEmpty);
    final indicators = context['indicadores'] as List;
    expect(indicators, isNotEmpty);
    expect(
      (indicators.first as Map).keys,
      containsAll(['nombre', 'valor', 'unidad', 'estado']),
    );
    // Historial día a día (como mucho 14 días) para comparar fechas.
    final days = context['historial_por_dia'] as List;
    expect(days, isNotEmpty);
    expect(days.length, lessThanOrEqualTo(14));
    expect((days.first as Map).keys, containsAll(['fecha', 'valores']));
    // El backend rechaza contextos de más de 20 000 caracteres.
    expect(json.length, lessThan(20000));
    // Ni nombre ni códigos del tripulante o la misión.
    for (final banned in ['AST-', 'ARTEMIS', 'nombre_completo', 'codigo']) {
      expect(json, isNot(contains(banned)));
    }
    controller.dispose();
  });

  test('El historial envía como mucho 8 turnos y omite los locales', () {
    final turns = [
      for (var i = 0; i < 12; i++) OrbiTurn(i.isEven, 'm$i'),
      const OrbiTurn(false, 'local', local: true),
    ];
    final sent = OrbiAssistant.historyPayload(turns);
    expect(sent, hasLength(8));
    expect(sent.first, {'rol': 'user', 'mensaje': 'm4'});
    expect(sent.last, {'rol': 'orbi', 'mensaje': 'm11'});
  });
}
