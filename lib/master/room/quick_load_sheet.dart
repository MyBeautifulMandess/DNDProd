/// Экран выбора записи справочника для быстрой подгрузки в комнату.
library;

import 'package:flutter/material.dart';

import '../../core/models/catalog.dart';
import '../../data/catalog_loader.dart';
import 'quick_load.dart';

typedef CatalogBundle = ({
  List<Monster> monsters,
  List<Item> items,
  List<Spell> spells,
});

Future<QuickLoadSelection?> showQuickLoadSheet(
  BuildContext context, {
  CatalogLoader? catalogs,
}) =>
    showModalBottomSheet<QuickLoadSelection>(
      context: context,
      isScrollControlled: true,
      builder: (context) => QuickLoadSheet(catalogs: catalogs),
    );

class QuickLoadSheet extends StatefulWidget {
  const QuickLoadSheet({super.key, this.catalogs});

  final CatalogLoader? catalogs;

  @override
  State<QuickLoadSheet> createState() => _QuickLoadSheetState();
}

class _QuickLoadSheetState extends State<QuickLoadSheet> {
  late final CatalogLoader _catalogs = widget.catalogs ?? catalogLoader;
  late final Future<CatalogBundle> _bundle = _load();
  String _query = '';
  QuickLoadKind? _kind;

  Future<List<T>> _safe<T>(Future<List<T>> Function() load) async {
    try {
      return await load();
    } on Object {
      return <T>[];
    }
  }

  Future<CatalogBundle> _load() async {
    final monsters = await _safe<Monster>(() => _catalogs.monsters());
    final items = await _safe<Item>(() => _catalogs.items());
    final spells = await _safe<Spell>(() => _catalogs.spells());
    return (monsters: monsters, items: items, spells: spells);
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.8;
    return SizedBox(
      height: height,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              key: const ValueKey('quick-load-search'),
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Поиск по справочникам',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text('Все'),
                selected: _kind == null,
                onSelected: (_) => setState(() => _kind = null),
              ),
              for (final kind in QuickLoadKind.values)
                FilterChip(
                  label: Text(_kindLabel(kind)),
                  selected: _kind == kind,
                  onSelected: (_) => setState(() => _kind = kind),
                ),
            ],
          ),
          const Divider(height: 12),
          Expanded(
            child: FutureBuilder<CatalogBundle>(
              future: _bundle,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Text('Ошибка загрузки: ${snapshot.error}'));
                }
                final bundle = snapshot.data;
                if (bundle == null) {
                  return const Center(child: Text('Каталоги недоступны'));
                }
                final results = searchQuickLoad(
                  monsters: bundle.monsters,
                  items: bundle.items,
                  spells: bundle.spells,
                  query: _query,
                  kind: _kind,
                );
                if (results.isEmpty) {
                  return const Center(child: Text('Ничего не найдено'));
                }
                return ListView.separated(
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = results[index];
                    return ListTile(
                      key: ValueKey('quick-load-${item.kind.name}-${item.entry.id}'),
                      title: Text(item.label),
                      subtitle: Text(_subtitle(item)),
                      onTap: () => Navigator.of(context).pop(item),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _kindLabel(QuickLoadKind kind) => switch (kind) {
        QuickLoadKind.monster => 'Монстры',
        QuickLoadKind.item => 'Предметы',
        QuickLoadKind.spell => 'Заклинания',
      };

  String _subtitle(QuickLoadSelection selection) {
    switch (selection.kind) {
      case QuickLoadKind.monster:
        final monster = selection.entry as Monster;
        return 'Монстр · ${monster.size} · CR ${monster.cr}';
      case QuickLoadKind.item:
        final item = selection.entry as Item;
        final rarity = item.rarity.trim();
        return 'Предмет${rarity.isEmpty ? '' : ' · $rarity'}';
      case QuickLoadKind.spell:
        final spell = selection.entry as Spell;
        final circle = spell.level == 0 ? 'заговор' : '${spell.level} круг';
        return 'Заклинание · $circle';
    }
  }
}
