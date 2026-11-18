/// Модели записей справочников. Соответствуют JSON в data/catalogs/ (собраны с dnd.su).
/// Парсинг — CatalogLoader (lib/data/catalog_loader.dart).
library;

/// Базовая запись справочника: названия и ссылка на источник.
sealed class CatalogEntry {
  const CatalogEntry({required this.id, required this.url, required this.nameRu, required this.nameEn});

  /// Ключ записи — последний сегмент url, напр. «115-fireball».
  final String id;
  final String url;
  final String nameRu;
  final String nameEn;
}

class Spell extends CatalogEntry {
  const Spell({
    required super.id,
    required super.url,
    required super.nameRu,
    required super.nameEn,
    required this.level,
    required this.school,
    required this.schoolLine,
    required this.castTime,
    required this.range,
    required this.components,
    required this.duration,
    required this.classes,
    required this.classList,
    required this.subclasses,
    required this.concentration,
    required this.ritual,
    required this.description,
    required this.sources,
  });

  /// Уровень заклинания 0–9 (0 = заговор).
  final int level;
  final String school;
  final String schoolLine;
  final String castTime;
  final String range;
  final String components;
  final String duration;

  /// Список классов строкой, как в каталоге (напр. «Жрец, Чародей»).
  final String classes;

  /// Классы по отдельности (без служебных пометок источника).
  final List<String> classList;
  final String subclasses;
  final bool concentration;
  final bool ritual;

  /// Текст заклинания (включая «На больших уровнях»).
  final String description;
  final List<String> sources;
}

/// Способность, атака или черта существа: название и текст.
class MonsterAbility {
  const MonsterAbility({required this.name, required this.text});

  final String name;
  final String text;
}

/// Именованная секция карточки существа («Действия», «Реакции», «Логово»).
class MonsterSection {
  const MonsterSection({required this.title, required this.entries});

  final String title;
  final List<MonsterAbility> entries;
}

class Monster extends CatalogEntry {
  const Monster({
    required super.id,
    required super.url,
    required super.nameRu,
    required super.nameEn,
    required this.size,
    required this.sizeType,
    required this.ac,
    required this.hp,
    required this.cr,
    required this.xp,
    required this.skills,
    required this.senses,
    required this.languages,
    required this.habitat,
    required this.speed,
    required this.damageResistance,
    required this.damageImmunity,
    required this.damageVulnerability,
    required this.conditionImmunity,
    required this.traits,
    required this.sections,
    required this.actions,
    required this.abilities,
    required this.legendaryActions,
    required this.reactions,
    required this.description,
    required this.sources,
  });

  final String size;
  final String sizeType;
  final int ac;
  final int hp;
  final double cr;
  final String xp;
  final String skills;
  final String senses;
  final String languages;
  final String habitat;
  final String speed;

  /// Сопротивление, иммунитеты и уязвимости урону/состояниям.
  final String damageResistance;
  final String damageImmunity;
  final String damageVulnerability;
  final String conditionImmunity;

  /// Особенности существа (без названия секции).
  final List<MonsterAbility> traits;

  /// Именованные секции карточки: «Действия», «Реакции», «Логово» и прочие.
  final List<MonsterSection> sections;

  /// Атаки и прочие действия.
  final List<MonsterAbility> actions;

  /// Особые способности.
  final List<MonsterAbility> abilities;

  /// Легендарные действия.
  final List<MonsterAbility> legendaryActions;

  /// Реакции.
  final List<MonsterAbility> reactions;

  /// Лорное описание существа.
  final String description;
  final List<String> sources;
}

class Item extends CatalogEntry {
  const Item({
    required super.id,
    required super.url,
    required super.nameRu,
    required super.nameEn,
    required this.kind,
    required this.rarity,
    required this.attunement,
    required this.cost,
    required this.description,
    required this.sources,
  });

  final String kind;
  final String rarity;
  final bool attunement;
  final String cost;

  /// Текст описания предмета (пустой, если у предмета нет описания).
  final String description;
  final List<String> sources;
}

class RaceEntry extends CatalogEntry {
  const RaceEntry({
    required super.id,
    required super.url,
    required super.nameRu,
    required super.nameEn,
    required this.source,
    required this.sources,
  });

  final String source;
  final List<String> sources;
}

class Background extends CatalogEntry {
  const Background({
    required super.id,
    required super.url,
    required super.nameRu,
    required super.nameEn,
    required this.skills,
    required this.tools,
    required this.languages,
    required this.equipment,
    required this.featureName,
    required this.featureText,
    required this.source,
  });

  /// Навыки строкой (напр. «Проницательность, Религия»).
  final String skills;
  final String tools;
  final String languages;
  final String equipment;

  /// Умение предыстории: название и текст (пустые, если не распарсилось).
  final String featureName;
  final String featureText;
  final String source;
}

/// Бонус характеристики расы: ability — id из Ability (str..cha).
class RaceBonus {
  const RaceBonus({required this.ability, required this.bonus});

  final String ability;
  final int bonus;
}

