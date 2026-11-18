import 'package:flutter/material.dart';

import 'lobby/connect_screen.dart';
import 'characters/characters_screen.dart';
import '../shared/catalog_ui/library_home.dart';

/// Домашний экран роли «Игрок».
/// Реализация вкладок — фазы 1–2 (билдер, список персонажей, справочники), см. docs/07-roadmap.md.
class PlayerHomeScreen extends StatefulWidget {
  const PlayerHomeScreen({super.key});

  @override
  State<PlayerHomeScreen> createState() => _PlayerHomeScreenState();
}

class _PlayerHomeScreenState extends State<PlayerHomeScreen> {
  int _tab = 0;

  static const _tabs = [
    (icon: Icons.person_outline, label: 'Персонажи'),
    (icon: Icons.book_outlined, label: 'Справочники'),
    (icon: Icons.wifi_tethering, label: 'Подключение'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(_tabs[_tab].label)),
        body: switch (_tab) {
          0 => const CharactersScreen(),
          1 => const LibraryHomeScreen(),
          _ => const ConnectScreen(),
        },
        // Нижняя навигация — форм-фактор телефона; на широких экранах заменить
        // боковой (LayoutBuilder), см. правила переносимости docs/01-architecture.md.
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: [
            for (final t in _tabs)
              NavigationDestination(icon: Icon(t.icon), label: t.label),
          ],
        ),
      );
}
