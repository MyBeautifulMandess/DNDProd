import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Хранение пользовательских файлов (персонажи, приключения, экспорт JSON).
/// Абстракция изолирует path_provider, чтобы ядро не зависело от платформы.
/// Реализация одна — через path_provider работает и на Windows, и на Android.
library;

abstract class FileStore {
  Future<String> read(String name);
  Future<void> write(String name, String contents);
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
  Future<List<String>> list() async {
    final dir = await _dir;
    if (!await dir.exists()) return [];
    return dir.list().where((e) => e is File).map((e) => p.basename(e.path)).toList();
  }

  @override
  Future<void> delete(String name) async => (await _file(name)).delete().ignore();
}

/// Fallback для тестов и десктоп-окружений без path_provider.
class InMemoryFileStore implements FileStore {
  final _files = <String, String>{};

  @override
  Future<String> read(String name) async => _files[name] ?? (throw FileSystemException('Файл не найден', name));

  @override
  Future<void> write(String name, String contents) async => _files[name] = contents;

  @override
  Future<List<String>> list() async => _files.keys.toList();

  @override
  Future<void> delete(String name) async => _files.remove(name);
}
