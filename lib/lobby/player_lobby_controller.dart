/// Состояние комнаты у игрока: подключение, снапшот, чат и броски.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/models/room.dart';
import '../lobby/lobby_log.dart';
import '../platform/network/channel_lobby_client.dart';
import '../platform/network/lobby_transport.dart';

class PlayerLobbyController extends ChangeNotifier {
  PlayerLobbyController({ChannelLobbyClient? client})
      : _client = client ?? ChannelLobbyClient();

  final ChannelLobbyClient _client;
  StreamSubscription<LobbyMessage>? _subscription;
  RoomState? _state;
  final List<LobbyLogEntry> _log = [];
  String? _playerId;
  String? _error;
  String? _imageUrl;
  bool _connecting = false;

  RoomState? get state => _state;
  List<LobbyLogEntry> get log => List.unmodifiable(_log);
  String? get playerId => _playerId;
  String? get error => _error;
  bool get connecting => _connecting;
  bool get connected => _client.connected && _playerId != null;
  String? get imageUrl => _imageUrl;

  void dismissImage() {
    _imageUrl = null;
    notifyListeners();
  }

  Future<void> connect({
    required String address,
    required String name,
    String? characterId,
    int? hp,
    int? maxHp,
    Map<String, dynamic>? characterSnapshot,
  }) async {
    if (connected || _connecting) return;
    await _subscription?.cancel();
    _subscription = _client.messages.listen(_onMessage);
    _connecting = true;
    _error = null;
    notifyListeners();
    try {
      await _client.connect(address);
      _client.send(LobbyMessage(LobbyMessageType.hello, {
        'name': name,
        'character_id': characterId,
        'hp': hp,
        'max_hp': maxHp,
        'character': characterSnapshot,
      }));
    } catch (error) {
      _error = 'Не удалось подключиться: $error';
      _connecting = false;
    }
    notifyListeners();
  }

  Future<void> disconnect() async {
    await _client.disconnect();
    await _subscription?.cancel();
    _subscription = null;
    _playerId = null;
    _state = null;
    _imageUrl = null;
    _connecting = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void moveToken(String tokenId, int x, int y) => _client.send(LobbyMessage(
      LobbyMessageType.tokenMove, {'id': tokenId, 'x': x, 'y': y}));

  void sendChat(String text) {
    if (text.trim().isEmpty) return;
    _client.send(LobbyMessage(LobbyMessageType.chat, {'text': text.trim()}));
  }

  void requestRoll(String formula, {bool hidden = false}) {
    if (formula.trim().isEmpty) return;
    _client.send(LobbyMessage(LobbyMessageType.roll, {
      'formula': formula.trim(),
      'hidden': hidden,
    }));
  }

  void drawStroke(Iterable<(int, int)> cells) => _client.send(LobbyMessage(
      LobbyMessageType.draw, {
        'cells': [
          for (final cell in cells) [cell.$1, cell.$2]
        ],
      }));

  void _onMessage(LobbyMessage message) {
    switch (message.type) {
      case LobbyMessageType.welcome:
        _playerId = message.payload['player_id'] as String?;
        final snapshot = message.payload['state'];
        if (snapshot is Map) {
          _state = RoomState.fromJson(snapshot.cast<String, dynamic>());
        }
        _connecting = false;
        break;
      case LobbyMessageType.state:
        final snapshot = message.payload['state'];
        if (snapshot is Map) {
          _state = RoomState.fromJson(snapshot.cast<String, dynamic>());
        }
        break;
      case LobbyMessageType.chat:
      case LobbyMessageType.roll:
        final entry = message.payload['entry'];
        if (entry is Map) {
          _log.add(LobbyLogEntry.fromJson(entry.cast<String, dynamic>()));
          if (_log.length > 200) _log.removeAt(0);
        }
        break;
      case LobbyMessageType.imageShow:
        _imageUrl = message.payload['url'] as String?;
        break;
      case LobbyMessageType.imageHide:
        _imageUrl = null;
        break;
      case LobbyMessageType.error:
        _error = message.payload['message'] as String?;
        break;
      default:
        break;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_client.close());
    unawaited(_subscription?.cancel());
    _subscription = null;
    super.dispose();
  }
}
