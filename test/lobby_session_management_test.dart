import 'dart:async';
import 'dart:typed_data';

import 'package:dnd_prod/core/models/room.dart';
import 'package:dnd_prod/lobby/lobby_map.dart';
import 'package:dnd_prod/platform/network/channel_lobby_client.dart';
import 'package:dnd_prod/platform/network/lobby_transport.dart';
import 'package:dnd_prod/platform/network/shelf_lobby_server.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('комната переключает карты, показывает картинку и архивирует персонажа',
      () async {
    final first = LobbyMap(
      key: 'm1',
      name: 'Подземелье',
      state: const RoomState(
        tokens: [
          Token(
              id: 'e1',
              kind: TokenKind.monster,
              label: 'Гоблин',
              x: 3,
              y: 4,
              hp: 7),
        ],
        revealedCells: {(1, 1)},
      ),
      imageBytes: Uint8List.fromList([1, 2, 3]),
      contentType: 'image/jpeg',
    );
    const second = LobbyMap(
      key: 'm2',
      name: 'Лес',
      state: RoomState(
        tokens: [
          Token(id: 'e2', kind: TokenKind.npc, label: 'Страж', x: 5, y: 5),
        ],
      ),
    );
    final server = ShelfLobbyServer(
      port: 0,
      maps: [first, second],
      initialMapKey: 'm1',
    );
    await server.start();
    final client = ChannelLobbyClient();
    final master = _MessageTap(server.messages);
    final player = _MessageTap(client.messages);
    try {
      expect(server.state.mapKey, 'm1');
      expect(server.state.mapId, contains('/map.png?v=1'));
      expect(server.mapChoices.map((choice) => choice.name),
          ['Подземелье', 'Лес']);

      await client.connect('localhost:${server.boundPort}');
      client.send(const LobbyMessage(LobbyMessageType.hello, {
        'name': 'Алиса',
        'character_id': 'c1',
        'character': {'id': 'c1', 'name': 'Алиса', 'level': 3},
      }));

      final character = await master.wait(LobbyMessageType.characterSnapshot);
      expect(character.payload['player_name'], 'Алиса');
      expect((character.payload['character'] as Map)['name'], 'Алиса');

      server.switchMap('m2');
      final switched = await player.wait(
        LobbyMessageType.mapSwitch,
        where: (message) => message.payload['map_key'] == 'm2',
      );
      expect(switched.payload['map_id'], startsWith('asset:'));
      final state = await player.wait(
        LobbyMessageType.state,
        where: (message) =>
            ((message.payload['state'] as Map?)?['room'] as Map?)?['map_key'] ==
            'm2',
      );
      final restored = RoomState.fromJson(
          (state.payload['state'] as Map).cast<String, dynamic>());
      expect(restored.mapKey, 'm2');
      expect(restored.tokens.map((token) => token.label),
          containsAll(['Страж', 'Алиса']));
      expect(restored.tokens.map((token) => token.label),
          isNot(contains('Гоблин')));
      expect(restored.players.single.name, 'Алиса');

      server.showImageBytes(Uint8List.fromList([9, 9]),
          contentType: 'image/png');
      expect((await player.wait(LobbyMessageType.imageShow))
          .payload['url'], contains('/image.png?'));
      expect((await master.wait(LobbyMessageType.imageShow))
          .payload['url'], contains('/image.png?'));
      server.hideImage();
      await player.wait(LobbyMessageType.imageHide);

      server.moveToken('e2', 7, 7);
      final states = server.collectMapStates();
      expect(states['m1']!.tokens.map((token) => token.label),
          contains('Гоблин'));
      expect(states['m2']!.tokens
          .firstWhere((token) => token.id == 'e2')
          .x, 7);
    } finally {
      await player.close();
      await master.close();
      await client.close();
      await server.stop();
    }
  }, timeout: const Timeout(Duration(seconds: 15)));
}

class _MessageTap {
  _MessageTap(this._stream) {
    _subscription = _stream.listen(_seen.add);
  }

  final Stream<LobbyMessage> _stream;
  final List<LobbyMessage> _seen = [];
  late final StreamSubscription<LobbyMessage> _subscription;

  Future<LobbyMessage> wait(String type,
      {bool Function(LobbyMessage)? where}) async {
    for (var attempt = 0; attempt < 400; attempt++) {
      for (final message in _seen) {
        if (message.type == type && (where == null || where(message))) {
          return message;
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('Сообщение $type не пришло (получено: ${_seen.map((m) => m.type)})');
  }

  Future<void> close() => _subscription.cancel();
}
