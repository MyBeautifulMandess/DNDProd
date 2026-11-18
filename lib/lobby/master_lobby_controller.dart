/// Состояние комнаты у мастера: обёртка над локальным сервером для UI.
library;

import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../core/models/room.dart';
import '../lobby/lobby_log.dart';
import '../platform/files/map_file.dart';
import '../platform/network/lobby_transport.dart';
import '../platform/network/shelf_lobby_server.dart';

class MasterLobbyController extends ChangeNotifier {
  ShelfLobbyServer? _server;
  StreamSubscription<LobbyMessage>? _subscription;
  RoomState _state = const RoomState();
  final List<LobbyLogEntry> _log = [];
  String? _address;
  String? _error;
  bool _starting = false;
  bool _moveOwnAllowed = true;

  RoomState get state => _state;
  List<LobbyLogEntry> get log => List.unmodifiable(_log);
  String? get address => _address;
  int? get port => _server?.boundPort;
  String? get error => _error;
  bool get isRunning => _server != null;
  bool get isStarting => _starting;
  bool get moveOwnAllowed => _moveOwnAllowed;

  Future<void> start({int port = defaultLobbyPort}) async {
    if (_server != null || _starting) return;
    _starting = true;
    notifyListeners();
    final server = ShelfLobbyServer(port: port);
    try {
      await server.start();
      _subscription = server.messages.listen(_onMessage);
      _server = server;
      _address = server.address;
      _state = server.state;
      _error = null;
    } catch (error) {
      _error = 'Не удалось запустить комнату: $error';
    }
    _starting = false;
    notifyListeners();
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    await _subscription?.cancel();
    _subscription = null;
    await server?.stop();
    _address = null;
    _state = const RoomState();
    _moveOwnAllowed = true;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void moveToken(String tokenId, int x, int y) =>
      _server?.moveToken(tokenId, x, y);

  void addToken(String label) {
    if (label.trim().isEmpty) return;
    _server?.addToken(label: label.trim());
  }

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

  void switchMap(String mapId) => _server?.switchMap(mapId);

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
