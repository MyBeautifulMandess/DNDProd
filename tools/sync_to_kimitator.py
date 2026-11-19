#!/usr/bin/env python3
"""Синхронизация статуса DNDProd с облачным агентом Kimitator (Kimi Claw).

После каждого обновления docs/07-roadmap.md запускать:
    python tools/sync_to_kimitator.py

Скрипт пишет снапшот роадмапа в память агента OpenClaw
(~/.kimi_openclaw/workspace/memory/), чтобы пользователь мог спрашивать
у Kimitator в облачном чате текущую стадию проекта.
"""

import datetime
import os
import re
import subprocess
import sys

# Консоль Windows (cp1251) не выводит часть символов юникода (✅ и пр.).
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROADMAP = os.path.join(PROJECT_ROOT, "docs", "07-roadmap.md")
PROGRESS = os.path.join(PROJECT_ROOT, "docs", "11-progress-log.md")

OPENCLAW_WS = os.path.expanduser(os.environ.get("OPENCLAW_WORKSPACE", "~/.kimi_openclaw/workspace"))
MEMORY_DIR = os.path.join(OPENCLAW_WS, "memory")
SNAPSHOT_NAME = "dndprod-roadmap.md"
MEMORY_MD = os.path.join(OPENCLAW_WS, "MEMORY.md")


def read(path: str) -> str:
    with open(path, encoding="utf-8") as f:
        return f.read()


def current_stage(roadmap: str) -> str:
    """Последняя выполненная строка мапы развития + первая невыполненная."""
    done, todo = [], []
    for line in roadmap.splitlines():
        if not line.strip().startswith("|"):
            continue
        if "✅" in line:
            done.append(line.strip())
        elif "⬜" in line:
            todo.append(line.strip())
    last_done = done[-1] if done else "(нет выполненных шагов)"
    next_step = todo[0] if todo else "(все шаги выполнены)"
    return last_done, next_step


def git_stamp() -> str:
    try:
        out = subprocess.run(
            ["git", "log", "--oneline", "-1", "--date=short", "--format=%h %ad %s"],
            cwd=PROJECT_ROOT, capture_output=True, timeout=10,
        ).stdout.decode("utf-8", errors="replace")
        return out.strip() or "(нет коммитов)"
    except Exception:
        return "(git недоступен)"


def main() -> int:
    if not os.path.isdir(MEMORY_DIR):
        print(f"Не найдена память OpenClaw: {MEMORY_DIR}")
        print("Убедись, что Kimi Desktop (Kimitator) запущен хотя бы раз.")
        return 1

    roadmap = read(ROADMAP)
    last_done, next_step = current_stage(roadmap)
    today = datetime.date.today().isoformat()
    stamp = git_stamp()

    snapshot = f"""# DNDProd — текущая стадия проекта

> Файл обновляется автоматически скриптом tools/sync_to_kimitator.py
> после каждого изменения роадмапа. Не редактировать вручную.
> Полные данные: репозиторий D:/DNDProd (приватный GitHub: MyBeautifulMandess/DNDProd),
> документы docs/07-roadmap.md (план) и docs/11-progress-log.md (журнал).

## Стадия на {today}

- Последний выполненный шаг: {last_done}
- Следующий шаг: {next_step}
- Последний коммит: {stamp}

## Что это за проект

Десктопное/мобильное приложение для D&D 5e (официальные правила, dnd.su):
Flutter (Windows → Android), две роли (Игрок/Мастер), офлайн-справочники,
лобби по локальной сети. Подробности — docs/00-index.md в репозитории.
"""

    with open(os.path.join(MEMORY_DIR, SNAPSHOT_NAME), "w", encoding="utf-8") as f:
        f.write(snapshot)

    # Дневная заметка: секция за сегодня (обновляется при повторном запуске).
    daily_path = os.path.join(MEMORY_DIR, f"{today}.md")
    daily = read(daily_path) if os.path.exists(daily_path) else f"# {today}\n"
    marker = "## DNDProd — статус роадмапа"
    block = (
        f"{marker} ({today})\n"
        f"- Синхронизировано скриптом tools/sync_to_kimitator.py.\n"
        f"- Выполнено: {last_done}\n"
        f"- Далее: {next_step}\n"
        f"- Коммит: {stamp}\n"
        f"- Детали: файл памяти {SNAPSHOT_NAME} и репозиторий D:/DNDProd.\n"
    )
    if marker in daily:
        daily = re.sub(re.escape(marker) + r".*?(?=\n## |\Z)", block.rstrip() + "\n", daily, flags=re.S)
    else:
        daily = daily.rstrip() + "\n\n" + block
    with open(daily_path, "w", encoding="utf-8") as f:
        f.write(daily)

    # Указатель в долговременной памяти (читается в главной сессии).
    pointer = (
        "# MEMORY.md\n\n"
        "## Проекты\n\n"
        "- **DNDProd** (D:/DNDProd) — приложение для D&D 5e на Flutter. "
        "Текущая стадия: см. `memory/dndprod-roadmap.md` (обновляется после каждого шага). "
        "План — docs/07-roadmap.md, журнал — docs/11-progress-log.md. "
        "Пользователь спрашивает стадии проекта — отвечай по этим файлам.\n"
    )
    if not os.path.exists(MEMORY_MD):
        with open(MEMORY_MD, "w", encoding="utf-8") as f:
            f.write(pointer)
    elif "dndprod-roadmap.md" not in read(MEMORY_MD):
        with open(MEMORY_MD, "a", encoding="utf-8") as f:
            f.write("\n" + pointer.split("\n", 1)[1])

    print(f"OK: снапшот записан в {os.path.join(MEMORY_DIR, SNAPSHOT_NAME)}")
    print(f"OK: дневная заметка {daily_path}")
    print("OK: указатель в MEMORY.md")
    print(f"\nСтадия: {last_done}\nДалее:  {next_step}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
