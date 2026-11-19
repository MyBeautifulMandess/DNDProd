#!/usr/bin/env python3
"""Сбор официального каталога dnd.su (5e14) в data/catalogs/*.json.

Источник: https://dnd.su/sitemap.xml
Извлекаем только официальные разделы (без /homebrew/).
Скрипт идемпотентен: повторный запуск перезаписывает JSON.
"""

from __future__ import annotations

import concurrent.futures
import html as htmllib
import json
import re
import sys
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "data" / "catalogs"
OUT.mkdir(parents=True, exist_ok=True)

UA = {"User-Agent": "Mozilla/5.0 (compatible; DNDProd-catalog/1.0)"}
BASE = "https://dnd.su"


def fetch(url: str, retries: int = 3) -> str | None:
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=25) as r:
                return r.read().decode("utf-8", errors="replace")
        except Exception:
            if attempt == retries - 1:
                return None
            time.sleep(1.5 * (attempt + 1))
    return None


def strip(s: str) -> str:
    s = re.sub(r"<br\s*/?>", " ", s)
    s = re.sub(r"<[^>]+>", "", s)
    s = htmllib.unescape(s).replace("\xa0", " ")
    return re.sub(r"[ \t]+", " ", s).strip()


def html_to_text(fragment: str) -> str:
    """HTML → текст с сохранением абзацев и пунктов списков."""
    s = re.sub(r"<br\s*/?>", "\n", fragment)
    s = re.sub(r"<li[^>]*>", "• ", s)
    s = re.sub(r"</li\s*>", "\n", s)
    s = re.sub(r"</?(?:p|div|ul|ol)[^>]*>", "\n\n", s)
    s = re.sub(r"<[^>]+>", "", s)
    s = htmllib.unescape(s).replace("\xa0", " ")
    blocks = []
    for block in re.split(r"\n{2,}", s):
        lines = [re.sub(r"[ \t]+", " ", line).strip() for line in block.split("\n")]
        lines = [line for line in lines if line]
        if lines:
            blocks.append("\n".join(lines))
    return "\n\n".join(blocks)


def params_html(h: str) -> str:
    """Содержимое <ul class='params card__article-body'> карточки (без внешних тегов)."""
    start = h.find('<ul class="params card__article-body">')
    if start < 0:
        return ""
    depth = 0
    for m in re.finditer(r"<ul\b[^>]*>|</ul>", h):
        if m.start() < start:
            continue
        if m.group(0).startswith("</"):
            depth -= 1
            if depth == 0:
                return h[start:m.start()]
        else:
            depth += 1
    return h[start:]


# Начало названия способности/атаки: «<strong>Имя.</strong>», «<em><strong>Имя.</strong>»,
# «<strong><em>Имя</em>.</strong>».
ENTRY_NAME = re.compile(
    r"^(?:<(?:div|p)[^>]*>\s*)*(?:<em[^>]*>\s*)?<strong[^>]*>\s*(?:<em[^>]*>\s*)?"
    r"([^<]{1,80}?)\s*(?:</em>)?\s*\.?\s*</strong>",
    re.S,
)


def section_entries(chunk: str) -> list[dict]:
    """Пункты секции существа: [{name, text}]. Имя — если абзац начинается с него."""
    title_m = re.search(r'<h3 class="subsection-title">([\s\S]*?)</h3>', chunk)
    title = strip(title_m.group(1)) if title_m else ""
    body = chunk[title_m.end():] if title_m else chunk
    entries = []
    for block in re.split(r"</p>", body):
        block = block.strip()
        if not block or not strip(block):
            continue
        name = ""
        m = ENTRY_NAME.match(block)
        if m:
            name = strip(m.group(1)).rstrip(".").strip()
        text = html_to_text(block)
        if name and text.lower().startswith(name.lower()):
            text = text[len(name):].lstrip(" .:;—–-").strip()
        entries.append({"name": name, "text": text})
    return entries


def _id_from_url(url: str) -> str:
    """«https://dnd.su/race/78-dwarf/» → «78-dwarf» (ключ записи в детальных каталогах)."""
    return url.rstrip("/").split("/")[-1]


def li_fields(h: str) -> dict[str, str]:
    """Поля карточки: <li><strong>Ключ:</strong> значение</li>
    или <li><strong>Ключ</strong> значение</li> (без двоеточия)."""
    out: dict[str, str] = {}
    for m in re.finditer(r"<li[^>]*><strong>([^<]+)</strong>\s*:?\s*([\s\S]*?)</li>", h):
        key = strip(m.group(1)).rstrip(":")
        val = strip(m.group(2))
        if val and len(val) < 400:
            out[key] = val
    return out


