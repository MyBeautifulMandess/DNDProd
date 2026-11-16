import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:dnd_prod/core/rules/dice.dart';

void main() {
  // Фиксированный seed — детерминированные тесты.
  final roller = DiceRoller(Random(42));

  group('rollDice', () {
    test('значения в диапазоне кубика', () {
      for (var i = 0; i < 200; i++) {
        final r = roller.rollDice(2, 6);
        expect(r.rolls.length, 2);
        for (final v in r.rolls) {
          expect(v, inInclusiveRange(1, 6));
        }
        expect(r.total, r.rolls.fold<int>(0, (a, b) => a + b));
      }
    });

    test('модификатор добавляется к итогу', () {
      final r = DiceRoller(Random(1)).rollDice(1, 20, modifier: 5);
      expect(r.total, r.rolls.single + 5);
    });

    test('недопустимый кубик — ошибка', () {
      expect(() => roller.roll(7), throwsArgumentError);
      expect(() => roller.rollDice(0, 6), throwsArgumentError);
    });
  });

  group('d20Test', () {
    test('обычный бросок: одна кость', () {
      final r = roller.d20Test();
      expect(r.rolls[0], r.rolls[1]);
      expect(r.total, r.rolls[0]);
    });

    test('преимущество ≥ обычного результата, помеха ≤', () {
      for (var i = 0; i < 100; i++) {
        final normal = roller.d20Test();
        final adv = roller.d20Test(advantage: true);
        final dis = roller.d20Test(disadvantage: true);
        expect(adv.total - adv.modifier, greaterThanOrEqualTo(normal.rolls.first));
        expect(dis.total - dis.modifier, lessThanOrEqualTo(normal.rolls.first));
      }
    });

    test('преимущество + помеха отменяются', () {
      final r = roller.d20Test(advantage: true, disadvantage: true);
      expect(r.rolls[0], r.rolls[1]);
    });
  });
}
