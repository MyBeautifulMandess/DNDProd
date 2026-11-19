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
    this.size = 1,
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

  /// Сторона пешки в клетках (1 — средняя, 2 — большая и т.д.).
  final int size;

  Token copyWith({int? x, int? y, int? hp, int? maxHp, bool? visible, int? size}) =>
      Token(
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
        size: size ?? this.size,
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
        'size': size,
      };

  factory Token.fromJson(Map<String, dynamic> json) {
    final rawSize = json['size'] as int?;
    return Token(
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
      size: rawSize == null ? 1 : rawSize.clamp(1, 4).toInt(),
    );
  }
}

/// Штрих рисования на поле: цвет по автору, клетки сохраняются в снапшоте.
class DrawStroke {
  const DrawStroke({
    required this.id,
    required this.author,
    required this.color,
    required this.cells,
  });

  final String id;
  final String author;
  final int color;
  final List<(int, int)> cells;

  Map<String, dynamic> toJson() => {
        'id': id,
        'author': author,
        'color': color,
        'cells': [
          for (final cell in cells) [cell.$1, cell.$2]
        ],
      };

  factory DrawStroke.fromJson(Map<String, dynamic> json) {
    final cells = <(int, int)>{};
    for (final cell in (json['cells'] as List?) ?? const []) {
      if (cell is List && cell.length == 2) {
        cells.add((cell[0] as int, cell[1] as int));
      }
    }
    return DrawStroke(
      id: json['id'] as String? ?? '',
      author: json['author'] as String? ?? '',
      color: json['color'] as int? ?? 0xFFC9A227,
      cells: cells.toList(),
    );
  }
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
    this.mapKey = '',
    this.grid = const GridSpec(),
    this.tokens = const [],
    this.players = const [],
    this.revealedCells = const {},
    this.strokes = const [],
  });

  final String adventureId;

  /// Логический ключ карты внутри приключения (для переключения на лету).
  final String mapKey;

  /// Адрес фона: `asset:...` или HTTP-URL раздачи сервера.
  final String mapId;
  final GridSpec grid;
  final List<Token> tokens;
  final List<RoomPlayer> players;

  /// Открытые туманом войны клетки (x, y). Скрытое = всё остальное.
  final Set<(int, int)> revealedCells;

  /// Штрихи рисования видны всем участникам комнаты.
  final List<DrawStroke> strokes;

  RoomState copyWith({
    List<Token>? tokens,
    Set<(int, int)>? revealedCells,
    String? mapId,
    String? mapKey,
    List<RoomPlayer>? players,
    GridSpec? grid,
    List<DrawStroke>? strokes,
  }) =>
      RoomState(
        adventureId: adventureId,
        mapId: mapId ?? this.mapId,
        mapKey: mapKey ?? this.mapKey,
        grid: grid ?? this.grid,
        tokens: tokens ?? this.tokens,
        players: players ?? this.players,
        revealedCells: revealedCells ?? this.revealedCells,
        strokes: strokes ?? this.strokes,
      );

  Map<String, dynamic> toJson() => {
        'protocol': 1,
        'room': {
          'adventure_id': adventureId,
          'map_id': mapId,
          'map_key': mapKey,
        },
        'map': {'grid': grid.toJson()},
        'tokens': [for (final token in tokens) token.toJson()],
        'fog': {
          'revealed': [
            for (final cell in revealedCells) [cell.$1, cell.$2]
          ],
          'grid': true,
        },
        'players': [for (final player in players) player.toJson()],
        'draw': {
          'strokes': [for (final stroke in strokes) stroke.toJson()],
        },
      };

  factory RoomState.fromJson(Map<String, dynamic> json) {
    final room = (json['room'] as Map?) ?? const {};
    final map = (json['map'] as Map?) ?? const {};
    final fog = (json['fog'] as Map?) ?? const {};
    final draw = (json['draw'] as Map?) ?? const {};
    final revealed = <(int, int)>{};
    for (final cell in (fog['revealed'] as List?) ?? const []) {
      if (cell is List && cell.length == 2) {
        revealed.add((cell[0] as int, cell[1] as int));
      }
    }
    return RoomState(
      adventureId: room['adventure_id'] as String? ?? '',
      mapKey: room['map_key'] as String? ?? '',
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
      strokes: [
        for (final stroke in (draw['strokes'] as List?) ?? const [])
          DrawStroke.fromJson((stroke as Map).cast<String, dynamic>()),
      ],
    );
  }
}
