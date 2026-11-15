import 'package:flutter_test/flutter_test.dart';
import 'package:horion_edge/l10n/language.dart';
import 'package:horion_edge/widgets/viewport_board.dart';
import 'package:material_ui/material_ui.dart';

/// Tablero de 700×400 con dos columnas y secciones de 150 px de alto.
Future<List<Offset>> _layout(WidgetTester tester, bool readingOrder) async {
  tester.view.physicalSize = const Size(700, 440);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    LanguageScope(
      controller: LanguageController(AppLanguage.es),
      child: MaterialApp(
        home: Scaffold(
          body: ViewportBoard(
            minColumnWidth: 300,
            maxColumns: 2,
            readingOrder: readingOrder,
            children: [
              for (var i = 0; i < 4; i++)
                SizedBox(key: ValueKey(i), height: 150, child: Text('$i')),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return [
    for (var i = 0; i < 4; i++) tester.getTopLeft(find.byKey(ValueKey(i))),
  ];
}

void main() {
  testWidgets(
    'en orden de lectura se llena una columna antes de la siguiente',
    (tester) async {
      final p = await _layout(tester, true);
      // 0 y 1 arriba y abajo en la primera columna; 2 y 3 en la segunda.
      expect(p[0].dx, p[1].dx);
      expect(p[1].dy, greaterThan(p[0].dy));
      expect(p[2].dx, greaterThan(p[0].dx));
      expect(p[2].dx, p[3].dx);
      expect(p[3].dy, greaterThan(p[2].dy));
    },
  );

  testWidgets('sin orden de lectura cada sección va a la columna más corta', (
    tester,
  ) async {
    final p = await _layout(tester, false);
    // 0 y 1 lado a lado en la primera fila.
    expect(p[0].dy, p[1].dy);
    expect(p[1].dx, greaterThan(p[0].dx));
  });

  testWidgets('cada grupo empieza en su propia columna', (tester) async {
    tester.view.physicalSize = const Size(700, 440);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      LanguageScope(
        controller: LanguageController(AppLanguage.es),
        child: MaterialApp(
          home: Scaffold(
            body: ViewportBoard(
              minColumnWidth: 300,
              maxColumns: 2,
              readingOrder: true,
              children: const [
                BoardGroupHeader(number: 1, title: 'Uno', color: Colors.blue),
                SizedBox(key: ValueKey('a'), height: 60),
                BoardGroupHeader(number: 2, title: 'Dos', color: Colors.green),
                SizedBox(key: ValueKey('b'), height: 60),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final a = tester.getTopLeft(find.byKey(const ValueKey('a')));
    final b = tester.getTopLeft(find.byKey(const ValueKey('b')));
    // Aunque 'b' cabría debajo de 'a', su grupo arranca en la segunda columna.
    expect(b.dx, greaterThan(a.dx));
    expect(b.dy, a.dy);
    expect(tester.getTopLeft(find.text('Dos')).dx, greaterThan(a.dx));
  });
}
