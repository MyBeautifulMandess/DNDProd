/// Сервер лобби на устройстве мастера: WebSocket + авторитетное состояние комнаты.
/// Платформенный слой (dart:io), за интерфейсом LobbyServer.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/field_grid.dart';
import '../../core/models/room.dart';
import '../../core/rules/dice.dart';
import '../../lobby/lobby_log.dart';
import '../../lobby/protocol/dice_formula.dart';
import '../../lobby/protocol/lobby_codec.dart';
import 'lobby_transport.dart';
import 'local_address.dart';

class ShelfLobbyServer implements LobbyServer {
  ShelfLobbyServer({this.port = defaultLobbyPort, DiceRoller? roller})
      : _roller = roller ?? DiceRoller();

  final int port;
  final DiceRoller _roller;
  final StreamController<LobbyMessage> _messages =
      StreamController<LobbyMessage>.broadcast();
  final Map<String, WebSocketChannel> _clients = {};
  final List<WebSocketChannel> _unregistered = [];
  final Map<WebSocketChannel, StreamSubscription<dynamic>> _listeners = {};
  HttpServer? _httpServer;
  String _host = '127.0.0.1';
  RoomState _state = const RoomState();
  bool _moveOwnAllowed = true;
  int _nextPlayer = 1;
  int _nextToken = 1;
  int _nextStroke = 1;
  static const _strokeColors = <int>[
    0xFFC9A227,
    0xFF64B5F6,
    0xFF81C784,
    0xFFFF8A65,
    0xFFBA68C8,
  ];
  Uint8List? _mapBytes;
  String _mapContentType = 'image/png';
  int _mapVersion = 0;

  @override
  String get address => '$_host:$boundPort';

  int get boundPort => _httpServer?.port ?? port;

  @override
  Stream<LobbyMessage> get messages => _messages.stream;

  RoomState get state => _state;

  bool get moveOwnAllowed => _moveOwnAllowed;

  @override
  Future<void> start() async {
    if (_httpServer != null) return;
    _host = await preferredLocalIp();
    final handler = shelf.Cascade()
        .add(_mapHandler)
        .add(webSocketHandler(_onConnection,
            pingInterval: const Duration(seconds: 30)))
        .handler;
    _httpServer = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  }

  @override
  Future<void> stop() async {
    final server = _httpServer;
    _httpServer = null;
    for (final subscription in _listeners.values) {
      await subscription.cancel();
    }
    _listeners.clear();
    for (final channel in [..._clients.values, ..._unregistered]) {
      await channel.sink.close();
    }
    _clients.clear();
    _unregistered.clear();
    await server?.close(force: true);
  }

  @override
  void broadcast(LobbyMessage message) {
    final raw = jsonEncode(message.toJson());
    for (final channel in [..._clients.values, ..._unregistered]) {
      channel.sink.add(raw);
    }
    _messages.add(message);
  }

  /// Действие мастера: сервер расположен на его устройстве, отдельный сокет не нужен.
  void submit(LobbyMessage message) => _handle(message, 'dm', isDm: true);

  void moveToken(String tokenId, int x, int y) => submit(LobbyMessage(
      LobbyMessageType.tokenMove, {'id': tokenId, 'x': x, 'y': y}));

  void sendChat(String text) => submit(
      LobbyMessage(LobbyMessageType.chat, {'text': text, 'author': 'Мастер'}));

  void requestRoll(String formula, {bool hidden = false}) => submit(
        LobbyMessage(LobbyMessageType.roll,
            {'formula': formula, 'hidden': hidden, 'author': 'Мастер'}),
      );

  void updateHp(String tokenId, int hp) => submit(
      LobbyMessage(LobbyMessageType.hpUpdate, {'id': tokenId, 'hp': hp}));

  void switchMap(String mapId) =>
      submit(LobbyMessage(LobbyMessageType.mapSwitch, {'map_id': mapId}));

