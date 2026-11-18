import 'package:flutter/material.dart';

import '../../../core/rules/ability.dart';
import '../../../core/rules/formulas.dart';
import '../character_builder_controller.dart';

const Color _gold = Color(0xFFC9A227);

class AbilitiesStep extends StatelessWidget {
  const AbilitiesStep({super.key, required this.controller});

  final CharacterBuilderController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<AbilityMode>(
          segments: const [
            ButtonSegment(
              value: AbilityMode.pointBuy,
              label: Text('Расстановка очков'),
            ),
            ButtonSegment(
              value: AbilityMode.standardArray,
              label: Text('Стандартный массив'),
            ),
          ],
          selected: {controller.abilityMode},
          onSelectionChanged: (selection) {
            if (selection.isNotEmpty) {
              controller.setAbilityMode(selection.first);
            }
          },
        ),
        const SizedBox(height: 16),
        if (controller.abilityMode == AbilityMode.pointBuy)
          _PointBuyBlock(controller: controller)
        else
          _StandardArrayBlock(controller: controller),
        const SizedBox(height: 20),
        _TotalsTable(controller: controller),
        const SizedBox(height: 16),
        _DerivedStats(controller: controller),
      ],
    );
  }
}

class _PointBuyBlock extends StatelessWidget {
  const _PointBuyBlock({required this.controller});

  final CharacterBuilderController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Осталось очков: ${controller.pointBuyRemaining} из $pointBuyBudget',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        for (final ability in Ability.values)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 140,
                  child: Text(ability.nameRu, style: theme.textTheme.bodyLarge),
                ),
                IconButton(
                  tooltip: 'Уменьшить',
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  onPressed: controller.canDecreaseAbility(ability)
                      ? () => controller.changeAbilityBase(ability, -1)
                      : null,
                  icon: const Icon(Icons.remove),
                ),
                SizedBox(
                  width: 44,
                  child: Center(
                    child: Text(
                      '${controller.baseScoreOf(ability)}',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Увеличить',
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  onPressed: controller.canIncreaseAbility(ability)
                      ? () => controller.changeAbilityBase(ability, 1)
                      : null,
                  icon: const Icon(Icons.add),
                ),
                const SizedBox(width: 8),
                Text(
                  '${pointBuyCost(controller.baseScoreOf(ability))}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StandardArrayBlock extends StatelessWidget {
  const _StandardArrayBlock({required this.controller});

  final CharacterBuilderController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Значения: ${standardArray.join(', ')}',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        for (final ability in Ability.values)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 160,
                  child: Text(ability.nameRu, style: theme.textTheme.bodyLarge),
                ),
                SizedBox(
                  width: 140,
                  child: DropdownButtonFormField<int>(
                    initialValue: controller.baseScoreOf(ability),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      for (final value
                          in controller.standardArrayOptionsFor(ability))
                        DropdownMenuItem(
                          value: value,
                          child: Text('$value'),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        controller.setAbilityBase(ability, value);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TotalsTable extends StatelessWidget {
  const _TotalsTable({required this.controller});

  final CharacterBuilderController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headerStyle = theme.textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w600,
      color: _gold,
    );

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2.4),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(1),
        3: FlexColumnWidth(1),
        4: FlexColumnWidth(1),
      },
      border: TableBorder(
        horizontalInside: BorderSide(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      children: [
        TableRow(
          children: [
            _cell('Характеристика', style: headerStyle),
            _cell('База', style: headerStyle),
            _cell('Раса', style: headerStyle),
            _cell('Итог', style: headerStyle),
            _cell('Мод', style: headerStyle),
          ],
        ),
        for (final ability in Ability.values)
          TableRow(
            children: [
              _cell(ability.nameRu),
              _cell('${controller.baseScoreOf(ability)}'),
              _cell('${controller.effectiveRaceBonuses[ability] ?? 0}'),
              _cell(
                '${controller.totalScoreOf(ability)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              _cell(_modifierText(controller.modifierOf(ability))),
            ],
          ),
      ],
    );
  }

  Widget _cell(String text, {TextStyle? style}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Text(text, style: style),
    );
  }
}

class _DerivedStats extends StatelessWidget {
  const _DerivedStats({required this.controller});

  final CharacterBuilderController controller;

  @override
  Widget build(BuildContext context) {
    final speed = controller.selectedSpeedFt;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _StatChip(label: 'КД', value: '${controller.armorClassValue}'),
        _StatChip(
          label: 'Инициатива',
          value: _modifierText(controller.modifierOf(Ability.dexterity)),
        ),
        _StatChip(
          label: 'Пассивное Восприятие',
          value: '${controller.passivePerceptionValue}',
        ),
        _StatChip(
          label: 'Скорость',
          value: speed == null ? '—' : '$speed футов',
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(width: 8),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: _gold,
            ),
          ),
        ],
      ),
    );
  }
}

String _modifierText(int modifier) => modifier >= 0 ? '+$modifier' : '$modifier';
