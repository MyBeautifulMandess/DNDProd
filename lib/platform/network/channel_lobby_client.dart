/// Клиент лобби игрока поверх web_socket_channel (интерфейс LobbyClient).
library;

import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

import '../../lobby/protocol/lobby_codec.dart';
import 'lobby_transport.dart';

class ChannelLobbyClient implements LobbyClient {
  final StreamController<LobbyMessage> _messages =
      StreamController<LobbyMessage>.broadcast();
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  bool _connected = false;
  bool _closed = false;

  @override
  Stream<LobbyMessage> get messages => _messages.stream;

  @override
  bool get connected => _connected;

  @override
  Future<void> connect(String address) async {
    await disconnect();
    final uri = Uri.parse(_socketUrl(address));
    final channel = IOWebSocketChannel.connect(uri,
        connectTimeout: const Duration(seconds: 5));
    _channel = channel;
    _subscription = channel.stream.listen(
      (dynamic raw) {
        try {
          _messages.add(decodeLobbyMessage(raw as String));
        } on FormatException catch (error) {
          _fail('Неверный ответ сервера: ${error.message}');
        }
      },
      onError: (Object error) => _fail('Ошибка соединения: $error'),
      onDone: () {
        if (!_connected) return;
        _connected = false;
        _messages.add(const LobbyMessage(
            LobbyMessageType.error, {'message': 'Соединение закрыто'}));
      },
    );
    await channel.ready;
    _connected = true;
  }

  @override
  Future<void> disconnect() async {
    final channel = _channel;
    _channel = null;
    _connected = false;
    await _subscription?.cancel();
    _subscription = null;
    if (channel != null) {
      await channel.sink.close();
    }
  }

  @override
  void send(LobbyMessage message) {
    final channel = _channel;
    if (channel == null || !_connected) {
      _fail('Нет соединения с комнатой');
      return;
    }
    channel.sink.add(jsonEncode(message.toJson()));
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await disconnect();
    await _messages.close();
  }

  void _fail(String text) =>
      _messages.add(LobbyMessage(LobbyMessageType.error, {'message': text}));

  /// Принимаем «192.168.1.5:7777», «ws://192.168.1.5:7777» и адрес из QR.
  String _socketUrl(String raw) {
    var host = raw.trim();
    if (host.isEmpty) throw ArgumentError('Укажите адрес сервера');
    host = host.replaceFirst(RegExp(r'^(wss?|https?)://'), '').split('/').first;
    if (host.isEmpty) throw ArgumentError('Укажите адрес сервера');
    if (!host.contains(':')) host = '$host:$defaultLobbyPort';
    return 'ws://$host/ws';
  }
}
