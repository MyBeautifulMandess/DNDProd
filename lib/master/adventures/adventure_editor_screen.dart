/// Редактор приключения мастера: карты и подготовка, лор, ПМ, настройки.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../platform/files/file_store.dart';
import 'adventure_editor_controller.dart';
import 'adventure_maps_tab.dart';
import 'adventure_notes_tab.dart';
import 'adventure_repository.dart';

class AdventureEditorScreen extends StatefulWidget {
  const AdventureEditorScreen({
    super.key,
    required this.repository,
    required this.store,
    this.adventureId,
    this.onRoomStarted,
  });

  final AdventureRepository repository;
  final FileStore store;

  /// `null` — создать новое приключение.
  final String? adventureId;
  final VoidCallback? onRoomStarted;

  @override
  State<AdventureEditorScreen> createState() => _AdventureEditorScreenState();
}

class _AdventureEditorScreenState extends State<AdventureEditorScreen> {
  late final AdventureEditorController _controller;
  late final Future<void> _prepared;

  @override
  void initState() {
    super.initState();
    _controller = AdventureEditorController(widget.repository, widget.store);
    _prepared = widget.adventureId == null
        ? _controller.createNew()
        : _controller.load(widget.adventureId!);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _roomStarted() {
    widget.onRoomStarted?.call();
    Navigator.of(context).pop<bool>(true);
  }

  Future<void> _save() async {
    final saved = await _controller.save();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(saved
            ? 'Приключение сохранено'
            : _controller.error ?? 'Не удалось сохранить'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
        value: _controller,
        child: FutureBuilder<void>(
          future: _prepared,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Scaffold(
                appBar: AppBar(title: const Text('Приключение')),
                body: Center(child: Text('Ошибка загрузки: ${snapshot.error}')),
              );
            }
            final controller = context.watch<AdventureEditorController>();
            return DefaultTabController(
              length: 2,
              child: Scaffold(
                appBar: AppBar(
                  title: Text(controller.adventure?.title ?? 'Приключение'),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.save_outlined),
                      tooltip: 'Сохранить',
                      onPressed: _save,
                    ),
                  ],
                  bottom: const TabBar(
                    tabs: [
                      Tab(text: 'Карты'),
                      Tab(text: 'Лор и ПМ'),
                    ],
                  ),
                ),
                body: TabBarView(
                  children: [
                    AdventureMapsTab(
                      repository: widget.repository,
                      onRoomStarted: _roomStarted,
                    ),
                    const AdventureNotesTab(),
                  ],
                ),
              ),
            );
          },
        ),
      );
}
