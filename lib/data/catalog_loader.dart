import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../core/models/catalog.dart';

/// Загрузка официальных каталогов из data/catalogs/ (зашиты в приложение как assets).
/// Офлайн-ферст: после парсинга справочники работают без сети.
/// Источник данных — dnd.su, пересбор через tools/build_catalogs.py.
library;

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

  Future<List<Spell>> spells() async => _spells ??= await _loadList('spells_5e14.json', _parseSpell);

  Future<List<Monster>> monsters() async => _monsters ??= await _loadList('bestiary_5e14.json', _parseMonster);

  Future<List<Item>> items() async => _items ??= await _loadList('items_5e14.json', _parseItem);

  Future<List<RaceEntry>> races() async => _races ??= await _loadList('races_5e14.json', _parseRace);

  Future<List<Background>> backgrounds() async => _backgrounds ??= await _loadList('backgrounds_full.json', _parseBackground);

  Future<List<Feat>> feats() async => _feats ??= await _loadList('feats_full.json', _parseFeat);

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
        subclasses: j['subclasses'] as String? ?? '',
        concentration: j['concentration'] as bool? ?? false,
        ritual: j['ritual'] as bool? ?? false,
        sources: _sources(j['sources']),
      );

  Monster _parseMonster(Map<String, dynamic> j) => Monster(
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
        sources: _sources(j['sources']),
      );

  Item _parseItem(Map<String, dynamic> j) => Item(
        id: _idFromUrl(j['url'] as String),
        url: j['url'] as String,
        nameRu: j['name_ru'] as String,
        nameEn: j['name_en'] as String,
        kind: j['kind'] as String? ?? '',
        rarity: j['rarity'] as String? ?? '',
        attunement: j['attunement'] as bool? ?? false,
        cost: j['cost'] as String? ?? '',
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
        feature: j['feature'] as String? ?? '',
        source: j['source'] as String? ?? '',
      );

  Feat _parseFeat(Map<String, dynamic> j) => Feat(
        id: _idFromUrl(j['url'] as String),
        url: j['url'] as String,
        nameRu: j['name_ru'] as String,
        nameEn: j['name_en'] as String,
        source: j['source'] as String? ?? '',
      );

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
