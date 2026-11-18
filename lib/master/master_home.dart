import 'package:flutter/material.dart';

import '../shared/catalog_ui/library_home.dart';
import '../shared/stub_placeholder.dart';

/// Домашний экран роли «Мастер».
/// Реализация вкладок — фазы 2–3 (справочники, приключения, комната), см. docs/05-master-app.md.
class MasterHomeScreen extends StatefulWidget {
  const MasterHomeScreen({super.key});

  @override
  State<MasterHomeScreen> createState() => _MasterHomeScreenState();
}

class _MasterHomeScreenState extends State<MasterHomeScreen> {
  int _tab = 0;

  static const _tabs = [
    (icon: Icons.auto_awesome_outlined, label: 'Приключения'),
    (icon: Icons.book_outlined, label: 'Справочники'),
    (icon: Icons.meeting_room_outlined, label: 'Комната'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(_tabs[_tab].label)),
        body: switch (_tab) {
          1 => const LibraryHomeScreen(),
          0 => StubPlaceholder(
              title: _tabs[_tab].label,
              phase: 'Фаза 5 — приключения: карты, токены врагов, лор, ПМ (docs/05-master-app.md)',
            ),
          _ => StubPlaceholder(
              title: _tabs[_tab].label,
              phase: 'Фаза 3 — запуск комнаты и управление сессией (docs/06-lobby-network.md)',
            ),
        },
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
