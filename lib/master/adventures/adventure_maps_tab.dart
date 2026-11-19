/// Вкладка редактора: подготовка карт, пешек, тумана и запуск комнаты.
library;

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/adventure.dart';
import '../../core/models/room.dart';
import '../../lobby/master_lobby_controller.dart';
import '../../platform/files/map_file.dart';
import '../../shared/field/battle_field.dart';
import 'adventure_editor_controller.dart';
import 'adventure_repository.dart';
import 'monster_picker_sheet.dart';

class AdventureMapsTab extends StatefulWidget {
  const AdventureMapsTab({
    super.key,
    required this.repository,
    required this.onRoomStarted,
  });

  final AdventureRepository repository;
  final VoidCallback onRoomStarted;

  @override
  State<AdventureMapsTab> createState() => _AdventureMapsTabState();
}

class _AdventureMapsTabState extends State<AdventureMapsTab> {
  String? _selectedTokenId;
  final _npcController = TextEditingController();
  String? _imagePathKey;
  Future<ImageProvider>? _imageFuture;
  bool _starting = false;

  @override
  void dispose() {
    _npcController.dispose();
    super.dispose();
  }

  AdventureEditorController get _controller =>
      context.watch<AdventureEditorController>();

  Future<ImageProvider> _imageFor(String path) {
    if (_imageFuture == null || _imagePathKey != path) {
      _imagePathKey = path;
      _imageFuture = _controller.mapImage();
    }
    return _imageFuture!;
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final adventure = controller.adventure;
    final map = controller.selectedMap;
    if (adventure == null || map == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('В приключении пока нет карт'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: controller.addMap,
              icon: const Icon(Icons.add),
              label: const Text('Добавить карту'),
            ),
          ],
        ),
      );
    }

    final selected = map.tokens.isEmpty
        ? null
        : map.tokens.firstWhere(
            (item) => item.id == _selectedTokenId,
            orElse: () => map.tokens.first,
          );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _mapChips(adventure, map),
          const SizedBox(height: 12),
          _mapActions(controller, map),
          const SizedBox(height: 12),
          Card(
            clipBehavior: Clip.antiAlias,
            child: FutureBuilder<ImageProvider>(
              future: _imageFor(map.imagePath),
              builder: (context, image) => BattleField(
                state: map.roomState(adventure.id),
                isMaster: true,
                height: 420,
                mapImage: image.data,
                selectedTokenId: selected?.id,
                onTokenTap: (id) => setState(() => _selectedTokenId = id),
                onTokenDrag: (id, x, y) =>
                    controller.updateToken(id: id, x: x, y: y),
                canDragToken: (_) => true,
                onCellTap: (x, y) {
                  final id = selected?.id;
                  if (id != null) {
                    controller.updateToken(id: id, x: x, y: y);
                  }
                },
                onDraw: controller.drawStroke,
                onFog: (cells, {required reveal}) =>
                    controller.toggleFog(cells, reveal: reveal),
                showTools: true,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _tokenControls(controller, selected),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Игра', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text(
                    'Запустит локальный сервер с расстановкой этой карты. '
                    'Игроки подключатся по адресу и QR-коду в вкладке «Комната».',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _starting ? null : () => _startRoom(controller),
                    icon: _starting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow),
                    label: const Text('Запустить комнату с этой карты'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapChips(Adventure adventure, AdventureMap map) => Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final item in adventure.maps)
            InputChip(
              label: Text(item.name),
              avatar: item.id == adventure.startMapId
                  ? const Icon(Icons.flag, size: 16)
                  : null,
              selected: item.id == map.id,
              onPressed: () => _controller.selectMap(item.id),
              onDeleted: adventure.maps.length > 1
                  ? () => _controller.removeMap(item.id)
                  : null,
            ),
          ActionChip(
            label: const Text('Новая карта'),
            avatar: const Icon(Icons.add),
            onPressed: _controller.addMap,
          ),
        ],
      );

  Widget _mapActions(AdventureEditorController controller, AdventureMap map) =>
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.tonal(
            onPressed: () => _importMap(controller),
            child: const Text('Загрузить фон'),
          ),
          OutlinedButton(
            onPressed: map.imagePath.isEmpty ? null : controller.useDefaultMap,
            child: const Text('Стандартный фон'),
          ),
          OutlinedButton.icon(
            onPressed: () => _editGrid(controller),
            icon: const Icon(Icons.grid_on),
            label: Text('Сетка ${map.grid.cols}×${map.grid.rows}'),
          ),
        ],
      );

  Widget _tokenControls(
    AdventureEditorController controller,
    Token? selected,
  ) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Пешки и трекеры',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: () => _addMonster(controller),
                    icon: const Icon(Icons.pets),
                    label: const Text('Монстр из бестиария'),
                  ),
                  SizedBox(
                    width: 160,
                    child: TextField(
                      controller: _npcController,
                      decoration: const InputDecoration(
                        hintText: 'Имя NPC',
                        isDense: true,
                      ),
                      onSubmitted: (_) => _addNpc(controller),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.person_add_alt_1),
                    tooltip: 'Добавить NPC',
                    onPressed: () => _addNpc(controller),
                  ),
                ],
              ),
              if (selected == null)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Выберите пешку на поле, чтобы менять хиты и размер. '
                    'Для расстановки нажмите клетку поля.',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(selected.label.isEmpty ? selected.id : selected.label,
                          style: const TextStyle(color: Colors.amber)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('ХП ${selected.hp ?? '—'}/${selected.maxHp ?? '—'}'),
                          IconButton(
                            icon: const Icon(Icons.remove),
                            tooltip: '−1 ХП',
                            onPressed: () => controller.updateToken(
                                id: selected.id,
                                hp: (selected.hp ?? 0) - 1),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add),
                            tooltip: '+1 ХП',
                            onPressed: () => controller.updateToken(
                                id: selected.id,
                                hp: (selected.hp ?? 0) + 1),
                          ),
                          const Text('Размер:'),
                          DropdownButton<int>(
                            value: selected.size,
                            onChanged: (value) => controller.updateToken(
                                id: selected.id, size: value ?? 1),
                            items: [
                              for (var size = 1; size <= 4; size++)
                                DropdownMenuItem<int>(
                                    value: size, child: Text('$size×$size')),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Удалить пешку',
                            onPressed: () {
                              controller.removeToken(selected.id);
                              setState(() => _selectedTokenId = null);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );

  Future<void> _importMap(AdventureEditorController controller) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    final file = result?.files.singleOrNull;
    if (file?.path == null) return;
    final bytes = await readMapBytes(file!.path!);
    await controller.importMapImage(file.path!, bytes);
  }

  Future<void> _addMonster(AdventureEditorController controller) async {
    final spec = await showMonsterPicker(context);
    if (spec == null || !mounted) return;
    controller.addMonsterToken(spec);
    final map = controller.selectedMap;
    if (map != null) {
      setState(() => _selectedTokenId = map.tokens.lastOrNull?.id);
    }
  }

  void _addNpc(AdventureEditorController controller) {
    final name = _npcController.text;
    if (name.trim().isEmpty) return;
    controller.addNpcToken(name);
    _npcController.clear();
    final map = controller.selectedMap;
    if (map != null) {
      setState(() => _selectedTokenId = map.tokens.lastOrNull?.id);
    }
  }

  Future<void> _editGrid(AdventureEditorController controller) async {
    final grid = controller.selectedMap?.grid;
    if (grid == null) return;
    final cols = TextEditingController(text: '${grid.cols}');
    final rows = TextEditingController(text: '${grid.rows}');
    final cell = TextEditingController(text: '${grid.cellPx}');
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Настройка сетки'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: cols,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Колонок')),
            TextField(
                controller: rows,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Строк')),
            TextField(
                controller: cell,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Размер клетки, px')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Применить')),
        ],
      ),
    );
    if (result != true) return;
    controller.setGrid(
      cols: int.tryParse(cols.text),
      rows: int.tryParse(rows.text),
      cellPx: int.tryParse(cell.text),
    );
  }

  Future<void> _startRoom(AdventureEditorController controller) async {
    final adventure = controller.adventure;
    final map = controller.selectedMap;
    final lobby = context.read<MasterLobbyController>();
    if (adventure == null || map == null || lobby.isRunning) return;
    setState(() => _starting = true);
    try {
      Uint8List? bytes;
      if (map.imagePath.isNotEmpty) {
        bytes = await widget.repository.mapBytes(map);
      }
      lobby.clearError();
      await lobby.start(
        initialState: map.roomState(adventure.id),
        mapBytes: bytes,
        mapContentType: widget.repository.contentType(map),
        moveOwnAllowed: adventure.moveOwnAllowed,
      );
      if (!mounted) return;
      if (lobby.isRunning) {
        widget.onRoomStarted();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lobby.error ?? 'Не удалось запустить комнату')),
        );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }
}
