/// Хаб справочников: выбор раздела (заклинания, бестиарий, предметы, черты,
/// предыстории). Общий для ролей «Игрок» и «Мастер».
library;

import 'package:flutter/material.dart';

import 'backgrounds_screen.dart';
import 'bestiary_screen.dart';
import 'feats_screen.dart';
import 'items_screen.dart';
import 'spells_screen.dart';

class LibraryHomeScreen extends StatelessWidget {
  const LibraryHomeScreen({super.key});

  static const _sections = <(IconData, String, String, Widget)>[
    (
      Icons.auto_stories_outlined,
      'Заклинания',
      'Уровень, школа, концентрация, ритуал',
      SpellsScreen(),
    ),
    (
      Icons.pest_control_outlined,
      'Бестиарий',
      'CR, размер, тип, среда обитания, источник',
      BestiaryScreen(),
    ),
    (
      Icons.inventory_2_outlined,
      'Предметы',
      'Редкость, вид, настройка',
      ItemsScreen(),
    ),
    (
      Icons.star_outline,
      'Черты',
      'Список черт по источникам',
      FeatsScreen(),
    ),
    (
      Icons.history_edu_outlined,
      'Предыстории',
      'Навыки, инструменты, языки, умение',
      BackgroundsScreen(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _sections.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final (icon, title, subtitle, screen) = _sections[index];
        return ListTile(
          minVerticalPadding: 12,
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (context) => screen),
          ),
        );
      },
    );
  }
}
