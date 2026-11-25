#!/usr/bin/env bash
# Меню питания через rofi
choice=$(printf 'Заблокировать\nСон\nПерезагрузить\nВыключить\nВыйти из сессии' | rofi -dmenu -i -p "Питание" -theme-str 'window {width: 340px;} listview {lines: 5;}')

case "$choice" in
    "Заблокировать")    pidof hyprlock || hyprlock ;;
    "Сон")              systemctl suspend ;;
    "Перезагрузить")    systemctl reboot ;;
    "Выключить")        systemctl poweroff ;;
    "Выйти из сессии")  command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()' ;;
esac
