import 'package:dnd_prod/data/catalog_loader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('в бестиарии есть атаки, способности и секции', () async {
    final monsters = await catalogLoader.monsters();
    expect(monsters, isNotEmpty);
    expect(monsters.any((monster) => monster.actions.isNotEmpty), isTrue);
    expect(monsters.any((monster) => monster.traits.isNotEmpty), isTrue);
    expect(
      monsters.any(
        (monster) => monster.sections.any((section) => section.title == 'Действия'),
      ),
      isTrue,
    );
    expect(
      monsters.any((monster) => monster.legendaryActions.isNotEmpty),
      isTrue,
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
