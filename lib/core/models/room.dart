/// Состояние комнаты (пешки, сетка, игроки) по docs/06-lobby-network.md.
/// Авторитет — сервер на устройстве мастера. Сериализация — снапшот `state`.
library;

/// Фон по умолчанию: генерируется из `08-assets.md`, лежит в `assets/maps/`.
const defaultMapAsset = 'assets/maps/grid_basic.jpg';

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

  Token copyWith({int? x, int? y, int? hp, int? maxHp, bool? visible}) => Token(
        id: id,
        kind: kind,
        owner: owner,
        catalogId: catalogId,
        label: label,
        x: x ?? this.x,
        y: y ?? this.y,
        hp: hp ?? this.hp,
        maxHp: maxHp ?? this.maxHp,
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
        kind: TokenKind.values.firstWhere((k) => k.name == json['kind'],
            orElse: () => TokenKind.npc),
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

  Map<String, dynamic> toJson() =>
      {'cell_px': cellPx, 'cols': cols, 'rows': rows};

  factory GridSpec.fromJson(Map<String, dynamic> json) => GridSpec(
        cellPx: json['cell_px'] as int? ?? 70,
        cols: json['cols'] as int? ?? 30,
        rows: json['rows'] as int? ?? 20,
      );
}

class RoomPlayer {
  const RoomPlayer(
      {required this.id,
      required this.name,
      this.characterId,
      this.moveOwn = true});

  final String id;
  final String name;
  final String? characterId;

  /// Может ли двигать свою пешку (право от мастера).
  final bool moveOwn;

  RoomPlayer copyWith({bool? moveOwn}) => RoomPlayer(
        id: id,
        name: name,
        characterId: characterId,
        moveOwn: moveOwn ?? this.moveOwn,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'character_id': characterId,
        'rights': {'move_own': moveOwn},
      };

  factory RoomPlayer.fromJson(Map<String, dynamic> json) {
    final rights = json['rights'];
    return RoomPlayer(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      characterId: json['character_id'] as String?,
      moveOwn: rights is Map ? rights['move_own'] as bool? ?? true : true,
    );
  }
}

class RoomState {
  const RoomState({
    this.adventureId = '',
    this.mapId = defaultMapAsset,
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

  RoomState copyWith({
    List<Token>? tokens,
    Set<(int, int)>? revealedCells,
    String? mapId,
    List<RoomPlayer>? players,
    GridSpec? grid,
  }) =>
      RoomState(
        adventureId: adventureId,
        mapId: mapId ?? this.mapId,
        grid: grid ?? this.grid,
        tokens: tokens ?? this.tokens,
        players: players ?? this.players,
        revealedCells: revealedCells ?? this.revealedCells,
      );

  Map<String, dynamic> toJson() => {
        'protocol': 1,
        'room': {'adventure_id': adventureId, 'map_id': mapId},
        'map': {'grid': grid.toJson()},
        'tokens': [for (final token in tokens) token.toJson()],
        'fog': {
          'revealed': [
            for (final cell in revealedCells) [cell.$1, cell.$2]
          ],
          'grid': true,
        },
        'players': [for (final player in players) player.toJson()],
      };

  factory RoomState.fromJson(Map<String, dynamic> json) {
    final room = (json['room'] as Map?) ?? const {};
    final map = (json['map'] as Map?) ?? const {};
    final fog = (json['fog'] as Map?) ?? const {};
    final revealed = <(int, int)>{};
    for (final cell in (fog['revealed'] as List?) ?? const []) {
      if (cell is List && cell.length == 2) {
        revealed.add((cell[0] as int, cell[1] as int));
      }
    }
    return RoomState(
      adventureId: room['adventure_id'] as String? ?? '',
      mapId: room['map_id'] as String? ?? defaultMapAsset,
      grid: map['grid'] is Map
          ? GridSpec.fromJson((map['grid'] as Map).cast<String, dynamic>())
          : const GridSpec(),
      tokens: [
        for (final token in (json['tokens'] as List?) ?? const [])
          Token.fromJson((token as Map).cast<String, dynamic>()),
      ],
      players: [
        for (final player in (json['players'] as List?) ?? const [])
          RoomPlayer.fromJson((player as Map).cast<String, dynamic>()),
      ],
      revealedCells: revealed,
    );
  }
}
