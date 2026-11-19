/// Лобби: сервер на устройстве мастера, клиенты — игроки (docs/06-lobby-network.md).
/// Здесь — только контракты и типы сообщений протокола v1.
/// Реализация (shelf_web_socket / web_socket_channel) — фаза 3: делегируется
/// отдельной модели, см. docs/11-progress-log.md.
library;

import '../../core/models/room.dart';

/// Версия протокола — в каждом сообщении, чтобы избежать рассинхрона клиент/сервер.
const protocolVersion = 1;

const defaultLobbyPort = 7777;

/// Сообщение лобби: JSON с полями `v` (версия), `type`, `payload`.
class LobbyMessage {
  const LobbyMessage(this.type, this.payload);

  final String type;
  final Map<String, dynamic> payload;

  Map<String, dynamic> toJson() =>
      {'v': protocolVersion, 'type': type, 'payload': payload};

  factory LobbyMessage.fromJson(Map<String, dynamic> json) => LobbyMessage(
        json['type'] as String,
        (json['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
}

/// Сервер комнаты (поднимается у мастера).
abstract class LobbyServer {
  /// Адрес для подключения игроков, напр. «192.168.1.5:7777».
  String get address;

  Stream<LobbyMessage> get messages;

  Future<void> start();
  Future<void> stop();

  /// Рассылка всем клиентам (скрытые броски — только мастеру).
  void broadcast(LobbyMessage message);
}

/// Клиент комнаты (у игрока).
abstract class LobbyClient {
  Stream<LobbyMessage> get messages;

  bool get connected;

  Future<void> connect(String address);
  Future<void> disconnect();
  void send(LobbyMessage message);
}

/// Типы сообщений протокола v1 (docs/06-lobby-network.md, раздел 3).
abstract final class LobbyMessageType {
  static const hello = 'hello';
  static const welcome = 'welcome';
  static const state = 'state';
  static const tokenMove = 'token_move';
  static const tokenRemove = 'token_remove';
  static const tokenResize = 'token_resize';
  static const fogUpdate = 'fog_update';
  static const mapSwitch = 'map_switch';
  static const chat = 'chat';
  static const roll = 'roll';
  static const hpUpdate = 'hp_update';
  static const imageShow = 'image_show';
  static const imageHide = 'image_hide';
  static const characterSnapshot = 'character_snapshot';
  static const draw = 'draw';
  static const ping = 'ping';
  static const pong = 'pong';
  static const error = 'error';
}

/// Валидация прав: кто может двигать токен (docs/06-lobby-network.md, раздел 5).
/// Чистая функция — покрыта юнит-тестами.
bool canMoveToken(
    {required Token token,
    required String playerId,
    required bool isDm,
    required bool moveOwnAllowed}) {
  if (isDm) return true;
  if (!moveOwnAllowed) return false;
  return token.owner == playerId;
}
