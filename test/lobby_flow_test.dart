import 'package:flutter_test/flutter_test.dart';

import 'package:dnd_prod/lobby/master_lobby_controller.dart';
import 'package:dnd_prod/lobby/player_lobby_controller.dart';

/// Сквозной сценарий на уровне контроллеров, которые использует UI.
void main() {
  test('мастер поднимает комнату, игрок подключается и обменивается событиями',
      () async {
    final master = MasterLobbyController();
    final player = PlayerLobbyController();
    await master.start(port: 0);
    addTearDown(() async {
      await player.disconnect();
      await master.stop();
      player.dispose();
      master.dispose();
    });

    await player.connect(
      address: 'localhost:${master.port}',
      name: 'Алиса',
      characterId: 'c1',
      hp: 10,
      maxHp: 12,
    );
    for (var attempt = 0; attempt < 200 && !player.connected; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    expect(player.connected, isTrue);
    expect(player.playerId, 'p1');
    expect(player.state!.players.single.name, 'Алиса');
    expect(master.state.players.single.name, 'Алиса');
    expect(master.state.tokens.single.hp, 10);

    final tokenId = master.state.tokens.single.id;
    player.sendChat('Привет, мастер');
    for (var attempt = 0;
        attempt < 200 &&
            !master.log.any((entry) => entry.text == 'Привет, мастер');
        attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(master.log.any((entry) => entry.text == 'Привет, мастер'), isTrue);

    master.moveToken(tokenId, 7, 8);
    for (var attempt = 0;
        attempt < 200 && player.state!.tokens.single.x != 7;
        attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(player.state!.tokens.single.x, 7);
    expect(player.state!.tokens.single.y, 8);

    await player.disconnect();
    for (var attempt = 0;
        attempt < 200 && master.state.players.isNotEmpty;
        attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(master.state.players, isEmpty);
  }, timeout: const Timeout(Duration(seconds: 15)));
}
