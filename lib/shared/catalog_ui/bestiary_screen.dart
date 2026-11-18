/// Экран справочника «Бестиарий»: список, фильтры (CR, размер, тип, среда
/// обитания, источник), карточка записи со ссылкой на dnd.su.
library;

import 'package:flutter/material.dart';

import '../../core/models/catalog.dart';
import '../../data/catalog_loader.dart';
import 'catalog_card.dart';
import 'catalog_filters.dart';
import 'catalog_list_screen.dart';

class BestiaryScreen extends StatefulWidget {
  const BestiaryScreen({super.key});

  @override
  State<BestiaryScreen> createState() => _BestiaryScreenState();
}

class _BestiaryScreenState extends State<BestiaryScreen> {
  late final Future<List<Monster>> _entries;
  MonsterFilter _filter = const MonsterFilter();
  int? _crBandIndex;

  /// Способности/атаки существа → пункты секции карточки.
  static List<(String, String)> _abilityEntries(List<MonsterAbility> abilities) => [
        for (final ability in abilities)
          if (ability.text.trim().isNotEmpty || ability.name.trim().isNotEmpty)
            (ability.name, ability.text),
      ];

  @override
  void initState() {
    super.initState();
    _entries = catalogLoader.monsters();
  }

  void _setCrBand(Set<String> selected) {
    var index = -1;
    if (selected.isNotEmpty) {
      for (var i = 0; i < crBands.length; i++) {
        if (crBands[i].label == selected.first) {
          index = i;
          break;
        }
      }
    }
    setState(() {
      if (index < 0) {
        _crBandIndex = null;
        _filter = _filter.copyWith(clearMinCr: true, clearMaxCr: true);
      } else {
        final band = crBands[index];
        _crBandIndex = index;
        _filter = _filter.copyWith(
          minCr: band.min,
          maxCr: band.max,
        );
      }
    });
  }

  void _setSize(Set<String> selected) {
    setState(() {
      _filter = selected.isEmpty
          ? _filter.copyWith(clearSize: true)
          : _filter.copyWith(size: selected.first);
    });
  }

  void _setType(Set<String> selected) {
    setState(() {
      _filter = selected.isEmpty
          ? _filter.copyWith(clearType: true)
          : _filter.copyWith(type: selected.first);
    });
  }

  void _setHabitat(String? value) {
    setState(() {
      _filter = value == null
          ? _filter.copyWith(clearHabitat: true)
          : _filter.copyWith(habitat: value);
    });
  }

  void _setSource(String? value) {
    setState(() {
      _filter = value == null
          ? _filter.copyWith(clearSource: true)
          : _filter.copyWith(source: value);
    });
  }

  /// Полная карточка существа: в списке лежит краткая запись из индекса,
  /// секции и атаки подгружаются из шарда при открытии.
  Future<void> _openMonsterCard(BuildContext context, Monster summary) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    Monster monster;
    try {
      monster = await catalogLoader.monsterDetails(summary.id);
    } catch (_) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Не удалось загрузить карточку существа')),
      );
      return;
    }
    if (!context.mounted) return;
    await showCatalogCard(
      context,
      monster,
      lines: _cardLines(monster),
      sections: _cardSections(monster),
    );
  }

  static List<(String, String)> _cardLines(Monster monster) => [
        ('Размер', normalizeSize(monster.size)),
        ('Тип', monsterType(monster.sizeType)),
        ('Мировоззрение', monsterAlignment(monster.sizeType)),
        ('Класс доспеха', monster.ac > 0 ? monster.ac.toString() : ''),
        ('Хиты', monster.hp > 0 ? monster.hp.toString() : ''),
        ('Скорость', monster.speed),
        ('Показатель опасности', formatCr(monster.cr)),
        ('Опыт', monster.xp),
        ('Навыки', monster.skills),
        ('Чувства', monster.senses),
        ('Языки', monster.languages),
        ('Сопротивление урону', monster.damageResistance),
        ('Иммунитет к урону', monster.damageImmunity),
        ('Уязвимость к урону', monster.damageVulnerability),
        ('Иммунитет к состоянию', monster.conditionImmunity),
        ('Среда обитания', monster.habitat),
        ('Источники', monster.sources.join(', ')),
      ];

  static List<CatalogSection> _cardSections(Monster monster) => [
        CatalogSection(
          title: 'Способности',
          entries: _abilityEntries(monster.traits),
        ),
        for (final section in monster.sections)
          if (section.title.trim().isNotEmpty && section.entries.isNotEmpty)
            CatalogSection(
              title: section.title,
              entries: _abilityEntries(section.entries),
            ),
      ];

  @override
  Widget build(BuildContext context) {
    final filter = _filter;
    return CatalogListScreen<Monster>(
      title: 'Бестиарий',
      entries: _entries,
      select: (raw, query) =>
          sortByNameRu(applyMonsterFilter(raw, filter.copyWith(query: query))),
      filtersBuilder: (context, raw) => Column(
        children: [
          CatalogFilterChips(
            label: 'CR',
            options: crBands.map((band) => band.label).toList(),
            selected: _crBandIndex == null
                ? const {}
                : {crBands[_crBandIndex!].label},
            onChanged: _setCrBand,
          ),
          CatalogFilterChips(
            label: 'Размер',
            options: collectMonsterSizes(raw).toList(),
            selected: filter.size == null ? const {} : {filter.size!},
            onChanged: _setSize,
          ),
          CatalogFilterChips(
            label: 'Тип',
            options: collectMonsterTypes(raw).toList(),
            selected: filter.type == null ? const {} : {filter.type!},
            onChanged: _setType,
          ),
          CatalogFilterRow(
            children: [
              CatalogFilterMenu(
                label: 'Среда',
                options: collectMonsterHabitats(raw).toList(),
                selected: filter.habitat,
                onChanged: _setHabitat,
              ),
              CatalogFilterMenu(
                label: 'Источник',
                options: collectMonsterSources(raw).toList(),
                selected: filter.source,
                onChanged: _setSource,
              ),
            ],
          ),
        ],
      ),
      onOpenCard: _openMonsterCard,
    );
  }
}
