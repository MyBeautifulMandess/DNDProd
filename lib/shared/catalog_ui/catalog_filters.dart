/// Фильтры справочников: чистые функции и неизменяемые состояния фильтров.
/// Значения нормализуются, потому что в каталогах dnd.su они свободный текст
/// («Средняя?», «редкий (требуется настройка)», «Средний? Гуманоид (человек), ...»).
library;

import '../../core/models/catalog.dart';

/// Приводит строку к виду для сравнения: без крайних пробелов, в нижнем регистре.
String normalizeCase(String raw) => raw.trim().toLowerCase();

const Map<String, String> _sizeStems = <String, String>{
  'громадн': 'Громадный',
  'огромн': 'Огромный',
  'больш': 'Большой',
  'средн': 'Средний',
  'маленьк': 'Маленький',
  'крошечн': 'Крошечный',
};

/// Нормализует размер существа: «Средняя?» → «Средний», «Крошечная?» → «Крошечный».
String normalizeSize(String raw) {
  final cleaned = raw.replaceAll('?', '').trim();
  if (cleaned.isEmpty) return '';
  final lower = cleaned.toLowerCase();
  for (final entry in _sizeStems.entries) {
    if (lower.startsWith(entry.key)) return entry.value;
  }
  return cleaned;
}

/// Базовое название школы: «прорицание (ритуал)» → «прорицание».
String baseSchool(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  final index = trimmed.indexOf('(');
  final base = index < 0 ? trimmed : trimmed.substring(0, index);
  return base.replaceAll(RegExp(r'[\)\(]'), '').trim();
}

/// Базовое название редкости: «редкий (требуется настройка)» → «редкий».
String baseRarity(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  final index = trimmed.indexOf('(');
  return (index < 0 ? trimmed : trimmed.substring(0, index)).trim();
}

/// Группа предмета: «Оружие (длинный меч), ...» → «Оружие».
String baseItemKind(String raw) {
  var value = raw.trim();
  final comma = value.indexOf(',');
  if (comma >= 0) value = value.substring(0, comma);
  final paren = value.indexOf('(');
  if (paren >= 0) value = value.substring(0, paren);
  return value.trim();
}

/// Тип существа из строки «Средний? Гуманоид (человек), нейтрально-злой» → «Гуманоид».
String monsterType(String sizeType) {
  var value = sizeType.split(',').first.trim();
  if (value.isEmpty) return '';
  final firstSpace = value.indexOf(' ');
  if (firstSpace > 0) {
    final head = value.substring(0, firstSpace);
    final normalized = normalizeSize(head);
    if (_sizeStems.containsValue(normalized)) {
      value = value.substring(firstSpace + 1).trim();
    }
  }
  final paren = value.indexOf('(');
  if (paren >= 0) value = value.substring(0, paren);
  value = value.trim();
  if (value.contains(' ')) {
    value = value.split(' ').last.trim();
  }
  if (value.isEmpty) return '';
  value = normalizeCase(value) == 'зверей' ? 'Зверь' : value;
  return value[0].toUpperCase() + value.substring(1);
}

/// Мировоззрение существа: часть строки типа после первой запятой.
String monsterAlignment(String sizeType) {
  final index = sizeType.indexOf(',');
  if (index < 0) return '';
  return sizeType.substring(index + 1).trim();
}

bool _matchesQuery(String query, List<String> names) {
  final needle = normalizeCase(query);
  if (needle.isEmpty) return true;
  return names.any((name) => normalizeCase(name).contains(needle));
}

/// Классы заклинания из строки каталога: «волшебник, чародей» → [Волшебник, Чародей].
/// Служебные пометки источника (TCE) и уточнения в скобках отбрасываются.
List<String> spellClassNames(String raw) {
  final names = <String>[];
  for (final part in raw.split(',')) {
    var value = part.trim();
    if (value.isEmpty) continue;
    value = value.replaceAll(RegExp(r'TCE$'), '').trim();
    final paren = value.indexOf('(');
    if (paren >= 0) value = value.substring(0, paren).trim();
    if (value.isEmpty) continue;
    value = value[0].toUpperCase() + value.substring(1);
    if (!names.contains(value)) names.add(value);
  }
  return names;
}

