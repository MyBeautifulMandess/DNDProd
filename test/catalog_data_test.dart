import 'package:dnd_prod/data/catalog_loader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('бестиарий: лёгкий индекс, полная карточка по требованию', () async {
    final monsters = await catalogLoader.monsters();
    expect(monsters.length, greaterThan(2600));
    // В списке — краткие записи из индекса: карточки ещё не разобраны.
    final summary = monsters.firstWhere(
      (monster) => monster.id == '107-ancient_red_dragon',
    );
    expect(summary.sections, isEmpty);
    expect(summary.actions, isEmpty);
    expect(summary.cr, greaterThan(0));

    final dragon = await catalogLoader.monsterDetails(summary.id);
    expect(dragon.nameRu, 'Древний красный дракон');
    expect(dragon.actions.isNotEmpty, isTrue);
    expect(dragon.legendaryActions.isNotEmpty, isTrue);
    expect(dragon.sections.any((section) => section.title == 'Действия'), isTrue);
  });

  test('бестиарий: у существ есть способности, атаки и секции', () async {
    final monsters = await catalogLoader.monsters();
    var withActions = false;
    var withTraits = false;
    // Карточки читаются шардами; для проверки хватает нескольких существ.
    for (final summary in monsters.take(40)) {
      final monster = await catalogLoader.monsterDetails(summary.id);
      withActions = withActions || monster.actions.isNotEmpty;
      withTraits = withTraits || monster.traits.isNotEmpty;
      if (withActions && withTraits) break;
    }
    expect(withActions, isTrue);
    expect(withTraits, isTrue);
  });

  test('бестиарий: неизвестное существо — понятная ошибка', () {
    expect(
      catalogLoader.monsterDetails('нет-такого-существа'),
      throwsStateError,
    );
  });

  test('у предметов есть описание и цена', () async {
    final items = await catalogLoader.items();
    expect(items, isNotEmpty);
    expect(items.every((item) => item.description.trim().isNotEmpty), isTrue);
    expect(items.any((item) => item.cost.trim().isNotEmpty), isTrue);
  });

  test('у черт есть описание и требование', () async {
    final feats = await catalogLoader.feats();
    expect(feats, isNotEmpty);
    expect(feats.every((feat) => feat.description.trim().isNotEmpty), isTrue);
    expect(feats.any((feat) => feat.prerequisite.trim().isNotEmpty), isTrue);
  });

  test('у заклинаний есть список классов', () async {
    final spells = await catalogLoader.spells();
    expect(spells, isNotEmpty);
    expect(spells.any((spell) => spell.classList.isNotEmpty), isTrue);
    expect(spells.any((spell) => spell.classList.contains('Волшебник')), isTrue);
  });
}
