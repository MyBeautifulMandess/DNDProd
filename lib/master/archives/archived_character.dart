/// Персонаж в архиве мастера: снимок игрока или созданный мастером NPC.
/// Игровые значения (уровень/класс) — только то, что задал мастер или прислал
/// клиент; конструктор не генерирует характеристики.
library;

class ArchivedCharacter {
  static const originPlayer = 'player';
  static const originNpc = 'npc';

  ArchivedCharacter({
    required this.id,
    required this.characterName,
    required this.playerName,
    required this.level,
    this.classNames = '',
    required this.snapshot,
    this.notes = '',
    this.archivedAtMs = 0,
    this.origin = originPlayer,
  });

  String id;
  String characterName;
  String playerName;
  int level;
  String classNames;

  /// Полный JSON персонажа на момент подключения (Character.toJson()).
  final Map<String, dynamic> snapshot;
  String notes;
  int archivedAtMs;
  String origin;

  bool get isNpc => origin == originNpc;

  Map<String, dynamic> toJson() => {
        'schema_version': 1,
        'id': id,
        'character_name': characterName,
        'player_name': playerName,
        'level': level,
        'class_names': classNames,
        'notes': notes,
        'archived_at_ms': archivedAtMs,
        'origin': origin,
        'snapshot': snapshot,
      };

  factory ArchivedCharacter.fromJson(Map<String, dynamic> json) =>
      ArchivedCharacter(
        id: json['id'] as String? ?? '',
        characterName: json['character_name'] as String? ?? '',
        playerName: json['player_name'] as String? ?? '',
        level: json['level'] as int? ?? 1,
        classNames: json['class_names'] as String? ?? '',
        notes: json['notes'] as String? ?? '',
        archivedAtMs: json['archived_at_ms'] as int? ?? 0,
        origin: json['origin'] as String? ?? originPlayer,
        snapshot:
            (json['snapshot'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
}
