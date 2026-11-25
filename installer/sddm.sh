#!/usr/bin/env bash
# Тема экрана входа SDDM «Northling Midnight».
# Безопасность: ставим файлы темы (ничего не меняет) → пробный запуск greeter (--test-mode) → включение по подтверждению.
# Включение = файл /etc/sddm.conf.d/zz-northling-theme.conf (имя с «zz», чтобы идти последним среди .conf.d).
# Если другая настройка уже задаёт тему (Current=… в /etc/sddm.conf или другом файле) — она перебьёт нашу,
# поэтому такие строки аккуратно закомментируются (с бэкапом), а при отключении темы вернутся.
# Откат из TTY (Ctrl+Alt+F3):   northling sddm disable    (или:  sudo rm /etc/sddm.conf.d/zz-northling-theme.conf)

SDDM_SRC="${NL_ROOT:-.}/themes/sddm/northling-midnight"
SDDM_ETC="${NL_SDDM_ETC:-/etc}"
SDDM_DST="${NL_SDDM_THEMES:-/usr/share/sddm/themes}/northling-midnight"
SDDM_CONF="$SDDM_ETC/sddm.conf.d/zz-northling-theme.conf"
SDDM_OLD_CONF="$SDDM_ETC/sddm.conf.d/10-northling-theme.conf"     # имя из beta.2 — чистим
SDDM_BAK="${NL_STATE:-$HOME/.local/share/northling}/sddm-backup"
SDDM_NEUT="$SDDM_BAK/neutralized.tsv"

sddm_have() { have sddm || pacman -Qq sddm >/dev/null 2>&1; }

sddm_files() {
  info "Ставлю файлы темы в $SDDM_DST (нужен sudo; тему пока НЕ включаю)"
  run sudo rm -rf "$SDDM_DST"
  run sudo install -d -m 755 "$SDDM_DST"
  run sudo cp -r "$SDDM_SRC"/. "$SDDM_DST"/
  run sudo chmod -R a+rX "$SDDM_DST"
}

