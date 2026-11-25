#!/usr/bin/env bash
# Текущая раскладка для Waybar: EN / RU
command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 || exit 0
km=$(hyprctl devices -j 2>/dev/null | jq -r '((.keyboards | map(select(.main == true)))[0] // .keyboards[0]).active_keymap // empty')
[ -n "$km" ] || exit 0
case "${km,,}" in
  *russian*|*рус*) t=RU ;;
  *english*|*"(us)"*) t=EN ;;
  *) t="${km:0:2}"; t="${t^^}" ;;
esac
printf '{"text":"%s","tooltip":"Раскладка: %s (клик — сменить)"}\n' "$t" "$km"