  void showImage(String url) =>
      submit(LobbyMessage(LobbyMessageType.imageShow, {'url': url}));

  /// Импортированная карта: байты отдаются на /map.png, URL уходит в снапшот.
  void setMapImage(Uint8List bytes, {String contentType = 'image/png'}) {
    if (bytes.isEmpty) return;
    _mapBytes = bytes;
    _mapContentType = contentType;
    _setMapId('http://$_host:$boundPort/map.png?v=${++_mapVersion}');
  }

  /// Вернуть стандартную карту из `assets/maps/`.
  void useAssetMap([String asset = defaultMapAsset]) {
    _mapBytes = null;
    _setMapId('asset:$asset');
  }

  void _setMapId(String mapId) {
    _state = _state.copyWith(mapId: mapId);
    broadcast(LobbyMessage(LobbyMessageType.mapSwitch, {'map_id': mapId}));
    _broadcastState();
  }

  shelf.Response _mapHandler(shelf.Request request) {
    if (request.url.path != 'map.png' || _mapBytes == null) {
      return shelf.Response.notFound('');
    }
    return shelf.Response.ok(
      _mapBytes,
      headers: {
        'Content-Type': _mapContentType,
        'Cache-Control': 'no-store',
      },
    );
  }

  void draw(Iterable<(int, int)> cells) =>
      submit(LobbyMessage(LobbyMessageType.draw, {
        'cells': [
          for (final cell in cells) [cell.$1, cell.$2]
        ],
      }));

  void setFog(Iterable<(int, int)> cells, {required bool reveal}) =>
      submit(LobbyMessage(LobbyMessageType.fogUpdate, {
        'cells': [
          for (final cell in cells) [cell.$1, cell.$2]
        ],
        'reveal': reveal,
      }));

  void setMoveOwnAllowed(bool allowed) {
    _moveOwnAllowed = allowed;
    _state = _state.copyWith(
      players: [
        for (final player in _state.players) player.copyWith(moveOwn: allowed)
      ],
    );
    _broadcastState();
  }

  /// Добавляет пешку master'ом (монстры/NPC из приключения — фаза 5).
  void addToken({
    required String label,
    TokenKind kind = TokenKind.npc,
    int? x,
    int? y,
    int? hp,
    int? maxHp,
    int size = 1,
  }) {
    final number = _nextToken++;
    final safeSize = size.clamp(1, 4).toInt();
    final spawn = clampCell(
      (x ?? 1 + (number % 10), y ?? 1),
      _state.grid,
      size: safeSize,
    );
    final token = Token(
      id: 't$number',
      kind: kind,
      label: label,
      x: spawn.$1,
      y: spawn.$2,
      hp: hp,
      maxHp: maxHp ?? hp,
      size: safeSize,
    );
    _state = _state.copyWith(tokens: [..._state.tokens, token]);
    _broadcastState();
  }

  void removeToken(String tokenId) => submit(LobbyMessage(
      LobbyMessageType.tokenRemove, {'id': tokenId}));

  void resizeToken(String tokenId, int size) => submit(LobbyMessage(
      LobbyMessageType.tokenResize, {'id': tokenId, 'size': size}));

  void _onConnection(WebSocketChannel channel) {
    _unregistered.add(channel);
    _listeners[channel] = channel.stream.listen(
      (Object? raw) => _onRaw(channel, raw ?? ''),
      onError: (Object _) => _drop(channel),
      onDone: () => _drop(channel),
    );
  }

  void _onRaw(WebSocketChannel channel, Object raw) {
    late final LobbyMessage message;
    try {
      message = decodeLobbyMessage(raw as String);
    } on FormatException catch (error) {
      _send(channel,
          LobbyMessage(LobbyMessageType.error, {'message': error.message}));
      return;
    }
    final playerId = _clients.entries
        .where((entry) => entry.value == channel)
        .map((entry) => entry.key)
        .firstOrNull;
    if (playerId == null) {
      if (message.type == LobbyMessageType.hello) {
        _register(channel, message);
      } else {
        _send(
            channel,
            const LobbyMessage(
                LobbyMessageType.error, {'message': 'Сначала представьтесь'}));
      }
      return;
    }
    _handle(message, playerId, isDm: false);
  }

