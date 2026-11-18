import 'package:dnd_prod/core/rules/roll_formula.dart';
import 'package:dnd_prod/lobby/protocol/dice_formula.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('d20CheckFormula: плюс, минус и нулевой бонус', () {
    expect(d20CheckFormula(2), '1к20+2');
    expect(d20CheckFormula(-1), '1к20-1');
    expect(d20CheckFormula(0), '1к20');
  });

  test('hitDieFormula: кость хитов класса', () {
    expect(hitDieFormula(8), '1к8');
    expect(hitDieFormula(12), '1к12');
  });

  test('формулы листа принимаются протоколом лобби', () {
    for (final formula in [d20CheckFormula(5), d20CheckFormula(-3), hitDieFormula(6)]) {
      final parsed = parseDiceFormula(formula);
      expect(parsed, isNotNull, reason: formula);
      expect(parsed!.count, 1);
      expect(parsed.sides, formula.contains('20') ? 20 : 6);
    }
  });
}
