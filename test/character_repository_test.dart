import 'package:dnd_prod/core/models/character.dart';
import 'package:dnd_prod/platform/files/file_store.dart';
import 'package:dnd_prod/player/characters/character_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Character _hero(String id, String name) => Character(
      id: id,
      name: name,
      level: 3,
      raceId: '78-dwarf',
      maxHp: 28,
      currentHp: 20,
    );

void main() {
  late InMemoryFileStore store;
  late CharacterRepository repo;
  var seq = 0;

  setUp(() {
    store = InMemoryFileStore();
    seq = 0;
    repo = CharacterRepository(store, idGenerator: () => 'new${++seq}');
  });

  test('пустое хранилище возвращает пустой список', () async {
    expect(await repo.list(), isEmpty);
  });

  test('save/list возвращает персонажа с полями', () async {
    await repo.save(_hero('c1', 'Бруенор'));
    final all = await repo.list();
    expect(all, hasLength(1));
    expect(all.single.name, 'Бруенор');
    expect(all.single.level, 3);
    expect(all.single.raceId, '78-dwarf');
    expect(all.single.currentHp, 20);
  });

  test('duplicate создаёт копию с новым id и именем', () async {
    await repo.save(_hero('c1', 'Бруенор'));
    final copy = await repo.duplicate('c1');
    expect(copy.id, isNot('c1'));
    expect(copy.name, 'Бруенор (копия)');
    expect(copy.level, 3);
    expect(await repo.list(), hasLength(2));
  });

  test('delete удаляет персонажа', () async {
    await repo.save(_hero('c1', 'А'));
    await repo.save(_hero('c2', 'Б'));
    await repo.delete('c1');
    final all = await repo.list();
    expect(all, hasLength(1));
    expect(all.single.id, 'c2');
  });

  test('export/import roundtrip сохраняет данные', () async {
    final hero = _hero('c1', 'Бруенор')..knownSpellIds.add('115-fireball');
    await repo.save(hero);
    final raw = await repo.exportJson('c1');
    final restored = await repo.importJson(raw);
    expect(restored.id, isNot('c1')); // id занят — выдан новый
    expect(restored.name, 'Бруенор');
    expect(restored.knownSpellIds, ['115-fireball']);
  });

  test('import чужого JSON не затирает существующего с тем же id', () async {
    await repo.save(_hero('c1', 'Оригинал'));
    final imported = await repo.importJson(
      '{"schema_version":1,"id":"c1","name":"Пришелец","level":1,"race_id":null,'
      '"subrace_id":null,"background_id":null,"avatar_path":null,"notes":"",'
      '"ability_scores":{"str":10,"dex":10,"con":10,"int":10,"wis":10,"cha":10},'
      '"skill_proficiencies":[],"save_proficiencies":[],"classes":[],'
      '"current_hp":1,"max_hp":1,"temp_hp":0}',
    );
    expect(imported.id, isNot('c1'));
    final all = await repo.list();
    expect(all, hasLength(2));
    expect(all.map((c) => c.name), containsAll(['Оригинал', 'Пришелец']));
  });

  test('битый JSON в хранилище пропускается', () async {
    await repo.save(_hero('c1', 'А'));
    await store.write('characters/broken.json', '{not json');
    final all = await repo.list();
    expect(all, hasLength(1));
  });

  test('list() видит файлы с обратным слэшем (реализации FileStore на Windows)', () async {
    await repo.save(_hero('c1', 'Бруенор'));
    // Имитируем list(), отдающий пути с '\' (PathProviderFileStore на Windows).
    final raw = await store.read('characters/c1.json');
    await store.delete('characters/c1.json');
    await store.write('characters\\c1.json', raw);
    final all = await repo.list();
    expect(all, hasLength(1));
    expect(all.single.name, 'Бруенор');
  });

  test('json roundtrip модели персонажа с новыми полями', () {
    final hero = Character(
      id: 'c1',
      name: 'Тест',
      level: 1,
      knownSpellIds: ['1-acid-splash'],
      equipmentLines: ['кольчуга'],
      languages: ['Дварфийский'],
    );
    final restored = Character.fromJson(hero.toJson());
    expect(restored.knownSpellIds, ['1-acid-splash']);
    expect(restored.equipmentLines, ['кольчуга']);
    expect(restored.languages, ['Дварфийский']);
  });
}
