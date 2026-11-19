/// Приключение мастера: карты с подготовленным состоянием, лор и ПМ.
/// Чистая модель без Flutter и платформы (docs/05-master-app.md).
library;

import 'room.dart';

/// Страница заметок по лору: NPC, фракции, сюжетные ветки.
class LorePage {
  LorePage({
    required this.id,
    required this.title,
    required this.text,
  });

  String id;
  String title;
  String text;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'text': text,
      };

  factory LorePage.fromJson(Map<String, dynamic> json) => LorePage(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        text: json['text'] as String? ?? '',
      );
}

/// Одна заготовленная карта приключения.
///
/// Состояние (пешки, туман, штрихи) хранится отдельно для каждой карты, чтобы
/// переключение карт в комнате не смешивало расстановки (см. фазу 5.2).
class AdventureMap {
  AdventureMap({
    required this.id,
    required this.name,
    this.imagePath = '',
    GridSpec? grid,
    List<Token>? tokens,
    Set<(int, int)>? revealedCells,
    List<DrawStroke>? strokes,
  })  : grid = grid ?? const GridSpec(),
        tokens = tokens ?? <Token>[],
        revealedCells = revealedCells ?? <(int, int)>{},
        strokes = strokes ?? <DrawStroke>[];

  String id;
  String name;

  /// Относительный путь к файлу в хранилище приложения; пустой = стандартный фон.
  String imagePath;
  GridSpec grid;
  List<Token> tokens;
  Set<(int, int)> revealedCells;
  List<DrawStroke> strokes;

  /// Снапшот для запуска комнаты. Сервер заменяет `mapId` на URL своей раздачи,
  /// если у карты есть импортированный фон.
  RoomState roomState(String adventureId) => RoomState(
        adventureId: adventureId,
        mapId: imagePath.isEmpty ? 'asset:$defaultMapAsset' : 'map:$id',
        grid: grid,
        tokens: List<Token>.of(tokens),
        revealedCells: Set<(int, int)>.of(revealedCells),
        strokes: List<DrawStroke>.of(strokes),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'image_path': imagePath,
        'grid': grid.toJson(),
        'tokens': [for (final token in tokens) token.toJson()],
        'fog': {
          'revealed': [
            for (final cell in revealedCells) [cell.$1, cell.$2]
          ],
        },
        'strokes': [for (final stroke in strokes) stroke.toJson()],
      };

  factory AdventureMap.fromJson(Map<String, dynamic> json) {
    final revealed = <(int, int)>{};
    final fog = json['fog'];
    for (final cell in ((fog is Map ? fog['revealed'] : null) as List?) ??
        const []) {
      if (cell is List && cell.length == 2) {
        revealed.add((cell[0] as int, cell[1] as int));
      }
    }
    return AdventureMap(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      imagePath: json['image_path'] as String? ?? '',
      grid: json['grid'] is Map
          ? GridSpec.fromJson((json['grid'] as Map).cast<String, dynamic>())
          : const GridSpec(),
      tokens: [
        for (final token in (json['tokens'] as List?) ?? const [])
          Token.fromJson((token as Map).cast<String, dynamic>()),
      ],
      revealedCells: revealed,
      strokes: [
        for (final stroke in (json['strokes'] as List?) ?? const [])
          DrawStroke.fromJson((stroke as Map).cast<String, dynamic>()),
      ],
    );
  }
}

/// Контейнер подготовки сессии мастера.
class Adventure {
  Adventure({
    required this.id,
    required this.title,
    this.description = '',
    this.privateNotes = '',
    this.moveOwnAllowed = true,
    List<AdventureMap>? maps,
    List<LorePage>? lore,
    this.startMapId = '',
    this.updatedAtMs = 0,
  })  : maps = maps ?? <AdventureMap>[],
        lore = lore ?? <LorePage>[];

  String id;
  String title;
  String description;
  String privateNotes;

  /// Настройка комнаты: могут ли игроки двигать свои пешки.
  bool moveOwnAllowed;

  List<AdventureMap> maps;
  List<LorePage> lore;

  /// Карта, с которой начинается комната.
  String startMapId;

  int updatedAtMs;

  AdventureMap? get startMap {
    if (maps.isEmpty) return null;
    return maps.firstWhere(
      (map) => map.id == startMapId,
      orElse: () => maps.first,
    );
  }

  Map<String, dynamic> toJson() => {
        'schema_version': 1,
        'id': id,
        'title': title,
        'description': description,
        'private_notes': privateNotes,
        'move_own_allowed': moveOwnAllowed,
        'start_map_id': startMapId,
        'updated_at_ms': updatedAtMs,
        'maps': [for (final map in maps) map.toJson()],
        'lore': [for (final page in lore) page.toJson()],
      };

  factory Adventure.fromJson(Map<String, dynamic> json) => Adventure(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        privateNotes: json['private_notes'] as String? ?? '',
        moveOwnAllowed: json['move_own_allowed'] as bool? ?? true,
        startMapId: json['start_map_id'] as String? ?? '',
        updatedAtMs: json['updated_at_ms'] as int? ?? 0,
        maps: [
          for (final map in (json['maps'] as List?) ?? const [])
            AdventureMap.fromJson((map as Map).cast<String, dynamic>()),
        ],
        lore: [
          for (final page in (json['lore'] as List?) ?? const [])
            LorePage.fromJson((page as Map).cast<String, dynamic>()),
        ],
      );
}