def sources(h: str) -> list[str]:
    return sorted(set(re.findall(r'class=[\'"]source-plaque[\'"][^>]*>([A-Z0-9:]+)<', h)))


def pick_main_card(h: str) -> str:
    """Вернуть HTML главной карточки (data-id=<section>:<id>), пропуская
    сервисные/пустые обёртки."""
    for m in re.finditer(r"<div class='paper-1 card[^']*'[^>]*data-id='([a-z]+):(\d+)'[^>]*>", h):
        return h[m.start():]
    return h


def card_title_from_span(h: str) -> tuple[str, str]:
    m = re.search(r'<h2 class="card-title" itemprop="name">\s*<span data-copy="([^"]+)"', h)
    if not m:
        m = re.search(r"<span data-copy=\"([^\"]+)\"", h)
    raw = htmllib.unescape(m.group(1)) if m else ""
    en = re.search(r"\[([^\]]+)\]", raw)
    ru = re.sub(r"\s*\[[^\]]+\]\s*$", "", raw).strip()
    return ru, (en.group(1) if en else "")


def spell_class_list(raw: str) -> list[str]:
    """Классы заклинания по отдельности: «волшебник, друидTCE» → [волшебник, друид]."""
    names: list[str] = []
    for part in raw.split(","):
        value = re.sub(r"TCE$", "", part.strip()).strip()
        if value and value not in names:
            names.append(value)
    return names


def spell(url: str, h: str) -> dict:
    h = pick_main_card(h)
    ru, en = card_title_from_span(h)
    m = re.search(r'class="?size-type-alignment"?[^>]*>([\s\S]*?)</li>', h)
    if not m:
        m = re.search(r"class='size-type-alignment'[^>]*>([\s\S]*?)</li>", h)
    line = strip(m.group(1)) if m else ""
    level = 0 if "Заговор" in line else None
    if level is None:
        lm = re.match(r"(\d+)", line)
        if lm:
            level = int(lm.group(1))
    f = li_fields(h)
    dur = f.get("Длительность", "")
    return {
        "url": url, "name_ru": ru, "name_en": en,
        "level": level, "school_line": line,
        "school": line.split(", ")[-1].strip() if ", " in line else "",
        "cast_time": f.get("Время накладывания", ""),
        "range": f.get("Дистанция", ""),
        "components": f.get("Компоненты", ""),
        "duration": dur,
        "classes": ", ".join(spell_class_list(f.get("Классы", ""))),
        "class_list": spell_class_list(f.get("Классы", "")),
        "subclasses": re.sub(r"TCE$", "", f.get("Подклассы", "")).strip(),
        "concentration": "концентрация" in dur.lower(),
        "ritual": "ритуал" in f.get("Время накладывания", "").lower(),
        "description": spell_description(h),
        "sources": sources(h),
    }


def spell_description(h: str) -> str:
    """Текст заклинания из <div itemprop='description'> (включая «На больших уровнях»)."""
    m = re.search(r'<li class="subsection desc"><div itemprop="description">([\s\S]*?)</div></li>', h)
    if not m:
        return ""
    txt = re.sub(r"<br\s*/?>", "\n", m.group(1))
    txt = re.sub(r"</p>\s*<p>", "\n\n", txt)
    txt = re.sub(r"<[^>]+>", "", txt)
    txt = htmllib.unescape(txt).replace("\xa0", " ")
    return re.sub(r"[ \t]+", " ", txt).strip()


