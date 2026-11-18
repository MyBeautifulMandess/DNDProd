import 'package:flutter/material.dart';

import '../../../core/models/catalog.dart';
import '../../../core/rules/ability.dart';
import '../character_builder_controller.dart';

const Color _gold = Color(0xFFC9A227);

class RaceStep extends StatefulWidget {
  const RaceStep({super.key, required this.controller});

  final CharacterBuilderController controller;

  @override
  State<RaceStep> createState() => _RaceStepState();
}

class _RaceStepState extends State<RaceStep> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final query = _query.trim().toLowerCase();
    final filtered = controller.races
        .where((race) =>
            query.isEmpty ||
            race.nameRu.toLowerCase().contains(query) ||
            race.nameEn.toLowerCase().contains(query))
        .toList()
      ..sort((a, b) => a.nameRu.compareTo(b.nameRu));

    final detail = controller.selectedRaceDetail;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          decoration: const InputDecoration(
            labelText: 'Поиск расы',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final race in filtered)
              ChoiceChip(
                label: Text(race.nameRu),
                selected: controller.raceId == race.id,
                selectedColor: _gold.withValues(alpha: 0.28),
                onSelected: (_) => controller.selectRace(race.id),
              ),
          ],
        ),
        if (detail != null) ...[
          const SizedBox(height: 16),
          _RaceDetailCard(controller: controller, race: detail),
        ],
      ],
    );
  }
}

class _RaceDetailCard extends StatelessWidget {
  const _RaceDetailCard({required this.controller, required this.race});

  final CharacterBuilderController controller;
  final RaceDetail race;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subspecies = controller.availableSubspecies;
    final selectedSub = controller.selectedSubspecies;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(race.nameRu, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            _InfoLine(
              label: 'Бонусы',
              value: _bonusLine(race.bonuses, race.bonusesChoice),
            ),
            _InfoLine(label: 'Скорость', value: race.speedFt == null ? '—' : '${race.speedFt} футов'),
            _InfoLine(label: 'Размер', value: race.size),
            if (race.darkvisionFt != null && race.darkvisionFt! > 0)
              _InfoLine(
                label: 'Тёмное зрение',
                value: '${race.darkvisionFt} футов',
              ),
            _InfoLine(
              label: 'Языки',
              value: _truncate(race.languagesText, 120),
            ),
            if (subspecies.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Подвид', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final sub in subspecies)
                    ChoiceChip(
                      label: Text(sub.name),
                      selected: controller.subraceId == sub.anchor,
                      selectedColor: _gold.withValues(alpha: 0.28),
                      onSelected: (selected) => controller.selectSubrace(
                        selected ? sub.anchor : null,
                      ),
                    ),
                ],
              ),
              if (selectedSub != null) ...[
                const SizedBox(height: 8),
                _InfoLine(
                  label: 'Бонусы подвида',
                  value: _bonusLine(
                    selectedSub.bonuses,
                    selectedSub.bonusesChoice,
                  ),
                ),
                if (selectedSub.traits.isNotEmpty)
                  _InfoLine(
                    label: 'Умения подвида',
                    value: _truncate(
                      selectedSub.traits.map((t) => t.name).join(', '),
                      160,
                    ),
                  ),
              ],
            ],
            if (controller.raceBonusHasChoice) ...[
              const SizedBox(height: 12),
              _RaceBonusEditor(controller: controller),
            ],
            if (race.traits.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Черты', style: theme.textTheme.titleMedium),
              for (final trait in race.traits)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  title: Text(trait.name),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(_truncate(trait.text, 200)),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RaceBonusEditor extends StatelessWidget {
  const _RaceBonusEditor({required this.controller});

  final CharacterBuilderController controller;

  @override
  Widget build(BuildContext context) {
    final picks = controller.raceBonusPicks;
    final count = controller.bonusPickCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Распределение расовых бонусов',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<RaceBonusMode>(
          segments: const [
            ButtonSegment(
              value: RaceBonusMode.plusTwoPlusOne,
              label: Text('+2/+1'),
            ),
            ButtonSegment(
              value: RaceBonusMode.plusOneThree,
              label: Text('+1/+1/+1'),
            ),
          ],
          selected: {controller.raceBonusMode},
          onSelectionChanged: (selection) {
            if (selection.isNotEmpty) {
              controller.setRaceBonusMode(selection.first);
            }
          },
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (var slot = 0; slot < count; slot++)
              SizedBox(
                width: 220,
                child: _BonusAbilityDropdown(
                  controller: controller,
                  slot: slot,
                  current: picks[slot],
                  otherPicks: <Ability>{
                    for (var i = 0; i < count; i++)
                      if (i != slot && picks[i] != null) picks[i]!,
                  },
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _BonusAbilityDropdown extends StatelessWidget {
  const _BonusAbilityDropdown({
    required this.controller,
    required this.slot,
    required this.current,
    required this.otherPicks,
  });

  final CharacterBuilderController controller;
  final int slot;
  final Ability? current;
  final Set<Ability> otherPicks;

  @override
  Widget build(BuildContext context) {
    final bonus = controller.raceBonusMode == RaceBonusMode.plusTwoPlusOne
        ? (slot == 0 ? '+2' : '+1')
        : '+1';
    final options = Ability.values
        .where((ability) => ability == current || !otherPicks.contains(ability))
        .toList();

    return DropdownButtonFormField<Ability>(
      initialValue: current,
      decoration: InputDecoration(
        labelText: 'Характеристика $bonus',
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final ability in options)
          DropdownMenuItem(
            value: ability,
            child: Text(ability.nameRu),
          ),
      ],
      onChanged: (value) => controller.setRaceBonusPick(slot, value),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          Expanded(child: Text(value.isEmpty ? '—' : value)),
        ],
      ),
    );
  }
}

String _bonusLine(List<RaceBonus> bonuses, bool hasChoice) {
  final parts = <String>[];
  for (final bonus in bonuses) {
    final name = _abilityName(bonus.ability);
    final sign = bonus.bonus >= 0 ? '+${bonus.bonus}' : '${bonus.bonus}';
    parts.add('$name $sign');
  }
  if (hasChoice) {
    parts.add('Выбор: +2/+1 или +1/+1/+1');
  }
  return parts.isEmpty ? '—' : parts.join(', ');
}

String _abilityName(dynamic raw) {
  if (raw is Ability) return raw.nameRu;
  final text = raw?.toString().trim() ?? '';
  final lower = text.toLowerCase();
  for (final ability in Ability.values) {
    if (ability.id.toLowerCase() == lower ||
        ability.nameRu.toLowerCase() == lower) {
      return ability.nameRu;
    }
  }
  return text.isEmpty ? 'Характеристика' : text;
}

String _truncate(String text, int maxLength) {
  final normalized = text.trim();
  if (normalized.length <= maxLength) return normalized;
  return '${normalized.substring(0, maxLength).trimRight()}…';
}
