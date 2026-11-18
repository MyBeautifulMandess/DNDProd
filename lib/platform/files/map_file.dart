/// Чтение файла карты: платформенный слой (dart:io) за интерфейсом контроллера.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

Future<Uint8List> readMapBytes(String path) => File(path).readAsBytes();

String mapContentType(String path) => switch (p.extension(path).toLowerCase()) {
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.webp' => 'image/webp',
      _ => 'image/png',
    };
