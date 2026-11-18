/// Общее игровое поле: фон, сетка, туман, пешки, рисование, линейка и зум.
/// Жесты и фигуры — кроссплатформенные (InteractiveViewer + CustomPainter).
library;

import 'package:flutter/material.dart';

import '../../core/models/room.dart';
import '../theme.dart';
import 'field_geometry.dart';
import 'field_painter.dart';

enum FieldTool { select, draw, ruler, fog }

class BattleField extends StatefulWidget {
  const BattleField({
    super.key,
    required this.state,
    this.selectedTokenId,
    this.isMaster = false,
    this.onCellTap,
    this.onTokenTap,
    this.onTokenDrag,
    this.canDragToken,
    this.onDraw,
    this.onFog,
    this.showTools = false,
    this.mapImage,
    this.height = 360,
  });

  final RoomState state;
  final String? selectedTokenId;
  final bool isMaster;
  final void Function(int x, int y)? onCellTap;
  final void Function(String tokenId)? onTokenTap;
  final void Function(String tokenId, int x, int y)? onTokenDrag;
  final bool Function(Token token)? canDragToken;
  final void Function(Iterable<(int, int)> cells)? onDraw;
  final void Function(Iterable<(int, int)> cells, {required bool reveal})? onFog;
  final bool showTools;

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

  FieldTool _tool = FieldTool.select;
  bool _fogReveal = true;
  ((int, int), (int, int))? _ruler;
  (String, (int, int))? _drag;
  Offset? _dragStartLocal;
  (int, int)? _dragLastCell;
  (int, int)? _strokeLast;
  final List<(int, int)> _strokeBuffer = [];

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

  void _startTool((int, int) cell) {
    if (_tool == FieldTool.ruler) {
      _ruler = (cell, cell);
    } else if (_tool == FieldTool.draw) {
      _strokeBuffer
        ..clear()
        ..add(cell);
    } else if (_tool == FieldTool.fog) {
      widget.onFog?.call([cell], reveal: _fogReveal);
    }
    _strokeLast = cell;
    setState(() {});
  }

  void _updateTool((int, int) cell) {
    final last = _strokeLast;
    if (last == null || last == cell) return;
    switch (_tool) {
      case FieldTool.ruler:
        _ruler = (_ruler!.$1, cell);
      case FieldTool.draw:
        _strokeBuffer.addAll(lineCells(last, cell).skip(1));
      case FieldTool.fog:
        widget.onFog?.call(lineCells(last, cell).skip(1), reveal: _fogReveal);
      case FieldTool.select:
        return;
    }
    _strokeLast = cell;
    setState(() {});
  }

  void _endTool() {
    if (_tool == FieldTool.draw && _strokeBuffer.isNotEmpty) {
      widget.onDraw?.call(List<(int, int)>.of(_strokeBuffer));
      _strokeBuffer.clear();
    }
    _strokeLast = null;
  }

  void _startTokenDrag(String tokenId, Token token, Offset local) {
    if (_tool != FieldTool.select ||
        widget.canDragToken?.call(token) != true) {
      return;
    }
    _drag = (tokenId, (token.x, token.y));
    _dragStartLocal = local;
    _dragLastCell = (token.x, token.y);
    setState(() {});
  }

  void _updateTokenDrag(String tokenId, Token token, Offset local) {
    final drag = _drag;
    final startLocal = _dragStartLocal;
    if (drag == null || drag.$1 != tokenId || startLocal == null) return;
    final delta = local - startLocal;
    final cellPx = widget.state.grid.cellPx;
    final target = clampCell(
      (
        drag.$2.$1 + (delta.dx / cellPx).round(),
        drag.$2.$2 + (delta.dy / cellPx).round(),
      ),
      widget.state.grid,
      size: token.size,
    );
    if (target == _dragLastCell) return;
    _dragLastCell = target;
    widget.onTokenDrag?.call(tokenId, target.$1, target.$2);
    setState(() {});
  }

