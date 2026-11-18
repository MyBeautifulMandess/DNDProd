/// Простая общая сетка комнаты: клетки, пешки и туман (полное поле — фаза 4).
library;

import 'package:flutter/material.dart';

import '../../core/models/room.dart';
import '../theme.dart';

class TokenGrid extends StatelessWidget {
  const TokenGrid({
    super.key,
    required this.state,
    required this.onCellTap,
    this.selectedId,
    this.isMaster = false,
    this.height = 340,
  });

  final RoomState state;
  final void Function(int x, int y) onCellTap;
  final String? selectedId;
  final bool isMaster;
  final double height;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final grid = state.grid;
          final cell =
              (constraints.maxWidth / grid.cols).clamp(48.0, 78.0).toDouble();
          final tokens = {
            for (final token in state.tokens) (token.x, token.y): token,
          };
          return SizedBox(
            height: height,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var y = 0; y < grid.rows; y++)
                      Row(
                        children: [
                          for (var x = 0; x < grid.cols; x++)
                            _cell(x, y, tokens[(x, y)], cell),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      );

  Widget _cell(int x, int y, Token? token, double cell) {
    final revealed = isMaster || state.revealedCells.contains((x, y));
    final selected = token != null && token.id == selectedId;
    final tokenColor = switch (token?.kind) {
      TokenKind.player => AppTheme.gold,
      TokenKind.monster => Colors.redAccent,
      _ => Colors.tealAccent,
    };
    return SizedBox(
      width: cell,
      height: cell,
      child: InkWell(
        onTap: () => onCellTap(x, y),
        child: Container(
          decoration: BoxDecoration(
            color: (x + y).isEven
                ? const Color(0xFF242424)
                : const Color(0xFF1F1F1F),
            border:
                Border.all(color: selected ? AppTheme.gold : Colors.white12),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (token != null && revealed)
                CircleAvatar(
                  backgroundColor: tokenColor,
                  foregroundColor: Colors.black87,
                  radius: cell / 3,
                  child: Text(
                    token.label.isEmpty ? '?' : token.label[0].toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              if (!revealed)
                Container(color: isMaster ? Colors.black26 : Colors.black87),
              if (token != null && revealed && cell >= 64)
                Positioned(
                  bottom: 1,
                  child: Text(
                    token.label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 9, color: Colors.white70),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
