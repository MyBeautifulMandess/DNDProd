import 'package:dnd_prod/core/models/catalog.dart';
import 'package:dnd_prod/core/models/character.dart';
import 'package:dnd_prod/core/rules/ability.dart';
import 'package:dnd_prod/data/catalog_loader.dart';
import 'package:dnd_prod/platform/files/file_store.dart';
import 'package:dnd_prod/player/characters/character_repository.dart';
import 'package:dnd_prod/player/sheet/character_sheet_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String classId;
  late int hitDice;
  late Spell spell;

  setUpAll(() async {
    final classes = await catalogLoader.classes();
    await catalogLoader.raceDetails();
    await catalogLoader.backgrounds();
    classId = classes.keys.first;
    hitDice = classes[classId]!.hitDiceSides;
    spell = (await catalogLoader.spells()).firstWhere((s) => s.level == 1);
  });

  Character buildCharacter() {
    final scores = {for (final ability in Ability.values) ability: 10};
    scores[Ability.strength] = 14;
    return Character(
      id: 'c1',
      name: 'Алиса',
      level: 1,
      abilityScores: scores,
      skillProficiencies: {Skill.athletics},
      saveProficiencies: {Ability.strength},
      classEntries: [ClassEntry(classId: classId, level: 1)],
      currentHp: 10,
      maxHp: 20,
      knownSpellIds: [spell.id],
      equipmentLines: ['Длинный меч'],
    );
  }

  Future<void> bringIntoView(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 20 && finder.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -350));
      await tester.pump();
    }
    await tester.ensureVisible(finder);
    await tester.pump();
  }

  Future<void> pumpSheet(
    WidgetTester tester, {
    required Character character,
    required CharacterRepository repository,
    required List<String> rolls,
    required List<String> chats,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CharacterSheetPanel(
          character: character,
          repository: repository,
          onRoll: rolls.add,
          onChat: chats.add,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('тап по характеристике отправляет проверку d20', (tester) async {
    final rolls = <String>[];
    final chats = <String>[];
    await pumpSheet(
      tester,
      character: buildCharacter(),
      repository: CharacterRepository(InMemoryFileStore()),
      rolls: rolls,
      chats: chats,
    );

    final finder = find.byKey(const ValueKey('sheet_ability_str'));
    expect(finder, findsOneWidget);
    await bringIntoView(tester, finder);
    await tester.tap(finder);
    expect(rolls, ['1к20+2']);
  });

  testWidgets('тап по владению навыком добавляет бонус мастерства',
      (tester) async {
    final rolls = <String>[];
    final chats = <String>[];
    await pumpSheet(
      tester,
      character: buildCharacter(),
      repository: CharacterRepository(InMemoryFileStore()),
      rolls: rolls,
      chats: chats,
    );

    final finder = find.byKey(const ValueKey('sheet_roll_Атлетика (str)'));
    await bringIntoView(tester, finder);
    expect(finder, findsOneWidget);
    expect(find.text('влад.'), findsWidgets);
    await tester.tap(finder);
    expect(rolls, ['1к20+4']);
  });

  testWidgets('хиты ±5 сохраняются и пишутся в чат', (tester) async {
    final rolls = <String>[];
    final chats = <String>[];
    final repository = CharacterRepository(InMemoryFileStore());
    await pumpSheet(
      tester,
      character: buildCharacter(),
      repository: repository,
      rolls: rolls,
      chats: chats,
    );

    await tester.tap(find.widgetWithText(TextButton, '+5').first);
    await tester.pumpAndSettle();

    expect(chats, hasLength(1));
    expect(chats.single, contains('Хиты Алиса: 15/20'));
    expect(find.text('15 / 20'), findsOneWidget);
    final saved = await repository.list();
    expect(saved.single.currentHp, 15);
  });

  testWidgets('кость хитов класса бросается формулой из каталога',
      (tester) async {
    final rolls = <String>[];
    final chats = <String>[];
    await pumpSheet(
      tester,
      character: buildCharacter(),
      repository: CharacterRepository(InMemoryFileStore()),
      rolls: rolls,
      chats: chats,
    );

    final finder = find.widgetWithText(FilledButton, 'Кость d$hitDice');
    expect(finder, findsOneWidget);
    await tester.tap(finder);
    expect(rolls, ['1к$hitDice']);
  });

  testWidgets('заклинания сгруппированы по кругам и «Наложить» пишет в чат',
      (tester) async {
    final rolls = <String>[];
    final chats = <String>[];
    await pumpSheet(
      tester,
      character: buildCharacter(),
      repository: CharacterRepository(InMemoryFileStore()),
      rolls: rolls,
      chats: chats,
    );

    final circle = find.text('Круг 1');
    await bringIntoView(tester, circle);
    expect(circle, findsOneWidget);
    expect(find.text(spell.nameRu), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Наложить'));
    expect(chats, contains('Заклинание: ${spell.nameRu}'));
  });
}
