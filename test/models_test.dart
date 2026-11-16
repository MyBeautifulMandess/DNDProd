import 'package:flutter_test/flutter_test.dart';

import 'package:dnd_prod/core/models/catalog.dart';
import 'package:dnd_prod/core/models/character.dart';
import 'package:dnd_prod/core/models/room.dart';
import 'package:dnd_prod/core/rules/ability.dart';
import 'package:dnd_prod/platform/network/lobby_transport.dart';

void main() {
  group('parseCr', () {
    test('дроби и целые из каталога', () {
      expect(parseCr('1/8'), 0.125);
      expect(parseCr('1/4'), 0.25);
      expect(parseCr('5'), 5.0);
      expect(parseCr('—'), 0);
      expect(parseCr(''), 0);
    });
  });

  group('parseHitDiceSides', () {
    test('кость из строки вида «1к8 за каждый уровень»', () {
      expect(parseHitDiceSides('1к8 за каждый уровень жреца'), 8);
      expect(parseHitDiceSides('1к12'), 12);
    });
  });

  group('Character JSON', () {
    test('roundtrip: toJson → fromJson', () {
      final c = Character(
        id: 'c1',
        name: 'Тест',
        level: 3,
        raceId: '79-elf',
        classEntries: [ClassEntry(classId: '91-fighter', level: 3, subclassId: 'champion')],
        abilityScores: const {Ability.strength: 16, Ability.dexterity: 14},
        skillProficiencies: const {Skill.athletics, Skill.perception},
        saveProficiencies: const {Ability.strength, Ability.constitution},
        currentHp: 24,
        maxHp: 28,
      );
      final restored = Character.fromJson(c.toJson());
      expect(restored.name, 'Тест');
      expect(restored.level, 3);
      expect(restored.abilityScores[Ability.strength], 16);
      expect(restored.skillProficiencies, contains(Skill.athletics));
      expect(restored.classEntries.single.subclassId, 'champion');
      expect(restored.maxHp, 28);
    });
  });

  group('canMoveToken (права из docs/06-lobby-network.md)', () {
    Token token(String? owner) => Token(id: 't1', kind: TokenKind.player, owner: owner, x: 0, y: 0);

    test('мастер двигает любую пешку', () {
      expect(canMoveToken(token: token('p2'), playerId: 'dm', isDm: true, moveOwnAllowed: false), isTrue);
    });
    test('игрок — только свою и только если разрешено', () {
      expect(canMoveToken(token: token('p1'), playerId: 'p1', isDm: false, moveOwnAllowed: true), isTrue);
      expect(canMoveToken(token: token('p2'), playerId: 'p1', isDm: false, moveOwnAllowed: true), isFalse);
      expect(canMoveToken(token: token('p1'), playerId: 'p1', isDm: false, moveOwnAllowed: false), isFalse);
    });
  });

  group('LobbyMessage', () {
    test('сериализация: v, type, payload', () {
      final m = LobbyMessage(LobbyMessageType.tokenMove, {'id': 't1', 'x': 3, 'y': 5});
      final restored = LobbyMessage.fromJson(m.toJson());
      expect(restored.type, 'token_move');
      expect(restored.payload['x'], 3);
    });
  });
}
