/// Проверка и разбор сообщений протокола лобби v1 (docs/06-lobby-network.md).
library;

import 'dart:convert';

import '../../platform/network/lobby_transport.dart';

const _knownTypes = <String>{
  LobbyMessageType.hello,
  LobbyMessageType.welcome,
  LobbyMessageType.state,
  LobbyMessageType.tokenMove,
  LobbyMessageType.tokenRemove,
  LobbyMessageType.tokenResize,
  LobbyMessageType.fogUpdate,
  LobbyMessageType.mapSwitch,
  LobbyMessageType.chat,
  LobbyMessageType.roll,
  LobbyMessageType.hpUpdate,
  LobbyMessageType.imageShow,
  LobbyMessageType.draw,
  LobbyMessageType.ping,
  LobbyMessageType.pong,
  LobbyMessageType.error,
};

/// Разбирает JSON от-peer'а, отбрасывая сообщения другой версии и неизвестные типы.
LobbyMessage decodeLobbyMessage(String raw) {
  final Object? decoded = jsonDecode(raw);
  if (decoded is! Map) {
    throw const FormatException('Сообщение должно быть объектом JSON');
  }
  final json = decoded.cast<String, dynamic>();
  if (json['v'] != protocolVersion) {
    throw FormatException('Несовместимая версия протокола: ${json['v']}');
  }
  final type = json['type'] as String?;
  if (type == null || !_knownTypes.contains(type)) {
    throw FormatException('Неизвестный тип сообщения: $type');
  }
  final Object? payload = json['payload'];
  if (payload != null && payload is! Map) {
    throw const FormatException('payload должен быть объектом JSON');
  }
  return LobbyMessage(
      type, payload is Map ? payload.cast<String, dynamic>() : const {});
}
