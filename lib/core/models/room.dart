/// Состояние комнаты (пешки, сетка, игроки) по docs/06-lobby-network.md.
/// Авторитет — сервер на устройстве мастера. Сетевая реализация — фаза 3.
library;

enum TokenKind { player, monster, npc }

class Token {
  const Token({
    required this.id,
    required this.kind,
    required this.x,
    required this.y,
    this.owner,
    this.catalogId,
    this.label = '',
    this.hp,
    this.maxHp,
    this.visible = true,
  });

  final String id;
  final TokenKind kind;
  final String? owner;
  final String? catalogId;
  final String label;
  final int x;
  final int y;
  final int? hp;
  final int? maxHp;
  final bool visible;

  Token copyWith({int? x, int? y, int? hp, bool? visible}) => Token(
        id: id,
        kind: kind,
        owner: owner,
        catalogId: catalogId,
        label: label,
        x: x ?? this.x,
        y: y ?? this.y,
        hp: hp ?? this.hp,
        maxHp: maxHp,
        visible: visible ?? this.visible,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'owner': owner,
        'catalog_id': catalogId,
        'label': label,
        'x': x,
        'y': y,
        'hp': hp,
        'max_hp': maxHp,
        'visible': visible,
      };

  factory Token.fromJson(Map<String, dynamic> json) => Token(
        id: json['id'] as String,
        kind: TokenKind.values.firstWhere((k) => k.name == json['kind'], orElse: () => TokenKind.npc),
        owner: json['owner'] as String?,
        catalogId: json['catalog_id'] as String?,
        label: json['label'] as String? ?? '',
        x: json['x'] as int,
        y: json['y'] as int,
        hp: json['hp'] as int?,
        maxHp: json['max_hp'] as int?,
        visible: json['visible'] as bool? ?? true,
      );
}

class GridSpec {
  const GridSpec({this.cellPx = 70, this.cols = 30, this.rows = 20});

  final int cellPx;
  final int cols;
  final int rows;
}

class RoomPlayer {
  const RoomPlayer({required this.id, required this.name, this.characterId, this.moveOwn = true});

  final String id;
  final String name;
  final String? characterId;

  /// Может ли двигать свою пешку (право от мастера).
  final bool moveOwn;
}

class RoomState {
  const RoomState({
    this.adventureId = '',
    this.mapId = '',
    this.grid = const GridSpec(),
    this.tokens = const [],
    this.players = const [],
    this.revealedCells = const {},
  });

  final String adventureId;
  final String mapId;
  final GridSpec grid;
  final List<Token> tokens;
  final List<RoomPlayer> players;

  /// Открытые туманом войны клетки (x, y). Скрытое = всё остальное.
  final Set<(int, int)> revealedCells;

  RoomState copyWith({List<Token>? tokens, Set<(int, int)>? revealedCells, String? mapId}) => RoomState(
        adventureId: adventureId,
        mapId: mapId ?? this.mapId,
        grid: grid,
        tokens: tokens ?? this.tokens,
        players: players,
        revealedCells: revealedCells ?? this.revealedCells,
      );
}
