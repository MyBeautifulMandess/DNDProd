import 'package:dnd_prod/core/models/character.dart';
import 'package:dnd_prod/master/archives/archive_repository.dart';
import 'package:dnd_prod/platform/files/file_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('архив: снимок, заметки и удаление', () async {
    final store = InMemoryFileStore();
    final repository =
        ArchiveRepository(store, idGenerator: () => 'arch1');
    final character = Character(
      id: 'c1',
      name: 'Алиса',
      level: 3,
      classEntries: [
        ClassEntry(classId: '91-fighter', level: 3),
      ],
    );

    final archived = await repository.addSnapshot(
      character.toJson(),
      playerName: 'Алиса',
    );
    expect(archived.id, 'arch1');
    expect(archived.characterName, 'Алиса');
    expect(archived.level, 3);
    expect(archived.snapshot['id'], 'c1');

    await repository.setNotes('arch1', 'Помнит клятву');
    final list = await repository.list();
    expect(list.single.notes, 'Помнит клятву');

    await repository.delete('arch1');
    expect(await repository.list(), isEmpty);
    expect(await store.list(), isEmpty);
  });
}