  void _register(WebSocketChannel channel, LobbyMessage message) {
    final name = (message.payload['name'] as String? ?? '').trim();
    final id = 'p${_nextPlayer++}';
    _unregistered.remove(channel);
    _clients[id] = channel;
    final player = RoomPlayer(
      id: id,
      name: name.isEmpty ? 'Игрок $id' : name,
      characterId: message.payload['character_id'] as String?,
      moveOwn: _moveOwnAllowed,
    );
    final number = _nextToken++;
    final token = Token(
      id: 't$number',
      kind: TokenKind.player,
      owner: id,
      catalogId: player.characterId,
      label: player.name,
      x: 2 + ((number - 1) % 8) * 3,
      y: 2 + ((number - 1) ~/ 8) * 3,
      hp: message.payload['hp'] as int?,
      maxHp: message.payload['max_hp'] as int?,
    );
    _state = _state.copyWith(
      tokens: [..._state.tokens, token],
      players: [..._state.players, player],
    );
    _send(
        channel,
        LobbyMessage(LobbyMessageType.welcome, {
          'player_id': id,
          'rights': {'move_own': _moveOwnAllowed},
          'state': _state.toJson(),
        }));
    _broadcastState();
    _logSystem('${player.name} подключился');
  }

  void _drop(WebSocketChannel channel) {
    final entry =
        _clients.entries.where((item) => item.value == channel).firstOrNull;
    if (entry == null) {
      _unregistered.remove(channel);
      _listeners.remove(channel);
      return;
    }
    final player = _state.players.firstWhere((item) => item.id == entry.key);
    _clients.remove(entry.key);
    _unregistered.remove(channel);
    _listeners.remove(channel);
    _state = _state.copyWith(
      players: [
        for (final item in _state.players)
          if (item.id != entry.key) item
      ],
      tokens: [
        for (final item in _state.tokens)
          if (item.owner != entry.key) item
      ],
    );
    _logSystem('${player.name} отключился');
    _broadcastState();
  }

  void _handle(LobbyMessage message, String playerId, {required bool isDm}) {
    final payload = message.payload;
    switch (message.type) {
      case LobbyMessageType.hello:
        if (!isDm) _errorTo(playerId, 'Вы уже подключены к комнате');
        break;
      case LobbyMessageType.tokenMove:
        _move(message, playerId, isDm: isDm);
        break;
      case LobbyMessageType.tokenRemove:
        if (!isDm) {
          _errorTo(playerId, 'Удаляет пешки только мастер');
          return;
        }
        _removeToken(message);
        break;
      case LobbyMessageType.tokenResize:
        if (!isDm) {
          _errorTo(playerId, 'Размер пешки меняет только мастер');
          return;
        }
        _resizeToken(message);
        break;
      case LobbyMessageType.chat:
        final text = (payload['text'] as String? ?? '').trim();
        if (text.isEmpty || text.length > 1000) return;
        final author = isDm ? 'Мастер' : _nameOf(playerId);
        broadcast(LobbyMessage(LobbyMessageType.chat, {
          'entry': LobbyLogEntry.chat(author: author, text: text).toJson(),
        }));
        break;
      case LobbyMessageType.roll:
        _roll(message, playerId, isDm: isDm);
        break;
      case LobbyMessageType.hpUpdate:
        if (!isDm) {
          _errorTo(playerId, 'Хиты обновляет только мастер');
          return;
        }
        _updateHp(message);
        break;
      case LobbyMessageType.fogUpdate:
        if (!isDm) {
          _errorTo(playerId, 'Туман войны обновляет только мастер');
          return;
        }
        _updateFog(message);
        break;
      case LobbyMessageType.mapSwitch:
        if (!isDm) {
          _errorTo(playerId, 'Карту переключает только мастер');
          return;
        }
        final mapId = payload['map_id'] as String? ?? '';
        _state = _state.copyWith(mapId: mapId);
        broadcast(LobbyMessage(LobbyMessageType.mapSwitch, {'map_id': mapId}));
        _broadcastState();
        break;
      case LobbyMessageType.imageShow:
        if (!isDm) {
          _errorTo(playerId, 'Картинки показывает только мастер');
          return;
        }
        broadcast(message);
        break;
      case LobbyMessageType.draw:
        _addStroke(message, playerId, isDm: isDm);
        break;
      case LobbyMessageType.ping:
        final channel = _clients[playerId];
        if (channel != null) {
          _send(channel, const LobbyMessage(LobbyMessageType.pong, {}));
        }
        break;
      case LobbyMessageType.pong:
        break;
      default:
        _errorTo(playerId, 'Неподдерживаемое действие: ${message.type}');
        break;
    }
  }

