import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dnd_prod/core/models/room.dart';
import 'package:dnd_prod/shared/field/field_geometry.dart';

void main() {
  const grid = GridSpec(cellPx: 70, cols: 30, rows: 20);

  test('полотно и клетки считаются из сетки', () {
    expect(fieldSize(grid), const Size(2100, 1400));
    expect(cellRect(grid, 2, 3), const Rect.fromLTWH(140, 210, 70, 70));
    expect(cellCenter(grid, 2, 3), const Offset(175, 245));
  });

  test('клетка вне поля не определяется', () {
    expect(cellAt(const Offset(139, 209), grid), (1, 2));
    expect(cellAt(const Offset(140, 210), grid), (2, 3));
    expect(cellAt(const Offset(-1, 10), grid), isNull);
    expect(cellAt(const Offset(2100, 10), grid), isNull);
    expect(cellAt(const Offset(10, 1400), grid), isNull);
  });

  test('зум вписывает поле, но не увеличивает его', () {
    expect(fitFieldScale(const Size(600, 400), fieldSize(grid)), closeTo(0.285, 0.001));
    expect(fitFieldScale(const Size(4000, 3000), fieldSize(grid)), 1);
    expect(clampFieldScale(9), 5);
    expect(clampFieldScale(0.01), 0.15);
  });

  test('источник фона: ассет, HTTP или стандартная карта', () {
    expect(fieldImageProvider('asset:assets/maps/grid_basic.jpg'),
        isA<AssetImage>());
    expect(fieldImageProvider('http://127.0.0.1:7777/map.png?v=1'),
        isA<NetworkImage>());
    expect(fieldImageProvider(''), isA<AssetImage>());
  });

  test('пешка размера 2 не выходит за край поля', () {
    expect(clampCell((29, 19), grid, size: 2), (28, 18));
    expect(clampCell((-3, 25), grid, size: 1), (0, 19));
    expect(tokenRect(
      grid,
      const Token(id: 't', kind: TokenKind.npc, x: 2, y: 3, size: 2),
    ), const Rect.fromLTWH(140, 210, 140, 140));
  });

  test('линия клеток непрерывна, линейка считает клетки и футы', () {
    expect(lineCells((0, 0), (3, 2)), [
      (0, 0),
      (1, 1),
      (2, 1),
      (3, 2),
    ]);
    expect(rulerCells((1, 1), (4, 3)), 3);
    expect(rulerFeet((1, 1), (4, 3)), 15);
    expect(rulerFeet((2, 2), (2, 2)), 0);
  });
}
