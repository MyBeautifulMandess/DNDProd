/// Состояние комнаты у мастера: обёртка над локальным сервером для UI.
library;

import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../core/models/room.dart';
import '../lobby/lobby_log.dart';
import '../lobby/lobby_map.dart';
import '../platform/files/map_file.dart';
import '../platform/network/lobby_transport.dart';
import '../platform/network/shelf_lobby_server.dart';

class MasterLobbyController extends ChangeNotifier {
  MasterLobbyController({
    void Function(Map<String, dynamic> character, String playerName)?
        onCharacterConnected,
  }) : _onCharacterConnected = onCharacterConnected;

  final void Function(Map<String, dynamic> character, String playerName)?
      _onCharacterConnected;
  ShelfLobbyServer? _server;
  StreamSubscription<LobbyMessage>? _subscription;
  RoomState _state = const RoomState();
  final List<LobbyLogEntry> _log = [];
  String? _address;
  String? _error;
  bool _starting = false;
  bool _moveOwnAllowed = true;
  List<({String key, String name})> _mapChoices = [];
  Map<String, RoomState> _lastMapStates = {};

  RoomState get state => _state;
  List<LobbyLogEntry> get log => List.unmodifiable(_log);
  String? get address => _address;
  int? get port => _server?.boundPort;
  String? get error => _error;
  bool get isRunning => _server != null;
  bool get isStarting => _starting;
  bool get moveOwnAllowed => _moveOwnAllowed;
  List<({String key, String name})> get mapChoices =>
      List.unmodifiable(_mapChoices);

  /// Состояния карт после остановки комнаты — для возврата в приключение.
  Map<String, RoomState> get lastMapStates =>
      Map.unmodifiable(_lastMapStates);

  void clearSessionStates() {
    _lastMapStates = {};
    notifyListeners();
  }

  /// `initialState` и `mapBytes` приходят из подготовленного приключения.
  Future<void> start({
    int port = defaultLobbyPort,
    RoomState? initialState,
    Uint8List? mapBytes,
    String mapContentType = 'image/png',
    bool moveOwnAllowed = true,
    List<LobbyMap>? maps,
    String? initialMapKey,
  }) async {
    if (_server != null || _starting) return;
    _starting = true;
    notifyListeners();
    final server = ShelfLobbyServer(
      port: port,
      initialState: initialState,
      mapBytes: mapBytes,
      mapContentType: mapContentType,
      moveOwnAllowed: moveOwnAllowed,
      maps: maps,
      initialMapKey: initialMapKey,
    );
    try {
      await server.start();
      _subscription = server.messages.listen(_onMessage);
      _server = server;
      _address = server.address;
      _state = server.state;
      _moveOwnAllowed = server.moveOwnAllowed;
      _mapChoices = server.mapChoices;
      _lastMapStates = {};
      _error = null;
    } catch (error) {
      _error = 'Не удалось запустить комнату: $error';
    }
    _starting = false;
    notifyListeners();
  }

  Future<void> stop() async {
    final server = _server;
    _lastMapStates = server?.collectMapStates() ?? {};
    _server = null;
    await _subscription?.cancel();
    _subscription = null;
    await server?.stop();
    _address = null;
    _state = const RoomState();
    _moveOwnAllowed = true;
    _mapChoices = [];
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void moveToken(String tokenId, int x, int y) =>
      _server?.moveToken(tokenId, x, y);

  void addToken(
    String label, {
    TokenKind kind = TokenKind.npc,
    int size = 1,
    int? hp,
  }) {
    if (label.trim().isEmpty) return;
    _server?.addToken(
      label: label.trim(),
      kind: kind,
      size: size,
      hp: hp,
      maxHp: hp,
    );
  }

  void removeToken(String tokenId) => _server?.removeToken(tokenId);

  void resizeToken(String tokenId, int size) =>
      _server?.resizeToken(tokenId, size);

  void drawStroke(Iterable<(int, int)> cells) => _server?.draw(cells);

  void sendChat(String text) {
    if (text.trim().isEmpty) return;
    _server?.sendChat(text.trim());
  }

  void requestRoll(String formula, {bool hidden = false}) =>
      _server?.requestRoll(formula, hidden: hidden);

  void updateHp(String tokenId, int hp) => _server?.updateHp(tokenId, hp);

  void setMoveOwnAllowed(bool allowed) {
    _moveOwnAllowed = allowed;
    _server?.setMoveOwnAllowed(allowed);
    notifyListeners();
  }

  void toggleFog(Iterable<(int, int)> cells, {required bool reveal}) =>
      _server?.setFog(cells, reveal: reveal);

  void switchMap(String mapKey) => _server?.switchMap(mapKey);

  void showImageBytes(Uint8List bytes, {String contentType = 'image/png'}) =>
      _server?.showImageBytes(bytes, contentType: contentType);

  void hideImage() => _server?.hideImage();

  /// Фон карты выбирает мастер; сервер раздаёт файл игрокам по HTTP.
  Future<bool> importMap() async {
    final server = _server;
    if (server == null) return false;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      final path = result?.files.singleOrNull?.path;
      if (path == null) return false;
      final bytes = await readMapBytes(path);
      server.setMapImage(bytes, contentType: mapContentType(path));
      return true;
    } catch (error) {
      _error = 'Не удалось загрузить карту: $error';
      notifyListeners();
      return false;
    }
  }

  void useDefaultMap() => _server?.useAssetMap();

  void _onMessage(LobbyMessage message) {
    switch (message.type) {
      case LobbyMessageType.state:
        final payload = message.payload['state'];
        if (payload is Map) {
          _state = RoomState.fromJson(payload.cast<String, dynamic>());
          if (_state.players.isNotEmpty) {
            _moveOwnAllowed = _state.players.first.moveOwn;
          }
        }
        break;
      case LobbyMessageType.characterSnapshot:
        final character = message.payload['character'];
        if (character is Map) {
          _onCharacterConnected?.call(
            character.cast<String, dynamic>(),
            message.payload['player_name'] as String? ?? '',
          );
        }
        break;
      case LobbyMessageType.chat:
      case LobbyMessageType.roll:
        final entry = message.payload['entry'];
        if (entry is Map) {
          _addLog(LobbyLogEntry.fromJson(entry.cast<String, dynamic>()));
        }
        break;
      case LobbyMessageType.error:
        _error = message.payload['message'] as String?;
        break;
      default:
        break;
    }
    notifyListeners();
  }

  void _addLog(LobbyLogEntry entry) {
    _log.add(entry);
    if (_log.length > 200) _log.removeAt(0);
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    unawaited(_server?.stop());
    _subscription = null;
    _server = null;
    super.dispose();
  }
}
