/// Хранение пользовательских файлов (персонажи, приключения, экспорт JSON).
/// Абстракция изолирует path_provider, чтобы ядро не зависело от платформы.
/// Реализация одна — через path_provider работает и на Windows, и на Android.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

abstract class FileStore {
  Future<String> read(String name);
  Future<void> write(String name, String contents);

  /// Бинарные файлы пользователя: фоны карт и картинки приключений.
  Future<Uint8List> readBytes(String name);
  Future<void> writeBytes(String name, Uint8List bytes);

  Future<List<String>> list();
  Future<void> delete(String name);
}

class PathProviderFileStore implements FileStore {
  Future<Directory> get _dir async => Directory(p.join((await getApplicationDocumentsDirectory()).path, 'dnd_prod'));

  Future<File> _file(String name) async => File(p.join((await _dir).path, name));

  @override
  Future<String> read(String name) async => (await _file(name)).readAsString();

  @override
  Future<void> write(String name, String contents) async {
    final file = await _file(name);
    await file.parent.create(recursive: true);
    await file.writeAsString(contents);
  }

  @override
  Future<Uint8List> readBytes(String name) async =>
      (await _file(name)).readAsBytes();

  @override
  Future<void> writeBytes(String name, Uint8List bytes) async {
    final file = await _file(name);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
  }

  @override
  Future<List<String>> list() async {
    final dir = await _dir;
    if (!await dir.exists()) return [];
    // Относительные пути с подпапками (characters/xxx.json), а не basename —
    // иначе теряется структура и репозитории не находят свои файлы.
    return dir
        .list(recursive: true)
        .where((e) => e is File)
        .map((e) => p.relative(e.path, from: dir.path))
        .toList();
  }

  @override
  Future<void> delete(String name) async => (await _file(name)).delete().ignore();
}

/// Fallback для тестов и десктоп-окружений без path_provider.
class InMemoryFileStore implements FileStore {
  final _files = <String, String>{};
  final _bytes = <String, Uint8List>{};

  @override
  Future<String> read(String name) async =>
      _files[name] ?? (throw FileSystemException('Файл не найден', name));

  @override
  Future<void> write(String name, String contents) async =>
      _files[name] = contents;

  @override
  Future<Uint8List> readBytes(String name) async =>
      _bytes[name] ?? (throw FileSystemException('Файл не найден', name));

  @override
  Future<void> writeBytes(String name, Uint8List bytes) async =>
      _bytes[name] = Uint8List.fromList(bytes);

  @override
  Future<List<String>> list() async => [..._files.keys, ..._bytes.keys];

  @override
  Future<void> delete(String name) async {
    _files.remove(name);
    _bytes.remove(name);
  }
}
