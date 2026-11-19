/// Снимок персонажа игрока, подключившегося к комнате мастера.
/// Только чтение + заметки мастера (docs/05-master-app.md, раздел 6).
library;

class ArchivedCharacter {
  ArchivedCharacter({
    required this.id,
    required this.characterName,
    required this.playerName,
    required this.level,
    this.classNames = '',
    required this.snapshot,
    this.notes = '',
    this.archivedAtMs = 0,
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

  Map<String, dynamic> toJson() => {
        'schema_version': 1,
        'id': id,
        'character_name': characterName,
        'player_name': playerName,
        'level': level,
        'class_names': classNames,
        'notes': notes,
        'archived_at_ms': archivedAtMs,
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
        snapshot:
            (json['snapshot'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
}
