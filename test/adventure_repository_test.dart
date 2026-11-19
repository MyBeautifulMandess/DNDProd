import 'dart:typed_data';

import 'package:dnd_prod/core/models/adventure.dart';
import 'package:dnd_prod/master/adventures/adventure_repository.dart';
import 'package:dnd_prod/platform/files/file_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('репозиторий: создание, список, правка и удаление с файлом карты',
      () async {
    final store = InMemoryFileStore();
    var counter = 0;
    final repository = AdventureRepository(
      store,
      idGenerator: () => 'id${++counter}',
    );

    final adventure = Adventure(id: 'id1', title: 'Первое');
    final map = AdventureMap(id: 'map1', name: 'Карта');
    adventure.maps.add(map);
    adventure.startMapId = map.id;
    await repository.save(adventure);
    map.imagePath =
        await repository.importMapImage('id1', 'map1', 'photo.jpg', Uint8List.fromList([1, 2, 3]));
    await repository.save(adventure);

    final listed = await repository.list();
    expect(listed.single.title, 'Первое');
    expect(listed.single.maps.single.imagePath,
        'adventures/id1/maps/map1.jpg');
    expect(await repository.mapBytes(listed.single.maps.single), [1, 2, 3]);
    expect(repository.contentType(listed.single.maps.single), 'image/jpeg');

    adventure.title = 'Переименовано';
    await repository.save(adventure);
    expect((await repository.byId('id1')).title, 'Переименовано');

    await repository.delete('id1');
    expect(await repository.list(), isEmpty);
    expect(await store.list(), isEmpty);
  });

  test('репозиторий: дублирование копирует изображения карт', () async {
    final store = InMemoryFileStore();
    var counter = 1;
    final repository = AdventureRepository(
      store,
      idGenerator: () => 'id${++counter}',
    );
    final adventure = Adventure(id: 'id1', title: 'Оригинал');
    final map = AdventureMap(id: 'map1', name: 'Карта');
    adventure.maps.add(map);
    adventure.startMapId = map.id;
    await repository.save(adventure);
    map.imagePath = await repository.importMapImage(
        'id1', 'map1', 'map.png', Uint8List.fromList([9, 8, 7]));
    await repository.save(adventure);

    final copy = await repository.duplicate('id1');
    expect(copy.id, 'id2');
    expect(copy.title, 'Оригинал (копия)');
    expect(copy.maps.single.imagePath, 'adventures/id2/maps/map1.png');
    expect(await repository.mapBytes(copy.maps.single), [9, 8, 7]);

    await repository.delete('id1');
    expect((await repository.byId('id2')).maps.single.imagePath,
        'adventures/id2/maps/map1.png');
    expect(await repository.mapBytes((await repository.byId('id2')).maps.single),
        [9, 8, 7]);
  });

  test('репозиторий пропускает битые файлы', () async {
    final store = InMemoryFileStore();
    await store.write('adventures/bad.json', '{не json');
    final repository = AdventureRepository(store);
    expect(await repository.list(), isEmpty);
  });
}
