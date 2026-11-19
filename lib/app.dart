import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'lobby/master_lobby_controller.dart';
import 'lobby/player_lobby_controller.dart';
import 'master/archives/archive_repository.dart';
import 'platform/files/file_store.dart';
import 'shared/theme.dart';
import 'ui/role_gate.dart';

class DndApp extends StatelessWidget {
  const DndApp({super.key});

  @override
  Widget build(BuildContext context) => MultiProvider(
        // Провайдеры выше MaterialApp: ролевые экраны открываются новыми маршрутами
        // через Navigator, поэтому в `home` они были бы недоступны.
        providers: [
          ChangeNotifierProvider(create: (_) {
            final archive = ArchiveRepository(PathProviderFileStore());
            return MasterLobbyController(
              onCharacterConnected: (character, playerName) {
                unawaited(
                  archive.addSnapshot(character, playerName: playerName),
                );
              },
            );
          }),
          ChangeNotifierProvider(create: (_) => PlayerLobbyController()),
        ],
        child: MaterialApp(
          title: 'D&D Помощник',
          theme: AppTheme.dark,
          home: const RoleGateScreen(),
          debugShowCheckedModeBanner: false,
        ),
      );
}