/// Черта расы/подвида: название и текст.
class RaceTrait {
  const RaceTrait({required this.name, required this.text});

  final String name;
  final String text;
}

/// Подвид расы (горный дварф, лесной эльф…). Самодостаточная запись:
/// при выборе подвида его поля заменяют/дополняют поля расы.
class Subspecies {
  const Subspecies({
    required this.anchor,
    required this.name,
    required this.source,
    required this.ua,
    required this.bonusesText,
    required this.bonuses,
    required this.bonusesChoice,
    required this.choiceOptions,
    required this.size,
    required this.sizeText,
    required this.speedFt,
    required this.speedText,
    required this.languagesText,
    required this.traits,
    required this.darkvisionFt,
  });

  /// Якорь на странице расы (напр. «hill»).
  final String anchor;
  final String name;
  final String source;

  /// Unearthed Arcana — неофициальный плейтест; в билдере скрывается.
  final bool ua;
  final String bonusesText;
  final List<RaceBonus> bonuses;

  /// true — бонусы выбирает игрок (правило MPMM: +2/+1 или +1/+1/+1).
  final bool bonusesChoice;

  /// Варианты распределения бонусов при выборе (напр. [[2, 1], [1, 1, 1]]).
  final List<List<int>>? choiceOptions;
  final String size;
  final String sizeText;
  final int? speedFt;
  final String speedText;
  final String languagesText;
  final List<RaceTrait> traits;
  final int? darkvisionFt;
}

/// Детальная карточка расы из _races_detail.json.
class RaceDetail {
  const RaceDetail({
    required this.id,
    required this.url,
    required this.nameRu,
    required this.nameEn,
    required this.bonusesText,
    required this.bonuses,
    required this.bonusesChoice,
    required this.choiceOptions,
    required this.size,
    required this.sizeText,
    required this.speedFt,
    required this.speedText,
    required this.languagesText,
    required this.traits,
    required this.darkvisionFt,
    required this.subspecies,
  });

  final String id;
  final String url;
  final String nameRu;
  final String nameEn;
  final String bonusesText;
  final List<RaceBonus> bonuses;
  final bool bonusesChoice;
  final List<List<int>>? choiceOptions;
  final String size;
  final String sizeText;
  final int? speedFt;
  final String speedText;
  final String languagesText;
  final List<RaceTrait> traits;
  final int? darkvisionFt;
  final List<Subspecies> subspecies;
}

/// Стартовое снаряжение класса из _classes_equipment.json:
/// rows — строки выбора, каждая строка — взаимоисключающие варианты.
class ClassEquipment {
  const ClassEquipment({required this.intro, required this.rows, required this.gold});

  final String intro;
  final List<List<String>> rows;
  final String gold;
}

class Feat extends CatalogEntry {
  const Feat({
    required super.id,
    required super.url,
    required super.nameRu,
    required super.nameEn,
    required this.source,
    required this.prerequisite,
    required this.description,
  });

  final String source;

  /// Требование к черте («Сила 13 или выше», «4 уровень, ...»).
  final String prerequisite;

  /// Текст черты.
  final String description;
}

/// Класс: ядро из _classes_core.json + прогрессия 1–20 из classes_5e14.json.
class ClassEntryCatalog {
  const ClassEntryCatalog({
    required this.id,
    required this.nameRu,
    required this.hitDiceSides,
    required this.armorProficiency,
    required this.weaponProficiency,
    required this.tools,
    required this.saves,
    required this.skillProficiencyRule,
    this.cols = const [],
    this.levels = const {},
  });

  final String id;
  final String nameRu;
  final int hitDiceSides;
  final String armorProficiency;
  final String weaponProficiency;
  final String tools;

  /// Спасброски строкой (напр. «Телосложение, Харизма»).
  final String saves;
  final String skillProficiencyRule;

  /// Колонки таблицы прогрессии (как в classes_5e14.json).
  final List<String> cols;

  /// Уровень (1–20) → строка таблицы + умения.
  final Map<int, ClassLevelRow> levels;
}

class ClassLevelRow {
  const ClassLevelRow({required this.cells, required this.features, required this.anchors});

  final List<String> cells;
  final List<String> features;
  final List<String> anchors;
}

/// Парсит CR из строки каталога: «1/8» → 0.125, «5» → 5.0, «—» → 0.
double parseCr(String raw) {
  final s = raw.trim();
  if (s.isEmpty || s == '—' || s == '-') return 0;
  final fraction = s.split('/');
  if (fraction.length == 2) {
    final num = double.tryParse(fraction[0]);
    final den = double.tryParse(fraction[1]);
    if (num != null && den != null && den != 0) return num / den;
  }
  return double.tryParse(s) ?? 0;
}

/// Извлекает число граней кости хитов из строки «1к8 за каждый уровень жреца».
int parseHitDiceSides(String raw) {
  final match = RegExp('к(\\d+)').firstMatch(raw);
  return match != null ? int.parse(match.group(1)!) : 8;
}