/// Классы заклинания: приоритет — готовый список из каталога.
List<String> spellClasses(Spell spell) =>
    spell.classList.isNotEmpty ? spell.classList : spellClassNames(spell.classes);

/// Варианты сортировки заклинаний.
enum SpellSort { name, className, level, school }

/// Фильтр заклинаний: уровень, школа, класс, концентрация, ритуал, поиск.
class SpellFilter {
  const SpellFilter({
    this.level,
    this.school,
    this.className,
    this.concentrationOnly = false,
    this.ritualOnly = false,
    this.query = '',
  });

  final int? level;
  final String? school;

  /// Класс наколдуна (напр. «Волшебник»).
  final String? className;
  final bool concentrationOnly;
  final bool ritualOnly;
  final String query;

  SpellFilter copyWith({
    int? level,
    bool clearLevel = false,
    String? school,
    bool clearSchool = false,
    String? className,
    bool clearClass = false,
    bool? concentrationOnly,
    bool? ritualOnly,
    String? query,
  }) {
    return SpellFilter(
      level: clearLevel ? null : (level ?? this.level),
      school: clearSchool ? null : (school ?? this.school),
      className: clearClass ? null : (className ?? this.className),
      concentrationOnly: concentrationOnly ?? this.concentrationOnly,
      ritualOnly: ritualOnly ?? this.ritualOnly,
      query: query ?? this.query,
    );
  }

  bool matches(Spell spell) {
    final levelFilter = level;
    if (levelFilter != null && spell.level != levelFilter) return false;
    final schoolFilter = school;
    if (schoolFilter != null &&
        normalizeCase(baseSchool(spell.school)) != normalizeCase(schoolFilter)) {
      return false;
    }
    final classFilter = className;
    if (classFilter != null &&
        !spellClasses(spell).any(
          (name) => normalizeCase(name) == normalizeCase(classFilter),
        )) {
      return false;
    }
    if (concentrationOnly && !spell.concentration) return false;
    if (ritualOnly && !spell.ritual) return false;
    return _matchesQuery(query, <String>[spell.nameRu, spell.nameEn]);
  }
}

/// Фильтр чудовищ: CR (мин включительно, макс исключительно), размер, тип,
/// среда обитания, источник, поиск.
class MonsterFilter {
  const MonsterFilter({
    this.minCr,
    this.maxCr,
    this.size,
    this.type,
    this.habitat,
    this.source,
    this.query = '',
  });

  final double? minCr;
  final double? maxCr;
  final String? size;
  final String? type;
  final String? habitat;
  final String? source;
  final String query;

  MonsterFilter copyWith({
    double? minCr,
    bool clearMinCr = false,
    double? maxCr,
    bool clearMaxCr = false,
    String? size,
    bool clearSize = false,
    String? type,
    bool clearType = false,
    String? habitat,
    bool clearHabitat = false,
    String? source,
    bool clearSource = false,
    String? query,
  }) {
    return MonsterFilter(
      minCr: clearMinCr ? null : (minCr ?? this.minCr),
      maxCr: clearMaxCr ? null : (maxCr ?? this.maxCr),
      size: clearSize ? null : (size ?? this.size),
      type: clearType ? null : (type ?? this.type),
      habitat: clearHabitat ? null : (habitat ?? this.habitat),
      source: clearSource ? null : (source ?? this.source),
      query: query ?? this.query,
    );
  }

  bool matches(Monster monster) {
    final minFilter = minCr;
    if (minFilter != null && monster.cr < minFilter) return false;
    final maxFilter = maxCr;
    if (maxFilter != null && monster.cr >= maxFilter) return false;
    final sizeFilter = size;
    if (sizeFilter != null &&
        normalizeCase(normalizeSize(monster.size)) !=
            normalizeCase(normalizeSize(sizeFilter))) {
      return false;
    }
    final typeFilter = type;
    if (typeFilter != null &&
        !normalizeCase(monsterType(monster.sizeType))
            .contains(normalizeCase(typeFilter))) {
      return false;
    }
    final habitatFilter = habitat;
    if (habitatFilter != null && habitatFilter.trim().isNotEmpty) {
      if (monster.habitat.trim().isEmpty) return false;
      if (!normalizeCase(monster.habitat).contains(normalizeCase(habitatFilter))) {
        return false;
      }
    }
    final sourceFilter = source;
    if (sourceFilter != null && sourceFilter.trim().isNotEmpty) {
      final needle = normalizeCase(sourceFilter);
      if (!monster.sources.any((item) => normalizeCase(item) == needle)) {
        return false;
      }
    }
    return _matchesQuery(query, <String>[monster.nameRu, monster.nameEn]);
  }
}