def monster(url: str, h: str) -> dict:
    h = pick_main_card(h)
    ru, en = card_title_from_span(h)
    params = params_html(h)
    head, *chunks = params.split('<li class="subsection desc">')
    f = li_fields(head)
    cr = f.get("Опасность", "")
    cmatch = re.match(r"(\d+(?:/\d+)?)", cr)
    cr_val = cmatch.group(1) if cmatch else ""
    st = re.search(r'class=["\']size-type-alignment["\'][^>]*>([\s\S]*?)</li>', head)
    size_line = strip(st.group(1)) if st else ""
    ac = f.get("Класс Доспеха", "")
    am = re.match(r"(\d+)", ac)
    hp = f.get("Хиты", "")
    hpm = re.search(r"(\d+)", hp)

    sections = []
    for chunk in chunks:
        chunk = chunk.rstrip()
        if chunk.endswith("</li>"):
            chunk = chunk[:-5]
        title_m = re.search(r'<h3 class="subsection-title">([\s\S]*?)</h3>', chunk)
        title = strip(title_m.group(1)) if title_m else ""
        entries = section_entries(chunk)
        if not entries:
            continue
        sections.append({"title": title, "entries": entries})

    return {
        "url": url, "name_ru": ru, "name_en": en,
        "size_type": size_line,
        "size": size_line.split(",")[0].split(" ")[0] if size_line else "",
        "ac": int(am.group(1)) if am else None,
        "hp": int(hpm.group(1)) if hpm else None,
        "cr": cr_val,
        "xp": cr,
        "skills": f.get("Навыки", ""),
        "senses": f.get("Чувства", ""),
        "languages": f.get("Языки", ""),
        "habitat": f.get("Местность обитания", f.get("Место обитания", "")),
        "speed": f.get("Скорость", ""),
        "damage_resistance": f.get("Сопротивление урону", ""),
        "damage_immunity": f.get("Иммунитет к урону", ""),
        "damage_vulnerability": f.get("Уязвимость к урону", ""),
        "condition_immunity": f.get("Иммунитет к состоянию", ""),
        "sections": sections,        "sources": sources(h),
    }


def item(url: str, h: str) -> dict:
    h = pick_main_card(h)
    ru, en = card_title_from_span(h)
    m = re.search(r'class="?size-type-alignment"?[^>]*>([\s\S]*?)</li>', h)
    if not m:
        m = re.search(r"class='size-type-alignment'[^>]*>([\s\S]*?)</li>", h)
    kind = strip(m.group(1)) if m else ""
    rarity = ""
    base = kind
    for word in ["легендарный", "очень редкий", "редкий", "необычный", "обычный", "без редкости", "артефакт", "варьируется"]:
        if word in kind.lower():
            idx = kind.lower().find(word)
            base = kind[:idx].rstrip(", ").strip()
            rarity = kind[idx:].strip()
            break
    attune = "настрой" in kind.lower()
    cost = ""
    pm = re.search(r'<li class=["\']price["\'][^>]*>([\s\S]*?)</li>', h)
    if pm:
        cost = re.sub(r"^[^:]{3,40}:\s*", "", strip(pm.group(1))).strip()
    description = ""
    dm = re.search(r'<li class=["\']subsection desc["\'][^>]*>\s*<div itemprop="description">([\s\S]*?)</div>', h)
    if dm:
        description = html_to_text(dm.group(1))
    return {
        "url": url, "name_ru": ru, "name_en": en,
        "kind": base, "rarity": rarity, "attunement": attune,
        "cost": cost,
        "description": description,
        "sources": sources(h),
    }


def feat(url: str, h: str) -> dict:
    """Черта: требование, описание, источник."""
    h = pick_main_card(h)
    ru, en = card_title_from_span(h)
    params = params_html(h)
    head, *chunks = params.split('<li class="subsection desc">')
    prerequisite = ""
    rm = re.search(r'<li class=["\']size-type-alignment["\'][^>]*>([\s\S]*?)</li>', head)
    if rm:
        prerequisite = re.sub(r"^Требование:\s*", "", strip(rm.group(1))).strip()
    description = ""
    for chunk in chunks:
        dm = re.search(r'<div itemprop="description">([\s\S]*?)</div>', chunk)
        if dm:
            description = html_to_text(dm.group(1))
            break
    srcs = sources(h)
    return {
        "url": url, "name_ru": ru, "name_en": en,
        "source": srcs[0] if srcs else "",
        "prerequisite": prerequisite,
        "description": description,
        "sources": srcs,
    }


def race(url: str, h: str) -> dict:
    h = pick_main_card(h)
    m = re.search(r"<h2 class=\"card-title\" itemprop=\"name\">\s*<a [^>]*>([^<]+)</a>", h)
    if not m:
        m = re.search(r"<h2 class=\"card-title\"[^>]*>([\s\S]*?)</h2>", h)
    raw = strip(m.group(1)) if m else ""
    en = re.search(r"\[([^\]]+)\]", raw)
    ru = re.sub(r"\s*\[[^\]]+\]\s*$", "", raw).strip()
    f = li_fields(h)
    return {
        "url": url, "name_ru": ru, "name_en": en.group(1) if en else "",
        "source": f.get("Источник", ""),
        "sources": sources(h),
    }


