/// Чтение файла карты: платформенный слой (dart:io) за интерфейсом контроллера.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:path/path.dart' as p;

import '../../core/models/room.dart';
import 'file_store.dart';

Future<Uint8List> readMapBytes(String path) => File(path).readAsBytes();

/// Фон карты из хранилища приложения; пустой путь = стандартный ассет.
Future<ImageProvider> localMapImage(FileStore store, String relativePath) async {
  if (relativePath.isEmpty) return const AssetImage(defaultMapAsset);
  return MemoryImage(await store.readBytes(relativePath));
}

String mapContentType(String path) => switch (p.extension(path).toLowerCase()) {
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.webp' => 'image/webp',
      _ => 'image/png',
    };
