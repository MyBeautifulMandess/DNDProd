/// Разбор формулы броска вида «2к6+3» / «1d20-1» (docs/02-rules-data.md).
library;

import '../../core/rules/dice.dart';

class DiceFormula {
  const DiceFormula(this.count, this.sides, this.modifier);

  final int count;
  final int sides;
  final int modifier;

  String get display {
    final sign = modifier == 0 ? '' : '${modifier > 0 ? '+' : ''}$modifier';
    return '$count' 'к' '$sides' '$sign';
  }

  RollResult roll(DiceRoller roller) =>
      roller.rollDice(count, sides, modifier: modifier);
}

/// Возвращает null, если строка не является формулой кубиков.
DiceFormula? parseDiceFormula(String raw) {
  final match = RegExp(
          r'^\s*(\d{1,2})?\s*[dкDК]\s*(\d{1,3})\s*(?:([+-])\s*(\d{1,3}))?\s*$')
      .firstMatch(raw);
  if (match == null) return null;
  final count = int.tryParse(match.group(1) ?? '1') ?? 0;
  final sides = int.tryParse(match.group(2) ?? '') ?? 0;
  final modifier = int.tryParse(match.group(4) ?? '0') ?? 0;
  if (count < 1 || sides < 2) return null;
  return DiceFormula(
      count, sides, match.group(3) == '-' ? -modifier : modifier);
}
