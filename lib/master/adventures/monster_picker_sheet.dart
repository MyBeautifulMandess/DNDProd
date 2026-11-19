/// Выбор существа из бестиария для пешки-врага в приключении.
/// Хиты и размер берутся из каталога dnd.su, ничего не выдумывается.
library;

import 'package:flutter/material.dart';

import '../../core/models/catalog.dart';
import '../../core/rules/monster_size.dart';
import '../../data/catalog_loader.dart';
import 'adventure_editor_controller.dart';

Future<MonsterTokenSpec?> showMonsterPicker(BuildContext context) =>
    showModalBottomSheet<MonsterTokenSpec>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const MonsterPickerSheet(),
    );

class MonsterPickerSheet extends StatefulWidget {
  const MonsterPickerSheet({super.key});

  @override
  State<MonsterPickerSheet> createState() => _MonsterPickerSheetState();
}

class _MonsterPickerSheetState extends State<MonsterPickerSheet> {
  final _search = TextEditingController();
  String _query = '';
  Monster? _loading;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _search,
                decoration: const InputDecoration(
                  hintText: 'Поиск существа',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
                onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
              ),
            ),
            Flexible(
              child: FutureBuilder<List<Monster>>(
                future: catalogLoader.monsters(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    );
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Бестиарий недоступен: ${snapshot.error}'),
                    );
                  }
                  final matches = (snapshot.data ?? const <Monster>[])
                      .where((monster) =>
                          _query.isEmpty ||
                          monster.nameRu.toLowerCase().contains(_query) ||
                          monster.nameEn.toLowerCase().contains(_query))
                      .take(200)
                      .toList();
                  if (matches.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Ничего не найдено'),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: matches.length,
                    itemBuilder: (context, index) {
                      final monster = matches[index];
                      final busy = _loading?.id == monster.id;
                      return ListTile(
                        title: Text(monster.nameRu),
                        subtitle: Text(
                            'КС ${monster.cr} · ${monster.sizeType} · ${monster.nameEn}'),
                        trailing: busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : null,
                        onTap: busy ? null : () => _pick(monster),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );

  Future<void> _pick(Monster monster) async {
    setState(() => _loading = monster);
    try {
      final details = await catalogLoader.monsterDetails(monster.id);
      if (!mounted) return;
      Navigator.of(context).pop<MonsterTokenSpec>(MonsterTokenSpec(
        label: details.nameRu,
        catalogId: details.id,
        hp: details.hp,
        size: monsterCellSize(details.size),
      ));
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось загрузить существо: $error')),
      );
    }
  }
}
