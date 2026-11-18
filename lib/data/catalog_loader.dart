/// Загрузка официальных каталогов из data/catalogs/ (зашиты в приложение как assets).
/// Офлайн-ферст: после парсинга справочники работают без сети.
/// Источник данных — dnd.su, пересбор через tools/build_catalogs.py.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../core/models/catalog.dart';

class CatalogLoader {
  CatalogLoader({Future<String> Function(String key)? assetLoader})
      : _loadAsset = assetLoader ?? rootBundle.loadString;

  final Future<String> Function(String key) _loadAsset;

  List<Spell>? _spells;
  List<Monster>? _monsters;
  List<Item>? _items;
  List<RaceEntry>? _races;
  List<Background>? _backgrounds;
  List<Feat>? _feats;
  Map<String, ClassEntryCatalog>? _classes;
  Map<String, RaceDetail>? _raceDetails;
  Map<String, ClassEquipment>? _classEquipment;

  Future<List<Spell>> spells() async => _spells ??= await _loadList('spells_5e14.json', _parseSpell);

  Future<List<Monster>> monsters() async => _monsters ??= await _loadList('bestiary_5e14.json', _parseMonster);

  Future<List<Item>> items() async => _items ??= await _loadList('items_5e14.json', _parseItem);

  Future<List<RaceEntry>> races() async => _races ??= await _loadList('races_5e14.json', _parseRace);

  Future<List<Background>> backgrounds() async => _backgrounds ??= await _loadList('backgrounds_full.json', _parseBackground);

  Future<List<Feat>> feats() async => _feats ??= await _loadList('feats_full.json', _parseFeat);

  /// Детали рас (бонусы/скорость/черты/подвиды) из _races_detail.json, ключ — id расы.
  Future<Map<String, RaceDetail>> raceDetails() async {
    if (_raceDetails != null) return _raceDetails!;
    final raw = await _loadJsonMap('_races_detail.json');
    _raceDetails = {
      for (final e in raw.entries) e.key: _parseRaceDetail(e.key, e.value as Map<String, dynamic>),
    };
    return _raceDetails!;
  }

  /// Стартовое снаряжение классов из _classes_equipment.json, ключ — id класса.
  Future<Map<String, ClassEquipment>> classEquipment() async {
    if (_classEquipment != null) return _classEquipment!;
    final raw = await _loadJsonMap('_classes_equipment.json');
    _classEquipment = {
      for (final e in raw.entries)
        e.key: ClassEquipment(
          intro: e.value['intro'] as String? ?? '',
          rows: [
            for (final row in (e.value['rows'] as List? ?? const []))
              (row as List).cast<String>(),
          ],
          gold: e.value['gold'] as String? ?? '',
        ),
    };
    return _classEquipment!;
  }

  /// Классы: _classes_core.json (хиты, владения) + classes_5e14.json (прогрессия 1–20).
  Future<Map<String, ClassEntryCatalog>> classes() async {
    if (_classes != null) return _classes!;
    final core = await _loadJsonMap('_classes_core.json');
    final progression = await _loadJsonMap('classes_5e14.json');
    _classes = {
      for (final entry in core.entries)
        entry.key: _parseClass(entry.key, entry.value as Map<String, dynamic>,
            progression[entry.key] as Map<String, dynamic>?),
    };
    return _classes!;
  }

  // --- поиск/фильтры (полные экраны справочников — фаза 2) ---

  List<T> search<T extends CatalogEntry>(List<T> entries, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return entries;
    return entries.where((e) => e.nameRu.toLowerCase().contains(q) || e.nameEn.toLowerCase().contains(q)).toList();
  }

  List<Spell> filterSpells(List<Spell> spells, {int? level, String? school, String? classId}) {
    return spells.where((s) {
      if (level != null && s.level != level) return false;
      if (school != null && s.school != school) return false;
      if (classId != null && !s.classes.toLowerCase().contains(classId.toLowerCase())) return false;
      return true;
    }).toList();
  }

  List<Monster> filterMonsters(List<Monster> monsters, {double? maxCr, String? size, String? habitat}) {
    return monsters.where((m) {
      if (maxCr != null && m.cr > maxCr) return false;
      if (size != null && m.size != size) return false;
      if (habitat != null && !(m.habitat.contains(habitat))) return false;
      return true;
    }).toList();
  }

  // --- приватное: загрузка ---

