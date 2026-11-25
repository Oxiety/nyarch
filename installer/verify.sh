#!/usr/bin/env bash
# Этап 12: проверка результата. Можно запускать и отдельно:  northling doctor
# Если в конфиге Hyprland ошибки — предлагает откатить его к предыдущей версии.

V_OK=0; V_BAD=0; V_WARN=0
vok()   { V_OK=$((V_OK+1));     printf '  %s✓%s %s\n' "$C_GRN" "$C_RESET" "$*"; log "v-ok: $*"; }
vbad()  { V_BAD=$((V_BAD+1));   printf '  %s✗%s %s\n' "$C_RED" "$C_RESET" "$*"; log "v-BAD: $*"; }
vwarn() { V_WARN=$((V_WARN+1)); printf '  %s!%s %s\n' "$C_PINK" "$C_RESET" "$*"; log "v-warn: $*"; }

v_cmd()  { if have "$1"; then vok "команда $1"; else vbad "нет команды $1${2:+  ($2)}"; fi; }
v_file() { if [ -s "$1" ]; then vok "файл $(tilde "$1")"; else vbad "нет файла $(tilde "$1")"; fi; }

v_json() { # файл
  [ -s "$1" ] || return 0
  if have jq; then jq -e . "$1" >/dev/null 2>&1 && vok "корректный JSON: $(tilde "$1")" || vbad "ломаный JSON: $(tilde "$1")"
  elif have python3; then python3 -c 'import json,sys;json.load(open(sys.argv[1]))' "$1" 2>/dev/null && vok "корректный JSON: $(tilde "$1")" || vbad "ломаный JSON: $(tilde "$1")"
  else vwarn "нечем проверить JSON ($(tilde "$1"))"; fi
}

