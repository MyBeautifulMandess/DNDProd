import 'package:dnd_prod/core/models/catalog.dart';
import 'package:dnd_prod/shared/catalog_ui/catalog_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final items = [
    for (var i = 0; i < 8; i++)
      Item(
        id: 'item-$i',
        url: 'https://dnd.su/items/$i/',
        nameRu: 'Предмет $i',
        nameEn: 'Item $i',
        kind: 'Прочее',
        rarity: 'обычный',
        attunement: false,
        cost: '1 зм',
        description: '',
        sources: const ['PHB'],
      ),
  ];

  testWidgets('список выдаёт записи страницами', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CatalogListScreen<Item>(
          title: 'Тест',
          entries: Future.value(items),
          select: (raw, query) => raw,
          onOpenCard: (context, item) {},
          pageSize: 3,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Показано 3 из 8'), findsOneWidget);
    expect(find.text('Показать ещё 3'), findsOneWidget);

    await tester.tap(find.text('Показать ещё 3'));
    await tester.pumpAndSettle();
    expect(find.text('Показано 6 из 8'), findsOneWidget);
    expect(find.text('Показать ещё 2'), findsOneWidget);

    // Прокрутка к концу списка догружает остаток автоматически.
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.text('Показано 8 из 8'), findsOneWidget);
    expect(find.textContaining('Показать ещё'), findsNothing);
  });
}
