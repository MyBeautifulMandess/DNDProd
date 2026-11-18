/// Чистая геометрия сетки без Flutter — используется ядром, сервером и UI.
library;

import 'dart:math' as math;

import 'models/room.dart';

/// Упрощение линейки: диагональ = 1 клетка = 5 футов (см. допущения roadmap).
const feetPerCell = 5;

/// Клетка, сдвинутая внутрь поля так, чтобы пешка размера `size` поместилась.
(int, int) clampCell((int, int) cell, GridSpec grid, {int size = 1}) => (
      cell.$1.clamp(0, math.max(0, grid.cols - size)),
      cell.$2.clamp(0, math.max(0, grid.rows - size)),
    );

/// Непрерывная линия клеток между двумя точками (алгоритм Брезенхема).
List<(int, int)> lineCells((int, int) from, (int, int) to) {
  var x = from.$1;
  var y = from.$2;
  final dx = (to.$1 - x).abs();
  final dy = -(to.$2 - y).abs();
  final stepX = x < to.$1 ? 1 : -1;
  final stepY = y < to.$2 ? 1 : -1;
  var error = dx + dy;
  final cells = <(int, int)>[];
  while (true) {
    cells.add((x, y));
    if (x == to.$1 && y == to.$2) break;
    final doubled = 2 * error;
    if (doubled >= dy) {
      error += dy;
      x += stepX;
    }
    if (doubled <= dx) {
      error += dx;
      y += stepY;
    }
  }
  return cells;
}

int rulerCells((int, int) from, (int, int) to) =>
    math.max((from.$1 - to.$1).abs(), (from.$2 - to.$2).abs());

int rulerFeet((int, int) from, (int, int) to) =>
    rulerCells(from, to) * feetPerCell;
