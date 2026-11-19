import 'dart:typed_data';

import 'package:dnd_prod/core/models/room.dart';
import 'package:dnd_prod/platform/network/channel_lobby_client.dart';
import 'package:dnd_prod/platform/network/lobby_transport.dart';
import 'package:dnd_prod/platform/network/shelf_lobby_server.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('комната стартует из подготовленной карты приключения', () async {
    const prepared = RoomState(
      adventureId: 'a1',
      tokens: [
        Token(
          id: 'e1',
          kind: TokenKind.monster,
          label: 'Гоблин',
          x: 5,
          y: 6,
          hp: 7,
          maxHp: 7,
        ),
      ],
      revealedCells: {(1, 1)},
    );
    final server = ShelfLobbyServer(
      port: 0,
      initialState: prepared,
      mapBytes: Uint8List.fromList([1, 2, 3]),
      mapContentType: 'image/jpeg',
      moveOwnAllowed: false,
    );
    await server.start();
    final client = ChannelLobbyClient();
    try {
      expect(server.state.adventureId, 'a1');
      expect(server.state.tokens.single.label, 'Гоблин');
      expect(server.moveOwnAllowed, isFalse);
      expect(server.state.mapId, contains('/map.png?v=1'));

      await client.connect('localhost:${server.boundPort}');
      client.send(const LobbyMessage(LobbyMessageType.hello, {
        'name': 'Игрок',
      }));
      final welcome = await client.messages
          .firstWhere((message) => message.type == LobbyMessageType.welcome);
      final state = RoomState.fromJson(
          (welcome.payload['state'] as Map).cast<String, dynamic>());
      expect(state.tokens.map((token) => token.label),
          containsAll(['Гоблин', 'Игрок']));
      expect(state.revealedCells, contains((1, 1)));
      expect(state.players.single.moveOwn, isFalse);
    } finally {
      await client.close();
      await server.stop();
    }
  }, timeout: const Timeout(Duration(seconds: 15)));
}
