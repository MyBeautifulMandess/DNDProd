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
    required this.subclasses,
    required this.concentration,
    required this.ritual,
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
  final String subclasses;
  final bool concentration;
  final bool ritual;
  final List<String> sources;
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
    required this.sources,
  });

  final String kind;
  final String rarity;
  final bool attunement;
  final String cost;
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
    required this.feature,
    required this.source,
  });

  /// Навыки строкой (напр. «Проницательность, Религия»).
  final String skills;
  final String tools;
  final String languages;
  final String equipment;
  final String feature;
  final String source;
}

class Feat extends CatalogEntry {
  const Feat({required super.id, required super.url, required super.nameRu, required super.nameEn, required this.source});

  final String source;
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
