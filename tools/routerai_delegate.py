#!/usr/bin/env python3
"""Проектная обёртка делегирования через RouterAI.

Источник правды — глобальный скрипт ~/.routerai/routerai_delegate.py
(см. ~/.agents/AGENTS.md, раздел «Делегирование токенозатратных задач»).
Этот файл нужен только чтобы вызывать делегирование короткой командой
`python tools/routerai_delegate.py ...` из корня репозитория.
"""

import sys
from pathlib import Path

GLOBAL_SCRIPT = Path.home() / ".routerai" / "routerai_delegate.py"

if not GLOBAL_SCRIPT.is_file():
    sys.exit(
        f"Не найден глобальный скрипт делегирования: {GLOBAL_SCRIPT}\n"
        "См. ~/.agents/AGENTS.md (раздел про RouterAI)."
    )

import runpy

runpy.run_path(str(GLOBAL_SCRIPT), run_name="__main__")
