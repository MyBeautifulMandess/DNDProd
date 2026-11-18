import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dnd_prod/core/models/room.dart';
import 'package:dnd_prod/shared/field/battle_field.dart';
import 'package:dnd_prod/shared/field/field_geometry.dart';
import 'package:dnd_prod/shared/field/field_painter.dart';

void main() {
  final image = MemoryImage(base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jR0kAAAAASUVORK5CYII=',
  ));

  RoomState smallRoom() => const RoomState(
        grid: GridSpec(cellPx: 70, cols: 4, rows: 3),
        tokens: [
          Token(id: 't1', kind: TokenKind.monster, x: 3, y: 2, label: 'Гоблин'),
        ],
        revealedCells: {(0, 0)},
      );

  testWidgets('поле рисует сетку и передаёт координаты тапа', (tester) async {
    final taps = <(int, int)>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 600,
          height: 400,
          child: BattleField(
            state: smallRoom(),
            isMaster: true,
            mapImage: image,
            onCellTap: (x, y) => taps.add((x, y)),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.byTooltip('Приблизить'), findsOneWidget);
    expect(find.byTooltip('Отдалить'), findsOneWidget);
    expect(find.byTooltip('Вписать поле'), findsOneWidget);

    final center = cellCenter(smallRoom().grid, 1, 2);
    await tester.tapAt(Offset(center.dx, center.dy));
    await tester.pump();
    expect(taps, [(1, 2)]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('зум меняет масштаб, кнопка «Вписать поле» сбрасывает его',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 600,
          height: 400,
          child: BattleField(
            state: smallRoom(),
            mapImage: image,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Приблизить'));
    await tester.pumpAndSettle();
    final zoomed = tester
        .widget<Text>(find.textContaining('%').first)
        .data!;
    expect(zoomed, isNot(contains('100%')));

    await tester.tap(find.byTooltip('Вписать поле'));
    await tester.pumpAndSettle();
    expect(find.textContaining('100%'), findsOneWidget);
  });

  testWidgets('кисть, линейка и туман работают инструментами', (tester) async {
    final strokes = <List<(int, int)>>[];
    final fogCalls = <bool>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 600,
          height: 400,
          child: BattleField(
            state: smallRoom(),
            mapImage: image,
            showTools: true,
            onDraw: (cells) => strokes.add(cells.toList()),
            onFog: (cells, {required reveal}) => fogCalls.add(reveal),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    Future<void> dragCells(Offset start, List<Offset> steps) async {
      final gesture = await tester.startGesture(start);
      for (final step in steps) {
        await gesture.moveBy(step);
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();
    }

    expect(find.byTooltip('Кисть'), findsOneWidget);
    expect(find.byTooltip('Линейка'), findsOneWidget);
    expect(find.byTooltip('Туман'), findsOneWidget);

    await tester.tap(find.byTooltip('Кисть'));
    await tester.pumpAndSettle();
    await dragCells(const Offset(35, 80), const [
      Offset(70, 0),
      Offset(70, 0),
      Offset(70, 0),
    ]);
    await tester.pumpAndSettle();
    expect(strokes, hasLength(1));
    expect(strokes.single, contains((2, 1)));

    await tester.tap(find.byTooltip('Линейка'));
    await tester.pumpAndSettle();
    await dragCells(const Offset(35, 80), const [
      Offset(70, 0),
      Offset(70, 0),
      Offset(70, 0),
      Offset(0, 70),
    ]);
    await tester.pumpAndSettle();
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data ?? '')
        .toList();
    expect(
      texts.any((text) => text.contains('15 фт')),
      isTrue,
      reason: 'Тексты на поле: ${texts.join(' | ')}',
    );

    await tester.tap(find.byTooltip('Туман'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Открывать'), findsOneWidget);
    expect(find.byTooltip('Закрывать'), findsOneWidget);
    await tester.tap(find.byTooltip('Закрывать'));
    await tester.pumpAndSettle();
    await dragCells(const Offset(35, 80), const [Offset(70, 0)]);
    await tester.pumpAndSettle();
    expect(fogCalls, isNotEmpty);
    expect(fogCalls.first, isFalse);
  });

  testWidgets('пешку можно перетащить долгим нажатием', (tester) async {
    final drags = <(String, int, int)>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 600,
          height: 400,
          child: BattleField(
            state: smallRoom(),
            mapImage: image,
            isMaster: true,
            canDragToken: (_) => true,
            onTokenDrag: (id, x, y) => drags.add((id, x, y)),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(const Offset(245, 175));
    await tester.pump(const Duration(milliseconds: 700));
    await gesture.moveBy(const Offset(-70, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(drags, [('t1', 2, 2)]);
  });

  test('художник поля перерисовывается при изменении тумана', () {
    const painter = FieldPainter(
      grid: GridSpec(cellPx: 70, cols: 4, rows: 3),
      revealedCells: {},
      isMaster: false,
    );
    const same = FieldPainter(
      grid: GridSpec(cellPx: 70, cols: 4, rows: 3),
      revealedCells: {},
      isMaster: false,
    );
    const changed = FieldPainter(
      grid: GridSpec(cellPx: 70, cols: 4, rows: 3),
      revealedCells: {(1, 1)},
      isMaster: false,
    );
    expect(painter.shouldRepaint(same), isFalse);
    expect(painter.shouldRepaint(changed), isTrue);
  });
}
