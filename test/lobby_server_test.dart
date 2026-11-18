import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:dnd_prod/core/models/room.dart';
import 'package:dnd_prod/core/rules/dice.dart';
import 'package:dnd_prod/lobby/lobby_log.dart';
import 'package:dnd_prod/platform/network/channel_lobby_client.dart';
import 'package:dnd_prod/platform/network/lobby_transport.dart';
import 'package:dnd_prod/platform/network/shelf_lobby_server.dart';

/// Интеграционный сценарий из docs/06-lobby-network.md: 1 сервер + 2 клиента.
void main() {
  late ShelfLobbyServer server;
  late ChannelLobbyClient alice;
  late ChannelLobbyClient bob;
  late _MessageTap masterTap;
  late _MessageTap aliceTap;
  late _MessageTap bobTap;

  RoomState snapshot(LobbyMessage message) => RoomState.fromJson(
      (message.payload['state'] as Map).cast<String, dynamic>());

  Future<void> join(ChannelLobbyClient client, String name) async {
    client.send(LobbyMessage(LobbyMessageType.hello, {
      'name': name,
      'character_id': 'c-$name',
    }));
  }

  setUp(() async {
    server = ShelfLobbyServer(port: 0, roller: DiceRoller(Random(42)));
    await server.start();
    masterTap = _MessageTap(server.messages);
    alice = ChannelLobbyClient();
    await alice.connect('localhost:${server.boundPort}');
    aliceTap = _MessageTap(alice.messages);
    bob = ChannelLobbyClient();
    await bob.connect('localhost:${server.boundPort}');
    bobTap = _MessageTap(bob.messages);
  });

  tearDown(() async {
    await aliceTap.close();
    await bobTap.close();
    await masterTap.close();
    await alice.close();
    await bob.close();
    await server.stop();
  });

  test('hello → welcome и общий снапшот комнаты', () async {
    await join(alice, 'Алиса');
    final welcome = await aliceTap.wait(LobbyMessageType.welcome);
    expect(welcome.payload['player_id'], 'p1');
    expect(snapshot(welcome).tokens.single.owner, 'p1');

    await join(bob, 'Борис');
    final bobWelcome = await bobTap.wait(LobbyMessageType.welcome);
    expect(bobWelcome.payload['player_id'], 'p2');
    final state = await bobTap.wait(
      LobbyMessageType.state,
      where: (message) => snapshot(message).players.length == 2,
    );
    expect(snapshot(state).tokens.length, 2);
    expect(snapshot(state).players.map((p) => p.name),
        containsAll(['Алиса', 'Борис']));
    await masterTap.wait(
      LobbyMessageType.state,
      where: (message) => snapshot(message).players.length == 2,
    );
  }, timeout: const Timeout(Duration(seconds: 15)));

  test('игрок двигает только свою пешку', () async {
    await join(alice, 'Алиса');
    await join(bob, 'Борис');
    final state = await aliceTap.wait(
      LobbyMessageType.state,
      where: (message) => snapshot(message).players.length == 2,
    );
    final own =
        snapshot(state).tokens.firstWhere((token) => token.owner == 'p1');

    alice.send(LobbyMessage(LobbyMessageType.tokenMove, {
      'id': own.id,
      'x': 4,
      'y': 5,
    }));
    final moved = await bobTap.wait(
      LobbyMessageType.state,
      where: (message) =>
          snapshot(message).tokens.any((token) => token.x == 4 && token.y == 5),
    );
    expect(
        snapshot(moved).tokens.firstWhere((token) => token.id == own.id).x, 4);

    bob.send(LobbyMessage(LobbyMessageType.tokenMove, {
      'id': own.id,
      'x': 9,
      'y': 9,
    }));
    final error = await bobTap.wait(LobbyMessageType.error);
    expect(error.payload['message'], contains('чужую'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final last = snapshot(
        bobTap.seen.where((m) => m.type == LobbyMessageType.state).last);
    expect(last.tokens.firstWhere((token) => token.id == own.id).x, 4);
  }, timeout: const Timeout(Duration(seconds: 15)));

  test('чат доставляется всем, скрытый бросок — только мастеру', () async {
    await join(alice, 'Алиса');
    await join(bob, 'Борис');

    alice.send(
        const LobbyMessage(LobbyMessageType.chat, {'text': 'Привет всем'}));
    final chat = await bobTap.wait(
      LobbyMessageType.chat,
      where: (message) =>
          (message.payload['entry'] as Map)['text'] == 'Привет всем',
    );
    expect(
        LobbyLogEntry.fromJson(
                (chat.payload['entry'] as Map).cast<String, dynamic>())
            .author,
        'Алиса');
    await masterTap.wait(
      LobbyMessageType.chat,
      where: (message) =>
          (message.payload['entry'] as Map)['text'] == 'Привет всем',
    );

    final expected = DiceRoller(Random(42)).rollDice(2, 6, modifier: 3).total;
    alice.send(const LobbyMessage(LobbyMessageType.roll, {
      'formula': '2к6+3',
      'hidden': true,
    }));
    final hidden = await masterTap.wait(LobbyMessageType.roll);
    final entry = LobbyLogEntry.fromJson(
        (hidden.payload['entry'] as Map).cast<String, dynamic>());
    expect(entry.kind, LobbyLogKind.hiddenRoll);
    expect(entry.total, expected);
    expect(entry.formula, '2к6+3');
    await bobTap.wait(
      LobbyMessageType.chat,
      where: (message) => (message.payload['entry'] as Map)['text']
          .toString()
          .contains('скрытый бросок'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(
        bobTap.seen.where((message) => message.type == LobbyMessageType.roll),
        isEmpty);
  }, timeout: const Timeout(Duration(seconds: 15)));

  test('отключение игрока убирает его из комнаты', () async {
    await join(alice, 'Алиса');
    await join(bob, 'Борис');
    await bob.close();
    final state = await aliceTap.wait(
      LobbyMessageType.state,
      where: (message) => snapshot(message).players.length == 1,
    );
    expect(snapshot(state).tokens.length, 1);
    expect(snapshot(state).players.single.name, 'Алиса');
  }, timeout: const Timeout(Duration(seconds: 15)));
}

class _MessageTap {
  _MessageTap(this._stream) {
    _subscription = _stream.listen(_seen.add);
  }

  final Stream<LobbyMessage> _stream;
  final List<LobbyMessage> _seen = [];
  late final StreamSubscription<LobbyMessage> _subscription;

  List<LobbyMessage> get seen => List.unmodifiable(_seen);

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
    fail(
        'Сообщение $type не пришло за 4 c (получено: ${_seen.map((m) => m.type).join(', ')})');
  }

  Future<void> close() => _subscription.cancel();
}
