/// Прокачка персонажа (level-up) по docs/03-character-builder.md:
/// хиты по кости класса, умения из таблицы прогрессии, на 4/8/12/16/19 —
/// увеличение характеристик или черта.
library;

import 'package:flutter/material.dart';

import '../../core/models/catalog.dart';
import '../../core/models/character.dart';
import '../../core/rules/ability.dart';
import '../../core/rules/formulas.dart';
import '../../data/catalog_loader.dart';
import 'character_repository.dart';

const Color _gold = Color(0xFFC9A227);

class LevelUpScreen extends StatefulWidget {
  const LevelUpScreen({
    super.key,
    required this.character,
    required this.repository,
  });

  final Character character;
  final CharacterRepository repository;

  @override
  State<LevelUpScreen> createState() => _LevelUpScreenState();
}

class _LevelUpScreenState extends State<LevelUpScreen> {
  bool _isAsiLevel = false;
  ClassEntryCatalog? _classCatalog;
  RaceDetail? _raceDetail;
  List<Feat> _feats = <Feat>[];
  bool _loading = true;

  AsiChoice _asiChoice = AsiChoice.plusTwo;
  Ability _asiAbility = Ability.strength;
  Ability _asiFirst = Ability.strength;
  Ability _asiSecond = Ability.dexterity;
  String? _featId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entry = widget.character.classEntries.first;
    final classes = await catalogLoader.classes();
    final details = await catalogLoader.raceDetails();
    final feats = await catalogLoader.feats();
    if (!mounted) return;
    setState(() {
      _classCatalog = classes[entry.classId];
      _raceDetail = details[widget.character.raceId];
      _feats = feats;
      _isAsiLevel = asiLevels.contains(entry.level + 1);
      _loading = false;
    });
  }

  int get _nextLevel => widget.character.classEntries.first.level + 1;

  ClassLevelRow? get _nextLevelRow =>
      _classCatalog?.levels[_nextLevel];

  /// Прирост хитов за новый уровень (фиксированное среднее по кости класса).
  int get _hpGain => hpOnLevelUp(
        hitDieSides: _classCatalog?.hitDiceSides ?? 8,
        constitution: _effectiveScore(Ability.constitution),
      );

  int _effectiveScore(Ability ability) {
    final base = widget.character.abilityScores[ability] ?? 10;
    return base +
        racialBonus(ability, _raceDetail,
            subraceAnchor: widget.character.subraceId);
  }

  bool get _canApply {
    if (_loading || _classCatalog == null || _nextLevel > 20) return false;
    if (_isAsiLevel) {
      if (_asiChoice == AsiChoice.feat) return _featId != null;
      if (_asiChoice == AsiChoice.plusTwo) {
        return _effectiveScore(_asiAbility) + 2 <= 20;
      }
      return _effectiveScore(_asiFirst) + 1 <= 20 &&
          _effectiveScore(_asiSecond) + 1 <= 20;
    }
    return true;
  }

  Future<void> _apply() async {
    final character = widget.character;
    character.level = _nextLevel;
    if (character.classEntries.isNotEmpty) {
      character.classEntries.first.level = _nextLevel;
    }
    final gain = _hpGain;
    character.maxHp += gain;
    character.currentHp += gain;

    if (_isAsiLevel) {
      switch (_asiChoice) {
        case AsiChoice.plusTwo:
          character.abilityScores[_asiAbility] =
              (character.abilityScores[_asiAbility] ?? 10) + 2;
        case AsiChoice.plusOnePlusOne:
          character.abilityScores[_asiFirst] =
              (character.abilityScores[_asiFirst] ?? 10) + 1;
          if (_asiSecond != _asiFirst) {
            character.abilityScores[_asiSecond] =
                (character.abilityScores[_asiSecond] ?? 10) + 1;
          }
        case AsiChoice.feat:
          // Черта фиксируется в заметках: отдельного поля в схеме пока нет.
          final feat = _feats.where((f) => f.id == _featId);
          if (feat.isNotEmpty) {
            character.notes = '${character.notes}\nЧерта ($_nextLevel ур.): '
                '${feat.first.nameRu}'.trim();
          }
      }
    }

    await widget.repository.save(character);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final features = _nextLevelRow?.features ?? const <String>[];

    return Scaffold(
      appBar: AppBar(title: Text('Повышение уровня — $_nextLevel')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${_classCatalog?.nameRu ?? ''} — уровень $_nextLevel',
                              style: theme.textTheme.titleLarge),
                          const SizedBox(height: 8),
                          Text('Прирост хитов: +$_hpGain '
                              '(кость 1к${_classCatalog?.hitDiceSides ?? 8} + мод. ТЕЛ)'),
                          if (features.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text('Новые умения:', style: theme.textTheme.titleSmall),
                            for (final feature in features)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text('• $feature'),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (_isAsiLevel) ...[
                    const SizedBox(height: 12),
                    _AsiCard(
                      theme: theme,
                      choice: _asiChoice,
                      onChoiceChanged: (c) => setState(() => _asiChoice = c),
                      ability: _asiAbility,
                      onAbilityChanged: (a) => setState(() => _asiAbility = a),
                      first: _asiFirst,
                      second: _asiSecond,
                      onFirstChanged: (a) => setState(() => _asiFirst = a),
                      onSecondChanged: (a) => setState(() => _asiSecond = a),
                      feats: _feats,
                      featId: _featId,
                      onFeatChanged: (f) => setState(() => _featId = f),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _canApply ? _apply : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      backgroundColor: _gold,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Применить'),
                  ),
                ],
              ),
            ),
    );
  }
}

