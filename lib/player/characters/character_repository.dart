/// Хранение персонажей игрока: JSON-файлы через FileStore (docs/03-character-builder.md).
/// Один файл на персонажа: characters/<id>.json. Публичное API не зависит от платформы.
library;

import 'dart:convert';
import 'dart:math';

import '../../core/models/character.dart';
import '../../platform/files/file_store.dart';

class CharacterRepository {
  CharacterRepository(this._store, {String Function()? idGenerator})
      : _idGenerator = idGenerator ?? _defaultId;

  final FileStore _store;
  final String Function() _idGenerator;

  static const _dir = 'characters';
  static const _extension = '.json';

  static String _name(String id) => '$_dir/$id$_extension';

  static String _defaultId() =>
      'c${DateTime.now().microsecondsSinceEpoch}${Random().nextInt(999999).toString().padLeft(6, '0')}';

  /// Все сохранённые персонажи. Битые файлы пропускаются (не ломают список).
  Future<List<Character>> list() async {
    final names = await _store.list();
    final result = <Character>[];
    for (final name in names) {
      // Нормализация сепаратора: реализации FileStore могут отдавать '\' (Windows).
      final normalized = name.replaceAll('\\', '/');
      if (!normalized.startsWith('$_dir/') || !normalized.endsWith(_extension)) {
        continue;
      }
      try {
        result.add(Character.fromJson(jsonDecode(await _store.read(name)) as Map<String, dynamic>));
      } on FormatException {
        continue;
      } on TypeError {
        continue;
      }
    }
    result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result;
  }

  Future<Character> save(Character character) async {
    await _store.write(_name(character.id), jsonEncode(character.toJson()));
    return character;
  }

  Future<void> delete(String id) => _store.delete(_name(id));

  /// Копия персонажа с новым id; имя получает суффикс «(копия)».
  Future<Character> duplicate(String id) async {
    final source = await _byId(id);
    final copy = Character.fromJson(jsonDecode(jsonEncode(source.toJson())) as Map<String, dynamic>)
      ..id = _idGenerator()
      ..name = '${source.name} (копия)';
    return save(copy);
  }

  /// Экспорт персонажа в JSON-строку (файл или share — на усмотрение вызывающего).
  Future<String> exportJson(String id) async => jsonEncode((await _byId(id)).toJson());

  /// Импорт из JSON-строки. Если id уже занят — выдаётся новый id.
  Future<Character> importJson(String raw) async {
    final character = Character.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    final existing = await list();
    if (existing.any((c) => c.id == character.id)) {
      character.id = _idGenerator();
    }
    return save(character);
  }

  Future<Character> _byId(String id) async {
    final raw = await _store.read(_name(id));
    return Character.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}
