/// Формулы бросков для быстрого листа персонажа.
/// Строки совместимы с parseDiceFormula из lobby/protocol/dice_formula.dart.
library;

/// Проверка d20 с бонусом: «1к20+2», «1к20-1», «1к20».
String d20CheckFormula(int bonus) => '1к20${_signed(bonus)}';

/// Бросок кости хитов класса: «1к8».
String hitDieFormula(int sides) => '1к$sides';

String _signed(int value) =>
    value == 0 ? '' : value > 0 ? '+$value' : '$value';
