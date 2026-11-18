/// Общий чат комнаты: сообщения, броски и ввод формулы кубиков.
library;

import 'package:flutter/material.dart';

import '../../lobby/lobby_log.dart';

class ChatPanel extends StatefulWidget {
  const ChatPanel({
    super.key,
    required this.entries,
    required this.onSend,
    required this.onRoll,
    this.allowHidden = false,
    this.height = 260,
  });

  final List<LobbyLogEntry> entries;
  final void Function(String text) onSend;
  final void Function(String formula, bool hidden) onRoll;
  final bool allowHidden;
  final double height;

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final _message = TextEditingController();
  final _formula = TextEditingController();
  final _scroll = ScrollController();
  bool _hidden = false;

  @override
  void didUpdateWidget(ChatPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.entries.length != oldWidget.entries.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _message.dispose();
    _formula.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: widget.height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: widget.entries.isEmpty
                  ? const Center(child: Text('Сообщений пока нет'))
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(8),
                      itemCount: widget.entries.length,
                      itemBuilder: (context, index) =>
                          _line(context, widget.entries[index]),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _message,
                  decoration: const InputDecoration(
                    hintText: 'Сообщение в чат',
                    isDense: true,
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _send,
                child: const Text('Отправить'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _formula,
                  decoration: const InputDecoration(
                    hintText: 'Бросок: 2к6+3',
                    isDense: true,
                  ),
                  onSubmitted: (_) => _roll(),
                ),
              ),
              if (widget.allowHidden) ...[
                const SizedBox(width: 4),
                FilterChip(
                  label: const Text('Скрыто'),
                  selected: _hidden,
                  onSelected: (value) => setState(() => _hidden = value),
                ),
              ],
              const SizedBox(width: 8),
              FilledButton.tonal(
                  onPressed: _roll, child: const Text('Бросить')),
            ],
          ),
        ],
      );

  Widget _line(BuildContext context, LobbyLogEntry entry) {
    final style = switch (entry.kind) {
      LobbyLogKind.hiddenRoll =>
        const TextStyle(color: Colors.amber, fontStyle: FontStyle.italic),
      LobbyLogKind.system =>
        const TextStyle(color: Colors.white54, fontStyle: FontStyle.italic),
      LobbyLogKind.roll => const TextStyle(color: Color(0xFFFFD97A)),
      LobbyLogKind.chat => const TextStyle(color: Colors.white),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Text(entry.line, style: style),
    );
  }

  void _send() {
    final text = _message.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _message.clear();
  }

  void _roll() {
    final formula = _formula.text.trim();
    if (formula.isEmpty) return;
    widget.onRoll(formula, _hidden);
    _formula.clear();
  }
}
