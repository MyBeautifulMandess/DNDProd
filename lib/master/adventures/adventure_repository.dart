/// Хранение приключений мастера: один JSON на приключение и файлы карт рядом.
/// Пути относительные — FileStore работает одинаково на Windows, Android и macOS.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../core/models/adventure.dart';
import '../../platform/files/file_store.dart';
import '../../platform/files/map_file.dart';

class AdventureRepository {
  AdventureRepository(this._store, {String Function()? idGenerator})
      : _idGenerator = idGenerator ?? _defaultId;

  final FileStore _store;
  final String Function() _idGenerator;

  static const _dir = 'adventures';
  static const _extension = '.json';

  static String _name(String id) => '$_dir/$id$_extension';

  /// Файл фона карты лежит в папке приключения, чтобы копирование/удаление
  /// приключения не затрагивало другие.
  static String mapPath(String adventureId, String mapId, String fileName) =>
      '$_dir/$adventureId/maps/$mapId${p.extension(fileName)}';

  static String _defaultId() =>
      'a${DateTime.now().microsecondsSinceEpoch}${Random().nextInt(999999).toString().padLeft(6, '0')}';

  Future<List<Adventure>> list() async {
    final names = await _store.list();
    final result = <Adventure>[];
    for (final name in names) {
      final normalized = name.replaceAll('\\', '/');
      if (!normalized.startsWith('$_dir/') ||
          !normalized.endsWith(_extension)) {
        continue;
      }
      try {
        result.add(
            Adventure.fromJson(jsonDecode(await _store.read(name)) as Map<String, dynamic>));
      } on FormatException {
        continue;
      } on TypeError {
        continue;
      }
    }
    result.sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
    return result;
  }

  Future<Adventure> save(Adventure adventure) async {
    adventure.updatedAtMs = DateTime.now().millisecondsSinceEpoch;
    if (adventure.maps.isNotEmpty &&
        !adventure.maps.any((map) => map.id == adventure.startMapId)) {
      adventure.startMapId = adventure.maps.first.id;
    }
    await _store.write(
      _name(adventure.id),
      jsonEncode(adventure.toJson()),
    );
    return adventure;
  }

  Future<Adventure> byId(String id) async =>
      Adventure.fromJson(jsonDecode(await _store.read(_name(id))) as Map<String, dynamic>);

  Future<void> delete(String id) async {
    Adventure? adventure;
    try {
      adventure = await byId(id);
    } on Exception {
      adventure = null;
    }
    for (final map in adventure?.maps ?? const <AdventureMap>[]) {
      if (map.imagePath.isNotEmpty) {
        await _store.delete(map.imagePath);
      }
    }
    await _store.delete(_name(id));
  }

  /// Копия приключения вместе с файлами карт; id, названия и заметки новые.
  Future<Adventure> duplicate(String id) async {
    final source = await byId(id);
    final copy = Adventure.fromJson(jsonDecode(jsonEncode(source.toJson())) as Map<String, dynamic>)
      ..id = _idGenerator()
      ..title = '${source.title} (копия)'
      ..startMapId = source.startMapId;
    for (final map in copy.maps) {
      if (map.imagePath.isEmpty) continue;
      final bytes = await _store.readBytes(map.imagePath);
      final newPath = mapPath(copy.id, map.id, map.imagePath);
      await _store.writeBytes(newPath, bytes);
      map.imagePath = newPath;
    }
    return save(copy);
  }

  /// Сохранить выбранный пользователем файл как фон карты и вернуть путь.
  Future<String> importMapImage(
    String adventureId,
    String mapId,
    String sourcePath,
    Uint8List bytes,
  ) async {
    final path = mapPath(adventureId, mapId, sourcePath);
    await _store.writeBytes(path, bytes);
    return path;
  }

  Future<Uint8List> mapBytes(AdventureMap map) =>
      _store.readBytes(map.imagePath);

  String contentType(AdventureMap map) => mapContentType(map.imagePath);
}
