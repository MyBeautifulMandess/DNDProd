/// Экран справочника «Предметы»: список, фильтры (редкость, вид, настройка),
/// карточка записи со ссылкой на dnd.su.
library;

import 'package:flutter/material.dart';

import '../../core/models/catalog.dart';
import '../../data/catalog_loader.dart';
import 'catalog_card.dart';
import 'catalog_filters.dart';
import 'catalog_list_screen.dart';

class ItemsScreen extends StatefulWidget {
  const ItemsScreen({super.key});

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  late final Future<List<Item>> _entries;
  ItemFilter _filter = const ItemFilter();

  @override
  void initState() {
    super.initState();
    _entries = catalogLoader.items();
  }

  void _setRarity(Set<String> selected) {
    setState(() {
      _filter = selected.isEmpty
          ? _filter.copyWith(clearRarity: true)
          : _filter.copyWith(rarity: selected.first);
    });
  }

  void _setKind(Set<String> selected) {
    setState(() {
      _filter = selected.isEmpty
          ? _filter.copyWith(clearKind: true)
          : _filter.copyWith(kind: selected.first);
    });
  }

  @override
  Widget build(BuildContext context) {
    final filter = _filter;
    return CatalogListScreen<Item>(
      title: 'Предметы',
      entries: _entries,
      select: (raw, query) =>
          sortByNameRu(applyItemFilter(raw, filter.copyWith(query: query))),
      filtersBuilder: (context, raw) => Column(
        children: [
          CatalogFilterChips(
            label: 'Редкость',
            options: collectItemRarities(raw).toList(),
            selected: filter.rarity == null ? const {} : {filter.rarity!},
            onChanged: _setRarity,
          ),
          CatalogFilterChips(
            label: 'Вид',
            options: collectItemKinds(raw).toList(),
            selected: filter.kind == null ? const {} : {filter.kind!},
            onChanged: _setKind,
          ),
          CatalogFilterRow(
            children: [
              CatalogFilterToggle(
                label: 'Требуется настройка',
                value: filter.attunementOnly,
                onChanged: (value) => setState(() {
                  _filter = _filter.copyWith(attunementOnly: value);
                }),
              ),
            ],
          ),
        ],
      ),
      onOpenCard: (context, item) => showCatalogCard(
        context,
        item,
        lines: [
          ('Вид', item.kind),
          ('Редкость', baseRarity(item.rarity)),
          ('Стоимость', item.cost),
          ('Требуется настройка', item.attunement ? 'да' : 'нет'),
          ('Источники', item.sources.join(', ')),
        ],
        description: item.description,
      ),
    );
  }
}
