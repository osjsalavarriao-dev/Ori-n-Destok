import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/language.dart';

Future<void> showBoardDetails(
  BuildContext context, {
  required String title,
  required List<Widget> children,
}) => showDialog<void>(
  context: context,
  builder: (context) => Dialog(
    child: SizedBox(
      width: 1000,
      height: MediaQuery.sizeOf(context).height * .8,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: context.tr('Cerrar', 'Close'),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(child: ViewportBoard(children: children)),
          ],
        ),
      ),
    ),
  ),
);

class ScreenBoard extends StatelessWidget {
  const ScreenBoard({
    super.key,
    required this.title,
    this.subtitle,
    this.controls,
    required this.children,
    this.minColumnWidth = 360,
    this.maxColumns = 3,
  });
  final String title;
  final String? subtitle;
  final Widget? controls;
  final List<Widget> children;
  final double minColumnWidth;
  final int maxColumns;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.headlineSmall),
      if (subtitle != null && MediaQuery.sizeOf(context).height >= 700)
        Text(subtitle!, style: const TextStyle(color: Colors.white60)),
      if (controls != null) ...[const SizedBox(height: 8), controls!],
      const SizedBox(height: 12),
      Expanded(
        child: ViewportBoard(
          minColumnWidth: minColumnWidth,
          maxColumns: maxColumns,
          children: children,
        ),
      ),
    ],
  );
}

/// Packs complete sections into the available height, then into columns.
/// Additional sections use explicit pages instead of an unbounded scroll view.
class ViewportBoard extends StatefulWidget {
  const ViewportBoard({
    super.key,
    required this.children,
    this.minColumnWidth = 360,
    this.maxColumns = 3,
    this.readingOrder = false,
  });

  final List<Widget> children;
  final double minColumnWidth;
  final int maxColumns;

  /// true: llena la primera columna de arriba abajo, luego la segunda… (orden
  /// de lectura de periódico). false: cada sección va a la columna más corta,
  /// que aprovecha mejor el espacio pero salta entre columnas.
  final bool readingOrder;

  @override
  State<ViewportBoard> createState() => _ViewportBoardState();
}

class _ViewportBoardState extends State<ViewportBoard> {
  int page = 0, pages = 1;
  List<int> assignments = const [];

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: ClipRect(
          child: _BoardLayout(
            page: page,
            minColumnWidth: widget.minColumnWidth,
            maxColumns: widget.maxColumns,
            readingOrder: widget.readingOrder,
            columnBreaks: {
              for (var index = 0; index < widget.children.length; index++)
                if (widget.children[index] is BoardGroupHeader) index,
            },
            onPages: (positions) {
              if (!mounted) return;
              final count = positions.isEmpty ? 1 : positions.last + 1;
              setState(() {
                assignments = positions;
                pages = count;
                page = page.clamp(0, count - 1);
              });
            },
            children: [
              for (var index = 0; index < widget.children.length; index++)
                ExcludeFocus(
                  excluding:
                      index >= assignments.length || assignments[index] != page,
                  child: widget.children[index],
                ),
            ],
          ),
        ),
      ),
      SizedBox(
        height: 40,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Flexible: en un tablero estrecho el texto se recorta en vez de
            // desbordar la fila.
            Flexible(
              child: Text(
                pages == 1
                    ? context.tr('Vista completa', 'Full view')
                    : context.tr(
                        'Página ${page + 1} de $pages',
                        'Page ${page + 1} of $pages',
                      ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.white60),
              ),
            ),
            if (pages > 1) ...[
              IconButton(
                tooltip: context.tr('Página anterior', 'Previous page'),
                onPressed: page == 0 ? null : () => setState(() => page--),
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                tooltip: context.tr('Página siguiente', 'Next page'),
                onPressed: page + 1 == pages
                    ? null
                    : () => setState(() => page++),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}

/// Encabezado numerado de un grupo de secciones relacionadas. En un tablero
/// con `readingOrder`, cada grupo empieza en su propia columna.
class BoardGroupHeader extends StatelessWidget {
  const BoardGroupHeader({
    super.key,
    required this.number,
    required this.title,
    required this.color,
  });
  final int number;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 2, bottom: 2),
    child: Row(
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .16),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: .7)),
          ),
          child: Text(
            '$number',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: .6,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(height: 1, color: color.withValues(alpha: .35)),
        ),
      ],
    ),
  );
}

