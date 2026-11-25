#!/usr/bin/env bash
# =============================================================================
# Northling Arch — обновление.      Запуск:   bash update.sh   (или:  northling update)
#
# Что делает: снимок конфигов → (по желанию) свежая версия проекта из GitHub →
# обновление системы → обновление конфигов проекта. Ничего без подтверждения.
# Твои правки в «личных» файлах (.zshrc, настройки VS Code) не перезаписываются,
# твои обои не трогаются. Флаги: -n/--dry-run (пробный), -y/--yes.
# =============================================================================
NL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; export NL_ROOT
set -uo pipefail
DRY_RUN=0; ASSUME_YES=0
for a in "$@"; do
  case "$a" in
    -y|--yes) ASSUME_YES=1 ;; -n|--dry-run) DRY_RUN=1 ;;
    -h|--help) sed -n '2,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Неизвестный параметр: $a" >&2; exit 2 ;;
  esac
done
export DRY_RUN ASSUME_YES
# shellcheck disable=SC1091
. "$NL_ROOT/installer/lib.sh"; . "$NL_ROOT/installer/backup.sh"; . "$NL_ROOT/installer/packages.sh"
nl_log_init update
banner
choices_load

[ "$(id -u)" -eq 0 ] && [ "${NL_ALLOW_ROOT:-0}" != 1 ] && die "Запусти от обычного пользователя, не от root."
say "${C_B}Обновление Northling Arch${C_RESET}"
ask "Начать обновление? (сначала сохраню снимок твоих конфигов)" y || { say "Отменено. Ничего не изменено."; exit 0; }

# 1. Свежая версия проекта
if [ "${NL_UPDATED:-0}" != 1 ] && [ -d "$NL_ROOT/.git" ] && have git; then
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
if have paru && ask "Обновить систему и AUR-пакеты (paru -Syu)?" y; then
  # shellcheck disable=SC2046
  run paru -Syu $(pkg_noconfirm) || warn "Обновление завершилось с ошибкой — смотри сообщения выше."
elif ask "Обновить систему (sudo pacman -Syu)?" y; then
  sys_upgrade || warn "Обновление системы не удалось."
else
  info "Обновление системы пропущено."
fi

# 4. Конфиги проекта
say ""; say "${C_B}Обновление конфигов проекта${C_RESET}"
args=(--update --yes --no-upgrade); [ "$DRY_RUN" = 1 ] && args+=(--dry-run)
bash "$NL_ROOT/install.sh" "${args[@]}"
rc=$?
[ ! -d "/usr/lib/modules/$(uname -r)" ] && warn "Обновилось ядро — перезагрузись."
exit $rc