# --- Детали для билдера персонажа (фаза 1): расширенные парсеры ---

ABILITY_RU = {
    "Сила": "str", "Ловкость": "dex", "Телосложение": "con",
    "Интеллект": "int", "Мудрость": "wis", "Харизма": "cha",
}
ABILITY_GEN = {  # родительный падеж
    "Силы": "str", "Ловкости": "dex", "Телосложения": "con",
    "Интеллекта": "int", "Мудрости": "wis", "Харизмы": "cha",
}

# Системные поля карточки расы (не являются чертами).
RACE_CORE_FIELDS = {"Увеличение характеристик", "Возраст", "Размер", "Скорость", "Языки", "Мировоззрение"}

# Начало игрового поля. Три формата dnd.su:
# A) <p><strong><em>Имя</em>. </strong> (старый, точка внутри strong)
# B) <p><strong style…>Имя</strong><strong>.</strong> (дроу) или <p><strong>Имя</strong>.
# C) <p><span class='…-feature-name'>Имя</span>. (новые форматы рас)
# Текст поля — всё до следующего поля (бывают многоабзацные).
FIELD_HEAD = re.compile(
    r"<p[^>]*>\s*(?:<span>\s*)?(?:"
    r"<strong[^>]*>\s*(?:<em[^>]*>)?\s*([^<]+?)\s*(?:</em>\s*)?\.\s*</strong>\s*"
    r"|<strong[^>]*>\s*(?:<em[^>]*>)?\s*([^<]+?)\s*(?:</em>\s*)?</strong>\s*(?:<strong[^>]*>\s*\.\s*</strong>|\.)\s*"
    r"|<em[^>]*>\s*<strong[^>]*>\s*([^<]+?)\s*\.\s*</strong>\s*</em>\s*"
    r"|<strong[^>]*>\s*<em[^>]*>\s*([^<]+?)\s*\.\s*</em>\s*</strong>\s*"
    r"|<em[^>]*>\s*<strong[^>]*>\s*([^<]+?)\s*</strong>\s*</em>\s*\.\s*"
    r"|<span class='(?:article-body__feature-name|dnd-feature-name)'>([^<]+)</span>\s*\.\s*"
    r")(?:</span>)?\s*"
)


def parse_bonuses(text: str) -> dict:
    """Парсит «Увеличение характеристик» расы.
    Возвращает {bonuses: [{ability, bonus}], bonuses_choice: bool, choice_options|None}.
    Официальные формулировки: «Ваше Телосложение увеличивается на 2»,
    «Все значения ваших характеристик увеличиваются на 1»,
    «Две разные характеристики по вашему выбору увеличиваются на 1»,
    MPMM: «(а) одна характеристика +2, а другая +1; (б) три различных +1».
    choice_options — список вариантов распределения (каждый вариант — список
    бонусов): [[2, 1], [1, 1, 1]] означает «+2/+1 ИЛИ +1/+1/+1»."""
    text = text.strip()
    low = text.lower()
    if re.search(r"все[хг][^.\n]{0,40}характеристик[^.\n]{0,40}на\s*(\d+)", low):
        n = int(re.search(r"на\s*(\d+)", low).group(1))
        return {"bonuses": [{"ability": a, "bonus": n} for a in ABILITY_RU.values()],
                "bonuses_choice": False, "choice_options": None}
    pairs = [
        {"ability": ABILITY_GEN[m.group(1)], "bonus": int(m.group(2))}
        for m in re.finditer(r"(Силы|Ловкости|Телосложения|Интеллекта|Мудрости|Харизмы)[^.\n]{0,60}?на\s*(\d+)", text)
    ]
    if pairs:
        return {"bonuses": pairs, "bonuses_choice": False, "choice_options": None}
    if re.search(r"(?:тр[её]х|три)\s+различн", low):
        return {"bonuses": [], "bonuses_choice": True, "choice_options": [[2, 1], [1, 1, 1]]}
    m = re.search(r"одн[аойй][^.\n]{0,40}характеристик[^.\n]{0,40}на\s*(\d+)[^.\n]{0,50}друг[а-я]+\s*—?\s*на\s*(\d+)", low)
    if m:
        return {"bonuses": [], "bonuses_choice": True, "choice_options": [[int(m.group(1)), int(m.group(2))]]}
    if "по вашему выбору" in low or "по своему выбору" in low:
        nums = [int(x) for x in re.findall(r"на\s*(\d+)", low)]
        if nums:
            return {"bonuses": [], "bonuses_choice": True, "choice_options": [nums]}
    return {"bonuses": [], "bonuses_choice": False, "choice_options": None}


