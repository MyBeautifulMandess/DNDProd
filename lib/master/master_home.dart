import 'package:flutter/material.dart';

import 'adventures/adventures_screen.dart';
import 'archives/archives_screen.dart';
import '../master/room/lobby_host_screen.dart';
import '../shared/catalog_ui/library_home.dart';

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
    (icon: Icons.badge_outlined, label: 'Архивы'),
    (icon: Icons.meeting_room_outlined, label: 'Комната'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(_tabs[_tab].label)),
        body: switch (_tab) {
          1 => const LibraryHomeScreen(),
          2 => const ArchivesScreen(),
          0 => AdventuresScreen(
              onStartRoom: () => setState(() => _tab = 3),
            ),
          _ => const LobbyHostScreen(),
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
