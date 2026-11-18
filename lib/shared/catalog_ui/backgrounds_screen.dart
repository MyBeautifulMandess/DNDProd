/// Экран справочника «Предыстории»: список, поиск, карточка записи со
/// ссылкой на dnd.su.
library;

import 'package:flutter/material.dart';

import '../../core/models/catalog.dart';
import '../../data/catalog_loader.dart';
import 'catalog_card.dart';
import 'catalog_filters.dart';
import 'catalog_list_screen.dart';

class BackgroundsScreen extends StatefulWidget {
  const BackgroundsScreen({super.key});

  @override
  State<BackgroundsScreen> createState() => _BackgroundsScreenState();
}

class _BackgroundsScreenState extends State<BackgroundsScreen> {
  late final Future<List<Background>> _entries;
  final BackgroundFilter _filter = const BackgroundFilter();

  @override
  void initState() {
    super.initState();
    _entries = catalogLoader.backgrounds();
  }

  @override
  Widget build(BuildContext context) {
    final filter = _filter;
    return CatalogListScreen<Background>(
      title: 'Предыстории',
      entries: _entries,
      select: (raw, query) =>
          sortByNameRu(applyBackgroundFilter(raw, filter.copyWith(query: query))),
      onOpenCard: (context, background) => showCatalogCard(
        context,
        background,
        lines: [
          ('Навыки', background.skills),
          ('Инструменты', background.tools),
          ('Языки', background.languages),
          ('Снаряжение', background.equipment),
          ('Умение', background.featureName),
          ('Источник', background.source),
        ],
        description: background.featureText,
      ),
    );
  }
}
