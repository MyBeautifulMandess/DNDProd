/// Чистая геометрия игрового поля и выбор источника фона (docs/01-architecture.md).
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../core/models/room.dart';

export '../../core/field_grid.dart';

/// Размер полотна в координатах поля (без учёта зума).
Size fieldSize(GridSpec grid) => Size(
      grid.cols * grid.cellPx.toDouble(),
      grid.rows * grid.cellPx.toDouble(),
    );

Rect cellRect(GridSpec grid, int x, int y) => Rect.fromLTWH(
      x * grid.cellPx.toDouble(),
      y * grid.cellPx.toDouble(),
      grid.cellPx.toDouble(),
      grid.cellPx.toDouble(),
    );

Offset cellCenter(GridSpec grid, int x, int y) => cellRect(grid, x, y).center;

/// Прямоугольник пешки с учётом её размера в клетках.
Rect tokenRect(GridSpec grid, Token token) {
  final cell = grid.cellPx.toDouble();
  return Rect.fromLTWH(
    token.x * cell,
    token.y * cell,
    token.size * cell,
    token.size * cell,
  );
}

/// Клетка под локальной точкой полотна; `null` — точка вне сетки.
(int, int)? cellAt(Offset point, GridSpec grid) {
  if (point.dx < 0 || point.dy < 0) return null;
  final x = point.dx ~/ grid.cellPx;
  final y = point.dy ~/ grid.cellPx;
  if (x >= grid.cols || y >= grid.rows) return null;
  return (x, y);
}

/// Масштаб, при котором всё поле помещается в окно (но не увеличивается).
double fitFieldScale(Size viewport, Size world) {
  if (world.width <= 0 || world.height <= 0) return 1;
  if (viewport.width <= 0 || viewport.height <= 0) return 0.15;
  final scale = math.min(
    1.0,
    math.min(viewport.width / world.width, viewport.height / world.height),
  );
  return scale.clamp(0.15, 1.0).toDouble();
}

double clampFieldScale(double scale) => scale.clamp(0.15, 5.0).toDouble();

/// `asset:...` — фон из `assets/`, HTTP(S) — карта, отданная сервером мастера.
ImageProvider fieldImageProvider(String mapId) {
  if (mapId.startsWith('asset:')) {
    return AssetImage(mapId.substring('asset:'.length));
  }
  if (mapId.isNotEmpty) return NetworkImage(mapId);
  return const AssetImage(defaultMapAsset);
}
