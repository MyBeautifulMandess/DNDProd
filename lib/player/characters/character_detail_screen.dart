/// Экран персонажа: полный просмотр всех данных (характеристики, навыки,
/// спасброски, расовые черты, умения класса, предыстория, заклинания,
/// снаряжение) и быстрая правка имени, аватара, хитов и заметок.
/// Игровые броски и лист в игре — фазы 3–4 (docs/07-roadmap.md).
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/models/catalog.dart';
import '../../core/models/character.dart';
import '../../core/rules/ability.dart';
import '../../core/rules/formulas.dart';
import '../../data/catalog_loader.dart';
import '../../shared/avatar_picker.dart';
import '../../shared/avatar_picture.dart';
import '../../shared/spell_card.dart';
import 'character_repository.dart';
import 'level_up_screen.dart';

const Color _gold = Color(0xFFC9A227);

class CharacterDetailScreen extends StatefulWidget {
  const CharacterDetailScreen({
    super.key,
    required this.character,
    required this.repository,
  });

  final Character character;
  final CharacterRepository repository;

  @override
  State<CharacterDetailScreen> createState() => _CharacterDetailScreenState();
}

class _DetailData {
  _DetailData({
    required this.character,
    required this.race,
    required this.raceClass,
    required this.background,
    required this.spells,
  });

  final Character character;
  final RaceDetail? race;
  final ClassEntryCatalog? raceClass;
  final Background? background;
  final Map<String, Spell> spells;

  Subspecies? get subspecies {
    final anchor = character.subraceId;
    if (anchor == null) return null;
    for (final s in race?.subspecies ?? const <Subspecies>[]) {
      if (s.anchor == anchor) return s;
    }
    return null;
  }
}

class _CharacterDetailScreenState extends State<CharacterDetailScreen> {
  late Character _character;
  late final TextEditingController _nameController;
  late final TextEditingController _notesController;
  Future<_DetailData>? _future;

  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    _character = widget.character;
    _nameController = TextEditingController(text: _character.name);
    _notesController = TextEditingController(text: _character.notes);
    _future = _load();
  }

  Future<_DetailData> _load() async {
    final raceDetails = await catalogLoader.raceDetails();
    final classes = await catalogLoader.classes();
    final backgroundList = await catalogLoader.backgrounds();
    final spells = await catalogLoader.spells();
    Background? background;
    for (final b in backgroundList) {
      if (b.id == _character.backgroundId) {
        background = b;
        break;
      }
    }
    return _DetailData(
      character: _character,
      race: raceDetails[_character.raceId],
      raceClass: classes[_character.classEntries.firstOrNull?.classId],
      background: background,
      spells: {for (final s in spells) s.id: s},
    );
  }

  Future<void> _persistNow() async {
    await widget.repository.save(_character);
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), () async {
      await _persistNow();
    });
  }

  void _mutate(VoidCallback change) {
    setState(change);
    _scheduleSave();
  }

  Future<void> _changeAvatar() async {
    final picked = await showAvatarPickerSheet(context, current: _character.avatarPath);
    if (picked == null || picked == _character.avatarPath) return;
    _mutate(() => _character.avatarPath = picked);
  }

  Future<void> _editHp() async {
    final current = TextEditingController(text: '${_character.currentHp}');
    final max = TextEditingController(text: '${_character.maxHp}');
    final temp = TextEditingController(text: '${_character.tempHp}');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Хиты'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: current,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Текущие'),
            ),
            TextField(
              controller: max,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Максимум'),
            ),
            TextField(
              controller: temp,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Временные'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      _mutate(() {
        _character.currentHp = int.tryParse(current.text.trim()) ?? _character.currentHp;
        _character.maxHp = int.tryParse(max.text.trim()) ?? _character.maxHp;
        _character.tempHp = int.tryParse(temp.text.trim()) ?? 0;
      });
    }
    current.dispose();
    max.dispose();
    temp.dispose();
  }

  Future<void> _levelUp() async {
    final raw = await widget.repository.exportJson(_character.id);
    if (!mounted) return;
    final leveled = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => LevelUpScreen(
          character: Character.fromJson(jsonDecode(raw) as Map<String, dynamic>),
          repository: widget.repository,
        ),
      ),
    );
    if (leveled ?? false) {
      final updated = await widget.repository.exportJson(_character.id);
      setState(() {
        _character = Character.fromJson(jsonDecode(updated) as Map<String, dynamic>);
        _nameController.text = _character.name;
        _notesController.text = _character.notes;
      });
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    unawaited(_persistNow());
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_character.name.isEmpty ? 'Персонаж' : _character.name),
        actions: [
          if (_character.classEntries.isNotEmpty &&
              _character.classEntries.first.level < 20)
            IconButton(
              tooltip: 'Повысить уровень',
              onPressed: _levelUp,
              icon: const Icon(Icons.arrow_upward),
            ),
        ],
      ),
      body: FutureBuilder<_DetailData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Ошибка загрузки: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return _CharacterView(
            data: snapshot.data!,
            nameController: _nameController,
            notesController: _notesController,
            onAvatarTap: _changeAvatar,
            onNameChanged: (value) => _mutate(() => _character.name = value),
            onNotesChanged: (value) => _mutate(() => _character.notes = value),
            onHpStep: (field, delta) => _mutate(() {
              switch (field) {
                case _HpField.current:
                  final next = _character.currentHp + delta;
                  _character.currentHp = next < 0
                      ? 0
                      : (next > _character.maxHp ? _character.maxHp : next);
                case _HpField.max:
                  _character.maxHp = max1(_character.maxHp + delta);
                  if (_character.currentHp > _character.maxHp) {
                    _character.currentHp = _character.maxHp;
                  }
                case _HpField.temp:
                  _character.tempHp = max0(_character.tempHp + delta);
              }
            }),
            onEditHp: _editHp,
          );
        },
      ),
    );
  }
}

