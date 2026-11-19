import 'package:flutter/material.dart';

import 'lobby/connect_screen.dart';
import 'characters/characters_screen.dart';
import '../shared/adaptive_navigation.dart';
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

  static const _items = [
    NavigationItem(icon: Icons.person_outline, label: 'Персонажи'),
    NavigationItem(icon: Icons.book_outlined, label: 'Справочники'),
    NavigationItem(icon: Icons.wifi_tethering, label: 'Подключение'),
  ];

  @override
  Widget build(BuildContext context) => AdaptiveNavigationShell(
        title: _items[_tab].label,
        items: _items,
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        body: switch (_tab) {
          0 => const CharactersScreen(),
          1 => const LibraryHomeScreen(),
          _ => const ConnectScreen(),
        },
      );
}
