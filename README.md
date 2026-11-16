# DNDProd

**Десктопное приложение для Windows** для мастеров и игроков D&D 5e, спроектированное для **лёгкого переноса на Android** без переписывания ядра. Две роли на входе — **Игрок** и **Мастер**. Официальные правила (dnd.su) как единственный источник данных.

## Кроссплатформенность

- Стек: **Flutter** — один код под Windows-десктоп и Android.
- Платформо-зависимости изолированы в `platform/` за интерфейсами.
- Правила переносимости: без WinAPI, без hover-only UI, адаптивная вёрстка — см. `docs/01-architecture.md`.

## Структура

- `docs/` — документация для ИИ-агентов, собирающих приложение. Начни с `docs/00-index.md`; состояние работ — в `docs/11-progress-log.md`, план — в `docs/07-roadmap.md`.
- `data/catalogs/` — официальные игровые данные, собранные с dnd.su (заклинания, бестиарий, предметы, расы, классы, предыстории, черты).
- `lib/` — код приложения: `core/` (правила и модели), `data/` (загрузчик каталогов), `platform/` (абстракции файлов/сети), `player/`, `master/`, `shared/`.
- `tools/build_catalogs.py` — пересборка каталогов из sitemap dnd.su.
- `assets/` — папки под 2D-ассеты и карты (промты в `docs/08-assets.md`).

## Запуск

Flutter SDK 3.44.1 уже установлен (`C:\Users\erizo\flutter`, в PATH). Платформенные папки (`android/`, `windows/`) сгенерированы. В сессии с прокси (иначе `pub` зависнет — см. `docs/11-progress-log.md`, раздел 2):

```bash
export HTTPS_PROXY=http://127.0.0.1:10809 HTTP_PROXY=http://127.0.0.1:10809 NO_PROXY=localhost,127.0.0.1,::1
flutter pub get        # если менялся pubspec
flutter test           # юнит-тесты ядра
flutter run -d windows # запуск (нужен workload «Desktop development with C++» в VS 2022)
```

## Быстрый старт для агента

1. Прочитай `docs/00-index.md` → `docs/01-architecture.md`.
2. Игровые данные бери только из `data/catalogs/`, не выдумывай.
3. Пиши код сразу кроссплатформенно (Windows + Android).
4. Обновляй `docs/07-roadmap.md` по мере выполнения фаз.
