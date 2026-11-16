import 'dart:math';

/// Броски кубиков по docs/02-rules-data.md (раздел «Броски»).
library;

/// Результат одного броска: выпавшие кости и итог.
class RollResult {
  const RollResult({required this.rolls, required this.modifier, required this.total});

  final List<int> rolls;
  final int modifier;
  final int total;

  @override
  String toString() => 'RollResult(rolls: $rolls, modifier: $modifier, total: $total)';
}

class DiceRoller {
  DiceRoller([Random? rng]) : _rng = rng ?? Random();

  final Random _rng;

  /// Один кубик с [sides] гранями (d4, d6, d8, d10, d12, d20, d100).
  int roll(int sides) {
    _checkSides(sides);
    return 1 + _rng.nextInt(sides);
  }

  /// n кубиков с модификатором: `rollDice(2, 6, modifier: 3)` — «2к6+3».
  RollResult rollDice(int count, int sides, {int modifier = 0}) {
    if (count < 1) throw ArgumentError('Число кубиков должно быть >= 1');
    final rolls = List<int>.generate(count, (_) => roll(sides));
    final total = rolls.fold<int>(0, (a, b) => a + b) + modifier;
    return RollResult(rolls: rolls, modifier: modifier, total: total);
  }

  /// d20-тест с преимуществом/помехой: два кубика, берём больший/меньший.
  RollResult d20Test({int modifier = 0, bool advantage = false, bool disadvantage = false}) {
    if (advantage && disadvantage) {
      advantage = false;
      disadvantage = false; // по правилам взаимно отменяются
    }
    final a = roll(20);
    final b = (advantage || disadvantage) ? roll(20) : a;
    final kept = advantage ? max(a, b) : (disadvantage ? min(a, b) : a);
    return RollResult(rolls: [a, b], modifier: modifier, total: kept + modifier);
  }

  void _checkSides(int sides) {
    const allowed = {4, 6, 8, 10, 12, 20, 100};
    if (!allowed.contains(sides)) throw ArgumentError('Недопустимый кубик: d$sides');
  }
}
