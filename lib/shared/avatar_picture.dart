/// Аватар персонажа: из ассетов приложения ('assets/…') или файла на устройстве
/// (пользовательская картинка, импортированная в документы).
library;

import 'dart:io';

import 'package:flutter/material.dart';

class AvatarPicture extends StatelessWidget {
  const AvatarPicture({super.key, required this.path, this.size = 76});

  final String? path;
  final double size;

  @override
  Widget build(BuildContext context) {
    final path = this.path;
    final fallback = CircleAvatar(
      radius: size / 2,
      child: const Icon(Icons.person),
    );
    if (path == null || path.isEmpty) return fallback;

    if (path.startsWith('assets/')) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: AssetImage(path),
        onBackgroundImageError: (_, __) {},
      );
    }

    final file = File(path);
    if (!file.existsSync()) return fallback;
    return CircleAvatar(
      radius: size / 2,
      backgroundImage: FileImage(file),
      onBackgroundImageError: (_, __) {},
    );
  }
}
