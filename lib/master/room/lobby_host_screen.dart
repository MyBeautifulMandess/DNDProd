/// Экран мастера: запуск комнаты, адрес/QR, игроки, пешки и чат.
library;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/models/room.dart';
import '../../lobby/master_lobby_controller.dart';
import '../../platform/files/map_file.dart';
import '../../shared/lobby/chat_panel.dart';
import '../../shared/field/battle_field.dart';
import 'quick_load.dart';
import 'quick_load_sheet.dart';

class LobbyHostScreen extends StatefulWidget {
  const LobbyHostScreen({super.key});

  @override
  State<LobbyHostScreen> createState() => _LobbyHostScreenState();
}

class _LobbyHostScreenState extends State<LobbyHostScreen> {
  String? _selectedToken;
  final _tokenName = TextEditingController();
  final _tokenHp = TextEditingController();
  TokenKind _newKind = TokenKind.npc;
  int _newSize = 1;

  @override
  void dispose() {
    _tokenName.dispose();
    _tokenHp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MasterLobbyController>();
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: controller.isRunning
              ? _session(context, controller)
              : _start(context, controller),
        ),
        if (controller.error != null)
          Positioned(
            top: 8,
            left: 16,
            right: 16,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              color: Colors.red.shade900,
              child: ListTile(
                title: Text(controller.error!),
                textColor: Colors.white,
                trailing: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: controller.clearError,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _start(BuildContext context, MasterLobbyController controller) =>
      Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.meeting_room_outlined,
                    size: 56, color: Colors.amber),
                const SizedBox(height: 12),
                const Text(
                  'Локальная комната',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Сервер поднимется на этом устройстве. Игроки в той же Wi-Fi/LAN-сети '
                  'подключатся по адресу из QR-кода.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: controller.isStarting
                      ? null
                      : () => context.read<MasterLobbyController>().start(),
                  icon: controller.isStarting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow),
                  label: const Text('Запустить комнату'),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _session(BuildContext context, MasterLobbyController controller) {
    final state = controller.state;
    final selected =
        state.tokens.where((token) => token.id == _selectedToken).firstOrNull;
    final session = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: BattleField(
              state: state,
              selectedTokenId: _selectedToken,
              isMaster: true,
              onTokenTap: (id) => setState(() => _selectedToken = id),
              onTokenDrag: (id, x, y) => controller.moveToken(id, x, y),
              canDragToken: (_) => true,
              onDraw: controller.drawStroke,
              onFog: (cells, {required reveal}) =>
                  controller.toggleFog(cells, reveal: reveal),
              showTools: true,
              onCellTap: (x, y) {
                final id = _selectedToken;
                if (id != null) controller.moveToken(id, x, y);
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        ChatPanel(
          entries: controller.log,
          onSend: controller.sendChat,
          onRoll: (formula, hidden) => controller.requestRoll(formula),
        ),
      ],
    );
    final sidebar = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                const Text('Адрес для игроков',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SelectableText(controller.address ?? ''),
                const SizedBox(height: 8),
                QrImageView(
                  data: 'ws://${controller.address}/ws',
                  version: QrVersions.auto,
                  size: 160,
                  backgroundColor: Colors.white,
                ),
                const Text('Игрок вводит адрес вручную',
                    style: TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed: () => context.read<MasterLobbyController>().stop(),
                  child: const Text('Остановить комнату'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Игроки',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (state.players.isEmpty) const Text('Никого пока нет'),
                for (final player in state.players)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.person_outline),
                    title: Text(player.name),
                    subtitle: Text(player.moveOwn
                        ? 'двигает свою пешку'
                        : 'только наблюдает'),
                  ),
                SwitchListTile(
                  title: const Text('Игроки двигают свои пешки'),
                  value: controller.moveOwnAllowed,
                  onChanged: controller.setMoveOwnAllowed,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Карты приключения',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (controller.mapChoices.isEmpty)
                  const Text('Комната запущена без набора карт',
                      style: TextStyle(fontSize: 12, color: Colors.white70)),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final choice in controller.mapChoices)
                      ChoiceChip(
                        label: Text(choice.name),
                        selected: choice.key == state.mapKey,
                        onSelected: (_) => controller.switchMap(choice.key),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Картинка игрокам',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonal(
                      onPressed: _showImage,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.image_outlined),
                          SizedBox(width: 8),
                          Text('Показать'),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: controller.hideImage,
                      child: const Text('Скрыть'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Быстрая подгрузка',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text(
                  'Монстр из справочника станет пешкой с хитами из каталога, '
                  'предмет или заклинание — сообщением в чат.',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  key: const ValueKey('quick-load-button'),
                  onPressed: _quickLoad,
                  icon: const Icon(Icons.manage_search),
                  label: const Text('Из справочника'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Карта', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  state.mapId.startsWith('asset:')
                      ? 'Стандартная карта'
                      : 'Своя карта (доступна игрокам)',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonal(
                      onPressed: () => controller.importMap(),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.image_outlined),
                          SizedBox(width: 8),
                          Text('Загрузить'),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: state.mapId.startsWith('asset:')
                          ? null
                          : controller.useDefaultMap,
                      child: const Text('Стандартная'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Пешки',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  children: [
                    for (final token in state.tokens)
                      Padding(
                        padding: const EdgeInsets.only(right: 4, bottom: 4),
                        child: ChoiceChip(
                          label: Text(
                              token.label.isEmpty ? token.id : token.label),
                          selected: token.id == _selectedToken,
                          onSelected: (_) =>
                              setState(() => _selectedToken = token.id),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _tokenName,
                        decoration: const InputDecoration(
                          hintText: 'Имя пешки',
                          isDense: true,
                        ),
                        onSubmitted: (_) => _addToken(controller),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      tooltip: 'Добавить пешку',
                      onPressed: () => _addToken(controller),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    DropdownButton<TokenKind>(
                      value: _newKind,
                      onChanged: (value) => setState(
                          () => _newKind = value ?? TokenKind.npc),
                      items: const [
                        DropdownMenuItem(
                            value: TokenKind.player, child: Text('Игрок')),
                        DropdownMenuItem(
                            value: TokenKind.monster, child: Text('Монстр')),
                        DropdownMenuItem(
                            value: TokenKind.npc, child: Text('NPC')),
                      ],
                    ),
                    DropdownButton<int>(
                      value: _newSize,
                      onChanged: (value) =>
                          setState(() => _newSize = value ?? 1),
                      items: [
                        for (var size = 1; size <= 4; size++)
                          DropdownMenuItem<int>(
                              value: size, child: Text('$size×$size')),
                      ],
                    ),
                    SizedBox(
                      width: 72,
                      child: TextField(
                        controller: _tokenHp,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: 'ХП',
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                if (selected != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Хиты: ${selected.hp ?? '—'}'),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.remove),
                            tooltip: '−1 ХП',
                            onPressed: () => controller.updateHp(
                                selected.id, (selected.hp ?? 0) - 1),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add),
                            tooltip: '+1 ХП',
                            onPressed: () => controller.updateHp(
                                selected.id, (selected.hp ?? 0) + 1),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Удалить пешку',
                            onPressed: () {
                              controller.removeToken(selected.id);
                              setState(() => _selectedToken = null);
                            },
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text('Размер:', style: TextStyle(fontSize: 12)),
                          DropdownButton<int>(
                            value: selected.size,
                            onChanged: (value) => controller.resizeToken(
                                selected.id, value ?? 1),
                            items: [
                              for (var size = 1; size <= 4; size++)
                                DropdownMenuItem<int>(
                                    value: size, child: Text('$size×$size')),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: constraints.maxWidth >= 900
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: session),
                  const SizedBox(width: 16),
                  SizedBox(width: 320, child: sidebar),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [sidebar, const SizedBox(height: 12), session],
              ),
      ),
    );
  }

  Future<void> _showImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    final path = result?.files.singleOrNull?.path;
    if (path == null) return;
    final bytes = await readMapBytes(path);
    if (!mounted) return;
    context.read<MasterLobbyController>().showImageBytes(
          bytes,
          contentType: mapContentType(path),
        );
  }

  Future<void> _quickLoad() async {
    final controller = context.read<MasterLobbyController>();
    final selection = await showQuickLoadSheet(context);
    if (selection == null || !mounted) return;
    await QuickLoadService(controller).load(selection);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(quickLoadSuccessText(selection))),
    );
  }

  void _addToken(MasterLobbyController controller) {
    controller.addToken(
      _tokenName.text,
      kind: _newKind,
      size: _newSize,
      hp: int.tryParse(_tokenHp.text.trim()),
    );
    _tokenName.clear();
    _tokenHp.clear();
  }
}
