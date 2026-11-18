import 'package:flutter/material.dart';

import '../character_builder_controller.dart';

const Color _gold = Color(0xFFC9A227);

class EquipmentStep extends StatelessWidget {
  const EquipmentStep({super.key, required this.controller});

  final CharacterBuilderController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final equipment = controller.selectedClassEquipment;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (controller.selectedClass == null)
          const Text('Сначала выберите класс на предыдущем шаге.')
        else if (equipment == null)
          const Text('Стартовый набор не найден в каталоге')
        else ...[
          Text(equipment.intro, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          for (var rowIndex = 0;
              rowIndex < equipment.rows.length;
              rowIndex++)
            if (equipment.rows[rowIndex].isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Вариант ${rowIndex + 1}',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        RadioGroup<int>(
                          groupValue:
                              controller.equipmentChoiceFor(rowIndex),
                          onChanged: (value) {
                            if (value != null) {
                              controller.selectEquipmentOption(
                                rowIndex,
                                value,
                              );
                            }
                          },
                          child: Column(
                            children: [
                              for (var optionIndex = 0;
                                  optionIndex <
                                      equipment.rows[rowIndex].length;
                                  optionIndex++)
                                RadioListTile<int>(
                                  value: optionIndex,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    equipment.rows[rowIndex][optionIndex],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
        const SizedBox(height: 8),
        Text('Снаряжение предыстории',
            style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          controller.selectedBackground == null
              ? 'Предыстория не выбрана'
              : controller.selectedBackground!.equipment,
        ),
        if (equipment != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _gold.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Итоговые строки снаряжения',
                    style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                if (controller.equipmentLines.isEmpty)
                  const Text('—')
                else
                  for (final line in controller.equipmentLines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text('• $line'),
                    ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