def race_fields(h: str) -> list[tuple[int, str, str]]:
    """Поля расы/подвида: (позиция, имя, текст). Поддержаны все форматы dnd.su:
    старый <p><strong><em>Имя</em>.</strong>, <strong style>…</strong><strong>.</strong> (дроу),
    <em><strong>Имя.</strong></em> и зеркальные (multiverse/MPMM), новые
    <span class='…-feature-name'>Имя</span>, а также вынесенные в <h3> заголовки."""
    matches = list(FIELD_HEAD.finditer(h))
    fields = []
    for i, m in enumerate(matches):
        name = next(g for g in m.groups() if g is not None).strip().rstrip(".")
        end = matches[i + 1].start() if i + 1 < len(matches) else len(h)
        text = strip(h[m.end():end])
        if name and text:
            fields.append((m.start(), name, text))
    have = {n for _, n, _ in fields}
    for m in re.finditer(r"<h3[^>]*>\s*([^<]+?)\s*</h3>\s*<p[^>]*>([\s\S]*?)</p>", h):
        name = strip(m.group(1)).rstrip(".")
        if name in RACE_CORE_FIELDS and name not in have:
            fields.append((m.start(), name, strip(m.group(2))))
    fields.sort(key=lambda e: e[0])
    return fields


def race_sections(h: str) -> list[tuple[int, int, str, str, str]]:
    """Игровые секции расы (подвиды): [(start, end, anchor, название, html)].
    Подвид — multiforo-блок (caption-якорь) или h2.bigSectionTitle+hide-wrapper,
    содержащий «Увеличение характеристик». Лор-разделы и имена пропускаются."""
    spans = []
    for m in re.finditer(r"<div class='multiforo'\s+caption=\"<span id='([^']+)'>([^<]+)</span>\">", h):
        spans.append((m.start(), m.group(1), strip(m.group(2))))
    for m in re.finditer(
        r"<h2 class=\"bigSectionTitle[^\"]*\"><span id='([^']+)'>([^<]+)</span></h2><div class=\"hide-wrapper\"[^>]*>", h
    ):
        spans.append((m.start(), m.group(1), strip(m.group(2))))
    spans.sort()
    sections = []
    for i, (start, anchor, title) in enumerate(spans):
        end = spans[i + 1][0] if i + 1 < len(spans) else len(h)
        seg = h[start:end]
        # Подвид только если у секции есть собственное поле «Увеличение характеристик»
        # (SCAG-тифлинг и подобные наборы вариантов-замен — не подвиды).
        if any(name == "Увеличение характеристик" for _, name, _ in race_fields(seg)):
            sections.append((start, end, anchor, title, seg))
    return sections


def race_article_end(h: str) -> int:
    """Позиция конца статьи расы (до комментариев/галереи/следующих карточек).
    Поиск ведётся после начала основной карточки, чтобы не цеплять шапку сайта."""
    start = h.find("class='paper-1 card")
    if start < 0:
        start = 0
    stops = [
        m.start()
        for pat in (r'<h2[^>]*>\s*Комментарии', r'class="comments', r"class='comments", r'<div class=[\'"]paper-1 card')
        for m in re.finditer(pat, h[start:])
    ]
    return start + min(stops) if stops else len(h)


def race_variants_marker(h: str) -> int:
    """Позиция начала абзаца-разделителя «Разновидности»/«Подвиды» (где кончаются
    базовые поля расы и начинаются описания видов), или len(h) если нет."""
    m = re.search(
        r"<p[^>]*>\s*<strong><span id='[^']+'>(?:Расовые разновидности|Разновидности|Подвиды)</span>", h
    )
    return m.start() if m else len(h)


def race_ua_boundaries(h: str) -> list[int]:
    """Позиции bigSectionTitle-заголовков с 'Unearthed Arcana' — подвиды после них — UA."""
    return [
        m.start()
        for m in re.finditer(r'<h2 class="bigSectionTitle[^"]*"><span id=\'[^\']+\'>[^<]*Unearthed Arcana[^<]*</span>', h)
    ]