  void _endTokenDrag() {
    if (_drag == null) return;
    _drag = null;
    _dragStartLocal = null;
    _dragLastCell = null;
    setState(() {});
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
        final fitKey =
            '${viewport.width}x${viewport.height}/${grid.cols}x${grid.rows}';
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
                  panEnabled: _tool == FieldTool.select && _drag == null,
                  onInteractionUpdate: (_) => _userAdjusted = true,
                  child: SizedBox(
                    width: world.width,
                    height: world.height,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: _tool == FieldTool.select
                          ? (details) {
                              final cell = cellAt(details.localPosition, grid);
                              if (cell != null) {
                                widget.onCellTap?.call(cell.$1, cell.$2);
                              }
                            }
                          : null,
                      onPanDown: _tool == FieldTool.select
                          ? null
                          : (details) {
                              final cell = cellAt(details.localPosition, grid);
                              if (cell != null) _startTool(cell);
                            },
                      onPanUpdate: _tool == FieldTool.select
                          ? null
                          : (details) {
                              final cell = cellAt(details.localPosition, grid);
                              if (cell != null) _updateTool(cell);
                            },
                      onPanEnd: _tool == FieldTool.select ? null : (_) => _endTool(),
                      onPanCancel:
                          _tool == FieldTool.select ? null : _endTool,
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
                                strokes: widget.state.strokes,
                                ruler: _ruler,
                              ),
                            ),
                          ),
                          if (_ruler != null) _rulerLabel(grid),
                          for (final token in widget.state.tokens)
                            _token(token, grid),
                        ],
                      ),
                    ),
                  ),
                ),
                if (widget.showTools)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Material(
                      borderRadius: BorderRadius.circular(8),
                      color: AppTheme.surface.withValues(alpha: 0.9),
                      child: Wrap(
                        children: [
                          _toolButton(Icons.touch_app, 'Указатель',
                              FieldTool.select),
                          if (widget.onDraw != null) ...[
                            _toolButton(
                                Icons.brush, 'Кисть', FieldTool.draw),
                            _toolButton(Icons.straighten, 'Линейка',
                                FieldTool.ruler),
                          ],
                          if (widget.onFog != null)
                            _toolButton(
                                Icons.blur_on, 'Туман', FieldTool.fog),
                          if (_tool == FieldTool.fog) ...[
                            _fogButton(Icons.visibility, 'Открывать', true),
                            _fogButton(Icons.visibility_off, 'Закрывать', false),
                          ],
                        ],
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
                        _zoomButton(
                            Icons.zoom_in, 'Приблизить', () => _zoom(1.25)),
                        _zoomButton(
                            Icons.zoom_out, 'Отдалить', () => _zoom(0.8)),
                        _zoomButton(Icons.center_focus_strong, 'Вписать поле',
                            () {
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

  Widget _toolButton(IconData icon, String tooltip, FieldTool tool) => SizedBox(
        width: 44,
        height: 44,
        child: IconButton(
          icon: Icon(icon),
          color: _tool == tool ? AppTheme.gold : null,
          tooltip: tooltip,
          onPressed: () => setState(() {
            _tool = tool;
            _strokeLast = null;
            if (tool != FieldTool.ruler) _ruler = null;
            _strokeBuffer.clear();
          }),
        ),
      );

  Widget _fogButton(IconData icon, String tooltip, bool reveal) => SizedBox(
        width: 44,
        height: 44,
        child: IconButton(
          icon: Icon(icon),
          color: _fogReveal == reveal ? AppTheme.gold : null,
          tooltip: tooltip,
          onPressed: () => setState(() => _fogReveal = reveal),
        ),
      );

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

  Widget _rulerLabel(GridSpec grid) {
    final ruler = _ruler!;
    final start = cellCenter(grid, ruler.$1.$1, ruler.$1.$2);
    final end = cellCenter(grid, ruler.$2.$1, ruler.$2.$2);
    return Positioned(
      left: (start.dx + end.dx) / 2 - 60,
      top: (start.dy + end.dy) / 2 - 36,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '${rulerCells(ruler.$1, ruler.$2)} кл · '
          '${rulerFeet(ruler.$1, ruler.$2)} фт',
          style: const TextStyle(color: AppTheme.gold, fontSize: 12),
        ),
      ),
    );
  }

  Widget _token(Token token, GridSpec grid) {
    final revealed = widget.isMaster ||
        widget.state.revealedCells.contains((token.x, token.y)) ||
        widget.state.revealedCells
            .any((cell) => cell.$1 >= token.x && cell.$1 < token.x + token.size && cell.$2 >= token.y && cell.$2 < token.y + token.size);
    if (!revealed) return const SizedBox.shrink();
    final rect = tokenRect(grid, token).deflate(grid.cellPx * 0.12 / token.size);
    final color = switch (token.kind) {
      TokenKind.player => AppTheme.gold,
      TokenKind.monster => Colors.redAccent,
      TokenKind.npc => Colors.tealAccent,
    };
    final selected = token.id == widget.selectedTokenId;
    final dragging = _drag?.$1 == token.id;
    final draggable = widget.canDragToken?.call(token) ?? false;
    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: GestureDetector(
        onTap: () => widget.onTokenTap?.call(token.id),
        onLongPressStart: draggable && _tool == FieldTool.select
            ? (details) => _startTokenDrag(token.id, token, details.localPosition)
            : null,
        onLongPressMoveUpdate: draggable && _tool == FieldTool.select
            ? (details) =>
                _updateTokenDrag(token.id, token, details.localPosition)
            : null,
        onLongPressEnd: draggable && _tool == FieldTool.select
            ? (_) => _endTokenDrag()
            : null,
        onLongPressCancel: draggable && _tool == FieldTool.select
            ? _endTokenDrag
            : null,
        child: AnimatedScale(
          scale: dragging ? 1.1 : 1,
          duration: const Duration(milliseconds: 120),
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
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 14 + 4 * token.size.toDouble(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
