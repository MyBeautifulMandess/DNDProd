/// Быстрый лист персонажа во время сессии: статы, хиты, броски и заклинания.
/// Данные — только из сохранённого персонажа и каталогов (docs/04-player-app.md).
library;

import 'package:flutter/material.dart';

import '../../core/models/catalog.dart';
import '../../core/models/character.dart';
import '../../core/rules/ability.dart';
import '../../core/rules/formulas.dart';
import '../../core/rules/roll_formula.dart';
import '../../data/catalog_loader.dart';
import '../../shared/spell_card.dart';
import '../characters/character_repository.dart';

const Color _gold = Color(0xFFC9A227);

/// Панель открывается поверх экрана лобби игрока.
/// [onRoll] отправляет формулу в общий бросок чата, [onChat] — текстовое событие.
class CharacterSheetPanel extends StatefulWidget {
  const CharacterSheetPanel({
    super.key,
    required this.character,
    required this.repository,
    required this.onRoll,
    required this.onChat,
    this.catalogs,
  });

  final Character character;
  final CharacterRepository repository;
  final ValueChanged<String> onRoll;
  final ValueChanged<String> onChat;

  /// Загрузчик можно подменить в тестах.
  final CatalogLoader? catalogs;

  @override
  State<CharacterSheetPanel> createState() => _CharacterSheetPanelState();
}

class _SheetData {
  _SheetData({
    required this.race,
    required this.subspecies,
    required this.mainClass,
    required this.background,
    required this.spells,
  });

  final RaceDetail? race;
  final Subspecies? subspecies;
  final ClassEntryCatalog? mainClass;
  final Background? background;
  final Map<String, Spell> spells;
}

enum _HpField { current, max, temp }

class _CharacterSheetPanelState extends State<CharacterSheetPanel> {
  late Character _character;
  late Future<_SheetData> _future;

  @override
  void initState() {
    super.initState();
    _character = widget.character;
    _future = _load();
  }

  Future<_SheetData> _load() async {
    final catalogs = widget.catalogs ?? catalogLoader;
    final races = await catalogs.raceDetails();
    final classes = await catalogs.classes();
    final backgrounds = await catalogs.backgrounds();
    final spells = await catalogs.spells();
    final race = races[_character.raceId];
    Subspecies? subspecies;
    for (final candidate in race?.subspecies ?? const <Subspecies>[]) {
      if (candidate.anchor == _character.subraceId) {
        subspecies = candidate;
        break;
      }
    }
    Background? background;
    for (final candidate in backgrounds) {
      if (candidate.id == _character.backgroundId) {
        background = candidate;
        break;
      }
    }
    return _SheetData(
      race: race,
      subspecies: subspecies,
      mainClass: classes[_character.classEntries.firstOrNull?.classId],
      background: background,
      spells: {for (final spell in spells) spell.id: spell},
    );
  }

  void _stepHp(_HpField field, int delta) {
    setState(() {
      switch (field) {
        case _HpField.current:
          final next = _character.currentHp + delta;
          _character.currentHp = next < 0
              ? 0
              : (next > _character.maxHp ? _character.maxHp : next);
        case _HpField.max:
          _character.maxHp = _steppedHp(_character.maxHp, delta);
          if (_character.currentHp > _character.maxHp) {
            _character.currentHp = _character.maxHp;
          }
        case _HpField.temp:
          _character.tempHp = _steppedHp(_character.tempHp, delta);
      }
    });
    _saveHp();
    widget.onChat(
      'Хиты ${_character.name}: ${_character.currentHp}/${_character.maxHp}'
      ' (временные ${_character.tempHp})',
    );
  }

  int _steppedHp(int value, int delta) {
    final next = value + delta;
    return next < 0 ? 0 : next;
  }

  void _saveHp() {
    widget.repository.save(_character).ignore();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: FutureBuilder<_SheetData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return SizedBox(
                height: 200,
                child: Center(
                  child: Text('Ошибка загрузки каталогов: ${snapshot.error}'),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return _SheetView(
              data: snapshot.data!,
              character: _character,
              onHpStep: _stepHp,
              onRoll: widget.onRoll,
              onChat: widget.onChat,
            );
          },
        ),
      ),
    );
  }
}

class _SheetView extends StatelessWidget {
  const _SheetView({
    required this.data,
    required this.character,
    required this.onHpStep,
    required this.onRoll,
    required this.onChat,
  });

  final _SheetData data;
  final Character character;
  final void Function(_HpField field, int delta) onHpStep;
  final ValueChanged<String> onRoll;
  final ValueChanged<String> onChat;

  int get _level {
    final value = character.classEntries.firstOrNull?.level ?? character.level;
    return value < 1 ? 1 : (value > 20 ? 20 : value);
  }

  int _score(Ability ability) =>
      (character.abilityScores[ability] ?? 10) +
      racialBonus(ability, data.race, subraceAnchor: character.subraceId);