def race_detail(url: str, h: str) -> dict:
    ru, en = card_title_from_span(h)
    if not ru:  # старый формат карточек рас: заголовок в <a> внутри h2.card-title
        m = re.search(r'<h2 class="card-title"[^>]*>\s*<a [^>]*>([\s\S]*?)</a>', h)
        if m:
            raw = strip(m.group(1))
            en_m = re.search(r"\[([^\]]+)\]", raw)
            ru = re.sub(r"\s*\[[^\]]+\]\s*$", "", raw).strip()
            en = en_m.group(1) if en_m else ""
    h = h[:race_article_end(h)]
    sections = race_sections(h)
    ua_marks = race_ua_boundaries(h)
    base_end = min(race_variants_marker(h), sections[0][0] if sections else len(h))
    base = _race_fields_to_json(dict((name, text) for _, name, text in race_fields(h[:base_end])))

    subspecies = []
    for start, _, anchor, title, seg in sections:
        src = ""
        src_m = re.search(r"<p[^>]*>\s*(?:<strong>)?Источник:\s*([^<]+)</p>", seg)
        if src_m:
            src = strip(src_m.group(1))
        sub = _race_fields_to_json(dict((name, text) for _, name, text in race_fields(seg)))
        sub.update({
            "anchor": anchor, "name": title, "source": src,
            "ua": any(start > mark for mark in ua_marks),
            "darkvision_ft": _darkvision_ft(sub["traits"]),
        })
        subspecies.append(sub)

    base.update({
        "url": url, "name_ru": ru, "name_en": en,
        "darkvision_ft": _darkvision_ft(base["traits"]),
        "subspecies": subspecies,
    })
    return base


def _race_fields_to_json(f: dict[str, str]) -> dict:
    bonuses = parse_bonuses(f.get("Увеличение характеристик", ""))
    size = ""
    size_m = re.search(r"размер\s*—\s*([^\s.,]+)", f.get("Размер", ""))
    if size_m:
        size = size_m.group(1).strip()
    speed_ft = None
    speed_m = re.search(r"(?:составляет|до|равна|равняется|—)\s*(\d+)\s*фут", f.get("Скорость", ""))
    if speed_m:
        speed_ft = int(speed_m.group(1))
    traits = [{"name": k, "text": v} for k, v in f.items() if k not in RACE_CORE_FIELDS]
    return {
        "bonuses_text": f.get("Увеличение характеристик", ""),
        **bonuses,
        "size": size,
        "size_text": f.get("Размер", ""),
        "speed_ft": speed_ft,
        "speed_text": f.get("Скорость", ""),
        "languages_text": f.get("Языки", ""),
        "traits": traits,
    }


def _darkvision_ft(traits: list[dict]) -> int | None:
    for t in traits:
        if "тёмное зрение" in t["name"].lower():
            m = re.search(r"(\d+)\s*фут", t["text"])
            return int(m.group(1)) if m else None
    return None


def p_fields(h: str) -> dict[str, str]:
    """Поля вида <p><strong>Ключ:</strong> значение</p> — двоеточие внутри
    или сразу после </strong> (карточки предысторий)."""
    out: dict[str, str] = {}
    for m in re.finditer(r"<p[^>]*>\s*<strong>([^<]+?)\s*(?::\s*</strong>|</strong>\s*:)\s*([\s\S]*?)</p>", h):
        key = strip(m.group(1)).rstrip(":")
        val = strip(m.group(2))
        if key and val:
            out[key] = val
    return out


def background_full(url: str, h: str) -> dict:
    """Предыстория: поля карточки + умение из <h3>УМЕНИЕ: НАЗВАНИЕ</h3>."""
    h = pick_main_card(h)
    ru, en = card_title_from_span(h)
    f = p_fields(h)
    feature_name, feature_text = "", ""
    fm = re.search(r"<h3[^>]*>\s*УМЕНИЕ[^:<]{0,40}:\s*([^<]+)</h3>([\s\S]*?)(?:<h3|<h2)", h, re.IGNORECASE)
    if fm:
        feature_name = strip(fm.group(1))
        feature_text = strip(fm.group(2))
    return {
        "url": url, "name_ru": ru, "name_en": en,
        "skills": f.get("Владение навыками", ""),
        "tools": f.get("Владение инструментами", ""),
        "languages": f.get("Языки", ""),
        "equipment": f.get("Снаряжение", ""),
        "feature": "",
        "feature_name": feature_name,
        "feature_text": feature_text,
        "source": f.get("Источник", ""),
    }


