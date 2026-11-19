/// Вкладка редактора: описание, страницы лора, приватные заметки и настройки.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'adventure_editor_controller.dart';

class AdventureNotesTab extends StatelessWidget {
  const AdventureNotesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AdventureEditorController>();
    final adventure = controller.adventure;
    if (adventure == null) {
      return const Center(child: Text('Приключение не загружено'));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TextFormField(
                    key: const ValueKey('adventure-title'),
                    initialValue: adventure.title,
                    decoration: const InputDecoration(labelText: 'Название'),
                    onChanged: controller.setTitle,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('adventure-description'),
                    initialValue: adventure.description,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Описание'),
                    onChanged: controller.setDescription,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Заметки по лору',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              FilledButton.icon(
                onPressed: controller.addLorePage,
                icon: const Icon(Icons.add),
                label: const Text('Страница'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (adventure.lore.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Запишите NPC, фракции и сюжетные ветки.'),
              ),
            ),
          for (final page in adventure.lore)
            Card(
              key: ValueKey(page.id),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            key: ValueKey('lore-title-${page.id}'),
                            initialValue: page.title,
                            decoration: const InputDecoration(labelText: 'Заголовок'),
                            onChanged: (value) =>
                                controller.updateLorePage(page.id, title: value),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Удалить страницу',
                          onPressed: () => controller.removeLorePage(page.id),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      key: ValueKey('lore-text-${page.id}'),
                      initialValue: page.text,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Текст',
                        alignLabelWithHint: true,
                      ),
                      onChanged: (value) =>
                          controller.updateLorePage(page.id, text: value),
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
                  const Text('ПМ (приватные заметки)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  TextFormField(
                    key: const ValueKey('private-notes'),
                    initialValue: adventure.privateNotes,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      hintText: 'Видно только мастеру, в том числе во время игры',
                      alignLabelWithHint: true,
                    ),
                    onChanged: controller.setPrivateNotes,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: SwitchListTile(
              title: const Text('Игроки двигают свои пешки'),
              subtitle: const Text('Настройка комнаты при запуске'),
              value: adventure.moveOwnAllowed,
              onChanged: controller.setMoveOwnAllowed,
            ),
          ),
        ],
      ),
    );
  }
}
