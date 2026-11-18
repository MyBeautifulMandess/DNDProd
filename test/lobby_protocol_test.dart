import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:dnd_prod/core/models/room.dart';
import 'package:dnd_prod/lobby/protocol/dice_formula.dart';
import 'package:dnd_prod/lobby/protocol/lobby_codec.dart';
import 'package:dnd_prod/platform/network/lobby_transport.dart';

void main() {
  group('decodeLobbyMessage', () {
    test('корректное сообщение протокола v1', () {
      final raw = jsonEncode({
        'v': 1,
        'type': LobbyMessageType.chat,
        'payload': {'text': 'Привет'},
      });
      final message = decodeLobbyMessage(raw);
      expect(message.type, LobbyMessageType.chat);
      expect(message.payload['text'], 'Привет');
    });

    test('отклоняет другую версию, неизвестный тип и не-object payload', () {
      String raw(Object type, Object version, Object payload) => jsonEncode({
            'v': version,
            'type': type,
            'payload': payload,
          });
      expect(
        () => decodeLobbyMessage(raw(LobbyMessageType.chat, 2, const {})),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => decodeLobbyMessage(raw('unknown', 1, const {})),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => decodeLobbyMessage(raw(LobbyMessageType.chat, 1, 'not a map')),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('parseDiceFormula', () {
    test('кириллица, латиница и модификаторы', () {
      expect(parseDiceFormula('2к6+3')?.display, '2к6+3');
      expect(parseDiceFormula('1d20-1')?.display, '1к20-1');
      expect(parseDiceFormula(' d100 ')?.display, '1к100');
      expect(parseDiceFormula('2к6')?.modifier, 0);
    });

    test('мусор и неверные кубики не разбираются', () {
      expect(parseDiceFormula('к6+'), isNull);
      expect(parseDiceFormula('2к3'), isNotNull);
      expect(parseDiceFormula('1к1'), isNull);
      expect(parseDiceFormula('1к4+2к6'), isNull);
    });
  });

  group('RoomState JSON (снапшот state)', () {
    test('roundtrip: токены, игроки и открытые клетки тумана', () {
      const state = RoomState(
        adventureId: 'a1',
        mapId: 'map-1',
        grid: GridSpec(cellPx: 64, cols: 20, rows: 12),
        tokens: [
          Token(
              id: 't1',
              kind: TokenKind.player,
              owner: 'p1',
              label: 'Алиса',
              x: 3,
              y: 4,
              hp: 10,
              maxHp: 12,
              size: 2),
        ],
        players: [
          RoomPlayer(id: 'p1', name: 'Алиса', characterId: 'c1', moveOwn: false)
        ],
        revealedCells: {(1, 2), (3, 4)},
        strokes: [
          DrawStroke(
            id: 's1',
            author: 'Мастер',
            color: 0xFFC9A227,
            cells: [(1, 1), (2, 2)],
          ),
        ],
      );
      final restored = RoomState.fromJson(state.toJson());
      expect(restored.adventureId, 'a1');
      expect(restored.mapId, 'map-1');
      expect(restored.grid.cellPx, 64);
      expect(restored.tokens.single.x, 3);
      expect(restored.tokens.single.hp, 10);
      expect(restored.tokens.single.size, 2);
      expect(restored.players.single.moveOwn, isFalse);
      expect(restored.revealedCells, contains((1, 2)));
      expect(restored.revealedCells, contains((3, 4)));
      expect(restored.strokes.single.cells, [(1, 1), (2, 2)]);
      expect(restored.strokes.single.color, 0xFFC9A227);
      expect(state.toJson()['protocol'], protocolVersion);
    });
  });
}
