import 'package:flutter/foundation.dart';

import '../../core/models/catalog.dart';
import '../../core/models/character.dart';
import '../../core/rules/ability.dart';
import '../../core/rules/formulas.dart';
import '../../data/catalog_loader.dart';
import '../../platform/files/file_store.dart';
import '../../shared/avatar_picker.dart' as avatar_picker;
import '../characters/character_repository.dart';

/// Шаги билдера. Ровно 7 точек прогресса.
enum BuilderStep { race, classStep, abilities, background, equipment, spells, identity }

extension BuilderStepTitle on BuilderStep {
  String get titleRu {
    switch (this) {
      case BuilderStep.race:
        return 'Раса';
      case BuilderStep.classStep:
        return 'Класс';
      case BuilderStep.abilities:
        return 'Характеристики';
      case BuilderStep.background:
        return 'Предыстория';
      case BuilderStep.equipment:
        return 'Снаряжение';
      case BuilderStep.spells:
        return 'Заклинания';
      case BuilderStep.identity:
        return 'Имя и сводка';
    }
  }
}

enum RaceBonusMode { plusTwoPlusOne, plusOneThree }

enum AbilityMode { pointBuy, standardArray }

/// Контроллер многошагового создания персонажа 1 уровня.
///
/// Допущения MVP:
/// - мультикласс не поддерживается: в Character попадает ровно один ClassEntry(level: 1);
/// - abilityScores в Character — база без расовых бонусов;
/// - languages в Character остаются пустыми (билдер не спрашивает языки);
/// - subclassId остаётся пустым: для колдуна выбор покровителя делается отдельно;
/// - языки/выбор заклинаний не пишутся в JSON на этом шаге.
class CharacterBuilderController extends ChangeNotifier {
  CharacterBuilderController({CharacterRepository? repository})
      : _repository = repository ?? CharacterRepository(PathProviderFileStore());

  final CharacterRepository _repository;

  // ---------------------------------------------------------------------------
  // Каталог
  // ---------------------------------------------------------------------------

  bool _isLoading = true;
  String? _loadError;
  List<RaceEntry> _races = <RaceEntry>[];
  Map<String, RaceDetail> _raceDetails = <String, RaceDetail>{};
  Map<String, ClassEntryCatalog> _classes = <String, ClassEntryCatalog>{};
  List<Background> _backgrounds = <Background>[];
  Map<String, ClassEquipment> _classEquipment = <String, ClassEquipment>{};
  List<Spell> _spells = <Spell>[];

  bool get isLoading => _isLoading;
  String? get loadError => _loadError;

  List<RaceEntry> get races => List<RaceEntry>.unmodifiable(_races);
  Map<String, RaceDetail> get raceDetails =>
      Map<String, RaceDetail>.unmodifiable(_raceDetails);
  Map<String, ClassEntryCatalog> get classes =>
      Map<String, ClassEntryCatalog>.unmodifiable(_classes);
  List<Background> get backgrounds => List<Background>.unmodifiable(_backgrounds);
  Map<String, ClassEquipment> get classEquipment =>
      Map<String, ClassEquipment>.unmodifiable(_classEquipment);

