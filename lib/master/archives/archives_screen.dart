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
        title: const Text('Удалить снимок?'),
        content: Text('Снимок «${archived.characterName}» будет удалён.'),
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

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Архивы персонажей')),
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
                    'к вашим комнатам.',
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
                return Card(
                  child: ExpansionTile(
                    leading: const Icon(Icons.badge_outlined,
                        color: Colors.amber),
                    title: Text(item.characterName),
                    subtitle: Text(
                      '${item.playerName} · ${item.level} ур.'
                      '${item.classNames.isEmpty ? '' : ' · ${item.classNames}'}',
                    ),
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
                                label: const Text('Удалить снимок'),
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
