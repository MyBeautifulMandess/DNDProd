import 'package:flutter/material.dart';

/// Оболочка ролевых экранов: нижние табы на телефоне, боковая панель на широком экране.
/// Порог и минимальные hit-area зафиксированы в docs/01-architecture.md.
class AdaptiveNavigationShell extends StatelessWidget {
  const AdaptiveNavigationShell({
    required this.title,
    required this.items,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    super.key,
  });

  final String title;
  final List<NavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 840;
          return Scaffold(
            appBar: AppBar(title: Text(title), centerTitle: true),
            body: wide
                ? Row(
                    children: [
                      NavigationRail(
                        selectedIndex: selectedIndex,
                        onDestinationSelected: onDestinationSelected,
                        labelType: NavigationRailLabelType.all,
                        destinations: [
                          for (final item in items)
                            NavigationRailDestination(
                              icon: Icon(item.icon),
                              label: Text(item.label),
                            ),
                        ],
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: body),
                    ],
                  )
                : body,
            bottomNavigationBar: wide
                ? null
                : NavigationBar(
                    selectedIndex: selectedIndex,
                    onDestinationSelected: onDestinationSelected,
                    destinations: [
                      for (final item in items)
                        NavigationDestination(
                          icon: Icon(item.icon),
                          label: item.label,
                        ),
                    ],
                  ),
          );
        },
      );
}

class NavigationItem {
  const NavigationItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}