class BoardSection extends StatelessWidget {
  const BoardSection({super.key, this.title, required this.children});
  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
          ],
          ...children,
        ],
      ),
    ),
  );
}

class _BoardData extends ContainerBoxParentData<RenderBox> {
  int page = 0;
}

class _BoardLayout extends MultiChildRenderObjectWidget {
  const _BoardLayout({
    required this.page,
    required this.minColumnWidth,
    required this.maxColumns,
    required this.onPages,
    required super.children,
    this.readingOrder = false,
    this.columnBreaks = const {},
  });
  final int page, maxColumns;
  final double minColumnWidth;
  final ValueChanged<List<int>> onPages;
  final bool readingOrder;

  /// Índices de los hijos que empiezan columna nueva (encabezados de grupo).
  final Set<int> columnBreaks;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderBoard(page, minColumnWidth, maxColumns, onPages)
        ..readingOrder = readingOrder
        ..columnBreaks = columnBreaks;

  @override
  void updateRenderObject(BuildContext context, _RenderBoard renderObject) {
    renderObject
      ..page = page
      ..minColumnWidth = minColumnWidth
      ..maxColumns = maxColumns
      ..onPages = onPages
      ..readingOrder = readingOrder
      ..columnBreaks = columnBreaks
      ..markNeedsLayout()
      ..markNeedsSemanticsUpdate();
  }
}

class _RenderBoard extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _BoardData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _BoardData> {
  _RenderBoard(this.page, this.minColumnWidth, this.maxColumns, this.onPages);
  int page, maxColumns;
  double minColumnWidth;
  ValueChanged<List<int>> onPages;
  bool readingOrder = false;
  Set<int> columnBreaks = const {};
  List<int>? _reportedAssignments;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _BoardData) child.parentData = _BoardData();
  }

  @override
  void performLayout() {
    size = constraints.biggest;
    const gap = 12.0;
    var columns = ((size.width + gap) / (minColumnWidth + gap)).floor().clamp(
      1,
      maxColumns,
    );
    // A short window needs wider sections so that text wraps into fewer lines.
    // Measure the actual content before choosing a column count.
    var width = 0.0;
    while (true) {
      width = (size.width - gap * (columns - 1)) / columns;
      var fits = true;
      var item = firstChild;
      while (item != null) {
        item.layout(
          BoxConstraints.tightFor(width: width),
          parentUsesSize: true,
        );
        if (item.size.height > size.height) fits = false;
        item = (item.parentData! as _BoardData).nextSibling;
      }
      if (fits || columns == 1) break;
      columns--;
    }
    final heights = List<double>.filled(columns, 0);
    var currentPage = 0;
    final assignments = <int>[];
    var child = firstChild;
    var next = 0; // Columna actual en orden de lectura.
    var index = -1;
    while (child != null) {
      index++;
      var column = readingOrder
          ? next
          : heights.indexOf(heights.reduce(math.min));
      if (readingOrder &&
          heights[column] > 0 &&
          (columnBreaks.contains(index) ||
              heights[column] + child.size.height > size.height)) {
        // Columna llena o empieza un grupo: sigue en la siguiente.
        column = ++next;
      }
      if (column >= columns ||
          heights[column] > 0 &&
              heights[column] + child.size.height > size.height) {
        currentPage++;
        heights.fillRange(0, columns, 0);
        column = next = 0;
      }
      final data = child.parentData! as _BoardData;
      data.page = currentPage;
      assignments.add(currentPage);
      data.offset = Offset(column * (width + gap), heights[column]);
      heights[column] += child.size.height + gap;
      child = data.nextSibling;
    }
    if (!listEquals(_reportedAssignments, assignments)) {
      _reportedAssignments = assignments;
      WidgetsBinding.instance.addPostFrameCallback((_) => onPages(assignments));
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    var child = firstChild;
    while (child != null) {
      final data = child.parentData! as _BoardData;
      if (data.page == page) context.paintChild(child, offset + data.offset);
      child = data.nextSibling;
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    var child = lastChild;
    while (child != null) {
      final data = child.parentData! as _BoardData;
      if (data.page == page &&
          result.addWithPaintOffset(
            offset: data.offset,
            position: position,
            hitTest: (result, transformed) =>
                child!.hitTest(result, position: transformed),
          )) {
        return true;
      }
      child = data.previousSibling;
    }
    return false;
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    var child = firstChild;
    while (child != null) {
      final data = child.parentData! as _BoardData;
      if (data.page == page) visitor(child);
      child = data.nextSibling;
    }
  }
}
