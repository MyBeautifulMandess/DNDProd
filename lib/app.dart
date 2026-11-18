import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'lobby/master_lobby_controller.dart';
import 'lobby/player_lobby_controller.dart';
import 'shared/theme.dart';
import 'ui/role_gate.dart';

class DndApp extends StatelessWidget {
  const DndApp({super.key});

  @override
  Widget build(BuildContext context) => MultiProvider(
        // Провайдеры выше MaterialApp: ролевые экраны открываются новыми маршрутами
        // через Navigator, поэтому в `home` они были бы недоступны.
        providers: [
          ChangeNotifierProvider(create: (_) => MasterLobbyController()),
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
