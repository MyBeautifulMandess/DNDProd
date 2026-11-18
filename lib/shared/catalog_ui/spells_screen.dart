/// Экран справочника «Заклинания»: список, фильтры (уровень, школа,
/// концентрация, ритуал), карточка записи со ссылкой на dnd.su.
library;

import 'package:flutter/material.dart';

import '../../core/models/catalog.dart';
import '../../data/catalog_loader.dart';
import 'catalog_card.dart';
import 'catalog_filters.dart';
import 'catalog_list_screen.dart';

class SpellsScreen extends StatefulWidget {
  const SpellsScreen({super.key});

  @override
  State<SpellsScreen> createState() => _SpellsScreenState();
}

class _SpellsScreenState extends State<SpellsScreen> {
  late final Future<List<Spell>> _entries;
  SpellFilter _filter = const SpellFilter();
  SpellSort _sort = SpellSort.name;

  static const _sortLabels = <SpellSort, String>{
    SpellSort.name: 'по названию',
    SpellSort.className: 'по классу',
    SpellSort.level: 'по уровню',
    SpellSort.school: 'по школе',
  };

  static const _levelLabels = <int, String>{
    0: 'Заговор',
    1: '1',
    2: '2',
    3: '3',
    4: '4',
    5: '5',
    6: '6',
    7: '7',
    8: '8',
    9: '9',
  };

  @override
  void initState() {
    super.initState();
    _entries = catalogLoader.spells();
  }

  void _setLevel(Set<String> selected) {
    int? level;
    if (selected.isNotEmpty) {
      for (final entry in _levelLabels.entries) {
        if (entry.value == selected.first) {
          level = entry.key;
          break;
        }
      }
    }
    setState(() {
      _filter = level == null
          ? _filter.copyWith(clearLevel: true)
          : _filter.copyWith(level: level);
    });
  }

  void _setSchool(Set<String> selected) {
    setState(() {
      _filter = selected.isEmpty
          ? _filter.copyWith(clearSchool: true)
          : _filter.copyWith(school: selected.first);
    });
  }

  void _setClass(Set<String> selected) {
    setState(() {
      _filter = selected.isEmpty
          ? _filter.copyWith(clearClass: true)
          : _filter.copyWith(className: selected.first);
    });
  }

  void _setSort(String label) {
    setState(() {
      for (final entry in _sortLabels.entries) {
        if (entry.value == label) _sort = entry.key;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filter = _filter;
    return CatalogListScreen<Spell>(
      title: 'Заклинания',
      entries: _entries,
      select: (raw, query) =>
          sortSpells(applySpellFilter(raw, filter.copyWith(query: query)), _sort),
      filtersBuilder: (context, raw) => Column(
        children: [
          CatalogFilterChips(
            label: 'Уровень',
            options: _levelLabels.values.toList(),
            selected:
                filter.level == null ? const {} : {_levelLabels[filter.level]!},
            onChanged: _setLevel,
          ),
          CatalogFilterChips(
            label: 'Школа',
            options: collectSpellSchools(raw).toList(),
            selected: filter.school == null ? const {} : {filter.school!},
            onChanged: _setSchool,
          ),
          CatalogFilterChips(
            label: 'Класс',
            options: collectSpellClasses(raw).toList(),
            selected: filter.className == null ? const {} : {filter.className!},
            onChanged: _setClass,
          ),
          CatalogSortChips(
            label: 'Сортировка',
            options: _sortLabels.values.toList(),
            selected: _sortLabels[_sort]!,
            onChanged: _setSort,
          ),
          CatalogFilterRow(
            children: [
              CatalogFilterToggle(
                label: 'Концентрация',
                value: filter.concentrationOnly,
                onChanged: (value) => setState(() {
                  _filter = _filter.copyWith(concentrationOnly: value);
                }),
              ),
              CatalogFilterToggle(
                label: 'Ритуал',
                value: filter.ritualOnly,
                onChanged: (value) => setState(() {
                  _filter = _filter.copyWith(ritualOnly: value);
                }),
              ),
            ],
          ),
        ],
      ),
      onOpenCard: (context, spell) => showCatalogCard(
        context,
        spell,
        lines: [
          ('Школа и уровень', spell.schoolLine),
          ('Время накладывания', spell.castTime),
          ('Дистанция', spell.range),
          ('Компоненты', spell.components),
          ('Длительность', spell.duration),
          ('Классы', spellClasses(spell).join(', ')),
          ('Концентрация', spell.concentration ? 'да' : 'нет'),
          ('Ритуал', spell.ritual ? 'да' : 'нет'),
        ],
        description: spell.description,
      ),
    );
  }
}