def class_equipment(url: str, h: str) -> dict | None:
    """Стартовое снаряжение класса: h4 СНАРЯЖЕНИЕ + список с вариантами «а) ... или б) ...»."""
    m = re.search(r'<h4 class="(?:smallSectionTitle|tableTitle)"[^>]*>\s*СНАРЯЖЕНИЕ\s*</h4>', h)
    if not m:
        return None
    seg = h[m.end():]
    end = re.search(r"<h[1-4][^>]*>", seg)
    seg = seg[: end.start()] if end else seg[:8000]

    intro = ""
    im = re.search(r"<p[^>]*>([\s\S]*?)</p>", seg)
    if im:
        intro = strip(im.group(1))

    rows: list[list[str]] = []
    for li in re.findall(r"<li[^>]*>([\s\S]*?)</li>", seg):
        txt = strip(li)
        if not txt:
            continue
        parts = re.split(r"(?:^|\s)([абв])\)\s*", txt)
        if len(parts) >= 5:  # ['', 'а', 'текст', 'б', 'текст']
            variants = [parts[i + 1].strip() for i in range(1, len(parts) - 1, 2)]
            variants = [re.sub(r"\s*или\s*$", "", v).strip() for v in variants]
            variants = [v for v in variants if v]
            if variants:
                rows.append(variants)
        else:
            rows.append([txt])

    gold = ""
    gm = re.search(r"<p[^>]*>([^<]*альтернатив[а-я]*[^<]*)</p>", seg)
    if gm:
        gold = strip(gm.group(1))

    return {"intro": intro, "rows": rows, "gold": gold}


SECTIONS = {
    "spells": (re.compile(r"^/spells/\d+-"), spell, "spells_5e14.json"),
    "bestiary": (re.compile(r"^/bestiary/\d+-"), monster, "bestiary_5e14.json"),
    "items": (re.compile(r"^/items/\d+-"), item, "items_5e14.json"),
    "race": (re.compile(r"^/race/\d+-"), race, "races_5e14.json"),
    "backgrounds": (re.compile(r"^/backgrounds/\d+-"), background_full, "backgrounds_full.json"),
    "feats": (re.compile(r"^/feats/\d+-"), feat, "feats_full.json"),
}

# Крупные каталоги пишем без отступов — экономия места в ассетах приложения.
COMPACT_SECTIONS = {"bestiary"}

# Бестиарий — самый большой каталог (~14 МБ). Для приложения он режется на
# лёгкий индекс (список и фильтры) и шарды с полными карточками, которые
# CatalogLoader читает по требованию. Имена шардов: bestiary_00.json …
BESTIARY_SHARDS = 32
BESTIARY_INDEX = "_bestiary_index.json"
BESTIARY_INDEX_FIELDS = (
    "url", "name_ru", "name_en", "size", "size_type", "cr", "habitat", "sources",
)


# Категории, чьи элементы не попадают в sitemap: URL собираем с категорийной страницы.
CATEGORY_PAGES = {
    "backgrounds": "/backgrounds/",
    "feats": "/feats/",
}

# Секции-детали: результат — dict (ключ — id из url), а не список.
DETAIL_SECTIONS = {
    "race_detail": (re.compile(r"^/race/\d+-"), race_detail, "_races_detail.json"),
    "class_equipment": (re.compile(r"^/class/\d+-"), class_equipment, "_classes_equipment.json"),
}


def repair_empty_rows(name: str, rows: list, fetch_html) -> list:
    """Повторная докачка записей с пустым name_ru (сеть dnd.su нестабильна):
    до 2 раундов; перепарсенные записи заменяют пустые по url."""
    for _ in range(2):
        empty = [r for r in rows if not (r.get("name_ru") or "").strip()]
        if not empty:
            break
        fixed = 0
        for row in empty:
            h = fetch_html(row["url"])
            if not h:
                continue
            try:
                parsed = (SECTIONS | DETAIL_SECTIONS)[name][1](row["url"], h)
            except Exception:  # noqa: BLE001
                continue
            if parsed:
                row.clear()
                row.update(parsed)
                fixed += 1
        print(f"  {name}: докачано пустых записей {fixed}", flush=True)
        if not fixed:
            break
    return rows


