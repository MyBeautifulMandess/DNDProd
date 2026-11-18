import 'package:flutter_test/flutter_test.dart';

import 'package:dnd_prod/core/models/catalog.dart';
import 'package:dnd_prod/core/rules/ability.dart';
import 'package:dnd_prod/core/rules/formulas.dart';

/// Края по docs/02-rules-data.md, раздел 8: значения 1/20/30, БМ на 1/5/9/13/17.
void main() {
  group('abilityModifier', () {
    test('края: 1 → −5, 20 → +5, 30 → +10', () {
      expect(abilityModifier(1), -5);
      expect(abilityModifier(20), 5);
      expect(abilityModifier(30), 10);
      expect(abilityModifier(10), 0);
      expect(abilityModifier(11), 0);
      expect(abilityModifier(9), -1);
    });
  });

  group('proficiencyBonus', () {
    test('1–4: +2, 5–8: +3, 9–12: +4, 13–16: +5, 17–20: +6', () {
      expect(proficiencyBonus(1), 2);
      expect(proficiencyBonus(4), 2);
      expect(proficiencyBonus(5), 3);
      expect(proficiencyBonus(8), 3);
      expect(proficiencyBonus(9), 4);
      expect(proficiencyBonus(12), 4);
      expect(proficiencyBonus(13), 5);
      expect(proficiencyBonus(16), 5);
      expect(proficiencyBonus(17), 6);
      expect(proficiencyBonus(20), 6);
    });

    test('уровень вне 1–20 — ошибка', () {
      expect(() => proficiencyBonus(0), throwsArgumentError);
      expect(() => proficiencyBonus(21), throwsArgumentError);
    });
  });

  group('armorClass', () {
    test('без доспеха: 10 + ЛОВ', () {
      expect(armorClass(dexterity: 14), 12); // +2 ЛОВ
    });
    test('с доспехом и щитом', () {
      expect(armorClass(dexterity: 14, armorBonus: 3, shieldBonus: 2), 17);
    });
  });

  group('хиты', () {
    test('1 уровень: максимум кости + мод. ТЕЛ', () {
      expect(hpAtFirstLevel(hitDieSides: 8, constitution: 14), 10); // 8 + 2
    });
    test('повышение: среднее вверх + мод. ТЕЛ, минимум 1', () {
      expect(hpOnLevelUp(hitDieSides: 8, constitution: 14), 6); // среднее 4 + мод. ТЕЛ 2
      expect(hpOnLevelUp(hitDieSides: 12, constitution: 1), 1); // 6 + (−5) → минимум 1
    });
  });

  group('пассивное Восприятие', () {
    test('10 + МДР (+БМ при владении)', () {
      expect(passivePerception(wisdom: 14), 12);
      expect(passivePerception(wisdom: 14, proficient: true, proficiencyBonusValue: 3), 15);
    });
  });

  group('навыки и спасброски', () {
    test('навык: мод. характеристики + БМ', () {
      expect(skillBonus(skill: Skill.stealth, abilityScore: 16, proficient: true, level: 5), 6); // +3 + 3
      expect(skillBonus(skill: Skill.arcana, abilityScore: 10, proficient: false), 0);
    });
    test('спасбросок', () {
      expect(savingThrowBonus(ability: Ability.constitution, abilityScore: 15, proficient: true, level: 1), 4); // +2 + 2
    });
  });

  group('racialBonus', () {
    RaceDetail race({
      bool choice = false,
      List<RaceBonus> bonuses = const [],
      List<Subspecies> subspecies = const [],
    }) =>
        RaceDetail(
          id: 'test',
          url: '',
          nameRu: 'Тестовая раса',
          nameEn: 'Test',
          bonusesText: '',
          bonuses: bonuses,
          bonusesChoice: choice,
          choiceOptions: null,
          size: '',
          sizeText: '',
          speedFt: 30,
          speedText: '',
          languagesText: '',
          traits: const [],
          darkvisionFt: null,
          subspecies: subspecies,
        );

    test('бонусы расы складываются с бонусами подвида', () {
      final r = race(
        bonuses: const [RaceBonus(ability: 'str', bonus: 2)],
        subspecies: const [
          Subspecies(
            anchor: 'hill',
            name: 'Холмовой',
            source: '',
            ua: false,
            bonusesText: '',
            bonuses: [RaceBonus(ability: 'str', bonus: 1)],
            bonusesChoice: false,
            choiceOptions: null,
            size: '',
            sizeText: '',
            speedFt: null,
            speedText: '',
            languagesText: '',
            traits: [],
            darkvisionFt: null,
          ),
        ],
      );
      expect(racialBonus(Ability.strength, r), 2);
      expect(racialBonus(Ability.strength, r, subraceAnchor: 'hill'), 3);
      expect(racialBonus(Ability.dexterity, r, subraceAnchor: 'hill'), 0);
    });

    test('раса с выбором бонусов (MPMM) не даёт автоматического бонуса', () {
      final r = race(choice: true, bonuses: const [RaceBonus(ability: 'str', bonus: 2)]);
      expect(racialBonus(Ability.strength, r), 0);
      expect(racialBonus(Ability.strength, null), 0);
    });
  });

  group('point buy', () {
    test('стоимость 8–15 и бюджет 27', () {
      expect(pointBuyCost(8), 0);
      expect(pointBuyCost(13), 5);
      expect(pointBuyCost(14), 7);
      expect(pointBuyCost(15), 9);
      expect(pointBuyBudget, 27);
      expect(standardArray, [15, 14, 13, 12, 10, 8]);
      expect(() => pointBuyCost(16), throwsArgumentError);
    });
  });
}
