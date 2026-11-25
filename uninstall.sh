#!/usr/bin/env bash
# =============================================================================
# Northling Arch — удаление конфигураций проекта.   Запуск:  bash uninstall.sh
#
# Удаляет ТОЛЬКО файлы, которые положил проект и которые ты не менял, и возвращает
# на место то, что лежало там раньше (из бэкапа). Всё остальное — не трогает:
#   • личные документы и файлы, • твои обои (в т.ч. копии из проекта),
#   • файлы проекта, которые ты изменил сам (их оставляет и сообщает),
#   • установленные пакеты (их удаление — отдельное решение, список внизу).
# Перед удалением показывает список и спрашивает подтверждение.
# Флаги: -n/--dry-run (только показать), -y/--yes.
# =============================================================================
NL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; export NL_ROOT
set -uo pipefail
DRY_RUN=0; ASSUME_YES=0
for a in "$@"; do
  case "$a" in
    -y|--yes) ASSUME_YES=1 ;; -n|--dry-run) DRY_RUN=1 ;;
    -h|--help) sed -n '2,13p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Неизвестный параметр: $a" >&2; exit 2 ;;
  esac
done
export DRY_RUN ASSUME_YES
# shellcheck disable=SC1091
. "$NL_ROOT/installer/lib.sh"; . "$NL_ROOT/installer/backup.sh"
nl_log_init uninstall
banner
say "${C_B}Удаление конфигураций Northling Arch${C_RESET}"
[ "$(id -u)" -eq 0 ] && [ "${NL_ALLOW_ROOT:-0}" != 1 ] && die "Запусти от обычного пользователя, не от root."

if [ ! -s "$NL_MANIFEST" ]; then
  say ""; info "Манифест установки не найден ($(tilde "$NL_MANIFEST")) — проект либо не ставился, либо уже удалён. Нечего делать."
  exit 0
fi

REMOVE=(); RESTORE=(); KEEP=(); GONE=()
while IFS=$'\t' read -r sha path bk; do
  [ -n "$path" ] || continue
  if [ ! -e "$path" ] && [ ! -L "$path" ]; then GONE+=("$path"); REMOVE+=("$path|$bk|gone"); continue; fi
  if [ "$(sha_of "$path")" = "$sha" ]; then
    REMOVE+=("$path|$bk|rm")
  else
    KEEP+=("$path")
  fi
done < "$NL_MANIFEST"

say ""
say "${C_B}Что будет сделано${C_RESET}"
n_rm=0; n_rs=0
for e in "${REMOVE[@]:-}"; do
  [ -n "$e" ] || continue
  IFS='|' read -r p bk kind <<<"$e"
  [ "$kind" = gone ] && continue
  if [ "$bk" != "-" ] && [ -f "$NL_BACKUPS/$bk" ]; then info "вернуть прежний файл вместо нашего: $(tilde "$p")"; n_rs=$((n_rs+1))
  else info "удалить: $(tilde "$p")"; n_rm=$((n_rm+1)); fi
done
for p in "${KEEP[@]:-}"; do [ -n "$p" ] && warn "оставлю (ты менял его сам): $(tilde "$p")"; done
[ ${#GONE[@]} -gt 0 ] && info "уже удалены тобой: ${#GONE[@]} (просто уберу из списка)"
info "Итого: удалить $n_rm, вернуть из бэкапа $n_rs"
info "НЕ будут тронуты: личные файлы, твои обои, установленные пакеты, Windows и загрузчик"
echo
ask "Удалить конфигурации проекта?" n || { say "Отменено. Ничего не изменено."; exit 0; }

for e in "${REMOVE[@]:-}"; do
  [ -n "$e" ] || continue
  IFS='|' read -r p bk kind <<<"$e"
  if [ "$kind" = rm ]; then run rm -f "$p"; fi
  if [ "$kind" != gone ] && [ "$bk" != "-" ] && [ -f "$NL_BACKUPS/$bk" ]; then
    run mkdir -p "$(dirname "$p")"; run cp -a "$NL_BACKUPS/$bk" "$p" && ok "возвращён прежний: $(tilde "$p")"
  elif [ "$kind" = rm ]; then
    ok "удалён: $(tilde "$p")"
  fi
  [ "$DRY_RUN" = 1 ] || manifest_del "$p"
  # пустые каталоги внутри ~/.config и ~/.local убираем аккуратно
  [ "$DRY_RUN" = 1 ] || rmdir -p --ignore-fail-on-non-empty "$(dirname "$p")" 2>/dev/null || true
done

# служебные файлы проекта (выбор при установке, путь к репозиторию, симлинк обоев)
if [ "$DRY_RUN" != 1 ]; then
  rm -f "$NL_CONF/choices.env" "$NL_CONF/repo-path" "$NL_CONF/wallpaper"
  rmdir "$NL_CONF" 2>/dev/null || true
fi

[ "$DRY_RUN" = 1 ] || pkill -f northling_widgets.py 2>/dev/null || true
# shellcheck disable=SC1091
. "$NL_ROOT/installer/sddm.sh"; sddm_remove

if [ -d "$HOME/.oh-my-zsh" ] && ask "Удалить также Oh My Zsh и Powerlevel10k (~/.oh-my-zsh)?" n; then run rm -rf "$HOME/.oh-my-zsh"; fi

say ""
ok "Готово. Выйди из сессии и войди снова, чтобы вернулись прежние настройки."
info "Бэкапы остались: $(tilde "$NL_BACKUPS") (удали вручную, когда убедишься, что всё в порядке)."
info "Пакеты не удалялись. Если нужно убрать то, что поставил проект, — скажи, дам точный список."
exit 0
