#!/usr/bin/env python3
"""Часы для Waybar. По клику показывают ещё и дату. Всё по-русски и не зависит от локали системы."""
import calendar, datetime, json, os

ALT = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "northling-clock-alt")
DAYS = ["понедельник", "вторник", "среда", "четверг", "пятница", "суббота", "воскресенье"]
MONTHS = ["января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа", "сентября", "октября", "ноября", "декабря"]
MONTHS_NOM = ["Январь", "Февраль", "Март", "Апрель", "Май", "Июнь", "Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь"]

n = datetime.datetime.now()
text = f"<b>{n:%H:%M}</b>"
if os.path.exists(ALT):
    text += f"  <span color='#9E94CD'>{DAYS[n.weekday()]}, {n.day} {MONTHS[n.month - 1]} {n.year}</span>"

rows = [f"<span color='#A78BFA'><b>{MONTHS_NOM[n.month - 1]} {n.year}</b></span>",
        "<span color='#9E94CD'>Пн Вт Ср Чт Пт Сб Вс</span>"]
for week in calendar.Calendar(firstweekday=0).monthdayscalendar(n.year, n.month):
    cells = []
    for d in week:
        if d == 0:
            cells.append("  ")
        elif d == n.day:
            cells.append(f"<span color='#D284E5'><b><u>{d:2d}</u></b></span>")
        else:
            cells.append(f"{d:2d}")
    rows.append(" ".join(cells))
tip = "<tt>" + "\n".join(rows) + "</tt>"
print(json.dumps({"text": text, "tooltip": tip, "class": "alt" if os.path.exists(ALT) else "time"}, ensure_ascii=False))
