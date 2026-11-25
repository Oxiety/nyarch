#!/usr/bin/env bash
# Клик по часам: показать/спрятать дату
f="${XDG_RUNTIME_DIR:-/tmp}/northling-clock-alt"
if [ -e "$f" ]; then rm -f "$f"; else : > "$f"; fi
pkill -RTMIN+8 waybar
