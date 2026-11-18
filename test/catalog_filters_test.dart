import 'package:dnd_prod/core/models/catalog.dart';
import 'package:dnd_prod/shared/catalog_ui/catalog_filters.dart';
import 'package:flutter_test/flutter_test.dart';

Spell _spell({
  int level = 1,
  String school = 'воплощение',
  bool concentration = false,
  bool ritual = false,
  String nameRu = 'Огненный шар',
  String nameEn = 'Fireball',
  String classes = 'Волшебник, Жрец',
  List<String>? classList,
}) {
  return Spell(
    id: '115-fireball',
    url: 'https://dnd.su/spells/115-fireball/',
    nameRu: nameRu,
    nameEn: nameEn,
    level: level,
    school: school,
    schoolLine: '3 уровень, воплощение',
    castTime: '1 действие',
    range: '150 футов',
    components: 'V, S, M',
    duration: 'Мгновенная',
    classes: classes,
    classList: classList ?? spellClassNames(classes),
    subclasses: '',
    concentration: concentration,
    ritual: ritual,
    description: 'Описание.',
    sources: const ['PH14'],
  );
}

Monster _monster({
  double cr = 1,
  String size = 'Средний?',
  String sizeType = 'Средний? Гуманоид (человек), нейтрально-злой',
  String habitat = 'лес, подземье',
  List<String> sources = const ['MM14'],
  String nameRu = 'Волк',
  String nameEn = 'Wolf',
}) {
  return Monster(
    id: '266-wolf',
    url: 'https://dnd.su/bestiary/266-wolf/',
    nameRu: nameRu,
    nameEn: nameEn,
    size: size,
    sizeType: sizeType,
    ac: 13,
    hp: 11,
    cr: cr,
    xp: '200',
    skills: 'Восприятие +3',
    senses: 'пассивное 13',
    languages: '—',
    habitat: habitat,
    speed: '40 футов',
    damageResistance: '—',
    damageImmunity: '—',
    damageVulnerability: '—',
    conditionImmunity: '—',
    traits: const [MonsterAbility(name: 'Тактика', text: 'Прячется в тени.')],
    sections: const [
      MonsterSection(
        title: 'Действия',
        entries: [MonsterAbility(name: 'Укус', text: '+4 к попаданию, 1к6+2.')],
      ),
    ],
    actions: const [MonsterAbility(name: 'Укус', text: '+4 к попаданию, 1к6+2.')],
    abilities: const [],
    legendaryActions: const [],
    reactions: const [],
    description: 'Волк — стайный хищник.',
    sources: sources,
  );
}

Item _item({
  String kind = 'Оружие (длинный меч)',
  String rarity = 'редкий (требуется настройка)',
  bool attunement = true,
  String nameRu = 'Меч',
  String nameEn = 'Sword',
}) {
  return Item(
    id: '1-sword',
    url: 'https://dnd.su/items/1-sword/',
    nameRu: nameRu,
    nameEn: nameEn,
    kind: kind,
    rarity: rarity,
    attunement: attunement,
    cost: '500 зм',
    description: 'Длинный меч.',
    sources: const ['DMG14'],
  );
}

Feat _feat({String source = 'PH14'}) {
  return Feat(
    id: '101-actor',
    url: 'https://dnd.su/feats/101-actor/',
    nameRu: 'Артистичный',
    nameEn: 'Actor',
    source: source,
    prerequisite: 'Харизма 13 или выше',
    description: 'Вы получаете преимущество на проверки Обмана.',
  );
}

Background _background({String nameRu = 'Авантюрист'}) {
  return Background(
    id: '756-adventurer',
    url: 'https://dnd.su/backgrounds/756-adventurer/',
    nameRu: nameRu,
    nameEn: 'Adventurer',
    skills: 'Атлетика, Скрытность',
    tools: 'Игра на музыкальном инструменте',
    languages: 'Общий, эльфийский',
    equipment: 'Снаряжение искателя приключений',
    featureName: 'Удачный беглец',
    featureText: 'Текст умения.',
    source: 'PH14',
  );
}

