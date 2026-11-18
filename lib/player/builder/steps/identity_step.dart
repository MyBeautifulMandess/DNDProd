import 'package:flutter/material.dart';

import '../../../core/rules/ability.dart';
import '../../../shared/avatar_picker.dart';
import '../character_builder_controller.dart';

const Color _gold = Color(0xFFC9A227);

class IdentityStep extends StatefulWidget {
  const IdentityStep({super.key, required this.controller});

  final CharacterBuilderController controller;

  @override
  State<IdentityStep> createState() => _IdentityStepState();
}

class _IdentityStepState extends State<IdentityStep> {
  late final TextEditingController _nameController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.controller.name);
    _notesController =
        TextEditingController(text: widget.controller.notes);
  }

  Future<void> _pickCustomAvatar() async {
    final controller = widget.controller;
    await controller.importCustomAvatar();
    if (!mounted) return;
    final error = controller.saveError;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Имя персонажа',
            border: OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.next,
          onChanged: controller.setName,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notesController,
          decoration: const InputDecoration(
            labelText: 'Заметки',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          minLines: 3,
          maxLines: 6,
          onChanged: controller.setNotes,
        ),
        const SizedBox(height: 16),
        Text('Аватар', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final asset in kAvatarPresetAssets)
              _AvatarCard(
                asset: asset,
                selected: controller.avatarPath == asset,
                onTap: () => controller.setAvatarPath(asset),
              ),
            _AvatarCard(
              asset: null,
              selected: controller.avatarPath.isNotEmpty &&
                  !controller.avatarPath.startsWith('assets/'),
              onTap: _pickCustomAvatar,
            ),
          ],
        ),
        const SizedBox(height: 20),
        _SummaryCard(controller: controller),
      ],
    );
  }
}

class _AvatarCard extends StatelessWidget {
  const _AvatarCard({
    required this.asset,
    required this.selected,
    required this.onTap,
  });

  /// null — карточка импорта своей картинки.
  final String? asset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final asset = this.asset;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? _gold : Colors.white.withValues(alpha: 0.16),
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: asset == null
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined, size: 28),
                  SizedBox(height: 2),
                  Text('Своя', style: TextStyle(fontSize: 11)),
                ],
              )
            : Image.asset(
                asset,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.image_not_supported_outlined,
                ),
              ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.controller});

  final CharacterBuilderController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final skills = controller.combinedSkillProficiencies
        .map((skill) => skill.nameRu)
        .toList()
      ..sort();

    final abilitiesText = Ability.values.map((ability) {
      final total = controller.totalScoreOf(ability);
      final modifier = controller.modifierOf(ability);
      return '${ability.nameRu} $total (${_modifierText(modifier)})';
    }).join(', ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Сводка', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            _SummaryRow(
              label: 'Имя',
              value: controller.name.trim().isEmpty
                  ? '—'
                  : controller.name.trim(),
            ),
            _SummaryRow(label: 'Раса', value: controller.raceDisplayName),
            _SummaryRow(label: 'Класс', value: controller.classDisplayName),
            const _SummaryRow(label: 'Уровень', value: '1'),
            _SummaryRow(label: 'Хиты', value: '${controller.computedMaxHp}'),
            _SummaryRow(label: 'Характеристики', value: abilitiesText),
            _SummaryRow(
              label: 'Навыки',
              value: skills.isEmpty ? '—' : skills.join(', '),
            ),
            _SummaryRow(
              label: 'Предыстория',
              value: controller.backgroundDisplayName,
            ),
            _SummaryRow(
              label: 'Заклинания',
              value: '${controller.knownSpellCount}',
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

String _modifierText(int modifier) => modifier >= 0 ? '+$modifier' : '$modifier';