  int get _proficiency => proficiencyBonus(_level);

  int get _hitDiceSides => data.mainClass?.hitDiceSides ?? 0;

  String _raceLine() {
    if (data.race == null) return character.raceId ?? '—';
    return data.subspecies == null
        ? data.race!.nameRu
        : '${data.race!.nameRu} (${data.subspecies!.name})';
  }

  String _classLine() {
    if (character.classEntries.isEmpty) return '—';
    final entry = character.classEntries.first;
    final name = data.mainClass?.nameRu ?? entry.classId;
    final suffix = character.classEntries.length > 1 ? ' и др.' : '';
    return '$name $entry.level ур.$suffix';
  }

  List<Spell> _knownSpells() {
    final result = <Spell>[];
    for (final id in character.knownSpellIds) {
      final spell = data.spells[id];
      if (spell != null) result.add(spell);
    }
    result.sort((a, b) {
      final byLevel = a.level.compareTo(b.level);
      return byLevel != 0 ? byLevel : a.nameRu.compareTo(b.nameRu);
    });
    return result;
  }

  List<RaceTrait> _traits() {
    final result = <RaceTrait>[...data.race?.traits ?? const <RaceTrait>[]];
    if (data.subspecies != null) result.addAll(data.subspecies!.traits);
    final background = data.background;
    if (background != null && background.featureName.isNotEmpty) {
      result.add(RaceTrait(
        name: background.featureName,
        text: background.featureText,
      ));
    }
    return result;
  }