void main() {
  group('нормализация значений каталога', () {
    test('размеры приводятся к мужскому роду без вопросительного знака', () {
      expect(normalizeSize('Средняя?'), 'Средний');
      expect(normalizeSize('Среднее?'), 'Средний');
      expect(normalizeSize('Крошечная?'), 'Крошечный');
      expect(normalizeSize('  '), '');
    });

    test('школа, редкость и вид предмета очищаются от уточнений', () {
      expect(baseSchool('прорицание (ритуал)'), 'прорицание');
      expect(baseSchool('воплощение (дюнамантия: гравитургия)'), 'воплощение');
      expect(baseRarity('редкий (требуется настройка)'), 'редкий');
      expect(baseItemKind('Оружие (длинный меч), ...'), 'Оружие');
      expect(baseItemKind('Чудесный предмет'), 'Чудесный предмет');
    });

    test('тип и мировоззрение извлекаются из строки вида существа', () {
      expect(
        monsterType('Средний? Гуманоид (человек), нейтрально-злой'),
        'Гуманоид',
      );
      expect(monsterType('Средняя? Нежить'), 'Нежить');
      expect(
        monsterAlignment('Средний? Гуманоид (человек), нейтрально-злой'),
        'нейтрально-злой',
      );
      expect(monsterAlignment('Средний? Нежить'), '');
    });

    test('CR форматируется как в каталоге', () {
      expect(formatCr(0.125), '1/8');
      expect(formatCr(0.5), '1/2');
      expect(formatCr(5), '5');
    });
  });

  group('фильтр заклинаний', () {
    test('уровень и школа', () {
      const filter = SpellFilter(level: 3, school: 'воплощение');
      expect(filter.matches(_spell(level: 3)), isTrue);
      expect(filter.matches(_spell(level: 2)), isFalse);
      expect(filter.matches(_spell(level: 3, school: 'иллюзия')), isFalse);
      expect(
        filter.matches(_spell(level: 3, school: 'воплощение (ритуал)')),
        isTrue,
      );
    });

    test('концентрация, ритуал и поиск по названию', () {
      const filter = SpellFilter(concentrationOnly: true, query: 'огн');
      expect(filter.matches(_spell(concentration: true)), isTrue);
      expect(filter.matches(_spell()), isFalse);
      expect(filter.matches(_spell(concentration: true, nameRu: 'Щит')), isFalse);
      expect(
        filter.matches(_spell(concentration: true, nameEn: 'Fireball')),
        isTrue,
      );
    });

    test('apply отбирает записи', () {
      final spells = [_spell(), _spell(level: 5, nameRu: 'Цель')];
      final filtered = applySpellFilter(spells, const SpellFilter(level: 5));
      expect(filtered.length, 1);
      expect(filtered.single.nameRu, 'Цель');
    });
  });

  group('классы заклинаний', () {
    test('классы разбираются из строки каталога', () {
      expect(spellClassNames('волшебник, друидTCE'), ['Волшебник', 'Друид']);
      expect(spellClassNames('жрец (свет)'), ['Жрец']);
      expect(spellClassNames(''), isEmpty);
    });

    test('фильтр по классу наколдуна', () {
      expect(const SpellFilter(className: 'Жрец').matches(_spell()), isTrue);
      expect(const SpellFilter(className: 'Волшебник').matches(_spell()), isTrue);
      expect(const SpellFilter(className: 'Друид').matches(_spell()), isFalse);
    });

    test('сортировка по классу, внутри класса — по названию', () {
      final spells = [
        _spell(nameRu: 'Яблоко', classes: 'Жрец'),
        _spell(nameRu: 'Абрикос', classes: 'Волшебник'),
        _spell(nameRu: 'Банан', classes: 'Волшебник'),
      ];
      final sorted = sortSpells(spells, SpellSort.className);
      expect(sorted.map((spell) => spell.nameRu), ['Абрикос', 'Банан', 'Яблоко']);
    });

    test('классы собираются для фильтра', () {
      final spells = [
        _spell(classes: 'Волшебник, Жрец'),
        _spell(classes: 'Друид'),
      ];
      expect(collectSpellClasses(spells), {'Волшебник', 'Жрец', 'Друид'});
    });
  });

  group('фильтр чудовищ', () {
    test('полосы CR: нижняя граница включена, верхняя исключена', () {
      const filter = MonsterFilter(minCr: 1, maxCr: 3);
      expect(filter.matches(_monster(cr: 1)), isTrue);
      expect(filter.matches(_monster(cr: 2.9)), isTrue);
      expect(filter.matches(_monster(cr: 3)), isFalse);
      expect(filter.matches(_monster(cr: 0.5)), isFalse);
    });

    test('размер, тип, среда и источник', () {
      expect(
        const MonsterFilter(size: 'Средний').matches(_monster()),
        isTrue,
      );
      expect(
        const MonsterFilter(size: 'Средняя').matches(_monster()),
        isTrue,
      );
      expect(const MonsterFilter(type: 'Гуманоид').matches(_monster()), isTrue);
      expect(const MonsterFilter(type: 'Дракон').matches(_monster()), isFalse);
      expect(const MonsterFilter(habitat: 'лес').matches(_monster()), isTrue);
      expect(
        const MonsterFilter(habitat: 'пустыня').matches(_monster()),
        isFalse,
      );
      expect(const MonsterFilter(source: 'MM14').matches(_monster()), isTrue);
      expect(const MonsterFilter(source: 'XGE').matches(_monster()), isFalse);
    });

    test('пустая среда не проходит фильтр по среде', () {
      final monster = _monster(habitat: '');
      expect(const MonsterFilter(habitat: 'лес').matches(monster), isFalse);
    });
  });

  group('фильтр предметов', () {
    test('редкость, вид и настройка', () {
      expect(const ItemFilter(rarity: 'редкий').matches(_item()), isTrue);
      expect(const ItemFilter(kind: 'Оружие').matches(_item()), isTrue);
      expect(const ItemFilter(kind: 'Зелье').matches(_item()), isFalse);
      expect(const ItemFilter(attunementOnly: true).matches(_item()), isTrue);
      expect(
        const ItemFilter(attunementOnly: true).matches(_item(attunement: false)),
        isFalse,
      );
    });
  });

  group('фильтры черт и предысторий', () {
    test('источник черты', () {
      expect(const FeatFilter(source: 'PH14').matches(_feat()), isTrue);
      expect(const FeatFilter(source: 'XGE').matches(_feat()), isFalse);
    });

    test('поиск по предыстории', () {
      expect(
        const BackgroundFilter(query: 'авант').matches(_background()),
        isTrue,
      );
      expect(
        const BackgroundFilter(query: 'кузнец').matches(_background()),
        isFalse,
      );
    });
  });

  group('сборщики значений для фильтров', () {
    test('школы, размеры, среды и источники собираются без пустых', () {
      final spells = [
        _spell(school: 'воплощение'),
        _spell(school: 'воплощение (ритуал)'),
        _spell(school: 'иллюзия'),
      ];
      expect(collectSpellSchools(spells), {'воплощение', 'иллюзия'});

      final monsters = [
        _monster(),
        _monster(size: 'Большой?', sizeType: 'Большой? Зверь, нейтральный'),
        _monster(habitat: ''),
      ];
      expect(collectMonsterSizes(monsters), {'Средний', 'Большой'});
      expect(collectMonsterTypes(monsters), {'Гуманоид', 'Зверь'});
      expect(collectMonsterHabitats(monsters), {'лес', 'подземье'});
      expect(collectMonsterSources(monsters), {'MM14'});
    });

    test('редкость и вид предмета собираются по базовым значениям', () {
      final items = [
        _item(),
        _item(kind: 'Зелье', rarity: 'необычный'),
        _item(kind: '', rarity: ''),
      ];
      expect(collectItemRarities(items), {'редкий', 'необычный'});
      expect(collectItemKinds(items), {'Оружие', 'Зелье'});
    });
  });
}