  Future<void> load() async {
    try {
      final results = await Future.wait<Object>([
        catalogLoader.races(),
        catalogLoader.raceDetails(),
        catalogLoader.classes(),
        catalogLoader.backgrounds(),
        catalogLoader.classEquipment(),
        catalogLoader.spells(),
      ]);
      _races = (results[0] as List).cast<RaceEntry>();
      _raceDetails = (results[1] as Map).cast<String, RaceDetail>();
      _classes = (results[2] as Map).cast<String, ClassEntryCatalog>();
      _backgrounds = (results[3] as List).cast<Background>();
      _classEquipment = (results[4] as Map).cast<String, ClassEquipment>();
      _spells = (results[5] as List).cast<Spell>();
      _loadError = null;
    } catch (error) {
      _loadError = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Навигация по шагам
  // ---------------------------------------------------------------------------

  int _stepIndex = 0;

  int get stepIndex => _stepIndex;
  BuilderStep get currentStep => BuilderStep.values[_stepIndex];
  bool get isLastStep => _stepIndex == BuilderStep.values.length - 1;

  bool get isCurrentStepValid {
    switch (currentStep) {
      case BuilderStep.race:
        return isRaceStepValid;
      case BuilderStep.classStep:
        return isClassStepValid;
      case BuilderStep.abilities:
        return isAbilitiesStepValid;
      case BuilderStep.background:
        return isBackgroundStepValid;
      case BuilderStep.equipment:
        return isEquipmentStepValid;
      case BuilderStep.spells:
        return true;
      case BuilderStep.identity:
        return isIdentityStepValid;
    }
  }

  bool _shouldSkip(BuilderStep step) {
    // Paladin/Ranger на 1 уровне не являются заклинателями в рамках этого шага.
    return step == BuilderStep.spells && !isSpellcasterClass;
  }

  void nextStep() {
    if (!isCurrentStepValid) return;
    var next = _stepIndex + 1;
    while (next < BuilderStep.values.length &&
        _shouldSkip(BuilderStep.values[next])) {
      next++;
    }
    if (next >= BuilderStep.values.length) return;
    _stepIndex = next;
    notifyListeners();
  }

  void previousStep() {
    var previous = _stepIndex - 1;
    while (previous >= 0 && _shouldSkip(BuilderStep.values[previous])) {
      previous--;
    }
    if (previous < 0) return;
    _stepIndex = previous;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Раса
  // ---------------------------------------------------------------------------

  String? _raceId;
  String? _subraceId;
  RaceBonusMode _raceBonusMode = RaceBonusMode.plusTwoPlusOne;
  List<Ability?> _raceBonusPicks = List<Ability?>.filled(2, null, growable: false);

  String? get raceId => _raceId;
  String? get subraceId => _subraceId;
  RaceBonusMode get raceBonusMode => _raceBonusMode;
  List<Ability?> get raceBonusPicks => List<Ability?>.unmodifiable(_raceBonusPicks);

  RaceDetail? get selectedRaceDetail {
    final id = _raceId;
    if (id == null) return null;
    return _raceDetails[id];
  }

  Subspecies? get selectedSubspecies {
    final race = selectedRaceDetail;
    final anchor = _subraceId;
    if (race == null || anchor == null) return null;
    for (final subspecies in race.subspecies) {
      if (subspecies.anchor == anchor) return subspecies;
    }
    return null;
  }

  List<Subspecies> get availableSubspecies {
    final race = selectedRaceDetail;
    if (race == null) return const <Subspecies>[];
    return race.subspecies.where((s) => !s.ua).toList();
  }

  bool get raceBonusHasChoice {
    final race = selectedRaceDetail;
    if (race == null) return false;
    final sub = selectedSubspecies;
    return race.bonusesChoice || (sub?.bonusesChoice ?? false);
  }

  int get bonusPickCount =>
      _raceBonusMode == RaceBonusMode.plusTwoPlusOne ? 2 : 3;

  Map<Ability, int> get chosenRaceBonuses {
    if (!raceBonusHasChoice) return const <Ability, int>{};
    final picks = _raceBonusPicks;
    if (picks.length != bonusPickCount || picks.any((a) => a == null)) {
      return const <Ability, int>{};
    }
    final result = <Ability, int>{};
    if (_raceBonusMode == RaceBonusMode.plusTwoPlusOne) {
      result[picks[0]!] = 2;
      result[picks[1]!] = (result[picks[1]!] ?? 0) + 1;
    } else {
      for (final ability in picks) {
        result[ability!] = (result[ability] ?? 0) + 1;
      }
    }
    return result;
  }

  /// Итоговые расовые бонусы, включая выбранный подвид и распределение.
  Map<Ability, int> get effectiveRaceBonuses {
    final result = <Ability, int>{};
    final race = selectedRaceDetail;
    if (race != null && !race.bonusesChoice) {
      for (final bonus in race.bonuses) {
        final ability = _abilityOf(bonus.ability);
        if (ability != null) {
          result[ability] = (result[ability] ?? 0) + bonus.bonus;
        }
      }
    }
    final sub = selectedSubspecies;
    if (sub != null && !sub.bonusesChoice) {
      for (final bonus in sub.bonuses) {
        final ability = _abilityOf(bonus.ability);
        if (ability != null) {
          result[ability] = (result[ability] ?? 0) + bonus.bonus;
        }
      }
    }
    if (raceBonusHasChoice) {
      chosenRaceBonuses.forEach((ability, value) {
        result[ability] = (result[ability] ?? 0) + value;
      });
    }
    return result;
  }

  int? get selectedSpeedFt {
    final sub = selectedSubspecies;
    final subSpeed = sub?.speedFt;
    if (subSpeed != null && subSpeed > 0) return subSpeed;
    final race = selectedRaceDetail;
    final raceSpeed = race?.speedFt;
    if (raceSpeed != null && raceSpeed > 0) return raceSpeed;
    return null;
  }

  void selectRace(String id) {
    if (_raceId == id) return;
    _raceId = id;
    _subraceId = null;
    _raceBonusPicks =
        List<Ability?>.filled(bonusPickCount, null, growable: false);
    notifyListeners();
  }

  void selectSubrace(String? anchor) {
    if (_subraceId == anchor) return;
    _subraceId = anchor;
    _raceBonusPicks =
        List<Ability?>.filled(bonusPickCount, null, growable: false);
    notifyListeners();
  }

  void setRaceBonusMode(RaceBonusMode mode) {
    if (_raceBonusMode == mode) return;
    _raceBonusMode = mode;
    _raceBonusPicks =
        List<Ability?>.filled(bonusPickCount, null, growable: false);
    notifyListeners();
  }

  void setRaceBonusPick(int slot, Ability? ability) {
    if (slot < 0 || slot >= bonusPickCount) return;
    if (ability != null) {
      for (var i = 0; i < _raceBonusPicks.length; i++) {
        if (i != slot && _raceBonusPicks[i] == ability) {
          _raceBonusPicks[i] = null;
        }
      }
    }
    _raceBonusPicks[slot] = ability;
    notifyListeners();
  }

  bool get isRaceStepValid {
    if (_raceId == null || selectedRaceDetail == null) return false;
    // Подвид обязателен, если он есть: иначе теряются бонусы и черты расы
    // (например, у дварфа вся механика лежит в подвидах).
    if (availableSubspecies.isNotEmpty && _subraceId == null) return false;
    if (raceBonusHasChoice) {
      return _raceBonusPicks.length == bonusPickCount &&
          _raceBonusPicks.every((a) => a != null);
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // Класс
  // ---------------------------------------------------------------------------

  String? _classId;
  final Set<Skill> _classSkills = <Skill>{};

  String? get classId => _classId;
  Set<Skill> get classSkills => Set<Skill>.unmodifiable(_classSkills);

  ClassEntryCatalog? get selectedClass {
    final id = _classId;
    if (id == null) return null;
    return _classes[id];
  }

  List<Skill> get availableClassSkills {
    final selected = selectedClass;
    if (selected == null) return const <Skill>[];
    final rule = selected.skillProficiencyRule;
    final colon = rule.lastIndexOf(':');
    final raw = colon >= 0 ? rule.substring(colon + 1) : rule;
    final result = <Skill>[];
    for (final part in raw.split(RegExp(r'[,;]'))) {
      final skill = _skillOf(part);
      if (skill != null && !result.contains(skill)) result.add(skill);
    }
    return result;
  }

  int get classSkillChoiceCount {
    final selected = selectedClass;
    if (selected == null) return 0;
    final rule = selected.skillProficiencyRule.toLowerCase();
    if (rule.contains('три') || rule.contains('three')) return 3;
    if (rule.contains('два') || rule.contains('two')) return 2;
    if (rule.contains('один') || rule.contains('one')) return 1;
    return availableClassSkills.isEmpty ? 0 : 2;
  }

  void selectClass(String id) {
    if (_classId == id) return;
    _classId = id;
    _classSkills.clear();
    _equipmentChoices.clear();
    _selectedCantripIds.clear();
    _selectedSpellIds.clear();

    final equipment = _classEquipment[id];
    if (equipment != null) {
      for (var i = 0; i < equipment.rows.length; i++) {
        if (equipment.rows[i].isNotEmpty) {
          _equipmentChoices[i] = 0;
        }
      }
    }

    // Если пользователь ушёл назад и сменил класс на незаклинателя,
    // не оставляем его на шаге заклинаний.
    if (currentStep == BuilderStep.spells && !isSpellcasterClass) {
      _stepIndex = BuilderStep.identity.index;
    }
    notifyListeners();
  }

  void toggleClassSkill(Skill skill) {
    if (_classSkills.contains(skill)) {
      _classSkills.remove(skill);
      notifyListeners();
      return;
    }
    if (_classSkills.length >= classSkillChoiceCount) return;
    if (!availableClassSkills.contains(skill)) return;
    _classSkills.add(skill);
    notifyListeners();
  }

  Set<Ability> get derivedSaveProficiencies {
    final selected = selectedClass;
    if (selected == null) return <Ability>{};
    final result = <Ability>{};
    for (final part in selected.saves.split(RegExp(r'[,;/]'))) {
      final ability = _abilityOf(part);
      if (ability != null) result.add(ability);
    }
    return result;
  }

  bool get isClassStepValid {
    if (_classId == null || selectedClass == null) return false;
    final available = availableClassSkills;
    if (available.isEmpty) return true;
    if (!_classSkills.every(available.contains)) return false;
    return _classSkills.length == classSkillChoiceCount;
  }

  static const Set<String> _spellcasterClassIds = <String>{
    '88-bard',
    '89-cleric',
    '90-druid',
    '101-sorcerer',
    '104-warlock',
    '105-wizard',
    '137-artificer',
  };

  bool get isSpellcasterClass =>
      _classId != null && _spellcasterClassIds.contains(_classId);

  // ---------------------------------------------------------------------------
  // Заклинания
  // ---------------------------------------------------------------------------

  final Set<String> _selectedCantripIds = <String>{};
  final Set<String> _selectedSpellIds = <String>{};

  Set<String> get selectedCantripIds =>
      Set<String>.unmodifiable(_selectedCantripIds);
  Set<String> get selectedSpellIds =>
      Set<String>.unmodifiable(_selectedSpellIds);

  /// Подстрока для фильтра списка заклинаний класса (Spell.classes — строчные).
  String? get _spellListSubstring {
    switch (_classId) {
      case '88-bard':
        return 'бард';
      case '89-cleric':
        return 'жрец';
      case '90-druid':
        return 'друид';
      case '101-sorcerer':
        return 'чародей';
      case '104-warlock':
        return 'колдун';
      case '105-wizard':
        return 'волшебник';
      case '137-artificer':
        return 'изобретатель';
      default:
        return null;
    }
  }

  /// Ячейки таблицы прогрессии на 1 уровне (структура cols/cells по dnd.su).
  List<String>? get _levelOneCells => selectedClass?.levels[1]?.cells;

  int? _cellIntAt(int index) {
    final cells = _levelOneCells;
    if (cells == null || index < 0 || index >= cells.length) return null;
    final raw = cells[index].trim();
    if (raw.isEmpty || raw == '-' || raw == '—') return 0;
    final match = RegExp(r'\d+').firstMatch(raw);
    return match == null ? 0 : int.tryParse(match.group(0)!) ?? 0;
  }

  /// Число заговоров на 1 уровне по таблице класса.
  int get cantripLimit {
    if (!isSpellcasterClass) return 0;
    final index = switch (_classId) {
      '101-sorcerer' => 3,
      '137-artificer' => 4,
      '88-bard' || '89-cleric' || '90-druid' || '104-warlock' || '105-wizard' => 2,
      _ => -1,
    };
    return index < 0 ? 0 : _cellIntAt(index) ?? 0;
  }

  /// Лимит известных заклинаний (бард/чародей/колдун), иначе null.
  int? get knownSpellsLimit {
    final index = switch (_classId) {
      '88-bard' => 3,
      '101-sorcerer' => 4,
      '104-warlock' => 3,
      _ => -1,
    };
    return index < 0 ? null : _cellIntAt(index) ?? 0;
  }

  /// Лимит подготовленных заклинаний (жрец/друид/волшебник/изобретатель).
  /// Официальные правила: PHB жрец/друид — мод МДР + уровень класса;
  /// PHB волшебник — мод ИНТ + уровень класса; TCE изобретатель —
  /// мод ИНТ + половина уровня, минимум 1.
  int? get preparedSpellsLimit {
    switch (_classId) {
      case '89-cleric':
      case '90-druid':
        return (modifierOf(Ability.wisdom) + 1).clamp(0, 99);
      case '105-wizard':
        return (modifierOf(Ability.intelligence) + 1).clamp(0, 99);
      case '137-artificer':
        return (modifierOf(Ability.intelligence) + (1 ~/ 2)).clamp(1, 99);
      default:
        return null;
    }
  }

  int get _spellsLimit => knownSpellsLimit ?? preparedSpellsLimit ?? 0;

  String get spellListCaption {
    if (knownSpellsLimit != null) return 'Известные заклинания';
    if (preparedSpellsLimit != null) return 'Подготовленные заклинания';
    return '';
  }

  List<Spell> get _classSpells => _spells
      .where((s) => s.classes.contains(_spellListSubstring ?? '\u0000'))
      .toList();

  List<Spell> get classCantrips =>
      _classSpells.where((s) => s.level == 0).toList()
        ..sort((a, b) => a.nameRu.compareTo(b.nameRu));

  List<Spell> get classLevelOneSpells =>
      _classSpells.where((s) => s.level == 1).toList()
        ..sort((a, b) => a.nameRu.compareTo(b.nameRu));

  bool get isSpellsStepValid {
    if (!isSpellcasterClass) return true;
    return _selectedCantripIds.length == cantripLimit &&
        _selectedSpellIds.length == _spellsLimit;
  }

  void toggleCantrip(Spell spell) {
    if (_selectedCantripIds.contains(spell.id)) {
      _selectedCantripIds.remove(spell.id);
    } else if (_selectedCantripIds.length < cantripLimit) {
      _selectedCantripIds.add(spell.id);
    }
    notifyListeners();
  }

  void toggleSpell(Spell spell) {
    if (_selectedSpellIds.contains(spell.id)) {
      _selectedSpellIds.remove(spell.id);
    } else if (_selectedSpellIds.length < _spellsLimit) {
      _selectedSpellIds.add(spell.id);
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Характеристики
  // ---------------------------------------------------------------------------

  AbilityMode _abilityMode = AbilityMode.pointBuy;
  final Map<Ability, int> _baseScores = <Ability, int>{
    for (final ability in Ability.values) ability: 8,
  };

  AbilityMode get abilityMode => _abilityMode;
  Map<Ability, int> get baseScores => Map<Ability, int>.unmodifiable(_baseScores);

  int baseScoreOf(Ability ability) => _baseScores[ability] ?? 8;

  int totalScoreOf(Ability ability) =>
      baseScoreOf(ability) + (effectiveRaceBonuses[ability] ?? 0);

  int modifierOf(Ability ability) => abilityModifier(totalScoreOf(ability));

  int get pointBuySpent => Ability.values.fold<int>(
        0,
        (sum, ability) => sum + pointBuyCost(baseScoreOf(ability)),
      );

  int get pointBuyRemaining => pointBuyBudget - pointBuySpent;

  bool canIncreaseAbility(Ability ability) {
    if (_abilityMode != AbilityMode.pointBuy) return false;
    final current = baseScoreOf(ability);
    if (current >= 15) return false;
    final candidate = Map<Ability, int>.from(_baseScores)..[ability] = current + 1;
    final total = candidate.values.fold<int>(
      0,
      (sum, value) => sum + pointBuyCost(value),
    );
    return total <= pointBuyBudget;
  }

  bool canDecreaseAbility(Ability ability) =>
      _abilityMode == AbilityMode.pointBuy && baseScoreOf(ability) > 8;

  void changeAbilityBase(Ability ability, int delta) {
    if (_abilityMode != AbilityMode.pointBuy) return;
    final current = baseScoreOf(ability);
    final next = (current + delta).clamp(8, 15).toInt();
    if (next == current) return;

    if (delta > 0) {
      final candidate = Map<Ability, int>.from(_baseScores)..[ability] = next;
      final total = candidate.values.fold<int>(
        0,
        (sum, value) => sum + pointBuyCost(value),
      );
      if (total > pointBuyBudget) return;
    }

    _baseScores[ability] = next;
    notifyListeners();
  }

  List<int> standardArrayOptionsFor(Ability ability) {
    final usedElsewhere = <int>{};
    for (final other in Ability.values) {
      if (other == ability) continue;
      usedElsewhere.add(baseScoreOf(other));
    }
    return standardArray.where((value) => !usedElsewhere.contains(value)).toList();
  }

  void setAbilityBase(Ability ability, int value) {
    if (_abilityMode == AbilityMode.pointBuy) {
      final clamped = value.clamp(8, 15).toInt();
      final candidate = Map<Ability, int>.from(_baseScores)..[ability] = clamped;
      final total = candidate.values.fold<int>(
        0,
        (sum, v) => sum + pointBuyCost(v),
      );
      if (total > pointBuyBudget) return;
      _baseScores[ability] = clamped;
      notifyListeners();
      return;
    }

    // Стандартный массив: повторно использовать значение нельзя — меняем местами.
    Ability? conflict;
    for (final other in Ability.values) {
      if (other != ability && baseScoreOf(other) == value) {
        conflict = other;
        break;
      }
    }
    final previous = baseScoreOf(ability);
    if (conflict != null) {
      _baseScores[conflict] = previous;
    }
    _baseScores[ability] = value;
    notifyListeners();
  }

  void setAbilityMode(AbilityMode mode) {
    if (_abilityMode == mode) return;
    _abilityMode = mode;
    if (mode == AbilityMode.pointBuy) {
      for (final ability in Ability.values) {
        _baseScores[ability] = 8;
      }
    } else {
      for (var i = 0; i < Ability.values.length; i++) {
        _baseScores[Ability.values[i]] = standardArray[i];
      }
    }
    notifyListeners();
  }

  bool get isAbilitiesStepValid {
    if (_abilityMode == AbilityMode.pointBuy) {
      return pointBuySpent <= pointBuyBudget;
    }
    final current = Ability.values.map(baseScoreOf).toList()..sort();
    final target = List<int>.from(standardArray)..sort();
    if (current.length != target.length) return false;
    for (var i = 0; i < current.length; i++) {
      if (current[i] != target[i]) return false;
    }
    return true;
  }

  int get armorClassValue =>
      armorClass(dexterity: totalScoreOf(Ability.dexterity));

  int get passivePerceptionValue => passivePerception(
        wisdom: totalScoreOf(Ability.wisdom),
        proficient: combinedSkillProficiencies.contains(Skill.perception),
        proficiencyBonusValue: 2,
      );

  // ---------------------------------------------------------------------------
  // Предыстория
  // ---------------------------------------------------------------------------

  String? _backgroundId;

  String? get backgroundId => _backgroundId;

  Background? get selectedBackground {
    final id = _backgroundId;
    if (id == null) return null;
    for (final background in _backgrounds) {
      if (background.id == id) return background;
    }
    return null;
  }

  List<Skill> get backgroundSkills {
    final background = selectedBackground;
    if (background == null) return const <Skill>[];
    final result = <Skill>[];
    for (final part in background.skills.split(RegExp(r'[,;]|\s+или\s+'))) {
      final skill = _skillOf(part);
      if (skill != null && !result.contains(skill)) result.add(skill);
    }
    return result;
  }

  /// Предыстории для выбора (без служебных страниц-«Адаптаций»).
  List<Background> get selectableBackgrounds => _backgrounds
      .where((b) => !b.nameRu.startsWith('Адаптация предысторий'))
      .toList();

  Set<Skill> get combinedSkillProficiencies => <Skill>{
        ..._classSkills,
        ...backgroundSkills,
      };

  void selectBackground(String id) {
    if (_backgroundId == id) return;
    _backgroundId = id;
    notifyListeners();
  }

  bool get isBackgroundStepValid => _backgroundId != null;

  // ---------------------------------------------------------------------------
  // Снаряжение
  // ---------------------------------------------------------------------------

  final Map<int, int> _equipmentChoices = <int, int>{};

  ClassEquipment? get selectedClassEquipment {
    final id = _classId;
    if (id == null) return null;
    return _classEquipment[id];
  }

  int? equipmentChoiceFor(int rowIndex) => _equipmentChoices[rowIndex];

  void selectEquipmentOption(int rowIndex, int optionIndex) {
    final equipment = selectedClassEquipment;
    if (equipment == null) return;
    if (rowIndex < 0 || rowIndex >= equipment.rows.length) return;
    final row = equipment.rows[rowIndex];
    if (optionIndex < 0 || optionIndex >= row.length) return;
    _equipmentChoices[rowIndex] = optionIndex;
    notifyListeners();
  }

  List<String> get equipmentLines {
    final lines = <String>[];
    final equipment = selectedClassEquipment;
    if (equipment != null) {
      for (var i = 0; i < equipment.rows.length; i++) {
        final row = equipment.rows[i];
        if (row.isEmpty) continue;
        final index = (_equipmentChoices[i] ?? 0).clamp(0, row.length - 1).toInt();
        lines.add(row[index]);
      }
    }
    final backgroundEquipment = selectedBackground?.equipment.trim() ?? '';
    if (backgroundEquipment.isNotEmpty) {
      lines.add(backgroundEquipment);
    }
    return lines;
  }

  bool get isEquipmentStepValid {
    final equipment = selectedClassEquipment;
    if (equipment == null) return true;
    for (var i = 0; i < equipment.rows.length; i++) {
      if (equipment.rows[i].isEmpty) continue;
      if (!_equipmentChoices.containsKey(i)) return false;
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // Имя, заметки, аватар
  // ---------------------------------------------------------------------------

  String _name = '';
  String _notes = '';
  String _avatarPath = 'assets/2d/ui/avatar_default.png';

  String get name => _name;
  String get notes => _notes;
  String get avatarPath => _avatarPath;

  void setName(String value) {
    if (_name == value) return;
    _name = value;
    notifyListeners();
  }

  void setNotes(String value) {
    if (_notes == value) return;
    _notes = value;
    notifyListeners();
  }

  void setAvatarPath(String value) {
    if (_avatarPath == value) return;
    _avatarPath = value;
    notifyListeners();
  }

  /// Импорт своей аватарки: выбор картинки, копия в Документы/dnd_prod/avatars.
  /// Возвращает путь; null — отмена или ошибка (текст в saveError).
  Future<String?> importCustomAvatar() async {
    try {
      final target = await avatar_picker.importCustomAvatar();
      if (target == null) return null;
      _avatarPath = target;
      _saveError = null;
      notifyListeners();
      return target;
    } catch (error) {
      _saveError = 'Не удалось загрузить картинку: $error';
      notifyListeners();
      return null;
    }
  }

  bool get isIdentityStepValid => _name.trim().isNotEmpty;

  // ---------------------------------------------------------------------------
  // Сводка и сохранение
  // ---------------------------------------------------------------------------

  String get raceDisplayName {
    final detail = selectedRaceDetail;
    if (detail != null) {
      final sub = selectedSubspecies;
      return sub == null ? detail.nameRu : '${detail.nameRu} (${sub.name})';
    }
    final id = _raceId;
    if (id != null) {
      for (final entry in _races) {
        if (entry.id == id) return entry.nameRu;
      }
    }
    return '—';
  }

  String get classDisplayName => selectedClass?.nameRu ?? '—';

  String get backgroundDisplayName => selectedBackground?.nameRu ?? '—';

  int get computedMaxHp {
    final sides = selectedClass?.hitDiceSides ?? 8;
    return hpAtFirstLevel(
      hitDieSides: sides,
      constitution: totalScoreOf(Ability.constitution),
    );
  }

  int get knownSpellCount =>
      _selectedCantripIds.length + _selectedSpellIds.length;

  String? _saveError;
  String? get saveError => _saveError;

  Future<bool> save() async {
    if (!isIdentityStepValid) return false;
    final classId = _classId;
    final raceId = _raceId;
    if (classId == null || raceId == null) return false;

    try {
      final maxHp = computedMaxHp;
      final character = Character(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: _name.trim(),
        level: 1,
        raceId: raceId,
        subraceId: _subraceId,
        backgroundId: _backgroundId,
        avatarPath: _avatarPath,
        notes: _notes.trim(),
        abilityScores: Map<Ability, int>.from(_baseScores),
        skillProficiencies: combinedSkillProficiencies,
        saveProficiencies: derivedSaveProficiencies,
        classEntries: <ClassEntry>[
          ClassEntry(classId: classId, level: 1, subclassId: null),
        ],
        currentHp: maxHp,
        maxHp: maxHp,
        tempHp: 0,
        knownSpellIds: <String>[
          ..._selectedCantripIds,
          ..._selectedSpellIds,
        ],
        equipmentLines: equipmentLines,
        languages: const <String>[],
      );
      await _repository.save(character);
      _saveError = null;
      return true;
    } catch (error) {
      _saveError = error.toString();
      notifyListeners();
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Утилиты парсинга каталога
  // ---------------------------------------------------------------------------

  static Ability? _abilityOf(dynamic raw) {
    if (raw == null) return null;
    if (raw is Ability) return raw;
    final text = raw.toString().trim().toLowerCase();
    if (text.isEmpty) return null;
    for (final ability in Ability.values) {
      if (ability.id.toLowerCase() == text ||
          ability.nameRu.toLowerCase() == text) {
        return ability;
      }
    }
    const fallback = <String, Ability>{
      'strength': Ability.strength,
      'dexterity': Ability.dexterity,
      'constitution': Ability.constitution,
      'intelligence': Ability.intelligence,
      'wisdom': Ability.wisdom,
      'charisma': Ability.charisma,
      'сила': Ability.strength,
      'ловкость': Ability.dexterity,
      'телосложение': Ability.constitution,
      'интеллект': Ability.intelligence,
      'мудрость': Ability.wisdom,
      'харизма': Ability.charisma,
    };
    return fallback[text];
  }

  static Skill? _skillOf(String raw) {
    final text = raw.trim().toLowerCase().replaceAll('.', '');
    if (text.isEmpty) return null;
    for (final skill in Skill.values) {
      if (skill.id.toLowerCase() == text ||
          skill.nameRu.toLowerCase() == text) {
        return skill;
      }
    }
    for (final skill in Skill.values) {
      if (text.startsWith(skill.nameRu.toLowerCase())) return skill;
    }
    return null;
  }
}