def write_bestiary(rows: list[dict]) -> None:
    """Индекс + шарды бестиария вместо единого 14-МБ файла.

    Индекс (``_bestiary_index.json``) — поля для списка и фильтров плюс номер
    шарда. Шарды ``bestiary_NN.json`` — полные карточки (секции, атаки, лор),
    их читает только открытая карточка существа. Записи раскладываются по
    шардам жадно: сначала крупные, поэтому размеры шардов выравнены.
    """
    legacy = OUT / "bestiary_5e14.json"
    for old in OUT.glob("bestiary_[0-9]*.json"):
        old.unlink()
    ordered = sorted(rows, key=lambda r: r["url"])
    sizes = [len(json.dumps(r, ensure_ascii=False).encode("utf-8")) for r in ordered]
    buckets: list[list[int]] = [[] for _ in range(BESTIARY_SHARDS)]
    loads = [0] * BESTIARY_SHARDS
    for position, size in sorted(enumerate(sizes), key=lambda pair: pair[1], reverse=True):
        target = loads.index(min(loads))
        buckets[target].append(position)
        loads[target] += size

    index = []
    total = 0
    for shard, bucket in enumerate(buckets):
        records = [ordered[position] for position in sorted(bucket)]
        shard_name = f"bestiary_{shard:02d}.json"
        payload = json.dumps(records, ensure_ascii=False, separators=(",", ":"))
        (OUT / shard_name).write_text(payload, encoding="utf-8")
        total += len(payload.encode("utf-8"))
        for row in records:
            index.append({**{key: row.get(key) for key in BESTIARY_INDEX_FIELDS}, "shard": shard})

    index.sort(key=lambda row: row["url"])
    (OUT / BESTIARY_INDEX).write_text(
        json.dumps(index, ensure_ascii=False, separators=(",", ":")), encoding="utf-8"
    )
    if legacy.exists():
        legacy.unlink()
    print(
        f"bestiary: -> {BESTIARY_INDEX} + {BESTIARY_SHARDS} шардов "
        f"({len(rows)} записей; шарды {total / 1048576:.1f} МБ)",
        flush=True,
    )


def main() -> None:
    print("sitemap...", flush=True)
    sm = fetch(f"{BASE}/sitemap.xml")
    if not sm:
        sys.exit("sitemap недоступен")
    urls = re.findall(r"<loc>([^<]+)</loc>", sm)
    rel = [u.replace(BASE, "") for u in urls if u.startswith(BASE)]
    print(f"urls: {len(rel)}", flush=True)

    only = sys.argv[1:] or list(SECTIONS) + list(DETAIL_SECTIONS)
    for name in only:
        pat, parser, filename = (SECTIONS | DETAIL_SECTIONS)[name]
        targets = [BASE + r for r in rel if pat.match(r)]
        if not targets and name in CATEGORY_PAGES:
            cat = fetch(BASE + CATEGORY_PAGES[name])
            if cat:
                targets = sorted({BASE + u for u in re.findall(r"href=[\'\"](" + pat.pattern[1:-1] + r"[^\'\"]*)[\'\"]", cat)})
        print(f"{name}: {len(targets)} страниц", flush=True)
        as_dict = name in DETAIL_SECTIONS
        rows: list[dict] | dict[str, dict] = {} if as_dict else []
        done = 0
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as ex:
            futs = {ex.submit(fetch, u): u for u in targets}
            for fut in concurrent.futures.as_completed(futs):
                u = futs[fut]
                h = fut.result()
                done += 1
                if done % 200 == 0:
                    print(f"  {name} {done}/{len(targets)}", flush=True)
                if not h:
                    continue
                try:
                    parsed = parser(u, h)
                    if parsed is None:
                        continue
                    if as_dict:
                        rows[_id_from_url(u)] = parsed
                    else:
                        rows.append(parsed)
                except Exception as e:  # noqa: BLE001
                    print(f"  parse error {u}: {e}", flush=True)
        if not as_dict:
            rows = repair_empty_rows(name, rows, fetch)
            rows.sort(key=lambda r: r["url"])
        else:
            remaining = {
                k: v
                for k, v in rows.items()
                if not (v.get("name_ru") or "").strip()
            }
            if remaining:
                repaired = repair_empty_rows(
                    name, [{"url": v["url"], **v} for v in remaining.values()], fetch
                )
                for fixed in repaired:
                    rows[_id_from_url(fixed["url"])] = fixed
            rows = dict(sorted(rows.items()))
        if name == "bestiary":
            write_bestiary(rows)
            continue
        payload = json.dumps(
            rows,
            ensure_ascii=False,
            indent=None if name in COMPACT_SECTIONS else 1,
            separators=(",", ":") if name in COMPACT_SECTIONS else None,
        )
        (OUT / filename).write_text(payload, encoding="utf-8")
        print(f"{name}: -> {filename} ({len(rows)})", flush=True)


if __name__ == "__main__":
    main()
