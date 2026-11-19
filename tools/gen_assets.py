#!/usr/bin/env python3
"""Генерация 2D-ассетов MVP через RouterAI (пункт 0.3 roadmap, см. docs/08-assets.md).

Модели:
  - black-forest-labs/flux-3-image-klein — «героические» ассеты (фон меню,
    иконка приложения, игровая карта): высокое качество, выбор разрешения.
  - recraft/recraft-v4.1-flash-v2 — массовые плоские иконки (прозрачный фон,
    палитра через image_config.rgb_colors, дешево при n-запросах).

Ключ читается из ~/.routerai/key или ROUTERAI_API_KEY (как в routerai_delegate.py).
Сырьё складывается в assets/_gen_raw/, потом ресайзится PIL в целевые пути.
Повторный запуск пропускает уже сгенерированные raw-файлы (resume).

Использование: python tools/gen_assets.py           # всё
              python tools/gen_assets.py --resize-only # только ресайз из raw
"""

import argparse
import base64
import io
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

API_BASE = "https://routerai.ru/api/v1"
ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "assets" / "_gen_raw"

FLUX = "black-forest-labs/flux-3-image-klein"
RECRAFT = "recraft/recraft-v4.1-flash-v2"

ICON_STYLE = (
    ", flat vector icon, minimal, bold shapes, solid colors, "
    "dark charcoal gray (#2B2B2B) shapes with antique gold (#C9A227) accents, "
    "no text, no watermark, centered, generous margins"
)

# (raw-имя, финальный путь, ширина, высота, формат финала)
FLUX_JOBS = [
    (
        "menu_bg",
        "Atmospheric fantasy tavern interior for a D&D app main menu background: "
        "wooden table with a hand-drawn world map, scattered dice and scrolls, "
        "burning candles, warm muted candlelight, soft top-down view, moody "
        "muted colors, painterly fantasy art, no people, no text, no logos, "
        "no watermarks",
        {"aspect_ratio": "16:9", "resolution": "2K", "output_format": "jpeg"},
        ("assets/2d/ui/menu_bg.jpg", 1920, 1080, "JPEG"),
    ),
    (
        "app_icon",
        "Mobile app icon: a twenty-sided die (d20) with elegant antique gold "
        "facets and engraved numerals on a very dark charcoal background, "
        "minimalist, high contrast, centered, soft glow, no text, no watermark",
        {"aspect_ratio": "1:1", "resolution": "1K", "output_format": "png"},
        ("assets/2d/ui/app_icon.png", 512, 512, "PNG"),
    ),
    (
        "grid_basic",
        "Top-down square battle map for a tabletop fantasy RPG, square grid "
        "overlay of 5-foot cells, terrain: generic grassy plains with gentle "
        "hills, a couple of leafy trees, dirt path crossing, muted earthy "
        "colors, hand-painted fantasy style, no text, no labels, no characters, "
        "no creatures, no buildings, no watermark",
        {"aspect_ratio": "1:1", "resolution": "2K", "output_format": "jpeg"},
        ("assets/maps/grid_basic.jpg", 2048, 2048, "JPEG"),
    ),
]

# (raw-имя, промт-субъект, финальный путь, размер)
ICON_JOBS = [
    ("tab_player", "front-view silhouette of an adventurer with a backpack and a "
     "sheathed sword on the back", "assets/2d/ui/tab_player.png", 128),
    ("tab_dm", "silhouette of a hooded dungeon master behind a DM screen with an "
     "open tome", "assets/2d/ui/tab_dm.png", 128),
    ("str", "a clenched fist", "assets/2d/ui/stats/str.png", 64),
    ("dex", "a flying arrow with motion lines", "assets/2d/ui/stats/dex.png", 64),
    ("con", "a sturdy shield with a heart emblem", "assets/2d/ui/stats/constitution.png", 64),
    ("int", "an open book with glowing runes rising from pages", "assets/2d/ui/stats/int.png", 64),
    ("wis", "an all-seeing eye", "assets/2d/ui/stats/wis.png", 64),
    ("cha", "a theatrical drama mask", "assets/2d/ui/stats/cha.png", 64),
    ("heart", "a heart", "assets/2d/ui/heart.png", 64),
    ("shield", "a kite shield", "assets/2d/ui/shield.png", 64),
    ("bolt", "a lightning bolt", "assets/2d/ui/bolt.png", 64),
    ("eye", "a wide-open eye", "assets/2d/ui/eye.png", 64),
    ("sword", "two crossed swords", "assets/2d/ui/sword.png", 64),
    ("backpack", "a traveler's backpack", "assets/2d/ui/backpack.png", 64),
    ("book", "a spellbook with a clasp and bookmark", "assets/2d/ui/book.png", 64),
    ("gear", "a cogwheel gear", "assets/2d/ui/gear.png", 64),
    ("ruler", "a straight ruler with tick marks", "assets/2d/ui/ruler.png", 64),
    ("brush", "a paint brush", "assets/2d/ui/brush.png", 64),
    ("fog", "three wavy horizontal fog lines", "assets/2d/ui/fog.png", 64),
    ("chat", "a rounded speech bubble", "assets/2d/ui/chat.png", 64),
    ("qr", "a QR code pattern", "assets/2d/ui/qr.png", 64),
    ("d20", "a twenty-sided die viewed from above", "assets/2d/ui/d20.png", 64),
    ("avatar_default", "neutral default character avatar: featureless silhouette "
     "of head and shoulders inside a circle ring", "assets/2d/ui/avatar_default.png", 256),
]


