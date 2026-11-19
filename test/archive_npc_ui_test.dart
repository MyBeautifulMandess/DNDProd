import 'package:dnd_prod/master/archives/archive_repository.dart';
import 'package:dnd_prod/master/archives/archives_screen.dart';
import 'package:dnd_prod/platform/files/file_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('мастер создаёт NPC в архиве', (tester) async {
    final repository = ArchiveRepository(
      InMemoryFileStore(),
      idGenerator: () => 'npc-ui',
    );
    await tester.pumpWidget(MaterialApp(
      home: ArchivesScreen(repository: repository),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('add-npc')));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey('npc-name')), 'Страж башни');
    await tester.enterText(find.byKey(const ValueKey('npc-level')), '4');
    await tester.enterText(
        find.byKey(const ValueKey('npc-class')), 'Воин');
    await tester.enterText(
        find.byKey(const ValueKey('npc-notes')), 'Держит дверь');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(find.text('Страж башни'), findsOneWidget);
    expect(find.textContaining('NPC · 4 ур. · Воин'), findsOneWidget);

    final saved = await repository.list();
    expect(saved, hasLength(1));
    expect(saved.single.isNpc, isTrue);
    expect(saved.single.notes, 'Держит дверь');
  });
}
