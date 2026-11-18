import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:dnd_prod/app.dart';
import 'package:dnd_prod/core/models/character.dart';
import 'package:dnd_prod/lobby/master_lobby_controller.dart';
import 'package:dnd_prod/lobby/player_lobby_controller.dart';
import 'package:dnd_prod/master/room/lobby_host_screen.dart';
import 'package:dnd_prod/platform/files/file_store.dart';
import 'package:dnd_prod/player/characters/character_repository.dart';
import 'package:dnd_prod/player/lobby/connect_screen.dart';
import 'package:dnd_prod/shared/theme.dart';

void main() {
  testWidgets('игрок видит форму подключения и своих персонажей',
      (tester) async {
    final repository = CharacterRepository(InMemoryFileStore());
    await repository.save(Character(
      id: 'c1',
      name: 'Алиса',
      level: 1,
      currentHp: 10,
      maxHp: 12,
    ));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => PlayerLobbyController()),
          ],
          child: ConnectScreen(repository: repository),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Подключение к комнате'), findsOneWidget);
    expect(find.textContaining('Алиса'), findsWidgets);
    expect(find.text('Подключиться'), findsOneWidget);
  });

  testWidgets('мастер до запуска видит кнопку старта комнаты', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => MasterLobbyController()),
          ],
          child: const LobbyHostScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Локальная комната'), findsOneWidget);
    expect(find.text('Запустить комнату'), findsOneWidget);
  });

  testWidgets('переход из роли игрока в подключение видит провайдер',
      (tester) async {
    await tester.pumpWidget(const DndApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Игрок'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.tap(find.text('Подключение'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.byType(ConnectScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
