import 'dart:convert';

import 'package:dnd_prod/core/models/room.dart';
import 'package:dnd_prod/data/catalog_loader.dart';
import 'package:dnd_prod/lobby/master_lobby_controller.dart';
import 'package:dnd_prod/master/room/quick_load.dart';
import 'package:dnd_prod/master/room/quick_load_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CatalogLoader _catalogs() => CatalogLoader(assetLoader: (key) async {
      switch (key) {
        case 'data/catalogs/_bestiary_index.json':
          return jsonEncode([
            {
              'url': 'https://dnd.su/bestiary/1-goblin/',
              'name_ru': 'Гоблин',
              'name_en': 'Goblin',
              'size': 'Маленькое?',
              'cr': '1/2',
              'shard': 0,
            },
          ]);
        case 'data/catalogs/bestiary_00.json':
          return jsonEncode([
            {
              'url': 'https://dnd.su/bestiary/1-goblin/',
              'name_ru': 'Гоблин',
              'name_en': 'Goblin',
              'size': 'Маленькое?',
              'hp': 22,
              'ac': 15,
            },
          ]);
        case 'data/catalogs/items_5e14.json':
          return jsonEncode([
            {
              'url': 'https://dnd.su/items/1-sword/',
              'name_ru': 'Меч',
              'name_en': 'Sword',
              'rarity': 'обычный',
              'kind': 'оружие',
              'description': 'Клинок с надписью.',
            },
          ]);
        case 'data/catalogs/spells_5e14.json':
          return jsonEncode([
            {
              'url': 'https://dnd.su/spells/1-fireball/',
              'name_ru': 'Огненный шар',
              'name_en': 'Fireball',
              'level': 3,
              'school': 'Воплощение',
              'description': 'Взрыв пламени.',
            },
          ]);
        default:
          return '[]';
      }
    });

Future<bool> _waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (condition()) return true;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  return condition();
}

void main() {
  test('поиск ищет по всем каталогам и уважает фильтр', () async {
    final catalogs = _catalogs();
    final monsters = await catalogs.monsters();
    final items = await catalogs.items();
    final spells = await catalogs.spells();

    final all = searchQuickLoad(
        monsters: monsters, items: items, spells: spells);
    expect(all.map((entry) => entry.label), ['Гоблин', 'Меч', 'Огненный шар']);

    final found = searchQuickLoad(
        monsters: monsters,
        items: items,
        spells: spells,
        query: 'огнен');
    expect(found, hasLength(1));
    expect(found.single.kind, QuickLoadKind.spell);

    final onlyItems = searchQuickLoad(
        monsters: monsters,
        items: items,
        spells: spells,
        kind: QuickLoadKind.item);
    expect(onlyItems.single.label, 'Меч');
  });

  test('текст в чат берётся из каталога, монстр даёт только пешку', () async {
    final catalogs = _catalogs();
    final monsters = await catalogs.monsters();
    final items = await catalogs.items();
    final spells = await catalogs.spells();

    final monster = QuickLoadSelection(QuickLoadKind.monster, monsters.single);
    final item = QuickLoadSelection(QuickLoadKind.item, items.single);
    final spell = QuickLoadSelection(QuickLoadKind.spell, spells.single);

    expect(quickLoadChatText(monster), isEmpty);
    expect(quickLoadChatText(item), contains('Меч'));
    expect(quickLoadChatText(item), contains('обычный'));
    expect(quickLoadChatText(item), contains('Клинок с надписью.'));
    expect(quickLoadChatText(spell), contains('Огненный шар'));
    expect(quickLoadChatText(spell), contains('3 круг'));
    expect(quickLoadChatText(spell), contains('Взрыв пламени.'));
    final token = quickLoadToken(await catalogs.monsterDetails(monsters.single.id));
    expect(token.label, 'Гоблин');
    expect(token.size, 1);
    expect(token.hp, 22);
  });

  test('сервис ставит пешку и пишет в чат запущенной комнаты', () async {
    final catalogs = _catalogs();
    final monsters = await catalogs.monsters();
    final items = await catalogs.items();
    final controller = MasterLobbyController();
    await controller.start(port: 0);
    try {
      final service = QuickLoadService(controller, catalogs: catalogs);
      await service.load(QuickLoadSelection(QuickLoadKind.monster, monsters.single));
      expect(await _waitUntil(() => controller.state.tokens.isNotEmpty), isTrue);
      final token = controller.state.tokens.single;
      expect(token.label, 'Гоблин');
      expect(token.kind, TokenKind.monster);
      expect(token.size, 1);
      expect(token.hp, 22);

      await service.load(QuickLoadSelection(QuickLoadKind.item, items.single));
      expect(
        await _waitUntil(
            () => controller.log.any((entry) => entry.text.contains('Меч'))),
        isTrue,
      );
      expect(controller.log.last.text, contains('Клинок с надписью.'));
    } finally {
      await controller.stop();
    }
  }, timeout: const Timeout(Duration(seconds: 15)));

  testWidgets('лист подгрузки ищет и возвращает выбранную запись', (tester) async {
    final catalogs = _catalogs();
    QuickLoadSelection? picked;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              picked = await showQuickLoadSheet(context, catalogs: catalogs);
            },
            child: const Text('Открыть подгрузку'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Открыть подгрузку'));
    await tester.pumpAndSettle();
    expect(find.text('Поиск по справочникам'), findsOneWidget);

    await tester.enterText(
        find.byKey(const ValueKey('quick-load-search')), 'гоб');
    await tester.pumpAndSettle();
    expect(find.text('Гоблин'), findsOneWidget);

    await tester.tap(find.text('Гоблин'));
    await tester.pumpAndSettle();
    expect(picked, isNotNull);
    expect(picked!.kind, QuickLoadKind.monster);
    expect(picked!.label, 'Гоблин');
  });
}
