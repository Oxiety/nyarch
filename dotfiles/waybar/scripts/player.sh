#!/usr/bin/env bash
# Что играет сейчас (playerctl). Если ничего не играет — пустой вывод, и Waybar прячет модуль.
command -v playerctl >/dev/null 2>&1 || exit 0
st=$(playerctl status 2>/dev/null) || exit 0
[ "$st" = "Playing" ] || [ "$st" = "Paused" ] || exit 0
title=$(playerctl metadata title 2>/dev/null); artist=$(playerctl metadata artist 2>/dev/null)
[ -n "$title" ] || exit 0
esc() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/&/\&amp;/g' -e 's/</\&lt;/g'; }
t=$(esc "${title:0:34}"); a=$(esc "${artist:0:22}")
icon="▶"; cl=playing; [ "$st" = "Paused" ] && { icon="❚❚"; cl=paused; }
printf '{"text":"%s  %s%s","class":"%s","tooltip":"ЛКМ — пауза/играть, ПКМ — дальше, СКМ — назад"}\n' "$icon" "$t" "${a:+ · $a}" "$cl"
