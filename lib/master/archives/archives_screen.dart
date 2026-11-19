/// Экран архива персонажей мастера: снимки игроков и заметки.
library;

import 'package:flutter/material.dart';

import '../../platform/files/file_store.dart';
import 'archive_repository.dart';
import 'archived_character.dart';

class ArchivesScreen extends StatefulWidget {
  const ArchivesScreen({super.key, this.repository});

  final ArchiveRepository? repository;

  @override
  State<ArchivesScreen> createState() => _ArchivesScreenState();
}

class _ArchivesScreenState extends State<ArchivesScreen> {
  late final ArchiveRepository _repository;
  late Future<List<ArchivedCharacter>> _future;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ?? ArchiveRepository(PathProviderFileStore());
    _future = _repository.list();
  }

  void _reload() {
    setState(() {
      _future = _repository.list();
    });
  }

  Future<void> _delete(ArchivedCharacter archived) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить запись?'),
        content: Text('«${archived.characterName}» будет удалён из архива.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Удалить')),
        ],
      ),
    );
    if (confirm != true) return;
    await _repository.delete(archived.id);
    _reload();
  }

  Future<void> _addNpc() async {
    final result = await showDialog<_NpcFormResult>(
      context: context,
      builder: (context) => const _NpcDialog(),
    );
    if (result == null) return;
    await _repository.addNpc(
      name: result.name,
      level: result.level,
      classNames: result.classNames,
      notes: result.notes,
    );
    if (!mounted) return;
    _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Архивы персонажей')),
        floatingActionButton: FloatingActionButton.extended(
          key: const ValueKey('add-npc'),
          onPressed: _addNpc,
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Добавить NPC'),
        ),
        body: FutureBuilder<List<ArchivedCharacter>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Ошибка загрузки: ${snapshot.error}'));
            }
            final archived = snapshot.data ?? const <ArchivedCharacter>[];
            if (archived.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Снимки появятся здесь, когда игроки подключатся '
                    'к вашим комнатам. Кнопка «Добавить NPC» создаёт запись '
                    'мастера.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: archived.length,
              itemBuilder: (context, index) {
                final item = archived[index];
                final date = DateTime.fromMillisecondsSinceEpoch(
                    item.archivedAtMs).toLocal();
                final hp = item.snapshot['current_hp'];
                final maxHp = item.snapshot['max_hp'];
                final classSuffix =
                    item.classNames.isEmpty ? '' : ' · ${item.classNames}';
                return Card(
                  child: ExpansionTile(
                    leading: Icon(
                      item.isNpc ? Icons.person_outline : Icons.badge_outlined,
                      color: Colors.amber,
                    ),
                    title: Text(item.characterName),
                    subtitle: Text(item.isNpc
                        ? 'NPC · ${item.level} ур.$classSuffix'
                        : '${item.playerName} · ${item.level} ур.$classSuffix'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Снимок от ${date.toString().substring(0, 16)}'
                              '${hp == null ? '' : ' · ХП $hp/$maxHp'}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.white70),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              key: ValueKey('archive-note-${item.id}'),
                              initialValue: item.notes,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                labelText: 'Заметки мастера',
                                alignLabelWithHint: true,
                              ),
                              onChanged: (value) =>
                                  _repository.setNotes(item.id, value),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () => _delete(item),
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Удалить запись'),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      );
}

class _NpcFormResult {
  const _NpcFormResult({
    required this.name,
    required this.level,
    required this.classNames,
    required this.notes,
  });

  final String name;
  final int level;
  final String classNames;
  final String notes;
}

class _NpcDialog extends StatefulWidget {
  const _NpcDialog();

  @override
  State<_NpcDialog> createState() => _NpcDialogState();
}

class _NpcDialogState extends State<_NpcDialog> {
  final _name = TextEditingController();
  final _level = TextEditingController(text: '1');
  final _classNames = TextEditingController();
  final _notes = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _level.dispose();
    _classNames.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(_NpcFormResult(
      name: name,
      level: int.tryParse(_level.text.trim()) ?? 1,
      classNames: _classNames.text,
      notes: _notes.text,
    ));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Новый NPC'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const ValueKey('npc-name'),
                controller: _name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Имя'),
              ),
              TextField(
                key: const ValueKey('npc-level'),
                controller: _level,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Уровень'),
              ),
              TextField(
                key: const ValueKey('npc-class'),
                controller: _classNames,
                decoration: const InputDecoration(labelText: 'Класс или роль'),
              ),
              TextField(
                key: const ValueKey('npc-notes'),
                controller: _notes,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Заметки мастера',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена')),
          FilledButton(onPressed: _save, child: const Text('Сохранить')),
        ],
      );
}
