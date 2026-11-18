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
