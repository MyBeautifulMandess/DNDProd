/// Карта, подготовленная в приключении, для запуска комнаты.
/// Сервер хранит снапшот каждой карты и отдаёт её фон по HTTP при переключении.
library;

import 'dart:typed_data';

import '../core/models/room.dart';

class LobbyMap {
  const LobbyMap({
    required this.key,
    required this.name,
    required this.state,
    this.imageBytes,
    this.contentType = 'image/png',
  });

  /// Ключ карты в приключении (AdventureMap.id).
  final String key;
  final String name;
  final RoomState state;
  final Uint8List? imageBytes;
  final String contentType;
}
