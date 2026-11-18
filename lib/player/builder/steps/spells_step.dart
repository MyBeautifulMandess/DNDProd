import 'package:flutter/material.dart';

import '../../../core/models/catalog.dart';
import '../../../shared/spell_card.dart';
import '../character_builder_controller.dart';

const Color _gold = Color(0xFFC9A227);

class SpellsStep extends StatefulWidget {
  const SpellsStep({super.key, required this.controller});

  final CharacterBuilderController controller;

  @override
  State<SpellsStep> createState() => _SpellsStepState();
}

class _SpellsStepState extends State<SpellsStep> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final next = _searchController.text;
    if (next != _searchQuery) {
      setState(() => _searchQuery = next);
    }
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  bool _matches(Spell spell, String query) =>
      query.isEmpty || spell.nameRu.toLowerCase().contains(query);

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    if (!controller.isSpellcasterClass) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Text(
            'Для выбранного класса заклинания на 1 уровне не выбираются.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final query = _searchQuery.trim().toLowerCase();
    final cantrips =
        controller.classCantrips.where((s) => _matches(s, query)).toList();
    final levelOneSpells =
        controller.classLevelOneSpells.where((s) => _matches(s, query)).toList();
    final isPrepared = controller.preparedSpellsLimit != null;
    final spellsLimit =
        controller.knownSpellsLimit ?? controller.preparedSpellsLimit ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Заговоры: выбрано ${controller.selectedCantripIds.length} из ${controller.cantripLimit}',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            labelText: 'Поиск заклинания',
            prefixIcon: Icon(Icons.search),
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Тап — выбрать, удержание — описание',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        if (cantrips.isEmpty)
          const Text('Заговоры не найдены в каталоге для этого класса.')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final spell in cantrips)
                _SpellChip(
                  spell: spell,
                  selected:
                      controller.selectedCantripIds.contains(spell.id),
                  onSelected: (_) => controller.toggleCantrip(spell),
                ),
            ],
          ),
        const SizedBox(height: 20),
        Text(
          isPrepared
              ? '${controller.spellListCaption}: выбрано '
                  '${controller.selectedSpellIds.length} из $spellsLimit '
                  '(модификатор характеристики + уровень)'
              : '${controller.spellListCaption}: выбрано '
                  '${controller.selectedSpellIds.length} из $spellsLimit',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        if (levelOneSpells.isEmpty)
          const Text('Заклинания 1-го уровня не найдены в каталоге для этого класса.')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final spell in levelOneSpells)
                _SpellChip(
                  spell: spell,
                  selected: controller.selectedSpellIds.contains(spell.id),
                  onSelected: (_) => controller.toggleSpell(spell),
                ),
            ],
          ),
      ],
    );
  }
}

class _SpellChip extends StatelessWidget {
  const _SpellChip({
    required this.spell,
    required this.selected,
    required this.onSelected,
  });

  final Spell spell;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    // Тап — выбор заклинания; удержание — карточка с описанием.
    return GestureDetector(
      onLongPress: () => showSpellCard(context, spell),
      child: Tooltip(
        message: spell.school.isEmpty ? spell.nameEn : spell.school,
        child: FilterChip(
          label: Text(spell.nameRu),
          selected: selected,
          selectedColor: _gold.withValues(alpha: 0.28),
          checkmarkColor: _gold,
          materialTapTargetSize: MaterialTapTargetSize.padded,
          onSelected: onSelected,
        ),
      ),
    );
  }
}