enum _HpField { current, max, temp }

int max0(int value) => value < 0 ? 0 : value;

class _CharacterView extends StatelessWidget {
  const _CharacterView({
    required this.data,
    required this.nameController,
    required this.notesController,
    required this.onAvatarTap,
    required this.onNameChanged,
    required this.onNotesChanged,
    required this.onHpStep,
    required this.onEditHp,
  });

  final _DetailData data;
  final TextEditingController nameController;
  final TextEditingController notesController;
  final VoidCallback onAvatarTap;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onNotesChanged;
  final void Function(_HpField field, int delta) onHpStep;
  final VoidCallback onEditHp;

  Character get character => data.character;

  int get _level => character.classEntries.isEmpty
      ? character.level
      : character.classEntries.first.level;

  int _effectiveScore(Ability ability) =>
      (character.abilityScores[ability] ?? 10) +
      racialBonus(ability, data.race, subraceAnchor: character.subraceId);

  String _raceLine() {
    final race = data.race;
    if (race == null) return character.raceId ?? 'Раса?';
    final sub = data.subspecies;
    return sub == null ? race.nameRu : '${race.nameRu} (${sub.name})';
  }

  String _classLine() {
    if (character.classEntries.isEmpty) return 'Класс?';
    final entry = character.classEntries.first;
    final name = data.raceClass?.nameRu ?? entry.classId;
    return '$name, $_level ур.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final level = _level < 1 ? 1 : (_level > 20 ? 20 : _level);
    final profBonus = proficiencyBonus(level);
    final sub = data.subspecies;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        // Шапка: аватар + имя + основные сведения.
        Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: onAvatarTap,
                      borderRadius: BorderRadius.circular(44),
                      child: AvatarPicture(
                        path: character.avatarPath,
                        size: 88,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              labelText: 'Имя',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: onNameChanged,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_raceLine()} · ${_classLine()}',
                            style: theme.textTheme.bodySmall,
                          ),
                          Text(
                            'Предыстория: ${data.background?.nameRu ?? character.backgroundId ?? '—'}',
                            style: theme.textTheme.bodySmall,
                          ),
                          Text(
                            'Бонус мастерства +$profBonus · Инициатива ${_modifierText(abilityModifier(_effectiveScore(Ability.dexterity)))}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (data.race != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    data.race!.url,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.hintColor),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Хиты.
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Хиты', style: theme.textTheme.titleMedium),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: onEditHp,
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Изменить'),
                    ),
                  ],
                ),
                _HpStepper(
                  label: 'Текущие',
                  value: character.currentHp,
                  onStep: (delta) => onHpStep(_HpField.current, delta),
                ),
                _HpStepper(
                  label: 'Максимум',
                  value: character.maxHp,
                  onStep: (delta) => onHpStep(_HpField.max, delta),
                ),
                _HpStepper(
                  label: 'Временные',
                  value: character.tempHp,
                  onStep: (delta) => onHpStep(_HpField.temp, delta),
                ),
              ],
            ),
          ),
        ),

        // Характеристики.
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Характеристики', style: theme.textTheme.titleMedium),
                if (data.race?.bonusesText.isNotEmpty ?? false) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Раса: ${data.race!.bonusesText}',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (sub != null && sub.bonusesText.isNotEmpty)
                    Text(
                      'Подвид: ${sub.bonusesText}',
                      style: theme.textTheme.bodySmall,
                    ),
                ],
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.4,
                  children: [
                    for (final ability in Ability.values)
                      _AbilityTile(
                        ability: ability,
                        effective: _effectiveScore(ability),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Спасброски.
        _BonusListCard(
          title: 'Спасброски',
          rows: [
            for (final ability in Ability.values)
              _BonusRow(
                label: ability.nameRu,
                bonus: savingThrowBonus(
                  ability: ability,
                  abilityScore: _effectiveScore(ability),
                  proficient: character.saveProficiencies.contains(ability),
                  level: level,
                ),
                proficient: character.saveProficiencies.contains(ability),
              ),
          ],
        ),

        // Навыки.
        _BonusListCard(
          title: 'Навыки',
          rows: [
            for (final skill in Skill.values)
              _BonusRow(
                label:
                    '${skill.nameRu} (${skill.ability.nameRu.substring(0, 3).toLowerCase()})',
                bonus: skillBonus(
                  skill: skill,
                  abilityScore: _effectiveScore(skill.ability),
                  proficient: character.skillProficiencies.contains(skill),
                  level: level,
                ),
                proficient: character.skillProficiencies.contains(skill),
              ),
          ]..sort((a, b) => a.label.compareTo(b.label)),
          footer:
              'Пассивное Восприятие: ${passivePerception(wisdom: _effectiveScore(Ability.wisdom), proficient: character.skillProficiencies.contains(Skill.perception), proficiencyBonusValue: profBonus)}',
        ),

        // Класс.
        if (data.raceClass != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Класс: ${data.raceClass!.nameRu} (кость хитов к${data.raceClass!.hitDiceSides})',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(label: 'Доспехи', value: data.raceClass!.armorProficiency),
                  _InfoRow(label: 'Оружие', value: data.raceClass!.weaponProficiency),
                  _InfoRow(label: 'Инструменты', value: data.raceClass!.tools),
                  _InfoRow(label: 'Спасброски', value: data.raceClass!.saves),
                  _InfoRow(
                    label: 'Навыки',
                    value: data.raceClass!.skillProficiencyRule,
                  ),
                  const SizedBox(height: 4),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Умения по уровням'),
                    children: [
                      for (var lvl = 1; lvl <= _level; lvl++)
                        if (data.raceClass!.levels[lvl]?.features.isNotEmpty ??
                            false)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 28,
                                  child: Text(
                                    '$lvl',
                                    style: const TextStyle(
                                      color: _gold,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    data.raceClass!.levels[lvl]!.features
                                        .join(', '),
                                  ),
                                ),
                              ],
                            ),
                          ),
                    ],
                  ),
                ],
              ),
            ),
          ),

        // Раса.
        if (data.race != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Раса: ${_raceLine()}', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _InfoRow(
                    label: 'Скорость',
                    value: '${sub?.speedFt ?? data.race!.speedFt ?? '—'} фт.',
                  ),
                  _InfoRow(
                    label: 'Размер',
                    value: sub?.sizeText.isNotEmpty == true
                        ? sub!.sizeText
                        : data.race!.sizeText,
                  ),
                  _InfoRow(
                    label: 'Тёмное зрение',
                    value:
                        '${sub?.darkvisionFt ?? data.race!.darkvisionFt ?? 0} фт.',
                  ),
                  _InfoRow(label: 'Языки', value: data.race!.languagesText),
                  if (sub != null && sub.languagesText.isNotEmpty)
                    _InfoRow(label: 'Языки подвида', value: sub.languagesText),
                  if (character.languages.isNotEmpty)
                    _InfoRow(
                      label: 'Доп. языки',
                      value: character.languages.join(', '),
                    ),
                  for (final trait in data.race!.traits)
                    _TraitTile(trait: trait),
                  if (sub != null) ...[
                    Text('Черты подвида «${sub.name}»',
                        style: theme.textTheme.bodySmall),
                    for (final trait in sub.traits) _TraitTile(trait: trait),
                  ],
                ],
              ),
            ),
          ),

        // Предыстория.
        if (data.background != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Предыстория: ${data.background!.nameRu}',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _InfoRow(label: 'Навыки', value: data.background!.skills),
                  _InfoRow(label: 'Инструменты', value: data.background!.tools),
                  _InfoRow(label: 'Языки', value: data.background!.languages),
                  _InfoRow(
                    label: 'Снаряжение',
                    value: data.background!.equipment,
                  ),
                  if (data.background!.featureName.isNotEmpty)
                    _TraitTile(
                      trait: RaceTrait(
                        name: data.background!.featureName,
                        text: data.background!.featureText,
                      ),
                    ),
                ],
              ),
            ),
          ),

        // Заклинания.
        if (character.knownSpellIds.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Заклинания (${character.knownSpellIds.length})',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final id in character.knownSpellIds)
                        if (data.spells[id] != null)
                          ActionChip(
                            label: Text(data.spells[id]!.nameRu),
                            onPressed: () =>
                                showSpellCard(context, data.spells[id]!),
                          ),
                    ],
                  ),
                ],
              ),
            ),
          ),

        // Снаряжение.
        if (character.equipmentLines.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Снаряжение', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  for (final line in character.equipmentLines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• '),
                          Expanded(child: Text(line)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

        // Заметки.
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Заметки', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  minLines: 3,
                  maxLines: 8,
                  onChanged: onNotesChanged,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HpStepper extends StatelessWidget {
  const _HpStepper({
    required this.label,
    required this.value,
    required this.onStep,
  });

  final String label;
  final int value;
  final ValueChanged<int> onStep;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => onStep(-1),
            icon: const Icon(Icons.remove_circle_outline, size: 20),
          ),
          SizedBox(
            width: 44,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => onStep(1),
            icon: const Icon(Icons.add_circle_outline, size: 20),
          ),
        ],
      ),
    );
  }
}