/// Фильтр предметов: редкость, вид, настройка, поиск.
class ItemFilter {
  const ItemFilter({
    this.rarity,
    this.kind,
    this.attunementOnly = false,
    this.query = '',
  });

  final String? rarity;
  final String? kind;
  final bool attunementOnly;
  final String query;

  ItemFilter copyWith({
    String? rarity,
    bool clearRarity = false,
    String? kind,
    bool clearKind = false,
    bool? attunementOnly,
    String? query,
  }) {
    return ItemFilter(
      rarity: clearRarity ? null : (rarity ?? this.rarity),
      kind: clearKind ? null : (kind ?? this.kind),
      attunementOnly: attunementOnly ?? this.attunementOnly,
      query: query ?? this.query,
    );
  }

  bool matches(Item item) {
    final rarityFilter = rarity;
    if (rarityFilter != null &&
        normalizeCase(baseRarity(item.rarity)) !=
            normalizeCase(baseRarity(rarityFilter))) {
      return false;
    }
    final kindFilter = kind;
    if (kindFilter != null &&
        normalizeCase(baseItemKind(item.kind)) !=
            normalizeCase(baseItemKind(kindFilter))) {
      return false;
    }
    if (attunementOnly && !item.attunement) return false;
    return _matchesQuery(query, <String>[item.nameRu, item.nameEn]);
  }
}

/// Фильтр черт: источник, поиск.
class FeatFilter {
  const FeatFilter({this.source, this.query = ''});

  final String? source;
  final String query;

  FeatFilter copyWith({
    String? source,
    bool clearSource = false,
    String? query,
  }) {
    return FeatFilter(
      source: clearSource ? null : (source ?? this.source),
      query: query ?? this.query,
    );
  }

  bool matches(Feat feat) {
    final sourceFilter = source;
    if (sourceFilter != null &&
        normalizeCase(feat.source) != normalizeCase(sourceFilter)) {
      return false;
    }
    return _matchesQuery(query, <String>[feat.nameRu, feat.nameEn]);
  }
}

/// Фильтр предысторий: поиск.
class BackgroundFilter {
  const BackgroundFilter({this.query = ''});

  final String query;

  BackgroundFilter copyWith({String? query}) =>
      BackgroundFilter(query: query ?? this.query);

  bool matches(Background background) =>
      _matchesQuery(query, <String>[background.nameRu, background.nameEn]);
}

/// Формат показателя опасности: 0.125 → «1/8», 5.0 → «5».
String formatCr(double cr) {
  const fractions = <(double, String)>[
    (0.125, '1/8'),
    (0.25, '1/4'),
    (0.5, '1/2'),
  ];
  for (final (value, label) in fractions) {
    if ((cr - value).abs() < 0.0001) return label;
  }
  if (cr == cr.roundToDouble()) return cr.toInt().toString();
  return cr.toStringAsFixed(2);
}
/// Полоса показателя опасности: min включительно, max исключительно.
class CrBand {
  const CrBand({required this.min, required this.max, required this.label});

  final double min;
  final double max;
  final String label;
}

/// Готовые полосы CR для фильтра чудовищ.
const List<CrBand> crBands = <CrBand>[
  CrBand(min: 0, max: 1, label: 'до 1'),
  CrBand(min: 1, max: 3, label: '1–2'),
  CrBand(min: 3, max: 5, label: '3–4'),
  CrBand(min: 5, max: 9, label: '5–8'),
  CrBand(min: 9, max: 13, label: '9–12'),
  CrBand(min: 13, max: 17, label: '13–16'),
  CrBand(min: 17, max: 21, label: '17–20'),
  CrBand(min: 21, max: double.infinity, label: '21+'),
];

