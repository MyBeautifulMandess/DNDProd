import 'dart:convert';

import 'package:dnd_prod/core/models/adventure.dart';
import 'package:dnd_prod/core/models/room.dart';
import 'package:dnd_prod/core/rules/monster_size.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('приключение переживает JSON roundtrip со всеми частями', () {
    final map = AdventureMap(
      id: 'm1',
      name: 'Подземелье',
      imagePath: 'adventures/a1/maps/m1.png',
      tokens: [
        const Token(
          id: 'e1',
          kind: TokenKind.monster,
          label: 'Гоблин',
          catalogId: '23-goblin',
          x: 4,
          y: 5,
          hp: 7,
          maxHp: 7,
          size: 2,
        ),
      ],
      revealedCells: const {(1, 2), (3, 4)},
      strokes: [
        const DrawStroke(
            id: 's1', author: 'Мастер', color: 0xFFC9A227, cells: [(1, 1)]),
      ],
    );
    final adventure = Adventure(
      id: 'a1',
      title: 'Поиск relic',
      description: 'Описание',
      privateNotes: 'ПМ: ловушка',
      moveOwnAllowed: false,
      startMapId: 'm1',
      maps: [map],
      lore: [LorePage(id: 'l1', title: 'NPC', text: 'Имя')],
    );

    final restored =
        Adventure.fromJson(jsonDecode(jsonEncode(adventure.toJson())) as Map<String, dynamic>);

    expect(restored.id, 'a1');
    expect(restored.title, 'Поиск relic');
    expect(restored.privateNotes, 'ПМ: ловушка');
    expect(restored.moveOwnAllowed, isFalse);
    expect(restored.startMapId, 'm1');
    expect(restored.maps.single.tokens.single.hp, 7);
    expect(restored.maps.single.tokens.single.size, 2);
    expect(restored.maps.single.revealedCells, contains((1, 2)));
    expect(restored.maps.single.strokes.single.cells, [
      (1, 1)
    ]);
    expect(restored.lore.single.text, 'Имя');
  });

  test('снапшот карты пригоден для запуска комнаты', () {
    final map = AdventureMap(
      id: 'm2',
      name: 'Лес',
      tokens: [
        const Token(
            id: 'e1', kind: TokenKind.npc, label: 'Страж', x: 1, y: 1),
      ],
    );
    final state = map.roomState('a7');
    expect(state.adventureId, 'a7');
    expect(state.mapId, 'asset:$defaultMapAsset');
    expect(state.tokens.single.label, 'Страж');

    final withImage = AdventureMap(id: 'm3', name: 'Гора', imagePath: 'x.png');
    expect(withImage.roomState('a7').mapId, 'map:m3');
  });

  test('размер монстра из каталога превращается в клетки поля', () {
    expect(monsterCellSize('Маленькое?'), 1);
    expect(monsterCellSize('Средняя?'), 1);
    expect(monsterCellSize('Большое?'), 2);
    expect(monsterCellSize('Огромный?'), 3);
    expect(monsterCellSize('Громадная?'), 4);
  });
}