class _AbilityTile extends StatelessWidget {
  const _AbilityTile({required this.ability, required this.effective});

  final Ability ability;
  final int effective;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            ability.nameRu,
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          Text(
            '$effective',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            _modifierText(abilityModifier(effective)),
            style: theme.textTheme.bodySmall?.copyWith(color: _gold),
          ),
        ],
      ),
    );
  }
}

class _BonusRow {
  _BonusRow({required this.label, required this.bonus, required this.proficient});

  final String label;
  final int bonus;
  final bool proficient;
}

class _BonusListCard extends StatelessWidget {
  const _BonusListCard({required this.title, required this.rows, this.footer});

  final String title;
  final List<_BonusRow> rows;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      row.proficient
                          ? Icons.circle
                          : Icons.circle_outlined,
                      size: 10,
                      color: row.proficient ? _gold : theme.hintColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(row.label)),
                    Text(
                      _modifierText(row.bonus),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            if (footer != null) ...[
              const SizedBox(height: 6),
              Text(footer!, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trimmed = value.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: theme.textTheme.bodySmall),
          ),
          Expanded(child: Text(trimmed.isEmpty ? '—' : trimmed)),
        ],
      ),
    );
  }
}

class _TraitTile extends StatelessWidget {
  const _TraitTile({required this.trait});

  final RaceTrait trait;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(trait.name),
      childrenPadding: const EdgeInsets.only(bottom: 8),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(trait.text),
        ),
      ],
    );
  }
}

String _modifierText(int modifier) =>
    modifier >= 0 ? '+$modifier' : '$modifier';
