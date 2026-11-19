/// Быстрая подгрузка записей справочника в текущую комнату мастера.
/// Монстр становится пешкой с данными из каталога, предмет и заклинание —
/// коротким сообщением в общий чат.
library;

import '../../core/models/catalog.dart';
import '../../core/models/room.dart';
import '../../core/rules/monster_size.dart';
import '../../data/catalog_loader.dart';
import '../../lobby/master_lobby_controller.dart';

enum QuickLoadKind { monster, item, spell }

class QuickLoadSelection {
  const QuickLoadSelection(this.kind, this.entry);

  final QuickLoadKind kind;
  final CatalogEntry entry;

  String get label =>
      entry.nameRu.trim().isEmpty ? entry.nameEn : entry.nameRu;
}

class QuickLoadToken {
  const QuickLoadToken({
    required this.label,
    required this.size,
    required this.hp,
  });

  final String label;
  final int size;
  final int? hp;
}

/// Пешка для монстра: размер и хиты берутся только из каталога.
QuickLoadToken quickLoadToken(Monster monster) => QuickLoadToken(
      label: monster.nameRu.trim().isEmpty ? monster.nameEn : monster.nameRu,
      size: monsterCellSize(monster.size),
      hp: monster.hp > 0 ? monster.hp : null,
    );

String _shortText(String text, [int limit = 180]) {
  final value = text.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (value.length <= limit) return value;
  return '${value.substring(0, limit)}…';
}

/// Сообщение в чат для предмета или заклинания. Монстр не даёт текста:
/// он добавляется пешкой.
String quickLoadChatText(QuickLoadSelection selection) {
  final label = selection.label;
  switch (selection.kind) {
    case QuickLoadKind.monster:
      return '';
    case QuickLoadKind.item:
      final item = selection.entry as Item;
      final details = <String>[
        if (item.rarity.trim().isNotEmpty) item.rarity.trim(),
        if (item.kind.trim().isNotEmpty) item.kind.trim(),
      ];
      final suffix = details.isEmpty ? '' : ' · ${details.join(' · ')}';
      final description = _shortText(item.description);
      return 'Из справочника: $label$suffix'
          '${description.isEmpty ? '' : ' — $description'}';
    case QuickLoadKind.spell:
      final spell = selection.entry as Spell;
      final circle = spell.level == 0 ? 'заговор' : '${spell.level} круг';
      final school = spell.school.trim().isEmpty ? '' : ' · ${spell.school.trim()}';
      final description = _shortText(spell.description);
      return 'Из справочника: $label · $circle$school'
          '${description.isEmpty ? '' : ' — $description'}';
  }
}

String quickLoadSuccessText(QuickLoadSelection selection) {
  switch (selection.kind) {
    case QuickLoadKind.monster:
      return 'Пешка «${selection.label}» добавлена на поле';
    case QuickLoadKind.item:
    case QuickLoadKind.spell:
      return '«${selection.label}» отправлено в чат';
  }
}

/// Один поиск по трём каталогам. Результаты берутся из `data/catalogs/`,
/// без выдуманных значений.
List<QuickLoadSelection> searchQuickLoad({
  required Iterable<Monster> monsters,
  required Iterable<Item> items,
  required Iterable<Spell> spells,
  String query = '',
  QuickLoadKind? kind,
  int limit = 60,
}) {
  final result = <QuickLoadSelection>[
    if (kind == null || kind == QuickLoadKind.monster)
      for (final monster in monsters)
        QuickLoadSelection(QuickLoadKind.monster, monster),
    if (kind == null || kind == QuickLoadKind.item)
      for (final item in items) QuickLoadSelection(QuickLoadKind.item, item),
    if (kind == null || kind == QuickLoadKind.spell)
      for (final spell in spells) QuickLoadSelection(QuickLoadKind.spell, spell),
  ];
  final q = query.trim().toLowerCase();
  final filtered = q.isEmpty
      ? result
      : result
          .where((entry) =>
              entry.entry.nameRu.toLowerCase().contains(q) ||
              entry.entry.nameEn.toLowerCase().contains(q))
          .toList();
  filtered.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
  return filtered.take(limit).toList();
}

/// Применяет выбор к запущенной комнате.
class QuickLoadService {
  QuickLoadService(this._controller, {CatalogLoader? catalogs})
      : _catalogs = catalogs ?? catalogLoader;

  final MasterLobbyController _controller;
  final CatalogLoader _catalogs;

  Future<void> load(QuickLoadSelection selection) async {
    if (selection.kind == QuickLoadKind.monster) {
      final monster = selection.entry as Monster;
      Monster details = monster;
      try {
        details = await _catalogs.monsterDetails(monster.id);
      } on Object {
        // Краткой записи из индекса достаточно, если шард недоступен.
      }
      final token = quickLoadToken(details);
      _controller.addToken(
        token.label,
        kind: TokenKind.monster,
        size: token.size,
        hp: token.hp,
      );
      return;
    }
    final text = quickLoadChatText(selection);
    if (text.isNotEmpty) _controller.sendChat(text);
  }
}
