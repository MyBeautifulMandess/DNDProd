/// Характеристики и навыки по docs/02-rules-data.md и docs/10-glossary.md.
/// Идентификаторы — английский snake_case, отображение — русский.
library;

enum Ability {
  strength('str', 'Сила'),
  dexterity('dex', 'Ловкость'),
  constitution('con', 'Телосложение'),
  intelligence('int', 'Интеллект'),
  wisdom('wis', 'Мудрость'),
  charisma('cha', 'Харизма');

  const Ability(this.id, this.nameRu);

  final String id;
  final String nameRu;

  static Ability byId(String id) =>
      Ability.values.firstWhere((a) => a.id == id, orElse: () => throw ArgumentError('Неизвестная характеристика: $id'));
}

/// 18 навыков. Каждый привязан к характеристике.
enum Skill {
  acrobatics('acrobatics', 'Акробатика', Ability.dexterity),
  animalHandling('animal_handling', 'Уход за животными', Ability.wisdom),
  arcana('arcana', 'Магия', Ability.intelligence),
  athletics('athletics', 'Атлетика', Ability.strength),
  deception('deception', 'Обман', Ability.charisma),
  history('history', 'История', Ability.intelligence),
  insight('insight', 'Проницательность', Ability.wisdom),
  intimidation('intimidation', 'Запугивание', Ability.charisma),
  investigation('investigation', 'Расследование', Ability.intelligence),
  medicine('medicine', 'Медицина', Ability.wisdom),
  nature('nature', 'Природа', Ability.intelligence),
  perception('perception', 'Восприятие', Ability.wisdom),
  performance('performance', 'Выполнение', Ability.charisma),
  persuasion('persuasion', 'Убеждение', Ability.charisma),
  religion('religion', 'Религия', Ability.intelligence),
  sleightOfHand('sleight_of_hand', 'Ловкость рук', Ability.dexterity),
  stealth('stealth', 'Скрытность', Ability.dexterity),
  survival('survival', 'Выживание', Ability.wisdom);

  const Skill(this.id, this.nameRu, this.ability);

  final String id;
  final String nameRu;
  final Ability ability;

  static Skill byId(String id) =>
      Skill.values.firstWhere((s) => s.id == id, orElse: () => throw ArgumentError('Неизвестный навык: $id'));
}
