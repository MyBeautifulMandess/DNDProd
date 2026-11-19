import 'package:flutter_driver/flutter_driver.dart';
import 'package:test/test.dart';

void main() {
  group('Сценарии Android из docs/04 и docs/05', () {
    late FlutterDriver driver;

    setUpAll(() async {
      driver = await FlutterDriver.connect();
    });

    tearDownAll(() async {
      await driver.close();
    });

    test('игрок: выбор роли, справочники, подключение', () async {
      await driver.waitFor(find.text('Игрок'),
          timeout: const Duration(seconds: 60));
      await driver.tap(find.text('Игрок'));
      await driver.waitFor(find.text('Персонажи'));

      await driver.tap(find.text('Справочники'));
      await driver.waitFor(find.text('Заклинания'),
          timeout: const Duration(seconds: 60));

      await driver.tap(find.text('Подключение'));
      await driver.waitFor(
          find.text('Сначала создайте персонажа во вкладке «Персонажи»'),
          timeout: const Duration(seconds: 90));
    }, timeout: const Timeout(Duration(minutes: 3)));

    test('мастер: приключения, архивы, запуск комнаты', () async {
      await driver.tap(find.byType('BackButton'));
      await driver.waitFor(find.text('Мастер'));
      await driver.tap(find.text('Мастер'));
      await driver.waitFor(find.text('Приключения'));

      await driver.tap(find.text('Архивы'));
      await driver.waitFor(find.text('Архивы'));

      await driver.tap(find.text('Комната'));
      await driver.waitFor(find.text('Локальная комната'));

      await driver.tap(find.text('Запустить комнату'));
      await driver.waitFor(find.text('Остановить комнату'),
          timeout: const Duration(seconds: 60));
      await driver.waitFor(find.text('Адрес для игроков'));
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
