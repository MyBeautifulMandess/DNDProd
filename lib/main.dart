import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'data/catalog_loader.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DndApp());
  // Предзагрузка каталогов после первого кадра: экраны справочников
  // открываются без ожидания, запуск при этом не тормозит.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(catalogLoader.preload());
  });
}
