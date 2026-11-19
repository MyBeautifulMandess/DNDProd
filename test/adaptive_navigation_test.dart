import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dnd_prod/shared/adaptive_navigation.dart';
import 'package:dnd_prod/shared/theme.dart';

void main() {
  final items = [
    const NavigationItem(icon: Icons.person_outline, label: 'Персонажи'),
    const NavigationItem(icon: Icons.book_outlined, label: 'Справочники'),
  ];

  Future<void> pumpHost(WidgetTester tester) => tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: _NavigationHost(items: items),
        ),
      );

  testWidgets('на телефоне нижние табы переключают экран', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHost(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Справочники'));
    await tester.pumpAndSettle();

    expect(find.text('Экран 1'), findsOneWidget);
  });

  testWidgets('на широком экране боковая панель переключает экран', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHost(tester);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    await tester.tap(find.text('Справочники'));
    await tester.pumpAndSettle();

    expect(find.text('Экран 1'), findsOneWidget);
  });

  testWidgets('кнопки темы имеют hit-area не менее 44×44', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          body: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(onPressed: null, child: Text('Текст')),
                IconButton(onPressed: null, icon: Icon(Icons.add)),
              ],
            ),
          ),
        ),
      ),
    );

    for (final finder in [find.byType(TextButton), find.byType(IconButton)]) {
      final size = tester.getSize(finder);
      expect(size.width, greaterThanOrEqualTo(44), reason: '$finder');
      expect(size.height, greaterThanOrEqualTo(44), reason: '$finder');
    }
  });
}

class _NavigationHost extends StatefulWidget {
  const _NavigationHost({required this.items});

  final List<NavigationItem> items;

  @override
  State<_NavigationHost> createState() => _NavigationHostState();
}

class _NavigationHostState extends State<_NavigationHost> {
  int _index = 0;

  @override
  Widget build(BuildContext context) => AdaptiveNavigationShell(
        title: widget.items[_index].label,
        items: widget.items,
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        body: Center(child: Text('Экран $_index')),
      );
}
