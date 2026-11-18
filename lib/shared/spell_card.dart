/// Карточка заклинания: метаданные + описание. Переиспользуется
/// билдером и будущими справочниками (фаза 2).
library;

import 'package:flutter/material.dart';

import '../core/models/catalog.dart';

const Color _gold = Color(0xFFC9A227);

Future<void> showSpellCard(BuildContext context, Spell spell) {
  return showDialog<void>(
    context: context,
    builder: (context) => SpellCard(spell: spell),
  );
}

class SpellCard extends StatelessWidget {
  const SpellCard({super.key, required this.spell});

  final Spell spell;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(spell.nameRu),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                spell.schoolLine.isEmpty
                    ? (spell.level == 0 ? 'Заговор' : '${spell.level} уровень')
                    : spell.schoolLine,
                style: theme.textTheme.bodySmall?.copyWith(color: _gold),
              ),
              const SizedBox(height: 8),
              _row('Время накладывания', spell.castTime),
              _row('Дистанция', spell.range),
              _row('Компоненты', spell.components),
              _row('Длительность', spell.duration),
              const SizedBox(height: 12),
              Text(spell.description),
              const SizedBox(height: 8),
              Text(
                spell.url,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Закрыть'),
        ),
      ],
    );
  }

  Widget _row(String label, String value) {
    final trimmed = value.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(trimmed.isEmpty ? '—' : trimmed)),
        ],
      ),
    );
  }
}
