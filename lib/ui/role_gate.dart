import 'package:flutter/material.dart';

import '../master/master_home.dart';
import '../player/player_home.dart';

/// Экран входа: выбор роли — Игрок / Мастер (docs/01-architecture.md, раздел 8).
/// Иконки-ассеты (assets/2d/ui/tab_player.png, tab_dm.png) подключаются после
/// генерации набора из docs/08-assets.md; до этого — системные иконки.
class RoleGateScreen extends StatelessWidget {
  const RoleGateScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 720;
              final cards = [
                _RoleCard(
                  icon: Icons.shield_outlined,
                  title: 'Игрок',
                  subtitle: 'Мои персонажи, справочники, подключение к комнате мастера',
                  onTap: () => _open(context, const PlayerHomeScreen()),
                ),
                _RoleCard(
                  icon: Icons.menu_book_outlined,
                  title: 'Мастер',
                  subtitle: 'Приключения, игровые поля, запуск комнаты',
                  onTap: () => _open(context, const MasterHomeScreen()),
                ),
              ];
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: isWide
                      ? Row(children: cards.map((c) => Expanded(child: c)).toList())
                      : Column(children: cards.map((c) => Expanded(child: c)).toList()),
                ),
              );
            },
          ),
        ),
      );

  void _open(BuildContext context, Widget screen) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => screen),
      );
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.all(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          // Hit-area ≥ 44×44 — правило переносимости из docs/01-architecture.md.
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 64),
                const SizedBox(height: 16),
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(subtitle, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
}
