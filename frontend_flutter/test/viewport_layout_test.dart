import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:horion_edge/l10n/language.dart';
import 'package:horion_edge/main.dart';
import 'package:horion_edge/models/health_knowledge.dart';
import 'package:horion_edge/models/mission_environment.dart';
import 'package:horion_edge/screens/body_map_screen.dart';
import 'package:horion_edge/services/local_guidance.dart';
import 'package:horion_edge/widgets/viewport_board.dart';
import 'package:horion_edge/screens/vital_monitor_screen.dart';
import 'package:horion_edge/widgets/indicator_detail.dart';

void checkBoards(WidgetTester tester) {
  final boards = find.byType(ViewportBoard);
  expect(boards, findsWidgets);
  for (final element in boards.evaluate()) {
    void visit(Element element) {
      if (element is RenderObjectElement &&
          element.renderObject.runtimeType.toString() == '_RenderBoard') {
        final board = element.renderObject as RenderBox;
        var slot = 0;
        board.visitChildren((child) {
          var section =
              (element.widget as MultiChildRenderObjectWidget).children[slot];
          if (section is ExcludeFocus) section = section.child;
          final box = child as RenderBox;
          final offset = (box.parentData! as BoxParentData).offset;
          expect(
            offset.dy + box.size.height,
            lessThanOrEqualTo(board.size.height + .1),
            reason:
                'Slot ${slot++}: ${section is BoardSection ? section.title : section} exceeds ${board.size}',
          );
          expect(
            offset.dx + box.size.width,
            lessThanOrEqualTo(board.size.width + .1),
          );
        });
      }
      element.visitChildren(visit);
    }

    visit(element);
  }
  expect(find.byType(SingleChildScrollView), findsNothing);
  expect(find.byType(ListView), findsNothing);
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('Indicator details and measurement form fit a compact window', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const HorionApp(language: AppLanguage.es));
    await tester.tap(find.byIcon(Icons.motion_photos_on));
    await tester.pumpAndSettle();
    for (final ind in indicators) {
      final context = tester.element(find.byType(VitalMonitorScreen));
      showIndicatorDetail(context, ind, '50', HealthStatus.critical);
      await tester.pumpAndSettle();
      checkBoards(tester);
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Registrar medición'));
    await tester.pumpAndSettle();
    checkBoards(tester);
    await tester.enterText(
      find.byKey(const ValueKey('measure-presion_sistolica')),
      '80',
    );
    await tester.enterText(
      find.byKey(const ValueKey('measure-presion_diastolica')),
      '90',
    );
    await tester.pumpAndSettle();
    checkBoards(tester);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final size in [
    const Size(800, 600),
    const Size(1024, 768),
    const Size(1366, 768),
    const Size(1920, 1080),
  ]) {
    for (final language in AppLanguage.values) {
      testWidgets('All screens fit $size in $language without scrolling', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(HorionApp(language: language));
        await tester.tap(find.byIcon(Icons.motion_photos_on));
        await tester.pumpAndSettle();
        for (final icon in [
          Icons.monitor_heart_outlined,
          Icons.accessibility_new,
          Icons.insights,
          Icons.shield_outlined,
          Icons.auto_awesome_outlined,
          Icons.history,
        ]) {
          await tester.tap(find.byIcon(icon).first);
          await tester.pumpAndSettle();
          checkBoards(tester);
          if (icon == Icons.accessibility_new) {
            final screen = tester.widget<BodyMapScreen>(
              find.byType(BodyMapScreen, skipOffstage: false),
            );
            for (final region in bodyRegions) {
              final dropdown = find.byType(DropdownButton<String>);
              if (dropdown.evaluate().isNotEmpty) {
                tester.widget<DropdownButton<String>>(dropdown).onChanged!(
                  region.id,
                );
              } else {
                await tester.tap(
                  find.widgetWithText(ChoiceChip, region.name.of(language)),
                );
              }
              await tester.pumpAndSettle();
              checkBoards(tester);
            }
            // Exercise critical alerts and environment escalation notes too.
            for (final environment in environments) {
              screen.controller.setEnvironment(environment);
              await tester.pumpAndSettle();
              checkBoards(tester);
            }
          }
          if (icon == Icons.auto_awesome_outlined) {
            for (final request in LocalRequest.values) {
              await tester.tap(
                find.widgetWithText(
                  ChoiceChip,
                  LocalGuidance.label(request).of(language),
                ),
              );
              await tester.pumpAndSettle();
              checkBoards(tester);
            }
          }
        }
        final controller = tester
            .widget<BodyMapScreen>(
              find.byType(BodyMapScreen, skipOffstage: false),
            )
            .controller;
        await controller.anomaly();
        await tester.tap(find.byIcon(Icons.monitor_heart_outlined).first);
        await tester.pumpAndSettle();
        checkBoards(tester);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
