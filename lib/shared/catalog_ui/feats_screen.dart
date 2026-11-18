/// Экран справочника «Черты»: список, фильтр по источнику, карточка записи
/// со ссылкой на dnd.su.
library;

import 'package:flutter/material.dart';

import '../../core/models/catalog.dart';
import '../../data/catalog_loader.dart';
import 'catalog_card.dart';
import 'catalog_filters.dart';
import 'catalog_list_screen.dart';

class FeatsScreen extends StatefulWidget {
  const FeatsScreen({super.key});

  @override
  State<FeatsScreen> createState() => _FeatsScreenState();
}

class _FeatsScreenState extends State<FeatsScreen> {
  late final Future<List<Feat>> _entries;
  FeatFilter _filter = const FeatFilter();

  @override
  void initState() {
    super.initState();
    _entries = catalogLoader.feats();
  }

  void _setSource(Set<String> selected) {
    setState(() {
      _filter = selected.isEmpty
          ? _filter.copyWith(clearSource: true)
          : _filter.copyWith(source: selected.first);
    });
  }

  @override
  Widget build(BuildContext context) {
    final filter = _filter;
    return CatalogListScreen<Feat>(
      title: 'Черты',
      entries: _entries,
      select: (raw, query) =>
          sortByNameRu(applyFeatFilter(raw, filter.copyWith(query: query))),
      filtersBuilder: (context, raw) => CatalogFilterChips(
        label: 'Источник',
        options: collectFeatSources(raw).toList(),
        selected: filter.source == null ? const {} : {filter.source!},
        onChanged: _setSource,
      ),
      onOpenCard: (context, feat) => showCatalogCard(
        context,
        feat,
        lines: [
          ('Источник', feat.source),
          ('Требование', feat.prerequisite),
        ],
        description: feat.description,
      ),
    );
  }
}