def load_key() -> str:
    key = os.environ.get("ROUTERAI_API_KEY")
    if key:
        return key.strip()
    key_file = Path.home() / ".routerai" / "key"
    if key_file.is_file():
        return key_file.read_text(encoding="utf-8").strip()
    sys.exit("Нет ключа RouterAI: ~/.routerai/key или ROUTERAI_API_KEY")


def generate(model: str, prompt: str, extra: dict, key: str) -> tuple[bytes, float]:
    payload = {"model": model, "prompt": prompt, "n": 1}
    payload.update(extra)
    req = urllib.request.Request(
        API_BASE + "/images",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=600) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            gen_id = resp.headers.get("X-Generation-Id")
    except urllib.error.HTTPError as e:
        sys.exit(f"Ошибка API {e.code}: {e.read().decode('utf-8', errors='replace')}")
    except urllib.error.URLError as e:
        sys.exit(f"Ошибка сети: {e}")
    images = data.get("data") or []
    if not images:
        sys.exit(f"Пустой ответ API: {json.dumps(data)[:500]}")
    cost = float(data.get("usage", {}).get("cost") or 0)
    print(
        f"  [routerai] id={gen_id} model={data.get('model')} cost={cost:.2f} ₽",
        file=sys.stderr,
    )
    return base64.b64decode(images[0]["b64_json"]), cost


def chroma_key(img):
    """Светлый фон recraft (белый) -> прозрачность, мягкая граница по расстоянию цвета."""
    import numpy as np
    from PIL import Image

    a = np.asarray(img.convert("RGB")).astype(np.int16)
    dist = np.sqrt(((a - np.array([255, 255, 255])) ** 2).sum(axis=2))
    alpha = np.clip((dist - 60) / 80 * 255, 0, 255).astype(np.uint8)
    out = np.dstack([a.astype(np.uint8), alpha])
    return Image.fromarray(out, "RGBA")


def resize_all() -> None:
    from PIL import Image

    jobs = [(n, d[0], d[1], d[2], d[3]) for n, _, _, d in FLUX_JOBS]
    jobs += [(n, d, s, s, "PNG") for n, _, d, s in ICON_JOBS]
    for raw_name, out_rel, w, h, fmt in jobs:
        raw = RAW / f"{raw_name}.png"
        if not raw.is_file():
            raw = RAW / f"{raw_name}.jpg"
        if not raw.is_file():
            print(f"  пропуск (нет raw): {raw_name}", file=sys.stderr)
            continue
        out = ROOT / out_rel
        out.parent.mkdir(parents=True, exist_ok=True)
        img = Image.open(raw)
        if fmt == "PNG":
            img = chroma_key(img) if raw_name in {n for n, *_ in ICON_JOBS} else img.convert("RGBA")
        else:
            img = img.convert("RGB")
        img = img.resize((w, h), Image.LANCZOS)
        img.save(out, fmt)
        print(f"  {out_rel} <- {raw.name} {w}x{h}")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--resize-only", action="store_true")
    args = ap.parse_args()

    RAW.mkdir(parents=True, exist_ok=True)
    if args.resize_only:
        resize_all()
        return

    key = load_key()
    total = 0.0

    for name, prompt, extra, _dest in FLUX_JOBS:
        raw = RAW / f"{name}.jpg" if extra.get("output_format") == "jpeg" else RAW / f"{name}.png"
        if raw.is_file():
            print(f"пропуск (есть raw): {name}", file=sys.stderr)
            continue
        print(f"flux: {name} …", file=sys.stderr)
        blob, cost = generate(FLUX, prompt, extra, key)
        raw.write_bytes(blob)
        total += cost
        time.sleep(1)

    for name, subject, _out, _size in ICON_JOBS:
        raw = RAW / f"{name}.png"
        if raw.is_file():
            print(f"пропуск (есть raw): {name}", file=sys.stderr)
            continue
        prompt = ("Flat game UI icon: " + subject + ICON_STYLE)
        # Recraft не отдаёт альфа-канал, а image_config провайдер игнорирует
        # (фон всегда белый) — фон вырезаем по яркости в resize_all().
        extra = {
            "aspect_ratio": "1:1",
            "output_format": "png",
            "image_config": {
                "rgb_colors": ["#2B2B2B", "#C9A227"],
                "background_rgb_color": "#FFFFFF",
            },
        }
        print(f"recraft: {name} …", file=sys.stderr)
        blob, cost = generate(RECRAFT, prompt, extra, key)
        raw.write_bytes(blob)
        total += cost
        time.sleep(0.5)

    print(f"\nИтого за генерацию: {total:.2f} ₽", file=sys.stderr)
    resize_all()


if __name__ == "__main__":
    main()