  void _move(LobbyMessage message, String playerId, {required bool isDm}) {
    final payload = message.payload;
    final id = payload['id'] as String? ?? '';
    final x = payload['x'] as int?;
    final y = payload['y'] as int?;
    final index = _state.tokens.indexWhere((token) => token.id == id);
    if (index < 0 || x == null || y == null || x < 0 || y < 0) {
      _errorTo(playerId, 'Некорректное перемещение пешки');
      return;
    }
    final token = _state.tokens[index];
    final clamped = clampCell((x, y), _state.grid, size: token.size);
    if (clamped.$1 != x || clamped.$2 != y) {
      _errorTo(playerId, 'Клетка вне поля');
      return;
    }
    final moveOwn = _state.players
            .where((item) => item.id == playerId)
            .map((item) => item.moveOwn)
            .firstOrNull ??
        false;
    final allowed = canMoveToken(
      token: token,
      playerId: playerId,
      isDm: isDm,
      moveOwnAllowed: moveOwn,
    );
    if (!allowed) {
      _errorTo(playerId, 'Нельзя двигать чужую пешку');
      return;
    }
    final tokens = [..._state.tokens]..[index] = token.copyWith(x: x, y: y);
    _state = _state.copyWith(tokens: tokens);
    _broadcastState();
  }

  void _removeToken(LobbyMessage message) {
    final id = message.payload['id'] as String? ?? '';
    final tokens = _state.tokens.where((token) => token.id != id).toList();
    if (tokens.length == _state.tokens.length) return;
    _state = _state.copyWith(tokens: tokens);
    _broadcastState();
  }

  void _resizeToken(LobbyMessage message) {
    final id = message.payload['id'] as String? ?? '';
    final rawSize = message.payload['size'] as int?;
    final index = _state.tokens.indexWhere((token) => token.id == id);
    if (index < 0 || rawSize == null) return;
    final size = rawSize.clamp(1, 4).toInt();
    final token = _state.tokens[index];
    final position = clampCell((token.x, token.y), _state.grid, size: size);
    final tokens = [..._state.tokens]
      ..[index] = token.copyWith(x: position.$1, y: position.$2, size: size);
    _state = _state.copyWith(tokens: tokens);
    _broadcastState();
  }

  void _addStroke(LobbyMessage message, String playerId, {required bool isDm}) {
    final seen = <(int, int)>{};
    final cells = <(int, int)>[];
    for (final cell in (message.payload['cells'] as List?) ?? const []) {
      if (cell is! List || cell.length != 2) continue;
      final x = cell[0];
      final y = cell[1];
      if (x is! int || y is! int) continue;
      final point = clampCell((x, y), _state.grid);
      if (seen.add(point) && cells.length < 400) cells.add(point);
    }
    if (cells.isEmpty) return;
    final index = _state.players.indexWhere((player) => player.id == playerId);
    final stroke = DrawStroke(
      id: 's${_nextStroke++}',
      author: isDm ? 'Мастер' : _nameOf(playerId),
      color: isDm
          ? _strokeColors.first
          : _strokeColors[(index + 1) % _strokeColors.length],
      cells: cells,
    );
    final strokes = [..._state.strokes, stroke];
    if (strokes.length > 200) strokes.removeAt(0);
    _state = _state.copyWith(strokes: strokes);
    broadcast(LobbyMessage(
        LobbyMessageType.draw, {'stroke': stroke.toJson()}..addAll(message.payload)));
    _broadcastState();
  }

