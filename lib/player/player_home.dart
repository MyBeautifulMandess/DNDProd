import 'package:flutter/material.dart';

import '../shared/stub_placeholder.dart';

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
        body: StubPlaceholder(
          title: _tabs[_tab].label,
          phase: _tab == 0
              ? 'Фаза 1 — создание и прокачка персонажа (docs/03-character-builder.md)'
              : _tab == 1
                  ? 'Фаза 2 — справочники из data/catalogs/ (docs/04-player-app.md, раздел 4)'
                  : 'Фаза 3 — подключение к лобби мастера (docs/06-lobby-network.md)',
        ),
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
