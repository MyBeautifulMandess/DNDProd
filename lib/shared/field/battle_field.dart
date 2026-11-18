/// Общее игровое поле: фон карты, сетка, туман, пешки, панорама и зум.
/// Жесты и фигуры — кроссплатформенные (InteractiveViewer + CustomPainter).
library;

import 'package:flutter/material.dart';

import '../../core/models/room.dart';
import '../theme.dart';
import 'field_geometry.dart';
import 'field_painter.dart';

class BattleField extends StatefulWidget {
  const BattleField({
    super.key,
    required this.state,
    this.selectedTokenId,
    this.isMaster = false,
    this.onCellTap,
    this.onTokenTap,
    this.mapImage,
    this.height = 360,
  });

  final RoomState state;
  final String? selectedTokenId;
  final bool isMaster;
  final void Function(int x, int y)? onCellTap;
  final void Function(String tokenId)? onTokenTap;

  /// Подмена источника фона (в тестах); в бою берётся из `state.mapId`.
  final ImageProvider? mapImage;
  final double height;

  @override
  State<BattleField> createState() => _BattleFieldState();
}

class _BattleFieldState extends State<BattleField> {
  final TransformationController _transform = TransformationController();
  Size _viewport = Size.zero;
  String? _fitKey;
  bool _userAdjusted = false;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _fit() {
    final scale = fitFieldScale(_viewport, fieldSize(widget.state.grid));
    _transform.value = Matrix4.diagonal3Values(scale, scale, 1);
  }

  void _zoom(double factor) {
    final matrix = _transform.value.clone();
    final current = matrix.getMaxScaleOnAxis();
    final target = clampFieldScale(current * factor);
    if (target == current) return;
    final ratio = target / current;
    final translation = matrix.getTranslation();
    final center = Offset(_viewport.width / 2, _viewport.height / 2);
    final moved =
        center - (center - Offset(translation.x, translation.y)) * ratio;
    _userAdjusted = true;
    final result = Matrix4.translationValues(moved.dx, moved.dy, 0);
    result.multiply(Matrix4.diagonal3Values(target, target, 1));
    _transform.value = result;
  }

  @override
  Widget build(BuildContext context) {
    final grid = widget.state.grid;
    final world = fieldSize(grid);
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Size(
          constraints.hasBoundedWidth ? constraints.maxWidth : 600,
          widget.height,
        );
        final fitKey = '${viewport.width}x${viewport.height}/${grid.cols}x${grid.rows}';
        if (!_userAdjusted && fitKey != _fitKey) {
          _fitKey = fitKey;
          _viewport = viewport;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_userAdjusted) _fit();
          });
        } else {
          _viewport = viewport;
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: widget.height,
            width: double.infinity,
            child: Stack(
              children: [
                InteractiveViewer(
                  transformationController: _transform,
                  constrained: false,
                  boundaryMargin: const EdgeInsets.all(80),
                  minScale: 0.15,
                  maxScale: 5,
                  onInteractionUpdate: (_) => _userAdjusted = true,
                  child: SizedBox(
                    width: world.width,
                    height: world.height,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) {
                        final cell = cellAt(details.localPosition, grid);
                        if (cell != null) {
                          widget.onCellTap?.call(cell.$1, cell.$2);
                        }
                      },
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Image(
                              image: widget.mapImage ??
                                  fieldImageProvider(widget.state.mapId),
                              width: world.width,
                              height: world.height,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stack) => Container(
                                color: const Color(0xFF242424),
                                alignment: Alignment.center,
                                child: const Text(
                                  'Фон карты недоступен',
                                  style: TextStyle(color: Colors.white54),
                                ),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: CustomPaint(
                              painter: FieldPainter(
                                grid: grid,
                                revealedCells: widget.state.revealedCells,
                                isMaster: widget.isMaster,
                              ),
                            ),
                          ),
                          for (final token in widget.state.tokens)
                            _token(token, grid),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Material(
                    borderRadius: BorderRadius.circular(8),
                    color: AppTheme.surface.withValues(alpha: 0.9),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _zoomButton(Icons.zoom_in, 'Приблизить', () => _zoom(1.25)),
                        _zoomButton(Icons.zoom_out, 'Отдалить', () => _zoom(0.8)),
                        _zoomButton(Icons.center_focus_strong, 'Вписать поле', () {
                          _userAdjusted = false;
                          _fit();
                        }),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: AnimatedBuilder(
                    animation: _transform,
                    builder: (context, _) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.surface.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${grid.cols}×${grid.rows} клеток · '
                        '${(_transform.value.getMaxScaleOnAxis() * 100).round()}%',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _zoomButton(IconData icon, String tooltip, VoidCallback onPressed) =>
      SizedBox(
        width: 44,
        height: 44,
        child: IconButton(
          icon: Icon(icon),
          tooltip: tooltip,
          onPressed: onPressed,
        ),
      );

  Widget _token(Token token, GridSpec grid) {
    final revealed = widget.isMaster ||
        widget.state.revealedCells.contains((token.x, token.y));
    if (!revealed) return const SizedBox.shrink();
    final cell = grid.cellPx.toDouble();
    final rect = cellRect(grid, token.x, token.y).deflate(cell * 0.12);
    final color = switch (token.kind) {
      TokenKind.player => AppTheme.gold,
      TokenKind.monster => Colors.redAccent,
      TokenKind.npc => Colors.tealAccent,
    };
    final selected = token.id == widget.selectedTokenId;
    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: GestureDetector(
        onTap: () => widget.onTokenTap?.call(token.id),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: selected
                ? Border.all(color: Colors.white, width: 3)
                : Border.all(color: Colors.black54, width: 1),
          ),
          alignment: Alignment.center,
          child: Text(
            token.label.isEmpty ? '?' : token.label[0].toUpperCase(),
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}
