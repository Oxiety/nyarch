#!/usr/bin/env bash
# Тема экрана входа SDDM «Northling Midnight».
# Безопасность: сначала ставим файлы темы (ничего не меняет), потом пробуем её в тестовом режиме
# (sddm-greeter --test-mode), и только затем — по подтверждению — включаем через /etc/sddm.conf.d.
# Откат из TTY (Ctrl+Alt+F3):   sudo rm /etc/sddm.conf.d/10-northling-theme.conf   → вернётся прежняя тема.

SDDM_SRC="${NL_ROOT:-.}/themes/sddm/northling-midnight"
SDDM_DST="${NL_SDDM_THEMES:-/usr/share/sddm/themes}/northling-midnight"
SDDM_CONF="${NL_SDDM_CONFD:-/etc/sddm.conf.d}/10-northling-theme.conf"

sddm_have() { have sddm || pacman -Qq sddm >/dev/null 2>&1; }

sddm_files() {
  info "Ставлю файлы темы в $SDDM_DST (нужен sudo; тему пока НЕ включаю)"
  run sudo rm -rf "$SDDM_DST"
  run sudo install -d -m 755 "$SDDM_DST"
  run sudo cp -r "$SDDM_SRC"/. "$SDDM_DST"/
  run sudo chmod -R a+rX "$SDDM_DST"
}

# Пробуем тему в окне. Возвращает 0 — ошибок QML нет, 1 — есть ошибки, 2 — проверить нельзя
sddm_test() {
  local g log
  for g in sddm-greeter-qt6 sddm-greeter; do have "$g" && break; g=""; done
  [ -n "$g" ] || { warn "Нет sddm-greeter — проверить тему нельзя"; return 2; }
  [ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ] || { info "Нет графической сессии — тест темы возможен только из Hyprland: northling sddm test"; return 2; }
  [ -d "$SDDM_DST" ] || { warn "Тема ещё не установлена"; return 2; }
  log="$(mktemp)"
  info "Пробный запуск темы (окно появится на несколько секунд)…"
  QT_QPA_PLATFORM="${WAYLAND_DISPLAY:+wayland}" timeout 6 "$g" --test-mode --theme "$SDDM_DST" >"$log" 2>&1
  local bad; bad="$(grep -E 'Main\.qml|qrc:|ReferenceError|TypeError|is not installed|Cannot assign|unavailable|module .* not' "$log" | head -n 8)"
  if [ -n "$bad" ]; then
    err "В теме найдены ошибки QML — НЕ включаю её:"; printf '%s\n' "$bad" | sed 's/^/      /'
    cp "$log" "$NL_STATE/sddm-test.log" 2>/dev/null && info "Полный вывод: $(tilde "$NL_STATE/sddm-test.log")"
    rm -f "$log"; return 1
  fi
  rm -f "$log"; ok "Тема запустилась без ошибок QML"; return 0
}

sddm_enable() {
  if [ -f /etc/sddm.conf ] && grep -qE '^\s*Current\s*=' /etc/sddm.conf; then
    warn "В /etc/sddm.conf уже задана своя тема (Current=…) — она приоритетнее и перебьёт нашу."
    warn "Убери строку Current= из /etc/sddm.conf (sudo nano) или напиши мне."
  fi
  run sudo install -d -m 755 "$(dirname "$SDDM_CONF")"
  printf '[Theme]\nCurrent=northling-midnight\n' | run sudo tee "$SDDM_CONF" >/dev/null
  ok "Тема включена: $SDDM_CONF (увидишь при следующем выходе/перезагрузке)"
  info "Если экран входа сломался: Ctrl+Alt+F3 → логин → sudo rm $SDDM_CONF → reboot"
}

sddm_disable() { run sudo rm -f "$SDDM_CONF"; ok "Тема SDDM отключена (файлы темы остались в $SDDM_DST)"; }

sddm_sync() { # активные обои → фон экрана входа (SDDM не читает ~/Pictures, поэтому копия)
  local src; src="$(readlink -f "$NL_CONF/wallpaper" 2>/dev/null)"
  [ -f "$src" ] || { warn "Активные обои не найдены"; return 1; }
  [ -d "$SDDM_DST" ] || { warn "Тема не установлена"; return 1; }
  run sudo install -m 644 "$src" "$SDDM_DST/background.png"
  ok "Фон экрана входа обновлён из текущих обоев"
}

sddm_install() {
  [ "${WITH_SDDM:-1}" = 1 ] || { info "Тема SDDM пропущена по твоему выбору"; return 0; }
  sddm_have || { info "SDDM не установлен — тему экрана входа пропускаю"; return 0; }
  [ "$(id -u)" -eq 0 ] && [ "${NL_ALLOW_ROOT:-0}" != 1 ] && return 0
  sddm_files
  [ "$DRY_RUN" = 1 ] && return 0
  local t; sddm_test; t=$?
  if [ -f "$SDDM_CONF" ]; then ok_dim "Тема SDDM уже включена — файлы обновлены"; return 0; fi
  case "$t" in
    0) ask "Включить тему входа Northling Midnight?" y && sddm_enable ;;
    1) info "Тему не включаю, пока не исправим ошибки (пришли мне sddm-test.log)." ;;
    *) ask "Тему не удалось проверить заранее. Включить всё равно? (откат из TTY есть)" n && sddm_enable \
         || info "Позже: northling sddm test  → northling sddm enable" ;;
  esac
  return 0
}

sddm_remove() { # для uninstall.sh
  [ -e "$SDDM_CONF" ] || [ -d "$SDDM_DST" ] || return 0
  info "Тема SDDM: $SDDM_DST и $SDDM_CONF"
  if ask "Удалить тему экрана входа и вернуть прежнюю?" y; then
    run sudo rm -f "$SDDM_CONF"; run sudo rm -rf "$SDDM_DST"; ok "Тема SDDM удалена"
  fi
}

# автономный запуск: northling sddm test|enable|disable|sync
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  NL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; SDDM_SRC="$NL_ROOT/themes/sddm/northling-midnight"
  DRY_RUN=0; ASSUME_YES=0; export DRY_RUN ASSUME_YES
  # shellcheck disable=SC1091
  . "$NL_ROOT/installer/lib.sh"
  case "${1:-}" in
    test)    sddm_test ;;
    enable)  sddm_test; [ $? -eq 1 ] && die "В теме ошибки — не включаю."; sddm_enable ;;
    disable) sddm_disable ;;
    sync)    sddm_sync ;;
    install) WITH_SDDM=1; sddm_install ;;
    *) echo "использование: northling sddm test|enable|disable|sync|install" ;;
  esac
fi