nl_verify() {
  V_OK=0; V_BAD=0; V_WARN=0
  local c

  say "${C_B}Программы${C_RESET}"
  for c in hyprland hyprctl hyprlock hypridle waybar swaync swaync-client kitty dolphin firefox vlc mpv ark swaybg grim slurp wl-copy cliphist playerctl wpctl nmcli rofi; do v_cmd "$c"; done
  if [ "${WITH_ZSH:-1}" = 1 ]; then for c in zsh fastfetch fzf zoxide eza bat rg btop; do v_cmd "$c"; done; fi
  [ "${WITH_DEV:-1}" = 1 ]    && for c in git gh node npm; do v_cmd "$c"; done
  [ "${WITH_VSCODE:-1}" = 1 ] && v_cmd code "AUR: visual-studio-code-bin"
  [ "${WITH_DOCKER:-0}" = 1 ] && v_cmd docker

  say "${C_B}Конфиги${C_RESET}"
  for c in hypr/hyprland.lua hypr/hyprlock.conf hypr/hypridle.conf waybar/config.jsonc waybar/style.css \
           rofi/config.rasi rofi/northling.rasi kitty/kitty.conf swaync/config.json swaync/style.css; do v_file "$XDG_CONFIG/$c"; done
  if [ "${WITH_WIDGETS:-1}" = 1 ]; then
    v_file "$HOME/.local/share/northling/widgets/northling_widgets.py"; v_file "$XDG_CONFIG/northling/widgets.json"; v_json "$XDG_CONFIG/northling/widgets.json"
    python3 -c "import gi; gi.require_version('GtkLayerShell','0.1')" >/dev/null 2>&1 && vok "виджеты: python-gobject и gtk-layer-shell на месте" \
      || vwarn "виджетам не хватает python-gobject / gtk-layer-shell → northling update --full (из TTY)"
  fi
  if [ "${WITH_SDDM:-1}" = 1 ] && [ -d "${NL_SDDM_THEMES:-/usr/share/sddm/themes}/northling-midnight" ]; then
    if [ -f "${NL_SDDM_CONFD:-/etc/sddm.conf.d}/10-northling-theme.conf" ]; then vok "тема SDDM установлена и включена"; else vwarn "тема SDDM установлена, но не включена: northling sddm test → northling sddm enable"; fi
  fi
  v_json "$XDG_CONFIG/waybar/config.jsonc"
  v_json "$XDG_CONFIG/swaync/config.json"
  for c in "$HOME"/.local/bin/northling*; do [ -f "$c" ] && { bash -n "$c" 2>/dev/null && vok "скрипт без синтаксических ошибок: $(basename "$c")" || vbad "ошибка синтаксиса в $(basename "$c")"; }; done
  [ -e "$XDG_CONFIG/hypr/hyprland.conf" ] && vwarn "остался старый ~/.config/hypr/hyprland.conf — в Hyprland 0.57 основной конфиг hyprland.lua (старый файл не используется)"
  if [ -L "$WALL_LINK" ] && [ -e "$WALL_LINK" ]; then vok "обои выбраны: $(tilde "$(readlink -f "$WALL_LINK")")"; else vbad "не выбраны обои (запусти northling-wallpaper)"; fi

  say "${C_B}Система${C_RESET}"
  [ "$(systemctl is-active NetworkManager 2>/dev/null)" = active ] && vok "NetworkManager работает" || vbad "NetworkManager не запущен"
  for c in pipewire wireplumber; do
    [ "$(systemctl --user is-active "$c" 2>/dev/null)" = active ] && vok "$c работает" || vwarn "$c не запущен (в TTY это нормально — стартует с сессией)"
  done
  if [ "${HAS_NVIDIA:-0}" = 1 ]; then
    [ "$(cat /sys/module/nvidia_drm/parameters/modeset 2>/dev/null)" = Y ] && vok "NVIDIA: DRM modeset включён" || vbad "NVIDIA: modeset выключен"
  fi
  { have pacman && pacman -Qq bluez >/dev/null 2>&1; } && vwarn "стоит bluez (от прошлой установки): Bluetooth тебе не нужен — можно убрать: sudo pacman -Rns bluez blueman"

  if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && have hyprctl; then
    say "${C_B}Живая сессия Hyprland${C_RESET}"
    local errs; errs="$(hyprctl configerrors 2>&1)"
    if printf '%s' "$errs" | grep -qi 'error'; then
      vbad "Hyprland сообщает об ошибках в конфиге:"; printf '%s\n' "$errs" | head -n 8 | sed 's/^/      /'
      verify_offer_rollback
    else
      vok "Hyprland: ошибок конфигурации нет"
    fi
    local mon; mon="$(hyprctl monitors 2>/dev/null | grep -E '^\s*[0-9]+x[0-9]+@' | head -n1 | sed 's/^[[:space:]]*//')"
    [ -n "$mon" ] && { case "$mon" in 1920x1080@1[12]*) vok "монитор: $mon" ;; 1920x1080@*) vwarn "монитор работает как «$mon» (режим «preferred»). Если нужны 120 Гц — посмотри hyprctl monitors и впиши режим в hyprland.lua" ;; *) vwarn "монитор работает как «$mon», ожидалось 1920x1080" ;; esac; }
    [ "${WITH_WIDGETS:-1}" = 1 ] && { pgrep -f northling_widgets.py >/dev/null && vok "запущены виджеты" || vwarn "виджеты не запущены: northling widgets restart (лог: northling widgets status)"; }
    for c in waybar swaync swaybg hypridle; do pgrep -x "$c" >/dev/null && vok "запущен: $c" || vwarn "не запущен: $c"; done
    pgrep -x mako >/dev/null && vwarn "работает старый mako — он конфликтует с swaync за уведомления; закрой: pkill mako"
  fi

  say ""
  printf '  %sИтог проверки:%s %s%d ок%s, %s%d замечаний%s, %s%d ошибок%s\n' "$C_B" "$C_RESET" "$C_GRN" "$V_OK" "$C_RESET" "$C_PINK" "$V_WARN" "$C_RESET" "$C_RED" "$V_BAD" "$C_RESET"
  return 0
}

# Откат hyprland.lua к версии, которая лежала до нас (если она была)
verify_offer_rollback() {
  local dst="$XDG_CONFIG/hypr/hyprland.lua"
  manifest_get "$dst"
  if [ -n "$MF_BK" ] && [ "$MF_BK" != "-" ] && [ -f "$NL_BACKUPS/$MF_BK" ]; then
    if ask "Откатить hyprland.lua к прежней версии (из бэкапа)?" y; then
      cp -a "$NL_BACKUPS/$MF_BK" "$dst" && manifest_del "$dst" && ok "hyprland.lua восстановлен из бэкапа" && hyprctl reload >/dev/null 2>&1
    fi
  else
    warn "Бэкапа прежнего hyprland.lua нет (его раньше не было). Пришли мне текст ошибок — исправлю."
  fi
  return 0
}

# Запуск отдельно: bash installer/verify.sh
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  NL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; export NL_ROOT
  # shellcheck disable=SC1091
  . "$NL_ROOT/installer/lib.sh"; . "$NL_ROOT/installer/backup.sh"; . "$NL_ROOT/installer/wallpapers.sh"; . "$NL_ROOT/installer/nvidia.sh"
  choices_load; nv_detect; banner; nl_log_init doctor
  say "${C_B}Проверка Northling Arch${C_RESET}"; nl_verify
fi