List<Spell> applySpellFilter(List<Spell> items, SpellFilter filter) =>
    items.where(filter.matches).toList();

List<Monster> applyMonsterFilter(List<Monster> items, MonsterFilter filter) =>
    items.where(filter.matches).toList();

List<Item> applyItemFilter(List<Item> items, ItemFilter filter) =>
    items.where(filter.matches).toList();

List<Feat> applyFeatFilter(List<Feat> items, FeatFilter filter) =>
    items.where(filter.matches).toList();

List<Background> applyBackgroundFilter(
  List<Background> items,
  BackgroundFilter filter,
) =>
    items.where(filter.matches).toList();

/// Сортировка записей по русскому названию.
List<T> sortByNameRu<T extends CatalogEntry>(List<T> items) {
  final sorted = List<T>.of(items);
  sorted.sort((a, b) => normalizeCase(a.nameRu).compareTo(normalizeCase(b.nameRu)));
  return sorted;
}

/// Сортировка заклинаний: по названию, классу, уровню или школе.
List<Spell> sortSpells(List<Spell> items, SpellSort sort) {
  final sorted = List<Spell>.of(items);
  int byName(Spell a, Spell b) =>
      normalizeCase(a.nameRu).compareTo(normalizeCase(b.nameRu));
  switch (sort) {
    case SpellSort.name:
      sorted.sort(byName);
    case SpellSort.className:
      sorted.sort((a, b) {
        final first = _spellSortKey(a);
        final second = _spellSortKey(b);
        final byClass = first.compareTo(second);
        return byClass != 0 ? byClass : byName(a, b);
      });
    case SpellSort.level:
      sorted.sort((a, b) {
        final byLevel = a.level.compareTo(b.level);
        return byLevel != 0 ? byLevel : byName(a, b);
      });
    case SpellSort.school:
      sorted.sort((a, b) {
        final bySchool = normalizeCase(baseSchool(a.school))
            .compareTo(normalizeCase(baseSchool(b.school)));
        return bySchool != 0 ? bySchool : byName(a, b);
      });
  }
  return sorted;
}

/// Ключ сортировки по классу: первый класс заклинания, иначе — пустое начало.
String _spellSortKey(Spell spell) {
  final classes = spellClasses(spell);
  if (classes.isEmpty) return '';
  return normalizeCase(classes.first);
}

Set<String> _sortedSet(Iterable<String> values) {
  final unique = <String>{};
  for (final value in values) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) unique.add(trimmed);
  }
  final list = unique.toList()
    ..sort((a, b) => normalizeCase(a).compareTo(normalizeCase(b)));
  return list.toSet();
}

Set<String> collectSpellSchools(List<Spell> items) =>
    _sortedSet(items.map((spell) => baseSchool(spell.school)));

/// Классы, встречающиеся в заклинаниях (для фильтра и сортировки).
Set<String> collectSpellClasses(List<Spell> items) =>
    _sortedSet(items.expand((spell) => spellClasses(spell)));

Set<String> collectMonsterSizes(List<Monster> items) =>
    _sortedSet(items.map((monster) => normalizeSize(monster.size)));

Set<String> collectMonsterTypes(List<Monster> items) =>
    _sortedSet(items.map((monster) => monsterType(monster.sizeType)));

Set<String> collectMonsterHabitats(List<Monster> items) => _sortedSet(
      items.expand((monster) => monster.habitat.split(',')),
    );

Set<String> collectMonsterSources(List<Monster> items) => _sortedSet(
      items.expand((monster) => monster.sources),
    );

Set<String> collectItemRarities(List<Item> items) =>
    _sortedSet(items.map((item) => baseRarity(item.rarity)));

Set<String> collectItemKinds(List<Item> items) =>
    _sortedSet(items.map((item) => baseItemKind(item.kind)));

Set<String> collectFeatSources(List<Feat> items) =>
    _sortedSet(items.map((feat) => feat.source));
