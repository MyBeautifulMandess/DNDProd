/// Сетка и туман войны игрового поля (Canvas, docs/01-architecture.md).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/models/room.dart';
import '../../shared/theme.dart';
import 'field_geometry.dart';

class FieldPainter extends CustomPainter {
  const FieldPainter({
    required this.grid,
    required this.revealedCells,
    required this.isMaster,
  });

  final GridSpec grid;
  final Set<(int, int)> revealedCells;
  final bool isMaster;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = grid.cellPx.toDouble();
    final width = grid.cols * cell;
    final height = grid.rows * cell;

    final minor = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;
    for (var x = 1; x < grid.cols; x++) {
      canvas.drawLine(Offset(x * cell, 0), Offset(x * cell, height), minor);
    }
    for (var y = 1; y < grid.rows; y++) {
      canvas.drawLine(Offset(0, y * cell), Offset(width, y * cell), minor);
    }

    final major = Paint()
      ..color = AppTheme.gold.withValues(alpha: 0.28)
      ..strokeWidth = 1.5;
    for (var x = 5; x < grid.cols; x += 5) {
      canvas.drawLine(Offset(x * cell, 0), Offset(x * cell, height), major);
    }
    for (var y = 5; y < grid.rows; y += 5) {
      canvas.drawLine(Offset(0, y * cell), Offset(width, y * cell), major);
    }

    final fog = Paint()
      ..color = isMaster ? const Color(0x33000000) : const Color(0xE0000000)
      ..style = PaintingStyle.fill;
    for (var y = 0; y < grid.rows; y++) {
      for (var x = 0; x < grid.cols; x++) {
        if (!revealedCells.contains((x, y))) {
          canvas.drawRect(cellRect(grid, x, y), fog);
        }
      }
    }

    canvas.drawRect(
      Offset.zero & Size(width, height),
      Paint()
        ..color = AppTheme.gold.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant FieldPainter old) =>
      old.grid.cellPx != grid.cellPx ||
      old.grid.cols != grid.cols ||
      old.grid.rows != grid.rows ||
      old.isMaster != isMaster ||
      !setEquals(old.revealedCells, revealedCells);
}