# Пробуем тему в окне. 0 — ошибок QML нет, 1 — есть, 2 — проверить нельзя
sddm_test() {
  local g log bad
  for g in sddm-greeter-qt6 sddm-greeter; do have "$g" && break; g=""; done
  [ -n "$g" ] || { warn "Нет sddm-greeter — проверить тему нельзя"; return 2; }
  [ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ] || { info "Нет графической сессии — тест темы возможен только из Hyprland: northling sddm test"; return 2; }
  [ -d "$SDDM_DST" ] || { warn "Тема ещё не установлена"; return 2; }
  log="$(mktemp)"
  info "Пробный запуск темы (окно появится на несколько секунд)…"
  QT_QPA_PLATFORM="${WAYLAND_DISPLAY:+wayland}" timeout 6 "$g" --test-mode --theme "$SDDM_DST" >"$log" 2>&1
  bad="$(grep -E 'Main\.qml:[0-9]+|ReferenceError|TypeError|is not a type|module "[^"]+" is not installed|File not found' "$log" | head -n 8)"
  if [ -n "$bad" ]; then
    err "В теме найдены ошибки QML:"; printf '%s\n' "$bad" | sed 's/^/      /'
    mkdir -p "$NL_STATE"; cp "$log" "$NL_STATE/sddm-test.log" 2>/dev/null && info "Полный вывод: $(tilde "$NL_STATE/sddm-test.log")"
    rm -f "$log"; return 1
  fi
  rm -f "$log"; ok "Тема запустилась без ошибок QML"; return 0
}

# Файлы, где другая настройка уже задаёт тему (кроме нашего)
sddm_conflicts() {
  local f
  for f in "$SDDM_ETC/sddm.conf" "$SDDM_ETC"/sddm.conf.d/*.conf; do
    [ -f "$f" ] || continue
    [ "$f" = "$SDDM_CONF" ] && continue
    grep -qE '^[[:space:]]*Current[[:space:]]*=' "$f" 2>/dev/null && echo "$f"
  done
}

sddm_neutralize() {
  local f c; c="$(sddm_conflicts)"
  [ -n "$c" ] || return 0
  warn "Другие настройки SDDM уже задают тему и перебьют нашу:"
  while IFS= read -r f; do
    [ -n "$f" ] && { printf '      %s   → %s\n' "$f" "$(grep -hE '^[[:space:]]*Current[[:space:]]*=' "$f" | head -n1)"; }
  done <<<"$c"
  if ! ask "Закомментировать эти строки Current= (бэкап сохраню, при отключении темы верну)?" y; then
    warn "Оставил как есть — наша тема не применится, пока эти строки активны."; return 0
  fi
  run mkdir -p "$SDDM_BAK"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    local bak; bak="$SDDM_BAK/$(basename "$f").$(date +%Y%m%d-%H%M%S).bak"
    run sudo cp -p "$f" "$bak"
    run sudo chmod a+r "$bak"
    run sudo sed -i -E 's/^([[:space:]]*Current[[:space:]]*=.*)$/# northling: \1/' "$f"
    [ "$DRY_RUN" = 1 ] || printf '%s\t%s\n' "$f" "$bak" >> "$SDDM_NEUT"
    ok "закомментировано в $f (бэкап: $(tilde "$bak"))"
  done <<<"$c"
}

sddm_enable() {
  run sudo rm -f "$SDDM_OLD_CONF"
  sddm_neutralize
  run sudo install -d -m 755 "$(dirname "$SDDM_CONF")"
  printf '[Theme]\nCurrent=northling-midnight\n' | run sudo tee "$SDDM_CONF" >/dev/null
  ok "Тема включена: $SDDM_CONF (увидишь при следующем выходе из сессии или перезагрузке)"
  info "Если экран входа сломался: Ctrl+Alt+F3 → логин → northling sddm disable → reboot"
}

sddm_restore_neutralized() {
  [ -s "$SDDM_NEUT" ] || return 0
  local f bak
  while IFS=$'\t' read -r f bak; do
    [ -f "$bak" ] && run sudo cp -p "$bak" "$f" && ok "вернул прежние настройки: $f"
  done < "$SDDM_NEUT"
  run rm -f "$SDDM_NEUT"
}

sddm_disable() {
  run sudo rm -f "$SDDM_CONF" "$SDDM_OLD_CONF"
  sddm_restore_neutralized
  ok "Тема SDDM отключена (файлы темы остались в $SDDM_DST)"
}

sddm_sync() { # активные обои → фон экрана входа (SDDM не читает ~/Pictures, поэтому копия)
  local src; src="$(readlink -f "$NL_CONF/wallpaper" 2>/dev/null)"
  [ -f "$src" ] || { warn "Активные обои не найдены"; return 1; }
  [ -d "$SDDM_DST" ] || { warn "Тема не установлена"; return 1; }
  run sudo install -m 644 "$src" "$SDDM_DST/background.png"
  ok "Фон экрана входа обновлён из текущих обоев"
}

sddm_installed_state() { [ -f "$SDDM_CONF" ]; }

sddm_install() {
  [ "${WITH_SDDM:-1}" = 1 ] || { info "Тема SDDM пропущена по твоему выбору"; return 0; }
  sddm_have || { info "SDDM не установлен — тему экрана входа пропускаю"; return 0; }
  [ "$(id -u)" -eq 0 ] && [ "${NL_ALLOW_ROOT:-0}" != 1 ] && return 0
  sddm_files
  [ "$DRY_RUN" = 1 ] && return 0
  if sddm_installed_state; then
    # уже включена: убедимся, что её никто не перебивает
    [ -n "$(sddm_conflicts)" ] && sddm_neutralize
    ok_dim "Тема SDDM включена — файлы обновлены"; return 0
  fi
  local t; sddm_test; t=$?
  case "$t" in
    0) ask "Включить тему входа Northling Midnight?" y && sddm_enable ;;
    1) info "Тему не включаю, пока не исправим ошибки (пришли мне $(tilde "$NL_STATE/sddm-test.log"))." ;;
    *) ask "Тему не удалось проверить заранее. Включить всё равно? (откат из TTY есть)" n && sddm_enable \
         || info "Позже, из Hyprland:  northling sddm test  →  northling sddm enable" ;;
  esac
  return 0
}

sddm_remove() { # для uninstall.sh
  [ -e "$SDDM_CONF" ] || [ -d "$SDDM_DST" ] || [ -s "$SDDM_NEUT" ] || return 0
  info "Тема SDDM: $SDDM_DST и $SDDM_CONF"
  if ask "Удалить тему экрана входа и вернуть прежнюю?" y; then
    run sudo rm -f "$SDDM_CONF" "$SDDM_OLD_CONF"; sddm_restore_neutralized; run sudo rm -rf "$SDDM_DST"; ok "Тема SDDM удалена"
  fi
}

# автономный запуск: northling sddm test|enable|disable|sync|install|status
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  NL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; SDDM_SRC="$NL_ROOT/themes/sddm/northling-midnight"
  DRY_RUN=0; ASSUME_YES=0; export DRY_RUN ASSUME_YES
  # shellcheck disable=SC1091
  . "$NL_ROOT/installer/lib.sh"
  SDDM_BAK="$NL_STATE/sddm-backup"; SDDM_NEUT="$SDDM_BAK/neutralized.tsv"
  case "${1:-}" in
    test)    sddm_test ;;
    enable)
      [ -d "$SDDM_DST" ] || sddm_files
      sddm_test; t=$?
      if [ "$t" -eq 1 ] && [ "${2:-}" != "--force" ]; then die "В теме ошибки — не включаю. (Если очень надо: northling sddm enable --force)"; fi
      sddm_enable ;;
    disable) sddm_disable ;;
    sync)    sddm_sync ;;
    install) WITH_SDDM=1; sddm_install ;;
    status)
      [ -d "$SDDM_DST" ] && ok "файлы темы: $SDDM_DST" || warn "тема не установлена"
      sddm_installed_state && ok "тема включена ($SDDM_CONF)" || info "тема не включена"
      c="$(sddm_conflicts)"; [ -n "$c" ] && { warn "Current= задан в других файлах (перебьёт нашу тему):"; printf '   %s\n' $c; } ;;
    *) echo "использование: northling sddm test|enable|disable|sync|install|status" ;;
  esac
fi
