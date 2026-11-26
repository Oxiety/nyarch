#!/usr/bin/env bash
# =============================================================================
# Northling Arch — обновление.      Запуск:   bash update.sh   (или:  northling update)
#
# Два режима:
#   быстрый (по умолчанию) — свежий дизайн и конфиги проекта. Безопасно запускать прямо из Hyprland.
#   полный (--full)        — ещё и обновление системы/пакетов. Запускай из TTY (Ctrl+Alt+F3).
# Всегда: снимок конфигов → (по желанию) свежая версия из GitHub → применение. Ничего без подтверждения.
# Твои правки в «личных» файлах (.zshrc, настройки VS Code) не перезаписываются,
# твои обои не трогаются. Флаги: --full, --fast, --no-pull, --in-session, -n/--dry-run, -y/--yes.
# =============================================================================
NL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; export NL_ROOT
set -uo pipefail
DRY_RUN=0; ASSUME_YES=0; MODE=""; NO_PULL=0; IN_SESSION_OK=0
for a in "$@"; do
  case "$a" in
    -y|--yes) ASSUME_YES=1 ;; -n|--dry-run) DRY_RUN=1 ;;
    --full) MODE=full ;; --fast) MODE=fast ;; --no-pull) NO_PULL=1 ;; --in-session) IN_SESSION_OK=1 ;;
    -h|--help) sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Неизвестный параметр: $a" >&2; exit 2 ;;
  esac
done
export DRY_RUN ASSUME_YES IN_SESSION_OK
# shellcheck disable=SC1091
. "$NL_ROOT/installer/lib.sh"; . "$NL_ROOT/installer/backup.sh"; . "$NL_ROOT/installer/packages.sh"; . "$NL_ROOT/installer/checks.sh"
nl_log_init update
banner
choices_load

[ "$(id -u)" -eq 0 ] && [ "${NL_ALLOW_ROOT:-0}" != 1 ] && die "Запусти от обычного пользователя, не от root."
say "${C_B}Обновление Northling Arch${C_RESET}"
if [ ! -s "$NL_MANIFEST" ]; then
  warn "Northling Arch ещё не установлен — обновлять нечего. Сначала: bash $(tilde "$NL_ROOT")/install.sh (из TTY)."
  exit 1
fi
if [ -z "$MODE" ]; then
  choose "Что обновляем?" 1 "Только дизайн и конфиги проекта (быстро, безопасно из Hyprland)" "Всё: ещё система и пакеты (запускай из TTY — Ctrl+Alt+F3)"
  [ "$CHOICE" = 2 ] && MODE=full || MODE=fast
fi
ask "Начать обновление ($MODE)? Сначала сохраню снимок твоих конфигов." y || { say "Отменено. Ничего не изменено."; exit 0; }
[ "$MODE" = full ] && [ "$DRY_RUN" != 1 ] && guard_session

# 1. Свежая версия проекта
if [ "${NL_UPDATED:-0}" != 1 ] && [ "$NO_PULL" != 1 ] && [ -d "$NL_ROOT/.git" ] && have git; then
  if ask "Скачать свежую версию Northling Arch из GitHub?" y; then
    before="$(git -C "$NL_ROOT" rev-parse HEAD 2>/dev/null)"
    if run git -C "$NL_ROOT" pull --ff-only; then
      after="$(git -C "$NL_ROOT" rev-parse HEAD 2>/dev/null)"
      if [ "$DRY_RUN" != 1 ] && [ "$before" != "$after" ]; then
        ok "Получена новая версия — перезапускаю обновление уже с ней"
        NL_UPDATED=1 exec bash "$NL_ROOT/update.sh" "$@"
      fi
    else
      warn "git pull не прошёл (в папке проекта есть локальные правки?). Продолжаю с текущей версией; напиши мне вывод ошибки."
    fi
  fi
fi

# 2. Снимок
say ""; say "${C_B}Снимок конфигов${C_RESET}"
nl_snapshot

# 3. Система
say ""; say "${C_B}Обновление системы${C_RESET}"
if [ "$MODE" = full ] && [ "$DRY_RUN" != 1 ] && have timeshift && [ -f /etc/timeshift/timeshift.json ] \
   && grep -Eq '"backup_device_uuid" *: *"[^"]+"' /etc/timeshift/timeshift.json; then
  info "Делаю снимок системы перед обновлением (Timeshift)…"
  sudo timeshift --create --comments "перед northling update" --tags D >/dev/null 2>&1 && ok "Снимок системы создан (откат: northling snapshot restore)" || warn "Снимок не удался — продолжаю без него."
elif [ "$MODE" = full ] && ! have timeshift; then
  info "Совет: Timeshift даст откат системы после неудачного обновления (northling update --full поставит его)."
fi
if [ "$MODE" != full ]; then
  info "Пропущено (быстрый режим). Систему и пакеты обновляет:  northling update --full  — из TTY."
elif have paru && ask "Обновить систему и AUR-пакеты (paru -Syu)?" y; then
  # shellcheck disable=SC2046
  run paru -Syu $(pkg_noconfirm) || warn "Обновление завершилось с ошибкой — смотри сообщения выше."
elif ask "Обновить систему (sudo pacman -Syu)?" y; then
  sys_upgrade || warn "Обновление системы не удалось."
else
  info "Обновление системы пропущено."
fi

# 4. Конфиги проекта
say ""; say "${C_B}Обновление конфигов проекта${C_RESET}"
args=(--update --yes --no-upgrade --in-session); [ "$MODE" != full ] && args+=(--fast); [ "$DRY_RUN" = 1 ] && args+=(--dry-run)
bash "$NL_ROOT/install.sh" "${args[@]}"
rc=$?
[ "$MODE" = full ] && [ ! -d "/usr/lib/modules/$(uname -r)" ] && warn "Обновилось ядро — перезагрузись."
exit $rc
