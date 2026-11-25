#!/usr/bin/env bash
# Загрузка и температура GPU для Waybar (только NVIDIA; иначе ничего не выводит)
command -v nvidia-smi >/dev/null 2>&1 || exit 0
out=$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null) || exit 0
util=$(echo "$out" | cut -d, -f1 | tr -d ' ')
temp=$(echo "$out" | cut -d, -f2 | tr -d ' ')
echo "<span color='#9E94CD'>gpu</span> ${util}% ${temp}°"
