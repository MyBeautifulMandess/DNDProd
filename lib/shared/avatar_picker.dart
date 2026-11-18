/// Выбор аватара персонажа: пресеты из ассетов + импорт своей картинки.
/// Используется билдером и экраном персонажа (docs/03-character-builder.md).
library;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const Color _gold = Color(0xFFC9A227);

/// Пресеты аватарок, зашитые в приложение (assets/2d/ui).
const List<String> kAvatarPresetAssets = <String>[
  'assets/2d/ui/avatar_default.png',
  'assets/2d/ui/tab_player.png',
  'assets/2d/ui/tab_dm.png',
  'assets/2d/ui/app_icon.png',
];

/// Импорт своей аватарки: выбор картинки, копия в Документы/dnd_prod/avatars.
/// Возвращает путь к копии; null — пользователь отменил выбор.
/// Ошибки пробрасываются вызывающему (показ SnackBar — на нём).
Future<String?> importCustomAvatar() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    allowMultiple: false,
  );
  final sourcePath = result?.files.single.path;
  if (sourcePath == null) return null;
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory(p.join(docs.path, 'dnd_prod', 'avatars'));
  await dir.create(recursive: true);
  final target = p.join(
    dir.path,
    '${DateTime.now().millisecondsSinceEpoch}${p.extension(sourcePath)}',
  );
  await File(sourcePath).copy(target);
  return target;
}

/// Bottom sheet с пресетами и импортом. Возвращает выбранный путь
/// (asset-путь или путь файла) либо null, если выбор не сделан.
Future<String?> showAvatarPickerSheet(
  BuildContext context, {
  String? current,
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final asset in kAvatarPresetAssets)
              _AvatarOption(
                asset: asset,
                selected: current == asset,
                onTap: () => Navigator.of(sheetContext).pop(asset),
              ),
            _AvatarOption(
              asset: null,
              selected: current != null &&
                  current.isNotEmpty &&
                  !current.startsWith('assets/'),
              onTap: () async {
                try {
                  final path = await importCustomAvatar();
                  if (sheetContext.mounted) {
                    Navigator.of(sheetContext).pop(path);
                  }
                } catch (_) {
                  if (sheetContext.mounted) {
                    Navigator.of(sheetContext).pop();
                  }
                }
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _AvatarOption extends StatelessWidget {
  const _AvatarOption({
    required this.asset,
    required this.selected,
    required this.onTap,
  });

  /// null — карточка импорта своей картинки.
  final String? asset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final asset = this.asset;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? _gold : Colors.white.withValues(alpha: 0.16),
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: asset == null
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined, size: 28),
                  SizedBox(height: 2),
                  Text('Своя', style: TextStyle(fontSize: 11)),
                ],
              )
            : Image.asset(
                asset,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.image_not_supported_outlined,
                ),
              ),
      ),
    );
  }
}
