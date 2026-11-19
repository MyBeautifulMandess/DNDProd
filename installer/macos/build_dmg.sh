#!/usr/bin/env bash
set -euo pipefail

# Собирает DNDProd-macOS.dmg из Flutter-таргета macOS.
# Запускать только на macOS с установленным Xcode.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

APP_NAME="D&D Помощник"
APP_BUNDLE="dnd_prod.app"
STAGING="$ROOT/build/dmg-staging"
DMG="$ROOT/installer/macos/DNDProd-macOS.dmg"
SOURCE_APP="$ROOT/build/macos/Build/Products/Release/$APP_BUNDLE"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Ошибка: сборка .dmg возможна только на macOS." >&2
  exit 1
fi

if ! command -v hdiutil >/dev/null 2>&1; then
  echo "Ошибка: не найден hdiutil." >&2
  exit 1
fi

echo "==> flutter build macos --release"
flutter build macos --release

if [[ ! -d "$SOURCE_APP" ]]; then
  echo "Ошибка: не найден $SOURCE_APP" >&2
  exit 1
fi

rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$SOURCE_APP" "$STAGING/$APP_NAME.app"

# Неподписанная ad-hoc подпись: без неё Gatekeeper может сразу заблокировать запуск.
# Для публичного распространения нужна подпись Developer ID + notarization.
if command -v codesign >/dev/null 2>&1; then
  echo "==> ad-hoc codesign"
  codesign --force --deep --sign - "$STAGING/$APP_NAME.app" || \
    echo "Внимание: ad-hoc подпись не удалась, продолжаем без неё." >&2
fi

echo "==> hdiutil create"
rm -f "$DMG"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -ov -format UDZO "$DMG"

echo "Готово: $DMG"
ls -lh "$DMG"
