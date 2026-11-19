/// Архив персонажей мастера: снимки подключившихся игроков + заметки.
/// Один JSON на снимок, файлы лежат рядом с приключениями в Documents/dnd_prod.
library;

import 'dart:convert';
import 'dart:math';

import '../../core/models/character.dart';
import '../../data/catalog_loader.dart';
import '../../platform/files/file_store.dart';
import 'archived_character.dart';

class ArchiveRepository {
  ArchiveRepository(this._store, {String Function()? idGenerator})
      : _idGenerator = idGenerator ?? _defaultId;

  final FileStore _store;
  final String Function() _idGenerator;

  static const _dir = 'archive/characters';
  static const _extension = '.json';

  static String _name(String id) => '$_dir/$id$_extension';

  static String _defaultId() =>
      'ch${DateTime.now().microsecondsSinceEpoch}${Random().nextInt(999999).toString().padLeft(6, '0')}';

  Future<List<ArchivedCharacter>> list() async {
    final names = await _store.list();
    final result = <ArchivedCharacter>[];
    for (final name in names) {
      final normalized = name.replaceAll('\\', '/');
      if (!normalized.startsWith('$_dir/') ||
          !normalized.endsWith(_extension)) {
        continue;
      }
      try {
        result.add(ArchivedCharacter.fromJson(
            jsonDecode(await _store.read(name)) as Map<String, dynamic>));
      } on FormatException {
        continue;
      } on TypeError {
        continue;
      }
    }
    result.sort((a, b) => b.archivedAtMs.compareTo(a.archivedAtMs));
    return result;
  }

  /// Сохранить копию персонажа, присланную игроком при подключении.
  Future<ArchivedCharacter> addSnapshot(
    Map<String, dynamic> character, {
    required String playerName,
  }) async {
    String name = character['name'] as String? ?? 'Персонаж';
    int level = character['level'] as int? ?? 1;
    String classNames = '';
    try {
      final parsed = Character.fromJson(character);
      name = parsed.name;
      level = parsed.level;
      final classes = await catalogLoader.classes();
      classNames = parsed.classEntries
          .map((entry) => classes[entry.classId]?.nameRu ?? entry.classId)
          .join(', ');
    } on Object {
      // Битый/неполный снимок всё равно сохраняем как есть.
    }
    final archived = ArchivedCharacter(
      id: _idGenerator(),
      characterName: name,
      playerName: playerName,
      level: level,
      classNames: classNames,
      snapshot: Map<String, dynamic>.from(character),
      archivedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await _write(archived);
    return archived;
  }

  /// Создать NPC мастера: имя, уровень, класс/роль и заметки.
  Future<ArchivedCharacter> addNpc({
    required String name,
    int level = 1,
    String classNames = '',
    String notes = '',
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Имя NPC не может быть пустым');
    }
    final archived = ArchivedCharacter(
      id: _idGenerator(),
      characterName: trimmed,
      playerName: '',
      level: level < 1 ? 1 : level,
      classNames: classNames.trim(),
      notes: notes.trim(),
      snapshot: const <String, dynamic>{},
      archivedAtMs: DateTime.now().millisecondsSinceEpoch,
      origin: ArchivedCharacter.originNpc,
    );
    await _write(archived);
    return archived;
  }

  Future<void> setNotes(String id, String notes) async {
    final archived = ArchivedCharacter.fromJson(
        jsonDecode(await _store.read(_name(id))) as Map<String, dynamic>)
      ..notes = notes;
    await _write(archived);
  }

  Future<void> delete(String id) => _store.delete(_name(id));

  Future<void> _write(ArchivedCharacter archived) =>
      _store.write(_name(archived.id), jsonEncode(archived.toJson()));
}
