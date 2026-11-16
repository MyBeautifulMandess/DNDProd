import '../rules/ability.dart';

/// Персонаж игрока по docs/01-architecture.md (раздел 5) и docs/03-character-builder.md.
/// Модель допускает мультиклассирование (несколько классов), хотя на старте — один класс.
library;

class Character {
  Character({
    required this.id,
    required this.name,
    required this.level,
    this.raceId,
    this.subraceId,
    this.backgroundId,
    this.avatarPath,
    this.notes = '',
    Map<Ability, int>? abilityScores,
    Set<Skill>? skillProficiencies,
    Set<Ability>? saveProficiencies,
    this.classEntries = const [],
    this.currentHp = 1,
    this.maxHp = 1,
    this.tempHp = 0,
  })  : abilityScores = abilityScores ?? {for (final a in Ability.values) a: 10},
        skillProficiencies = skillProficiencies ?? {},
        saveProficiencies = saveProficiencies ?? {};

  static const schemaVersion = 1;

  final String id;
  String name;
  int level;
  String? raceId;
  String? subraceId;
  String? backgroundId;
  String? avatarPath;
  String notes;

  /// Базовые значения характеристик (без временных бонусов).
  final Map<Ability, int> abilityScores;
  final Set<Skill> skillProficiencies;
  final Set<Ability> saveProficiencies;

  /// Классы персонажа (мультикласс — список из > 1 записи).
  List<ClassEntry> classEntries;

  int currentHp;
  int maxHp;
  int tempHp;

  Map<String, dynamic> toJson() => {
        'schema_version': schemaVersion,
        'id': id,
        'name': name,
        'level': level,
        'race_id': raceId,
        'subrace_id': subraceId,
        'background_id': backgroundId,
        'avatar_path': avatarPath,
        'notes': notes,
        'ability_scores': {for (final e in abilityScores.entries) e.key.id: e.value},
        'skill_proficiencies': skillProficiencies.map((s) => s.id).toList(),
        'save_proficiencies': saveProficiencies.map((a) => a.id).toList(),
        'classes': classEntries.map((c) => c.toJson()).toList(),
        'current_hp': currentHp,
        'max_hp': maxHp,
        'temp_hp': tempHp,
      };

  factory Character.fromJson(Map<String, dynamic> json) => Character(
        id: json['id'] as String,
        name: json['name'] as String,
        level: json['level'] as int,
        raceId: json['race_id'] as String?,
        subraceId: json['subrace_id'] as String?,
        backgroundId: json['background_id'] as String?,
        avatarPath: json['avatar_path'] as String?,
        notes: json['notes'] as String? ?? '',
        abilityScores: {
          for (final e in (json['ability_scores'] as Map<String, dynamic>).entries)
            Ability.byId(e.key): e.value as int,
        },
        skillProficiencies: (json['skill_proficiencies'] as List).map((s) => Skill.byId(s as String)).toSet(),
        saveProficiencies: (json['save_proficiencies'] as List).map((a) => Ability.byId(a as String)).toSet(),
        classEntries: (json['classes'] as List).map((c) => ClassEntry.fromJson(c as Map<String, dynamic>)).toList(),
        currentHp: json['current_hp'] as int,
        maxHp: json['max_hp'] as int,
        tempHp: json['temp_hp'] as int? ?? 0,
      );
}

/// Один класс персонажа (для мультикласса — их может быть несколько).
class ClassEntry {
  ClassEntry({required this.classId, required this.level, this.subclassId});

  final String classId;
  int level;
  String? subclassId;

  Map<String, dynamic> toJson() => {
        'class_id': classId,
        'level': level,
        'subclass_id': subclassId,
      };

  factory ClassEntry.fromJson(Map<String, dynamic> json) => ClassEntry(
        classId: json['class_id'] as String,
        level: json['level'] as int,
        subclassId: json['subclass_id'] as String?,
      );
}
