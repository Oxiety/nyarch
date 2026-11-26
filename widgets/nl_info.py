#!/usr/bin/env python3
"""Строки для экрана блокировки: northling-info date | weather | player"""
import datetime, os, subprocess, sys

DAYS = ["понедельник", "вторник", "среда", "четверг", "пятница", "суббота", "воскресенье"]
MONTHS = ["января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа", "сентября", "октября", "ноября", "декабря"]
what = sys.argv[1] if len(sys.argv) > 1 else "date"
if what == "date":
    n = datetime.datetime.now()
    print(f"{DAYS[n.weekday()].capitalize()}, {n.day} {MONTHS[n.month - 1]}")
elif what == "weather":
    sys.path.insert(0, os.path.expanduser("~/.local/share/northling/widgets"))
    try:
        import nl_data
        w = nl_data.weather(nl_data.load_config())
        print(f"{w['place']}  {w['temp']:+.0f}{w['unit']}  {w['text']}" if isinstance(w['temp'], (int, float)) else f"{w['place']}  {w['temp']}{w['unit']}  {w['text']}")
    except Exception:
        print("")
elif what == "player":
    try:
        r = subprocess.run(["playerctl", "metadata", "--format", "♪ {{artist}} — {{title}}"], capture_output=True, text=True, timeout=2)
        print(r.stdout.strip() if r.returncode == 0 else "")
    except (OSError, subprocess.SubprocessError):
        print("")