  void _roll(LobbyMessage message, String playerId, {required bool isDm}) {
    final payload = message.payload;
    final formula = parseDiceFormula(payload['formula'] as String? ?? '');
    if (formula == null) {
      _errorTo(playerId, 'Неверная формула. Пример: 2к6+3');
      return;
    }
    late final RollResult result;
    try {
      result = formula.roll(_roller);
    } on ArgumentError {
      _errorTo(
          playerId, 'Неверный кубик. Доступны d4, d6, d8, d10, d12, d20, d100');
      return;
    }
    final author = isDm ? 'Мастер' : _nameOf(playerId);
    final hidden = payload['hidden'] == true;
    final entry = LobbyLogEntry.roll(
      author: author,
      formula: formula.display,
      total: result.total,
      text: result.rolls.join(' + '),
      hidden: hidden,
    );
    if (hidden) {
      // Скрытый бросок виден только мастеру (локальный поток сервера).
      _messages.add(LobbyMessage(
          LobbyMessageType.roll, {'entry': entry.toJson(), 'hidden': true}));
      final notice = LobbyLogEntry.system('$author: скрытый бросок');
      broadcast(
          LobbyMessage(LobbyMessageType.chat, {'entry': notice.toJson()}));
      return;
    }
    broadcast(LobbyMessage(
        LobbyMessageType.roll, {'entry': entry.toJson(), 'hidden': false}));
  }

  void _updateHp(LobbyMessage message) {
    final payload = message.payload;
    final id = payload['id'] as String? ?? '';
    final hp = payload['hp'] as int?;
    final index = _state.tokens.indexWhere((token) => token.id == id);
    if (hp == null || index < 0) return;
    final tokens = [..._state.tokens]..[index] =
        _state.tokens[index].copyWith(hp: hp);
    _state = _state.copyWith(tokens: tokens);
    _broadcastState();
  }

  void _updateFog(LobbyMessage message) {
    final payload = message.payload;
    final reveal = payload['reveal'] == true;
    final cells = {..._state.revealedCells};
    for (final cell in (payload['cells'] as List?) ?? const []) {
      if (cell is List &&
          cell.length == 2 &&
          cell[0] is int &&
          cell[1] is int) {
        final point = (cell[0] as int, cell[1] as int);
        if (reveal) {
          cells.add(point);
        } else {
          cells.remove(point);
        }
      }
    }
    _state = _state.copyWith(revealedCells: cells);
    broadcast(message);
    _broadcastState();
  }

  void _broadcastState() => broadcast(
      LobbyMessage(LobbyMessageType.state, {'state': _state.toJson()}));

  void _send(WebSocketChannel channel, LobbyMessage message) =>
      channel.sink.add(jsonEncode(message.toJson()));

  void _errorTo(String playerId, String text) {
    final channel = _clients[playerId];
    if (channel != null) {
      _send(channel, LobbyMessage(LobbyMessageType.error, {'message': text}));
    }
    _logSystem(text);
  }

  void _logSystem(String text) =>
      broadcast(LobbyMessage(LobbyMessageType.chat, {
        'entry': LobbyLogEntry.system(text).toJson(),
      }));

  String _nameOf(String playerId) =>
      _state.players
          .where((player) => player.id == playerId)
          .map((player) => player.name)
          .firstOrNull ??
      'Игрок';
}
