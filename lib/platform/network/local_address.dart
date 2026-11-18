/// Локальный адрес устройства для подключения игроков (только слой platform).
library;

import 'dart:io';

/// Выбираем первый не-loopback IPv4; на устройстве без Wi-Fi остаётся localhost.
Future<String> preferredLocalIp() async {
  try {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (!address.isLoopback) return address.address;
      }
    }
  } on SocketException {
    return '127.0.0.1';
  }
  return '127.0.0.1';
}
