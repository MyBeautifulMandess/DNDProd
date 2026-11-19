/// Экран игрока: ввод адреса, выбор персонажа и сессия в комнате.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/character.dart';
import '../../lobby/player_lobby_controller.dart';
import '../../platform/files/file_store.dart';
import '../../player/characters/character_repository.dart';
import '../../player/sheet/character_sheet_panel.dart';
import '../../shared/lobby/chat_panel.dart';
import '../../shared/field/battle_field.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key, this.repository});

  /// Репозиторий можно подменить в тестах.
  final CharacterRepository? repository;

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  late final CharacterRepository _repository;
  late Future<List<Character>> _characters;
  final _address = TextEditingController();
  final _name = TextEditingController();
  String? _characterId;
  Character? _activeCharacter;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.repository ?? CharacterRepository(PathProviderFileStore());
    _characters = _repository.list();
  }

  @override
  void dispose() {
    _address.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PlayerLobbyController>();
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: controller.connected && controller.state != null
              ? _session(controller)
              : _connectForm(controller),
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
        if (controller.imageUrl != null)
          Positioned.fill(
            child: Material(
              color: const Color(0xF21A1A1A),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: InteractiveViewer(
                      child: Image.network(
                        controller.imageUrl!,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stack) => const Center(
                          child: Text('Картинка недоступна',
                              style: TextStyle(color: Colors.white70)),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      tooltip: 'Скрыть картинку',
                      onPressed: controller.dismissImage,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _connectForm(PlayerLobbyController controller) =>
      FutureBuilder<List<Character>>(
        future: _characters,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final characters = snapshot.data ?? const <Character>[];
          if (characters.isEmpty) {
            return const Center(
              child: Text('Сначала создайте персонажа во вкладке «Персонажи»'),
            );
          }
          _characterId ??= characters.first.id;
          final selected =
              characters.where((c) => c.id == _characterId).firstOrNull ??
                  characters.first;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.wifi_tethering,
                          size: 56, color: Colors.amber),
                      const SizedBox(height: 12),
                      const Text(
                        'Подключение к комнате',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _address,
                        decoration: const InputDecoration(
                          labelText: 'Адрес мастера',
                          hintText: '192.168.1.5:7777',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _characterId,
                        decoration: const InputDecoration(
                          labelText: 'Персонаж',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final character in characters)
                            DropdownMenuItem(
                              value: character.id,
                              child: Text(
                                  '${character.name} · ${character.level} ур.'),
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => _characterId = value),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _name,
                        decoration: InputDecoration(
                          labelText: 'Имя в комнате',
                          hintText: selected.name,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 44),
                              ),
                              onPressed: () =>
                                  _openSheet(context, controller, selected),
                              icon: const Icon(Icons.badge_outlined),
                              label: const Text('Лист персонажа'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 44),
                              ),
                              onPressed: controller.connecting
                                  ? null
                                  : () => _connect(controller, selected),
                              icon: controller.connecting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.login),
                              label: const Text('Подключиться'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );

  Widget _session(PlayerLobbyController controller) {
    final state = controller.state!;
    final ownToken = state.tokens
        .where((token) => token.owner == controller.playerId)
        .firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: BattleField(
              state: state,
              selectedTokenId: ownToken?.id,
              canDragToken: (token) => token.owner == controller.playerId,
              onTokenDrag: (id, x, y) => controller.moveToken(id, x, y),
              onDraw: controller.drawStroke,
              showTools: true,
              onCellTap: (x, y) {
                final token = ownToken;
                if (token != null) controller.moveToken(token.id, x, y);
              },
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Участники: ${state.players.map((p) => p.name).join(', ')}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                      ),
                      onPressed: () =>
                          _openSheet(context, controller, _activeCharacter),
                      icon: const Icon(Icons.badge_outlined),
                      label: const Text('Лист персонажа'),
                    ),
                  ],
                ),
                if (ownToken == null) const Text('Ваша пешка ещё не создана'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ChatPanel(
          entries: controller.log,
          onSend: controller.sendChat,
          onRoll: (formula, hidden) =>
              controller.requestRoll(formula, hidden: hidden),
          allowHidden: true,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: () {
            setState(() => _activeCharacter = null);
            context.read<PlayerLobbyController>().disconnect();
          },
          icon: const Icon(Icons.logout),
          label: const Text('Отключиться'),
        ),
      ],
    );
  }

  void _openSheet(
    BuildContext context,
    PlayerLobbyController controller,
    Character? character,
  ) {
    if (character == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала выберите персонажа')),
      );
      return;
    }
    final connected = controller.connected;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => CharacterSheetPanel(
        character: character,
        repository: _repository,
        onRoll: (formula) {
          if (!connected) {
            _offlineNotice(sheetContext);
            return;
          }
          controller.requestRoll(formula);
        },
        onChat: (text) {
          if (!connected) {
            _offlineNotice(sheetContext);
            return;
          }
          controller.sendChat(text);
        },
      ),
    );
  }

  void _offlineNotice(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Броски и сообщения доступны после подключения'),
      ),
    );
  }

  Future<void> _connect(
      PlayerLobbyController controller, Character character) async {
    setState(() => _activeCharacter = character);
    await controller.connect(
      address: _address.text.trim(),
      name: _name.text.trim().isEmpty ? character.name : _name.text.trim(),
      characterId: character.id,
      hp: character.currentHp,
      maxHp: character.maxHp,
      characterSnapshot: character.toJson(),
    );
  }
}
