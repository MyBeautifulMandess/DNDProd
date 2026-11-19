/// Список приключений мастера: создать, открыть, дублировать, удалить.
library;

import 'package:flutter/material.dart';

import '../../core/models/adventure.dart';
import '../../platform/files/file_store.dart';
import 'adventure_editor_screen.dart';
import 'adventure_repository.dart';

class AdventuresScreen extends StatefulWidget {
  const AdventuresScreen({
    super.key,
    this.store,
    this.onStartRoom,
  });

  /// Подставляется в тестах; в приложении — Files приложения.
  final FileStore? store;
  final VoidCallback? onStartRoom;

  @override
  State<AdventuresScreen> createState() => _AdventuresScreenState();
}

class _AdventuresScreenState extends State<AdventuresScreen> {
  late final FileStore _store;
  late final AdventureRepository _repository;
  late Future<List<Adventure>> _future;

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? PathProviderFileStore();
    _repository = AdventureRepository(_store);
    _future = _repository.list();
  }

  void _reload() {
    setState(() {
      _future = _repository.list();
    });
  }

  Future<void> _open(String? adventureId) async {
    final started = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AdventureEditorScreen(
          repository: _repository,
          store: _store,
          adventureId: adventureId,
          onRoomStarted: widget.onStartRoom,
        ),
      ),
    );
    if (!mounted) return;
    if (started == true) {
      Navigator.of(context).pop<bool>(true);
    } else {
      _reload();
    }
  }

  Future<void> _duplicate(String adventureId) async {
    await _repository.duplicate(adventureId);
    _reload();
  }

  Future<void> _delete(String adventureId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить приключение?'),
        content: Text('«$title» и все его карты будут удалены.'),
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
    await _repository.delete(adventureId);
    _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Приключения')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _open(null),
          icon: const Icon(Icons.add),
          label: const Text('Новое приключение'),
        ),
        body: FutureBuilder<List<Adventure>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Ошибка загрузки: ${snapshot.error}'),
                ),
              );
            }
            final adventures = snapshot.data ?? const <Adventure>[];
            if (adventures.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Пока нет приключений. Создайте первое — карты, лор и ПМ '
                    'будут храниться локально на этом устройстве.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: adventures.length,
              itemBuilder: (context, index) {
                final adventure = adventures[index];
                final date = DateTime.fromMillisecondsSinceEpoch(
                    adventure.updatedAtMs).toLocal();
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.auto_awesome_outlined,
                        color: Colors.amber),
                    title: Text(adventure.title),
                    subtitle: Text(
                      '${adventure.maps.length} карт · ${adventure.lore.length} страниц лора · '
                      '${date.toString().substring(0, 16)}',
                    ),
                    onTap: () => _open(adventure.id),
                    trailing: PopupMenuButton<String>(
                      tooltip: 'Действия',
                      onSelected: (action) {
                        if (action == 'duplicate') {
                          _duplicate(adventure.id);
                        } else if (action == 'delete') {
                          _delete(adventure.id, adventure.title);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                            value: 'duplicate', child: Text('Дублировать')),
                        PopupMenuItem(value: 'delete', child: Text('Удалить')),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      );
}
