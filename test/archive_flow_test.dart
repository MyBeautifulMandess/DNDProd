import 'dart:async';

import 'package:dnd_prod/lobby/master_lobby_controller.dart';
import 'package:dnd_prod/master/archives/archive_repository.dart';
import 'package:dnd_prod/platform/files/file_store.dart';
import 'package:dnd_prod/platform/network/channel_lobby_client.dart';
import 'package:dnd_prod/platform/network/lobby_transport.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('подключение игрока автоматически сохраняет снимок в архиве мастера',
      () async {
    final store = InMemoryFileStore();
    final archive = ArchiveRepository(store, idGenerator: () => 'arch1');
    final controller = MasterLobbyController(
      onCharacterConnected: (character, playerName) {
        unawaited(archive.addSnapshot(character, playerName: playerName));
      },
    );
    await controller.start(port: 0);
    final client = ChannelLobbyClient();
    try {
      await client.connect('localhost:${controller.port}');
      client.send(const LobbyMessage(LobbyMessageType.hello, {
        'name': 'Борис',
        'character': {
          'schema_version': 1,
          'id': 'c2',
          'name': 'Борис',
          'level': 5,
        },
      }));

      List<dynamic> saved = [];
      for (var attempt = 0; attempt < 100 && saved.isEmpty; attempt++) {
        saved = await archive.list();
        if (saved.isEmpty) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      }
      expect(saved, hasLength(1));
      expect(saved.single.characterName, 'Борис');
      expect(saved.single.playerName, 'Борис');
    } finally {
      await client.close();
      await controller.stop();
    }
  }, timeout: const Timeout(Duration(seconds: 15)));
}
