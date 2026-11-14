#!/usr/bin/env bash
# Power menu through wofi
choice=$(printf 'Выключить\nПерезагрузить\nСон\nВыйти из сессии' | wofi --dmenu --prompt "Питание" --width 320 --height 260 --cache-file /dev/null)

case "$choice" in
    "Выключить")        systemctl poweroff ;;
    "Перезагрузить")    systemctl reboot ;;
    "Сон")              systemctl suspend ;;
    "Выйти из сессии")  hyprctl dispatch 'hl.dsp.exit()' ;;
esac
