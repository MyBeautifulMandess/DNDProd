import 'package:dnd_prod/lobby/master_lobby_controller.dart';
import 'package:dnd_prod/master/adventures/adventures_screen.dart';
import 'package:dnd_prod/master/adventures/adventure_repository.dart';
import 'package:dnd_prod/platform/files/file_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('мастер создаёт приключение, добавляет лор и сохраняет',
      (tester) async {
    final store = InMemoryFileStore();
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => MasterLobbyController(),
      child: MaterialApp(home: AdventuresScreen(store: store)),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Пока нет приключений'), findsOneWidget);

    await tester.tap(find.text('Новое приключение'));
    await tester.pumpAndSettle();
    expect(find.text('Карты'), findsOneWidget);
    expect(find.text('Лор и ПМ'), findsOneWidget);

    await tester.tap(find.text('Лор и ПМ'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('adventure-title')), 'Мой модуль');
    await tester.tap(find.text('Страница'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(5));
    await tester.enterText(fields.at(2), 'Страж башни');
    await tester.enterText(fields.at(3), 'Стоит у двери');
    await tester.tap(find.byIcon(Icons.save_outlined));
    await tester.pumpAndSettle();

    final saved = await AdventureRepository(store).list();
    expect(saved.single.title, 'Мой модуль');
    expect(saved.single.lore.single.title, 'Страж башни');
    expect(saved.single.lore.single.text, 'Стоит у двери');

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('Мой модуль'), findsOneWidget);
  });
}