  List<String> _classFeatures() {
    final features = <String>[];
    for (var level = 1; level <= _level; level++) {
      for (final feature
          in data.mainClass?.levels[level]?.features ?? const <String>[]) {
        if (!features.contains(feature)) features.add(feature);
      }
    }
    return features;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dexterity = _score(Ability.dexterity);
    final speed = data.subspecies?.speedFt ?? data.race?.speedFt;
    final passive = passivePerception(
      wisdom: _score(Ability.wisdom),
      proficient: character.skillProficiencies.contains(Skill.perception),
      proficiencyBonusValue: _proficiency,
    );
    final spells = _knownSpells();

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  character.name.isEmpty ? 'Персонаж' : character.name,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text('${_raceLine()} · ${_classLine()}',
                    style: theme.textTheme.bodySmall),
                if (data.background != null)
                  Text('Предыстория: ${data.background!.nameRu}',
                      style: theme.textTheme.bodySmall),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _QuickStat(
                      label: 'КД (базовый)',
                      value: '${armorClass(dexterity: dexterity)}',
                    ),
                    _QuickStat(
                      label: 'Инициатива',
                      value: _signed(abilityModifier(dexterity)),
                    ),
                    _QuickStat(
                      label: 'Скорость',
                      value: speed == null ? '—' : '$speed фт.',
                    ),
                    _QuickStat(
                      label: 'Пасс. Восприятие',
                      value: '$passive',
                    ),
                    _QuickStat(
                      label: 'Бонус мастерства',
                      value: _signed(_proficiency),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
                    if (_hitDiceSides > 1)
                      FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 44),
                        ),
                        onPressed: () =>
                            onRoll(hitDieFormula(_hitDiceSides)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.casino_outlined, size: 18),
                            const SizedBox(width: 6),
                            Text('Кость d$_hitDiceSides'),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${character.currentHp} / ${character.maxHp}',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Временные: ${character.tempHp}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                _HpRow(
                  label: 'Текущие',
                  value: character.currentHp,
                  onStep: (delta) => onHpStep(_HpField.current, delta),
                ),
                _HpRow(
                  label: 'Максимум',
                  value: character.maxHp,
                  onStep: (delta) => onHpStep(_HpField.max, delta),
                ),
                _HpRow(
                  label: 'Временные',
                  value: character.tempHp,
                  onStep: (delta) => onHpStep(_HpField.temp, delta),
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Характеристики', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.35,
                  children: [
                    for (final ability in Ability.values)
                      _AbilityTile(
                        ability: ability,
                        score: _score(ability),
                        onTap: () => onRoll(
                          d20CheckFormula(abilityModifier(_score(ability))),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        _RollListCard(
          title: 'Спасброски',
          rows: [
            for (final ability in Ability.values)
              _RollRow(
                label: ability.nameRu,
                bonus: savingThrowBonus(
                  ability: ability,
                  abilityScore: _score(ability),
                  proficient: character.saveProficiencies.contains(ability),
                  level: _level,
                ),
                proficient: character.saveProficiencies.contains(ability),
                onTap: () => onRoll(d20CheckFormula(savingThrowBonus(
                  ability: ability,
                  abilityScore: _score(ability),
                  proficient: character.saveProficiencies.contains(ability),
                  level: _level,
                ))),
              ),
          ],
        ),
        _RollListCard(
          title: 'Навыки',
          rows: [
            for (final skill in Skill.values)
              _RollRow(
                label: '${skill.nameRu} (${skill.ability.id})',
                bonus: skillBonus(
                  skill: skill,
                  abilityScore: _score(skill.ability),
                  proficient: character.skillProficiencies.contains(skill),
                  level: _level,
                ),
                proficient: character.skillProficiencies.contains(skill),
                onTap: () => onRoll(d20CheckFormula(skillBonus(
                  skill: skill,
                  abilityScore: _score(skill.ability),
                  proficient: character.skillProficiencies.contains(skill),
                  level: _level,
                ))),
              ),
          ]..sort((a, b) => a.label.compareTo(b.label)),
        ),
        if (spells.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Заклинания (${spells.length})',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Ячейки не учитываются — в листе доступен только список '
                    'известных заклинаний по кругам.',
                    style: theme.textTheme.bodySmall,
                  ),
                  for (var circle = 0; circle <= 9; circle++) ...[
                    for (final spell
                        in spells.where((s) => s.level == circle)) ...[
                      const SizedBox(height: 6),
                      Text(
                        circle == 0 ? 'Заговоры' : 'Круг $circle',
                        style: theme.textTheme.labelLarge
                            ?.copyWith(color: _gold),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        minLeadingWidth: 0,
                        dense: true,
                        title: Text(spell.nameRu),
                        subtitle: Text(
                          [spell.schoolLine, spell.castTime]
                              .where((v) => v.trim().isNotEmpty)
                              .join(' · '),
                          style: theme.textTheme.bodySmall,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 44,
                              height: 44,
                              child: IconButton(
                                tooltip: 'Карточка',
                                icon: const Icon(Icons.description_outlined),
                                onPressed: () =>
                                    showSpellCard(context, spell),
                              ),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(64, 44),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              onPressed: () =>
                                  onChat('Заклинание: ${spell.nameRu}'),
                              child: const Text('Наложить'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Снаряжение и особенности',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                if (character.equipmentLines.isEmpty)
                  Text('Снаряжение не указано', style: theme.textTheme.bodySmall),
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
                for (final feature in _classFeatures())
                  _FeatureTile(name: feature, text: 'Умение класса'),
                for (final trait in _traits())
                  _FeatureTile(name: trait.name, text: trait.text),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

String _signed(int value) =>
    value == 0 ? '' : value > 0 ? '+$value' : '$value';

class _QuickStat extends StatelessWidget {
  const _QuickStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 96),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          Text(value,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _HpRow extends StatelessWidget {
  const _HpRow({
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
          SizedBox(width: 76, child: Text(label)),
          SizedBox(
            width: 44,
            child: Text('$value', textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          for (final delta in const [-5, -1, 1, 5])
            SizedBox(
              width: 44,
              height: 44,
              child: TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(44, 44),
                ),
                onPressed: () => onStep(delta),
                child: Text(delta > 0 ? '+$delta' : '$delta'),
              ),
            ),
        ],
      ),
    );
  }
}

class _AbilityTile extends StatelessWidget {
  const _AbilityTile({
    required this.ability,
    required this.score,
    required this.onTap,
  });

  final Ability ability;
  final int score;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formula = d20CheckFormula(abilityModifier(score));
    return Semantics(
      key: ValueKey('sheet_ability_${ability.id}'),
      button: true,
      label: 'Бросок ${ability.nameRu}: $formula',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(ability.nameRu,
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center),
                Text('$score', style: theme.textTheme.titleLarge),
                Text(_signed(abilityModifier(score)),
                    style: theme.textTheme.bodySmall?.copyWith(color: _gold)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RollRow {
  _RollRow({
    required this.label,
    required this.bonus,
    required this.proficient,
    required this.onTap,
  });

  final String label;
  final int bonus;
  final bool proficient;
  final VoidCallback onTap;
}

class _RollListCard extends StatelessWidget {
  const _RollListCard({required this.title, required this.rows});

  final String title;
  final List<_RollRow> rows;

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
            const SizedBox(height: 4),
            for (final row in rows)
              Semantics(
                key: ValueKey('sheet_roll_${row.label}'),
                button: true,
                label: 'Бросок ${row.label}: ${d20CheckFormula(row.bonus)}',
                child: InkWell(
                  onTap: row.onTap,
                  child: SizedBox(
                    height: 44,
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
                        if (row.proficient)
                          Text('влад.',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: _gold)),
                        const SizedBox(width: 8),
                        Text(_signed(row.bonus),
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        const Icon(Icons.casino_outlined, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.name, required this.text});

  final String name;
  final String text;

  @override
  Widget build(BuildContext context) => ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(name),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        children: [
          Align(alignment: Alignment.centerLeft, child: Text(text)),
        ],
      );
}
