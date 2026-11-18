/// Список персонажей игрока: просмотр, создание, дублирование, удаление,
/// экспорт JSON в буфер обмена / импорт из буфера (docs/03-character-builder.md).
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/character.dart';
import '../../data/catalog_loader.dart';
import '../../platform/files/file_store.dart';
import '../../shared/avatar_picture.dart';
import '../builder/character_builder_screen.dart';
import 'character_detail_screen.dart';
import 'character_repository.dart';
import 'level_up_screen.dart';

class CharactersScreen extends StatefulWidget {
  const CharactersScreen({super.key});

  @override
  State<CharactersScreen> createState() => _CharactersScreenState();
}

class _CharactersScreenState extends State<CharactersScreen> {
  final CharacterRepository _repository =
      CharacterRepository(PathProviderFileStore());

  late Future<_CharactersData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_CharactersData> _load() async {
    final characters = await _repository.list();
    final raceDetails = await catalogLoader.raceDetails();
    final classes = await catalogLoader.classes();
    return _CharactersData(
      characters: characters,
      raceNames: {for (final r in raceDetails.values) r.id: r.nameRu},
      subraceNames: {
        for (final r in raceDetails.values)
          for (final s in r.subspecies) s.anchor: s.name,
      },
      classNames: {for (final c in classes.values) c.id: c.nameRu},
    );
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _open(Character character) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CharacterDetailScreen(
          character: character,
          repository: _repository,
        ),
      ),
    );
    // Экран сам сохраняет правки — список перечитываем всегда.
    _reload();
  }

  Future<void> _createCharacter() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const CharacterBuilderScreen()),
    );
    if (created ?? false) _reload();
  }

  Future<void> _duplicate(Character character) async {
    await _repository.duplicate(character.id);
    _reload();
  }

  Future<void> _levelUp(Character character) async {
    final raw = await _repository.exportJson(character.id);
    if (!mounted) return;
    final leveled = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => LevelUpScreen(
          character:
              Character.fromJson(jsonDecode(raw) as Map<String, dynamic>),
          repository: _repository,
        ),
      ),
    );
    if (leveled ?? false) _reload();
  }

  Future<void> _delete(Character character) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Удалить ${character.name}?'),
        content: const Text('Персонаж будет удалён без возможности восстановления.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await _repository.delete(character.id);
      _reload();
    }
  }

  Future<void> _exportToClipboard(Character character) async {
    final json = await _repository.exportJson(character.id);
    await Clipboard.setData(ClipboardData(text: json));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${character.name}: JSON скопирован в буфер')),
      );
    }
  }

  Future<void> _importFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty || !text.startsWith('{')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('В буфере нет JSON персонажа')),
        );
      }
      return;
    }
    try {
      await _repository.importJson(text);
      _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Персонаж импортирован')),
        );
      }
    } on FormatException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось разобрать JSON персонажа')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<_CharactersData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Ошибка загрузки: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          if (data.characters.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Персонажей пока нет'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _createCharacter,
                    icon: const Icon(Icons.add),
                    label: const Text('Создать персонажа'),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              itemCount: data.characters.length,
              itemBuilder: (context, index) => _CharacterCard(
                character: data.characters[index],
                data: data,
                onOpen: () => _open(data.characters[index]),
                onLevelUp: () => _levelUp(data.characters[index]),
                onDuplicate: () => _duplicate(data.characters[index]),
                onDelete: () => _delete(data.characters[index]),
                onExport: () => _exportToClipboard(data.characters[index]),
              ),
            ),
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'import_character',
            tooltip: 'Импорт из буфера',
            onPressed: _importFromClipboard,
            child: const Icon(Icons.content_paste),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'create_character',
            tooltip: 'Создать персонажа',
            onPressed: _createCharacter,
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

class _CharactersData {
  _CharactersData({
    required this.characters,
    required this.raceNames,
    required this.subraceNames,
    required this.classNames,
  });

  final List<Character> characters;
  final Map<String, String> raceNames;
  final Map<String, String> subraceNames;
  final Map<String, String> classNames;

  String raceLine(Character character) {
    final race = raceNames[character.raceId] ?? 'Раса?';
    final sub = character.subraceId == null
        ? null
        : subraceNames[character.subraceId];
    return sub == null ? race : '$race ($sub)';
  }

  String classLine(Character character) {
    if (character.classEntries.isEmpty) return 'Класс?';
    final entry = character.classEntries.first;
    final name = classNames[entry.classId] ?? entry.classId;
    return '$name, ${entry.level} ур.';
  }
}

class _CharacterCard extends StatelessWidget {
  const _CharacterCard({
    required this.character,
    required this.data,
    required this.onOpen,
    required this.onLevelUp,
    required this.onDuplicate,
    required this.onDelete,
    required this.onExport,
  });

  final Character character;
  final _CharactersData data;
  final VoidCallback onOpen;
  final VoidCallback onLevelUp;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              AvatarPicture(path: character.avatarPath),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(character.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      '${data.raceLine(character)} · ${data.classLine(character)}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Хиты ${character.currentHp}/${character.maxHp}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'level_up':
                      if (character.classEntries.isNotEmpty &&
                          character.classEntries.first.level < 20) {
                        onLevelUp();
                      }
                    case 'duplicate':
                      onDuplicate();
                    case 'export':
                      onExport();
                    case 'delete':
                      onDelete();
                  }
                },
                itemBuilder: (context) => [
                  if (character.classEntries.isNotEmpty &&
                      character.classEntries.first.level < 20)
                    const PopupMenuItem(
                      value: 'level_up',
                      child: Text('Повысить уровень'),
                    ),
                  const PopupMenuItem(
                    value: 'duplicate',
                    child: Text('Дублировать'),
                  ),
                  const PopupMenuItem(
                    value: 'export',
                    child: Text('Экспорт JSON'),
                  ),
                  const PopupMenuItem(value: 'delete', child: Text('Удалить')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
