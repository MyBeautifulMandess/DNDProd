/// Лог комнаты: чат, броски, системные события и скрытые броски мастера.
library;

enum LobbyLogKind { chat, roll, hiddenRoll, system }

class LobbyLogEntry {
  const LobbyLogEntry({
    required this.id,
    required this.author,
    required this.text,
    required this.kind,
    required this.at,
    this.formula,
    this.total,
  });

  final String id;
  final String author;
  final String text;
  final LobbyLogKind kind;
  final DateTime at;
  final String? formula;
  final int? total;

  static String _newId() => 'l${DateTime.now().microsecondsSinceEpoch}';

  factory LobbyLogEntry.chat({required String author, required String text}) =>
      LobbyLogEntry(
        id: _newId(),
        author: author,
        text: text,
        kind: LobbyLogKind.chat,
        at: DateTime.now(),
      );

  factory LobbyLogEntry.roll({
    required String author,
    required String formula,
    required int total,
    required String text,
    required bool hidden,
  }) =>
      LobbyLogEntry(
        id: _newId(),
        author: author,
        text: text,
        kind: hidden ? LobbyLogKind.hiddenRoll : LobbyLogKind.roll,
        at: DateTime.now(),
        formula: formula,
        total: total,
      );

  factory LobbyLogEntry.system(String text) => LobbyLogEntry(
        id: _newId(),
        author: '',
        text: text,
        kind: LobbyLogKind.system,
        at: DateTime.now(),
      );

  String get line => switch (kind) {
        LobbyLogKind.system => text,
        LobbyLogKind.hiddenRoll =>
          '$author (скрыто): $formula = $total — $text',
        LobbyLogKind.roll => '$author: $formula = $total ($text)',
        LobbyLogKind.chat => '$author: $text',
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'author': author,
        'text': text,
        'kind': kind.name,
        'at': at.millisecondsSinceEpoch,
        'formula': formula,
        'total': total,
      };

  factory LobbyLogEntry.fromJson(Map<String, dynamic> json) => LobbyLogEntry(
        id: json['id'] as String? ?? _newId(),
        author: json['author'] as String? ?? '',
        text: json['text'] as String? ?? '',
        kind: LobbyLogKind.values.firstWhere(
          (k) => k.name == json['kind'],
          orElse: () => LobbyLogKind.chat,
        ),
        at: DateTime.fromMillisecondsSinceEpoch(json['at'] as int? ?? 0),
        formula: json['formula'] as String?,
        total: json['total'] as int?,
      );
}