  Future<List<Map<String, dynamic>>> _loadJsonList(String file) async {
    final raw = await _loadAsset('data/catalogs/$file');
    return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> _loadJsonMap(String file) async {
    final raw = await _loadAsset('data/catalogs/$file');
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<List<T>> _loadList<T>(String file, T Function(Map<String, dynamic>) parse) async =>
      (await _loadJsonList(file)).map(parse).toList();

  static String _idFromUrl(String url) => url.split('/').where((s) => s.isNotEmpty).last;

  static List<String> _sources(dynamic value) =>
      value is List ? value.cast<String>() : const [];

  /// Стоимость предмета без подписи («Рекомендованная стоимость: 500 зм» → «500 зм»).
  static String _itemCost(dynamic value) {
    final cost = (value as String? ?? '').trim();
    final colon = cost.indexOf(':');
    if (colon >= 0 && colon < 40) return cost.substring(colon + 1).trim();
    return cost;
  }

  /// Имя класса с заглавной буквы (в каталоге — строчными).
  static String _className(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  // --- приватное: парсеры записей ---

  Spell _parseSpell(Map<String, dynamic> j) => Spell(
        id: _idFromUrl(j['url'] as String),
        url: j['url'] as String,
        nameRu: j['name_ru'] as String,
        nameEn: j['name_en'] as String,
        level: j['level'] as int? ?? 0,
        school: j['school'] as String? ?? '',
        schoolLine: j['school_line'] as String? ?? '',
        castTime: j['cast_time'] as String? ?? '',
        range: j['range'] as String? ?? '',
        components: j['components'] as String? ?? '',
        duration: j['duration'] as String? ?? '',
        classes: j['classes'] as String? ?? '',
        classList: [
          for (final value in (j['class_list'] as List? ?? const []))
            _className(value as String),
        ],
        subclasses: j['subclasses'] as String? ?? '',
        concentration: j['concentration'] as bool? ?? false,
        ritual: j['ritual'] as bool? ?? false,
        description: j['description'] as String? ?? '',
        sources: _sources(j['sources']),
      );

  Monster _parseMonster(Map<String, dynamic> j) {
    final sections = _parseSections(j['sections']);
    List<MonsterAbility> byTitle(bool Function(String title) match) => [
          for (final section in sections)
            if (match(section.title)) ...section.entries,
        ];
    final traits = byTitle((title) => title.trim().isEmpty);
    return Monster(
        id: _idFromUrl(j['url'] as String),
        url: j['url'] as String,
        nameRu: j['name_ru'] as String,
        nameEn: j['name_en'] as String,
        size: j['size'] as String? ?? '',
        sizeType: j['size_type'] as String? ?? '',
        ac: j['ac'] as int? ?? 0,
        hp: j['hp'] as int? ?? 0,
        cr: parseCr(j['cr'] as String? ?? ''),
        xp: j['xp'] as String? ?? '',
        skills: j['skills'] as String? ?? '',
        senses: j['senses'] as String? ?? '',
        languages: j['languages'] as String? ?? '',
        habitat: j['habitat'] as String? ?? '',
        speed: j['speed'] as String? ?? '',
        damageResistance: j['damage_resistance'] as String? ?? '',
        damageImmunity: j['damage_immunity'] as String? ?? '',
        damageVulnerability: j['damage_vulnerability'] as String? ?? '',
        conditionImmunity: j['condition_immunity'] as String? ?? '',
        traits: traits.isNotEmpty ? traits : _parseAbilities(j['traits']),
        sections: sections,
        actions: byTitle(
          (title) =>
              title.toLowerCase().contains('действ') &&
              !title.toLowerCase().contains('легендар') &&
              !title.toLowerCase().contains('бонусн'),
        ),
        abilities: traits,
        legendaryActions: byTitle(
          (title) => title.toLowerCase().contains('легендар'),
        ),
        reactions: byTitle((title) => title.toLowerCase().contains('реакц')),
        description: byTitle(
          (title) => title.toLowerCase().contains('описан'),
        ).map((ability) => ability.text).where((text) => text.isNotEmpty).join('\n\n'),
        sources: _sources(j['sources']),
      );
  }

  Item _parseItem(Map<String, dynamic> j) => Item(
        id: _idFromUrl(j['url'] as String),
        url: j['url'] as String,
        nameRu: j['name_ru'] as String,
        nameEn: j['name_en'] as String,
        kind: j['kind'] as String? ?? '',
        rarity: j['rarity'] as String? ?? '',
        attunement: j['attunement'] as bool? ?? false,
        cost: _itemCost(j['cost']),
        description: j['description'] as String? ?? '',
        sources: _sources(j['sources']),
      );

  RaceEntry _parseRace(Map<String, dynamic> j) => RaceEntry(
        id: _idFromUrl(j['url'] as String),
        url: j['url'] as String,
        nameRu: j['name_ru'] as String,
        nameEn: j['name_en'] as String,
        source: j['source'] as String? ?? '',
        sources: _sources(j['sources']),
      );

  Background _parseBackground(Map<String, dynamic> j) => Background(
        id: _idFromUrl(j['url'] as String),
        url: j['url'] as String,
        nameRu: j['name_ru'] as String,
        nameEn: j['name_en'] as String,
        skills: j['skills'] as String? ?? '',
        tools: j['tools'] as String? ?? '',
        languages: j['languages'] as String? ?? '',
        equipment: j['equipment'] as String? ?? '',
        featureName: j['feature_name'] as String? ?? '',
        featureText: j['feature_text'] as String? ?? '',
        source: j['source'] as String? ?? '',
      );

  RaceDetail _parseRaceDetail(String id, Map<String, dynamic> j) => RaceDetail(
        id: id,
        url: j['url'] as String? ?? '',
        nameRu: j['name_ru'] as String? ?? '',
        nameEn: j['name_en'] as String? ?? '',
        bonusesText: j['bonuses_text'] as String? ?? '',
        bonuses: _parseBonuses(j['bonuses']),
        bonusesChoice: j['bonuses_choice'] as bool? ?? false,
        choiceOptions: _parseChoiceOptions(j['choice_options']),
        size: j['size'] as String? ?? '',
        sizeText: j['size_text'] as String? ?? '',
        speedFt: j['speed_ft'] as int?,
        speedText: j['speed_text'] as String? ?? '',
        languagesText: j['languages_text'] as String? ?? '',
        traits: _parseTraits(j['traits']),
        darkvisionFt: j['darkvision_ft'] as int?,
        subspecies: [
          for (final s in (j['subspecies'] as List? ?? const []))
            _parseSubspecies(s as Map<String, dynamic>),
        ],
      );

  Subspecies _parseSubspecies(Map<String, dynamic> j) => Subspecies(
        anchor: j['anchor'] as String? ?? '',
        name: j['name'] as String? ?? '',
        source: j['source'] as String? ?? '',
        ua: j['ua'] as bool? ?? false,
        bonusesText: j['bonuses_text'] as String? ?? '',
        bonuses: _parseBonuses(j['bonuses']),
        bonusesChoice: j['bonuses_choice'] as bool? ?? false,
        choiceOptions: _parseChoiceOptions(j['choice_options']),
        size: j['size'] as String? ?? '',
        sizeText: j['size_text'] as String? ?? '',
        speedFt: j['speed_ft'] as int?,
        speedText: j['speed_text'] as String? ?? '',
        languagesText: j['languages_text'] as String? ?? '',
        traits: _parseTraits(j['traits']),
        darkvisionFt: j['darkvision_ft'] as int?,
      );

  List<RaceBonus> _parseBonuses(dynamic value) => [
        for (final b in (value as List? ?? const []))
          RaceBonus(
            ability: (b as Map<String, dynamic>)['ability'] as String,
            bonus: b['bonus'] as int,
          ),
      ];

  List<List<int>>? _parseChoiceOptions(dynamic value) => value is List
      ? [for (final variant in value) (variant as List).cast<int>()]
      : null;

  List<RaceTrait> _parseTraits(dynamic value) => [
        for (final t in (value as List? ?? const []))
          RaceTrait(name: (t as Map<String, dynamic>)['name'] as String, text: t['text'] as String),
      ];

  Feat _parseFeat(Map<String, dynamic> j) => Feat(
        id: _idFromUrl(j['url'] as String),
        url: j['url'] as String,
        nameRu: j['name_ru'] as String,
        nameEn: j['name_en'] as String,
        source: j['source'] as String? ?? '',
        prerequisite: j['prerequisite'] as String? ?? '',
        description: j['description'] as String? ?? '',
      );

  List<MonsterAbility> _parseAbilities(dynamic value) => [
        for (final entry in (value as List? ?? const []))
          MonsterAbility(
            name: (entry as Map<String, dynamic>)['name'] as String? ?? '',
            text: entry['text'] as String? ?? '',
          ),
      ];

  List<MonsterSection> _parseSections(dynamic value) => [
        for (final entry in (value as List? ?? const []))
          MonsterSection(
            title: (entry as Map<String, dynamic>)['title'] as String? ?? '',
            entries: _parseAbilities(entry['entries']),
          ),
      ];

  ClassEntryCatalog _parseClass(String id, Map<String, dynamic> core, Map<String, dynamic>? progression) {
    final cols = (progression?['cols'] as List?)?.cast<String>() ?? const <String>[];
    final levelsRaw = (progression?['levels'] as Map<String, dynamic>?) ?? const {};
    final levels = <int, ClassLevelRow>{};
    for (final e in levelsRaw.entries) {
      final level = int.tryParse(e.key);
      if (level == null) continue;
      final row = e.value as Map<String, dynamic>;
      levels[level] = ClassLevelRow(
        cells: (row['row'] as List?)?.cast<String>() ?? const [],
        features: (row['features'] as List?)?.cast<String>() ?? const [],
        anchors: (row['anchors'] as List?)?.cast<String>() ?? const [],
      );
    }
    return ClassEntryCatalog(
      id: id,
      nameRu: core['class'] as String? ?? id,
      hitDiceSides: parseHitDiceSides(core['hit_dice'] as String? ?? 'к8'),
      armorProficiency: core['armor'] as String? ?? '',
      weaponProficiency: core['weapons'] as String? ?? '',
      tools: core['tools'] as String? ?? '',
      saves: core['saves'] as String? ?? '',
      skillProficiencyRule: core['skills'] as String? ?? '',
      cols: cols,
      levels: levels,
    );
  }
}

/// Точка входа для UI: один загрузчик на приложение.
final catalogLoader = CatalogLoader();
