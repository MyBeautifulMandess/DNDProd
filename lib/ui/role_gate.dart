import 'package:flutter/material.dart';

import '../master/master_home.dart';
import '../player/player_home.dart';

/// Экран входа: выбор роли — Игрок / Мастер (docs/01-architecture.md, раздел 8).
/// Иконки и фон — сгенерированный набор из docs/08-assets.md (шаг 0.3).
class RoleGateScreen extends StatelessWidget {
  const RoleGateScreen({super.key});

  static const _menuBg = 'assets/2d/ui/menu_bg.jpg';

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage(_menuBg),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(Colors.black54, BlendMode.darken),
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 720;
                final cards = [
                  _RoleCard(
                    iconAsset: 'assets/2d/ui/tab_player.png',
                    title: 'Игрок',
                    subtitle: 'Мои персонажи, справочники, подключение к комнате мастера',
                    onTap: () => _open(context, const PlayerHomeScreen()),
                  ),
                  _RoleCard(
                    iconAsset: 'assets/2d/ui/tab_dm.png',
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
        ),
      );

  void _open(BuildContext context, Widget screen) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => screen),
      );
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.iconAsset, required this.title, required this.subtitle, required this.onTap});

  final String iconAsset;
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
                Image.asset(iconAsset, width: 96, height: 96),
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
