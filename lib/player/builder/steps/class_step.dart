import 'package:flutter/material.dart';

import '../../../core/models/catalog.dart';
import '../../../core/rules/ability.dart';
import '../character_builder_controller.dart';

const Color _gold = Color(0xFFC9A227);

class ClassStep extends StatefulWidget {
  const ClassStep({super.key, required this.controller});

  final CharacterBuilderController controller;

  @override
  State<ClassStep> createState() => _ClassStepState();
}

class _ClassStepState extends State<ClassStep> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final query = _query.trim().toLowerCase();
    final classes = controller.classes.values
        .where((item) =>
            query.isEmpty || item.nameRu.toLowerCase().contains(query))
        .toList()
      ..sort((a, b) => a.nameRu.compareTo(b.nameRu));

    final selected = controller.selectedClass;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          decoration: const InputDecoration(
            labelText: 'Поиск класса',
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
            for (final item in classes)
              ChoiceChip(
                label: Text(item.nameRu),
                selected: controller.classId == item.id,
                selectedColor: _gold.withValues(alpha: 0.28),
                onSelected: (_) => controller.selectClass(item.id),
              ),
          ],
        ),
        if (selected != null) ...[
          const SizedBox(height: 16),
          _ClassDetailCard(controller: controller, selected: selected),
        ],
      ],
    );
  }
}

class _ClassDetailCard extends StatelessWidget {
  const _ClassDetailCard({required this.controller, required this.selected});

  final CharacterBuilderController controller;
  final ClassEntryCatalog selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final availableSkills = controller.availableClassSkills;
    final maxChoices = controller.classSkillChoiceCount;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(selected.nameRu, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            _InfoLine(
              label: 'Кость хитов',
              value: '1к${selected.hitDiceSides}',
            ),
            _InfoLine(label: 'Спасброски', value: selected.saves),
            if (selected.armorProficiency.trim().isNotEmpty)
              _InfoLine(
                label: 'Доспехи',
                value: selected.armorProficiency,
              ),
            if (selected.weaponProficiency.trim().isNotEmpty)
              _InfoLine(
                label: 'Оружие',
                value: selected.weaponProficiency,
              ),
            if (selected.tools.trim().isNotEmpty)
              _InfoLine(label: 'Инструменты', value: selected.tools),
            if (selected.id == '104-warlock') ...[
              const SizedBox(height: 8),
              Text(
                'Покровитель выбирается на 1 уровне (см. dnd.su). '
                'Поле подкласса останется пустым.',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (availableSkills.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Навыки: выбрано ${controller.classSkills.length} из $maxChoices',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final skill in availableSkills)
                    _SkillChip(
                      controller: controller,
                      skill: skill,
                      maxChoices: maxChoices,
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

class _SkillChip extends StatelessWidget {
  const _SkillChip({
    required this.controller,
    required this.skill,
    required this.maxChoices,
  });

  final CharacterBuilderController controller;
  final Skill skill;
  final int maxChoices;

  @override
  Widget build(BuildContext context) {
    final selected = controller.classSkills.contains(skill);
    final canSelect = selected || controller.classSkills.length < maxChoices;
    return FilterChip(
      label: Text(skill.nameRu),
      selected: selected,
      selectedColor: _gold.withValues(alpha: 0.28),
      onSelected: canSelect
          ? (_) => controller.toggleClassSkill(skill)
          : null,
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
