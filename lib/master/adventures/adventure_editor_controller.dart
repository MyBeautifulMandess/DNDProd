/// Редактор приключения мастера: состояние экрана отдельно от UI.
library;

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../core/field_grid.dart';
import '../../core/models/adventure.dart';
import '../../core/models/room.dart';
import '../../platform/files/file_store.dart';
import '../../platform/files/map_file.dart';
import 'adventure_repository.dart';

/// Параметры существа из справочника для пешки-врага.
class MonsterTokenSpec {
  const MonsterTokenSpec({
    required this.label,
    required this.catalogId,
    required this.hp,
    required this.size,
  });

  final String label;
  final String catalogId;
  final int hp;
  final int size;
}

class AdventureEditorController extends ChangeNotifier {
  AdventureEditorController(
    this._repository,
    this._store, {
    String Function()? idGenerator,
  }) : _idGenerator = idGenerator ?? _defaultId;

  final AdventureRepository _repository;
  final FileStore _store;
  final String Function() _idGenerator;

  Adventure? _adventure;
  String? _selectedMapId;
  String? _error;

  Adventure? get adventure => _adventure;
  String? get selectedMapId => _selectedMapId;
  String? get error => _error;

  AdventureMap? get selectedMap {
    final adventure = _adventure;
    if (adventure == null || adventure.maps.isEmpty) return null;
    return adventure.maps.firstWhere(
      (map) => map.id == _selectedMapId,
      orElse: () => adventure.maps.first,
    );
  }

  static String _defaultId() =>
      'e${DateTime.now().microsecondsSinceEpoch}${Random().nextInt(999999).toString().padLeft(6, '0')}';

  Future<void> createNew({String title = 'Новое приключение'}) async {
    final adventure = Adventure(id: _idGenerator(), title: title);
    await _repository.save(adventure);
    _adventure = adventure;
    _selectedMapId = null;
    _error = null;
    notifyListeners();
  }

  Future<void> load(String id) async {
    _adventure = await _repository.byId(id);
    _selectedMapId = _adventure?.startMapId;
    _error = null;
    notifyListeners();
  }

  Future<bool> save() async {
    final adventure = _adventure;
    if (adventure == null) return false;
    if (adventure.title.trim().isEmpty) adventure.title = 'Без названия';
    try {
      await _repository.save(adventure);
      _error = null;
    } catch (error) {
      _error = 'Не удалось сохранить: $error';
    }
    notifyListeners();
    return _error == null;
  }

  void setTitle(String value) {
    _adventure?.title = value;
    notifyListeners();
  }

  void setDescription(String value) {
    _adventure?.description = value;
    notifyListeners();
  }

  void setPrivateNotes(String value) {
    _adventure?.privateNotes = value;
    notifyListeners();
  }

