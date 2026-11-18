/// Формулы D&D 5e (PHB 2014) из docs/02-rules-data.md.
/// Все функции чистые — при изменении правил правится только этот файл.
library;

import 'ability.dart';
import '../models/catalog.dart';

/// Модификатор характеристики: floor((значение − 10) / 2).
/// Значение 1 → −5, 20 → +5, 30 → +10.
int abilityModifier(int score) => ((score - 10) / 2).floor();

/// Бонус мастерства: 2 + floor((уровень − 1) / 4).
/// Уровни 1–4: +2, 5–8: +3, 9–12: +4, 13–16: +5, 17–20: +6.
int proficiencyBonus(int level) {
  _checkLevel(level);
  return 2 + ((level - 1) / 4).floor();
}

/// Класс Доспеха: 10 + модификатор ЛОВ + бонус доспеха + бонус щита.
/// Умения вроде «Защиты без доспехов» — отдельные формулы на уровне класса.
int armorClass({required int dexterity, int armorBonus = 0, int shieldBonus = 0}) =>
    10 + abilityModifier(dexterity) + armorBonus + shieldBonus;

/// Хиты на 1 уровне: максимум кости хитов + модификатор ТЕЛ.
int hpAtFirstLevel({required int hitDieSides, required int constitution}) =>
    hitDieSides + abilityModifier(constitution);

/// Хиты при повышении уровня: фиксированное среднее (округление вверх) + мод. ТЕЛ, минимум 1.
int hpOnLevelUp({required int hitDieSides, required int constitution}) {
  final average = (hitDieSides / 2).ceil();
  return max1(average + abilityModifier(constitution));
}

/// Пассивное Восприятие: 10 + модификатор МДР (+ бонус мастерства, если владеешь Восприятием).
int passivePerception({required int wisdom, bool proficient = false, int proficiencyBonusValue = 2, int extraBonus = 0}) =>
    10 + abilityModifier(wisdom) + (proficient ? proficiencyBonusValue : 0) + extraBonus;

/// Инициатива: модификатор ЛОВ (бросок делает DiceRoller).
int initiativeBonus(int dexterity) => abilityModifier(dexterity);

/// Бонус навыка: модификатор характеристики + бонус мастерства при владении.
int skillBonus({required Skill skill, required int abilityScore, bool proficient = false, int level = 1}) =>
    abilityModifier(abilityScore) + (proficient ? proficiencyBonus(level) : 0);

/// Бонус спасброска: модификатор характеристики (+ бонус мастерства при владении).
int savingThrowBonus({required Ability ability, required int abilityScore, bool proficient = false, int level = 1}) =>
    abilityModifier(abilityScore) + (proficient ? proficiencyBonus(level) : 0);

/// Очки характеристик point buy: стоимость от 8 до 15 по таблице PHB.
/// 8→0, 9→1, 10→2, 11→3, 12→4, 13→5, 14→7, 15→9. Бюджет — 27 очков.
int pointBuyCost(int score) {
  if (score < 8 || score > 15) throw ArgumentError('Point buy: значение $score вне диапазона 8–15');
  const costs = [0, 1, 2, 3, 4, 5, 7, 9];
  return costs[score - 8];
}

const pointBuyBudget = 27;
const standardArray = [15, 14, 13, 12, 10, 8];

int max1(int value) => value < 1 ? 1 : value;

/// Расовый бонус характеристики из каталога рас. Складывает бонусы расы и
/// выбранного подвида. Для рас/подвидов с выбором бонусов (MPMM, bonusesChoice)
/// бонус решается в билдере и здесь не учитывается — возвращает 0.
int racialBonus(Ability ability, RaceDetail? race, {String? subraceAnchor}) {
  if (race == null) return 0;
  var bonus = 0;
  if (!race.bonusesChoice) {
    for (final b in race.bonuses) {
      if (b.ability == ability.id) bonus += b.bonus;
    }
  }
  for (final s in race.subspecies) {
    if (s.anchor == subraceAnchor && !s.bonusesChoice) {
      for (final b in s.bonuses) {
        if (b.ability == ability.id) bonus += b.bonus;
      }
    }
  }
  return bonus;
}

void _checkLevel(int level) {
  if (level < 1 || level > 20) throw ArgumentError('Уровень $level вне диапазона 1–20');
}
