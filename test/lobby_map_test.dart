import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:dnd_prod/core/models/room.dart';
import 'package:dnd_prod/platform/network/channel_lobby_client.dart';
import 'package:dnd_prod/platform/network/lobby_transport.dart';
import 'package:dnd_prod/platform/network/shelf_lobby_server.dart';

void main() {
  test('импортированная карта отдаётся игрокам и попадает в снапшот', () async {
    final server = ShelfLobbyServer(port: 0);
    await server.start();
    final client = ChannelLobbyClient();
    final messages = <LobbyMessage>[];
    final subscription = client.messages.listen(messages.add);
    addTearDown(() async {
      await subscription.cancel();
      await client.close();
      await server.stop();
    });

    await client.connect('localhost:${server.boundPort}');
    client.send(const LobbyMessage(LobbyMessageType.hello, {'name': 'Алиса'}));
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
    server.setMapImage(bytes, contentType: 'image/png');
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final stateMessage = messages.lastWhere(
      (message) => message.type == LobbyMessageType.state,
    );
    final mapId = RoomState.fromJson(
      (stateMessage.payload['state'] as Map).cast<String, dynamic>(),
    ).mapId;
    expect(mapId, contains('/map.png?v=1'));

    final request =
        await HttpClient().getUrl(Uri.parse('http://127.0.0.1:${server.boundPort}/map.png'));
    final response = await request.close();
    expect(response.statusCode, HttpStatus.ok);
    expect(response.headers.contentType.toString(), contains('image/png'));
    final builder = await response.fold<BytesBuilder>(
        BytesBuilder(), (accumulated, chunk) => accumulated..add(chunk));
    expect(builder.takeBytes(), bytes);

    server.useAssetMap();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(server.state.mapId, 'asset:$defaultMapAsset');
  }, timeout: const Timeout(Duration(seconds: 15)));
}