  void setMoveOwnAllowed(bool value) {
    _adventure?.moveOwnAllowed = value;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // --- Карты ---------------------------------------------------------------

  void selectMap(String id) {
    _selectedMapId = id;
    notifyListeners();
  }

  void addMap() {
    final adventure = _adventure;
    if (adventure == null) return;
    final map = AdventureMap(
      id: _idGenerator(),
      name: 'Карта ${adventure.maps.length + 1}',
    );
    adventure.maps.add(map);
    adventure.startMapId = map.id;
    _selectedMapId = map.id;
    notifyListeners();
  }

  void renameMap(String id, String name) {
    final map = _map(id);
    if (map == null) return;
    map.name = name;
    notifyListeners();
  }

  void setStartMap(String id) {
    final adventure = _adventure;
    if (adventure == null || !adventure.maps.any((map) => map.id == id)) return;
    adventure.startMapId = id;
    notifyListeners();
  }

  void removeMap(String id) {
    final adventure = _adventure;
    if (adventure == null) return;
    adventure.maps.removeWhere((map) => map.id == id);
    if (_selectedMapId == id) {
      _selectedMapId = adventure.maps.firstOrNull?.id;
    }
    if (adventure.startMapId == id) {
      adventure.startMapId = adventure.maps.firstOrNull?.id ?? '';
    }
    notifyListeners();
  }

  Future<bool> importMapImage(String sourcePath, Uint8List bytes) async {
    final adventure = _adventure;
    final map = selectedMap;
    if (adventure == null || map == null) return false;
    try {
      map.imagePath = await _repository.importMapImage(
        adventure.id,
        map.id,
        sourcePath,
        bytes,
      );
      _error = null;
    } catch (error) {
      _error = 'Не удалось загрузить карту: $error';
    }
    notifyListeners();
    return _error == null;
  }

  void useDefaultMap() {
    final map = selectedMap;
    if (map == null) return;
    map.imagePath = '';
    notifyListeners();
  }

  void setGrid({int? cols, int? rows, int? cellPx}) {
    final map = selectedMap;
    if (map == null) return;
    map.grid = GridSpec(
      cols: (cols ?? map.grid.cols).clamp(5, 100).toInt(),
      rows: (rows ?? map.grid.rows).clamp(5, 100).toInt(),
      cellPx: (cellPx ?? map.grid.cellPx).clamp(30, 150).toInt(),
    );
    notifyListeners();
  }

  // --- Пешки и состояние карты ---------------------------------------------

  void addMonsterToken(MonsterTokenSpec spec, {int x = 2, int y = 2}) {
    _addToken(
      Token(
        id: _idGenerator(),
        kind: TokenKind.monster,
        catalogId: spec.catalogId,
        label: spec.label,
        x: x,
        y: y,
        hp: spec.hp,
        maxHp: spec.hp,
        size: spec.size.clamp(1, 4).toInt(),
      ),
    );
  }

  void addNpcToken(String label) {
    if (label.trim().isEmpty) return;
    _addToken(Token(
      id: _idGenerator(),
      kind: TokenKind.npc,
      label: label.trim(),
      x: 2,
      y: 2,
    ));
  }

  void _addToken(Token token) {
    final map = selectedMap;
    if (map == null) return;
    final position = clampCell((token.x, token.y), map.grid, size: token.size);
    map.tokens.add(Token(
      id: token.id,
      kind: token.kind,
      catalogId: token.catalogId,
      label: token.label,
      x: position.$1,
      y: position.$2,
      hp: token.hp,
      maxHp: token.maxHp,
      size: token.size,
    ));
    notifyListeners();
  }

  void updateToken({
    required String id,
    int? hp,
    int? maxHp,
    int? size,
    int? x,
    int? y,
  }) {
    final map = selectedMap;
    if (map == null) return;
    final index = map.tokens.indexWhere((token) => token.id == id);
    if (index < 0) return;
    final token = map.tokens[index];
    final nextSize = (size ?? token.size).clamp(1, 4).toInt();
    final position = clampCell(
      (x ?? token.x, y ?? token.y),
      map.grid,
      size: nextSize,
    );
    map.tokens[index] = Token(
      id: token.id,
      kind: token.kind,
      catalogId: token.catalogId,
      label: token.label,
      x: position.$1,
      y: position.$2,
      hp: hp ?? token.hp,
      maxHp: maxHp ?? token.maxHp,
      visible: token.visible,
      size: nextSize,
    );
    notifyListeners();
  }

  void removeToken(String id) {
    final map = selectedMap;
    if (map == null) return;
    map.tokens.removeWhere((token) => token.id == id);
    notifyListeners();
  }

  void drawStroke(Iterable<(int, int)> cells) {
    final map = selectedMap;
    if (map == null) return;
    map.strokes.add(DrawStroke(
      id: _idGenerator(),
      author: 'Мастер',
      color: 0xFFC9A227,
      cells: List<(int, int)>.of(cells),
    ));
    notifyListeners();
  }

  void toggleFog(Iterable<(int, int)> cells, {required bool reveal}) {
    final map = selectedMap;
    if (map == null) return;
    for (final cell in cells) {
      if (reveal) {
        map.revealedCells.add(cell);
      } else {
        map.revealedCells.remove(cell);
      }
    }
    notifyListeners();
  }

  Future<ImageProvider> mapImage() =>
      localMapImage(_store, selectedMap?.imagePath ?? '');

  /// Переносит снапшоты остановленной комнаты обратно в приключение.
  /// Пешки игроков не сохраняются: они создаются заново при подключении.
  void applySessionStates(Map<String, RoomState> states) {
    final adventure = _adventure;
    if (adventure == null) return;
    for (final map in adventure.maps) {
      final state = states[map.id];
      if (state == null) continue;
      map.grid = state.grid;
      map.tokens = [
        for (final token in state.tokens)
          if (token.kind != TokenKind.player) token,
      ];
      map.revealedCells = Set<(int, int)>.of(state.revealedCells);
      map.strokes = List<DrawStroke>.of(state.strokes);
    }
    notifyListeners();
  }

  bool hasSessionStates(Map<String, RoomState> states) =>
      adventure?.maps.any((map) => states.containsKey(map.id)) ?? false;

  // --- Лор и ПМ -------------------------------------------------------------

  void addLorePage() {
    final adventure = _adventure;
    if (adventure == null) return;
    adventure.lore.add(LorePage(
      id: _idGenerator(),
      title: 'Новая страница',
      text: '',
    ));
    notifyListeners();
  }

  void updateLorePage(String id, {String? title, String? text}) {
    final adventure = _adventure;
    if (adventure == null) return;
    final index = adventure.lore.indexWhere((page) => page.id == id);
    if (index < 0) return;
    final page = adventure.lore[index];
    if (title != null) page.title = title;
    if (text != null) page.text = text;
    notifyListeners();
  }

  void removeLorePage(String id) {
    _adventure?.lore.removeWhere((page) => page.id == id);
    notifyListeners();
  }

  AdventureMap? _map(String id) {
    final maps = _adventure?.maps;
    if (maps == null) return null;
    final index = maps.indexWhere((map) => map.id == id);
    return index < 0 ? null : maps[index];
  }
}
