import 'package:flutter/material.dart';

import '../../../core/models/catalog.dart';
import '../../../core/rules/ability.dart';
import '../character_builder_controller.dart';

const Color _gold = Color(0xFFC9A227);

class BackgroundStep extends StatefulWidget {
  const BackgroundStep({super.key, required this.controller});

  final CharacterBuilderController controller;

  @override
  State<BackgroundStep> createState() => _BackgroundStepState();
}

class _BackgroundStepState extends State<BackgroundStep> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final query = _query.trim().toLowerCase();
    final backgrounds = controller.selectableBackgrounds
        .where((background) =>
            query.isEmpty || background.nameRu.toLowerCase().contains(query))
        .toList()
      ..sort((a, b) => a.nameRu.compareTo(b.nameRu));

    final selected = controller.selectedBackground;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          decoration: const InputDecoration(
            labelText: 'Поиск предыстории',
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
            for (final background in backgrounds)
              ChoiceChip(
                label: Text(background.nameRu),
                selected: controller.backgroundId == background.id,
                selectedColor: _gold.withValues(alpha: 0.28),
                onSelected: (_) => controller.selectBackground(background.id),
              ),
          ],
        ),
        if (selected != null) ...[
          const SizedBox(height: 16),
          _BackgroundDetailCard(controller: controller, selected: selected),
        ],
      ],
    );
  }
}

class _BackgroundDetailCard extends StatelessWidget {
  const _BackgroundDetailCard({
    required this.controller,
    required this.selected,
  });

  final CharacterBuilderController controller;
  final Background selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundSkills = controller.backgroundSkills;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(selected.nameRu, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            _InfoLine(
              label: 'Навыки',
              value: _skillsText(backgroundSkills, controller),
            ),
            _InfoLine(label: 'Инструменты', value: selected.tools),
            _InfoLine(label: 'Языки', value: selected.languages),
            _InfoLine(label: 'Снаряжение', value: selected.equipment),
            if (selected.featureName.isNotEmpty) ...[
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                title: Text(selected.featureName),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(selected.featureText),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _skillsText(List<Skill> skills, CharacterBuilderController controller) {
    if (skills.isEmpty) return '—';
    return skills.map((skill) {
      final alreadyOwned = controller.classSkills.contains(skill);
      return alreadyOwned ? '${skill.nameRu} (уже владеете)' : skill.nameRu;
    }).join(', ');
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = value.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          Expanded(child: Text(text.isEmpty ? '—' : text)),
        ],
      ),
    );
  }
}
