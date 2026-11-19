import 'dart:typed_data';

import 'package:dnd_prod/master/adventures/adventure_editor_controller.dart';
import 'package:dnd_prod/master/adventures/adventure_repository.dart';
import 'package:dnd_prod/platform/files/file_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('редактор: карта, враг, туман, лор и ПМ сохраняются', () async {
    final store = InMemoryFileStore();
    var counter = 0;
    final repository = AdventureRepository(
      store,
      idGenerator: () => 'id${++counter}',
    );
    final controller = AdventureEditorController(
      repository,
      store,
      idGenerator: () => 'gen${++counter}',
    );

    await controller.createNew(title: 'Тест');
    controller.addMap();
    expect(controller.adventure!.maps, hasLength(1));
    expect(controller.selectedMap, isNotNull);

    await controller.importMapImage('source.png', Uint8List.fromList([1, 2]));
    expect(controller.selectedMap!.imagePath,
        'adventures/gen1/maps/gen2.png');

    controller.addMonsterToken(const MonsterTokenSpec(
      label: 'Волк',
      catalogId: '1-wolf',
      hp: 11,
      size: 1,
    ));
    final token = controller.selectedMap!.tokens.single;
    expect(token.hp, 11);
    expect(token.maxHp, 11);
    controller.updateToken(id: token.id, hp: 5);
    expect(controller.selectedMap!.tokens.single.hp, 5);

    controller.toggleFog(const [(2, 3)], reveal: true);
    expect(controller.selectedMap!.revealedCells, contains((2, 3)));
    controller.toggleFog(const [(2, 3)], reveal: false);
    expect(controller.selectedMap!.revealedCells, isEmpty);

    controller.addLorePage();
    final page = controller.adventure!.lore.single;
    controller.updateLorePage(page.id, title: 'Сюжет', text: 'Текст');
    controller.setPrivateNotes('Секрет');
    controller.setTitle('Новое имя');
    expect(await controller.save(), isTrue);

    final reloaded = AdventureEditorController(repository, store);
    await reloaded.load('gen1');
    expect(reloaded.adventure!.title, 'Новое имя');
    expect(reloaded.adventure!.privateNotes, 'Секрет');
    expect(reloaded.adventure!.lore.single.text, 'Текст');
    expect(reloaded.adventure!.maps.single.tokens.single.hp, 5);
    expect(reloaded.adventure!.startMapId, reloaded.selectedMap!.id);
  });
}
