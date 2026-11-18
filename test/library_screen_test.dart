import 'package:dnd_prod/shared/catalog_ui/library_home.dart';
import 'package:dnd_prod/shared/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('хаб справочников открывает раздел заклинаний со списком', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: LibraryHomeScreen()),
      ),
    );

    expect(find.text('Бестиарий'), findsOneWidget);
    expect(find.text('Заклинания'), findsOneWidget);

    await tester.tap(find.text('Заклинания'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Загрузка каталога идёт через rootBundle — реальный асинхронный ввод-вывод.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 2)),
    );
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Адское возмездие'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'огн');
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await tester.pump();

    expect(find.text('Огненная буря'), findsOneWidget);
    expect(find.text('Адское возмездие'), findsNothing);
  });
}
