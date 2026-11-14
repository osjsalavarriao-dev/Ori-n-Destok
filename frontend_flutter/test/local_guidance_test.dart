import 'package:flutter_test/flutter_test.dart';
import 'package:horion_edge/services/edge_controller.dart';
import 'package:horion_edge/services/local_guidance.dart';
import 'package:horion_edge/l10n/language.dart';

void main() {
  test(
    'Offline guidance works and critical alerts override routine requests',
    () async {
      final c = EdgeController();
      addTearDown(c.dispose);
      await c.refresh();
      await c.toggleOffline(true);
      expect(
        LocalGuidance.answer(c, LocalRequest.status, AppLanguage.en),
        contains('Local guidance'),
      );
      await c.anomaly();
      expect(
        LocalGuidance.answer(c, LocalRequest.exercise, AppLanguage.en),
        contains('Priority alert'),
      );
      expect(
        LocalGuidance.answer(c, LocalRequest.food, AppLanguage.en),
        contains('Priority alert'),
      );
    },
  );
  test('Missing and stale measurements do not authorize a routine', () async {
    final c = EdgeController(demo: false);
    addTearDown(c.dispose);
    expect(
      LocalGuidance.answer(c, LocalRequest.exercise, AppLanguage.en),
      contains('Missing or old data'),
    );
    final demo = EdgeController();
    addTearDown(demo.dispose);
    await demo.refresh();
    expect(
      LocalGuidance.answer(
        demo,
        LocalRequest.food,
        AppLanguage.en,
        now: DateTime.now().add(const Duration(minutes: 2)),
      ),
      contains('Missing or old data'),
    );
  });
}
