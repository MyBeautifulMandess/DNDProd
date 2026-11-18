import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'lobby/master_lobby_controller.dart';
import 'lobby/player_lobby_controller.dart';
import 'shared/theme.dart';
import 'ui/role_gate.dart';

class DndApp extends StatelessWidget {
  const DndApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'D&D Помощник',
        theme: AppTheme.dark,
        // Контроллеры живут выше экранов: комната не сбрасывается при смене вкладок.
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => MasterLobbyController()),
            ChangeNotifierProvider(create: (_) => PlayerLobbyController()),
          ],
          child: const RoleGateScreen(),
        ),
        debugShowCheckedModeBanner: false,
      );
}