enum AsiChoice { plusTwo, plusOnePlusOne, feat }

/// Уровни с увеличением характеристик (или чертой) — PHB.
const Set<int> asiLevels = {4, 8, 12, 16, 19};

class _AsiCard extends StatelessWidget {
  const _AsiCard({
    required this.theme,
    required this.choice,
    required this.onChoiceChanged,
    required this.ability,
    required this.onAbilityChanged,
    required this.first,
    required this.second,
    required this.onFirstChanged,
    required this.onSecondChanged,
    required this.feats,
    required this.featId,
    required this.onFeatChanged,
  });

  final ThemeData theme;
  final AsiChoice choice;
  final ValueChanged<AsiChoice> onChoiceChanged;
  final Ability ability;
  final ValueChanged<Ability> onAbilityChanged;
  final Ability first;
  final Ability second;
  final ValueChanged<Ability> onFirstChanged;
  final ValueChanged<Ability> onSecondChanged;
  final List<Feat> feats;
  final String? featId;
  final ValueChanged<String?> onFeatChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Увеличение характеристик', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<AsiChoice>(
              segments: const [
                ButtonSegment(
                  value: AsiChoice.plusTwo,
                  label: Text('+2 к одной'),
                ),
                ButtonSegment(
                  value: AsiChoice.plusOnePlusOne,
                  label: Text('+1 к двум'),
                ),
                ButtonSegment(value: AsiChoice.feat, label: Text('Черта')),
              ],
              selected: {choice},
              onSelectionChanged: (s) {
                if (s.isNotEmpty) onChoiceChanged(s.first);
              },
            ),
            const SizedBox(height: 12),
            switch (choice) {
              AsiChoice.plusTwo => _abilityDropdown(
                  'Характеристика +2',
                  ability,
                  onAbilityChanged,
                ),
              AsiChoice.plusOnePlusOne => Row(
                  children: [
                    Expanded(
                      child: _abilityDropdown('+1', first, onFirstChanged),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _abilityDropdown('+1', second, onSecondChanged),
                    ),
                  ],
                ),
              AsiChoice.feat => DropdownButtonFormField<String>(
                  initialValue: featId,
                  decoration: const InputDecoration(
                    labelText: 'Черта',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final feat in feats)
                      DropdownMenuItem(value: feat.id, child: Text(feat.nameRu)),
                  ],
                  onChanged: onFeatChanged,
                ),
            },
          ],
        ),
      ),
    );
  }

  Widget _abilityDropdown(
    String label,
    Ability value,
    ValueChanged<Ability> onChanged,
  ) {
    return DropdownButtonFormField<Ability>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final a in Ability.values)
          DropdownMenuItem(value: a, child: Text(a.nameRu)),
      ],
      onChanged: (a) {
        if (a != null) onChanged(a);
      },
    );
  }
}
