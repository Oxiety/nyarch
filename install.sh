#!/usr/bin/env bash
# =============================================================================
# Northling Arch — установщик.        Запуск:   bash install.sh
#
# Безопасен при повторном запуске: уже сделанное не переделывается,
# всё, что заменяется, сначала сохраняется в бэкап.
# Флаги (необязательно):
#   -n, --dry-run     пробный запуск: показать, что будет сделано, ничего не менять
#   -y, --yes         не задавать вопросы, брать ответы по умолчанию
#       --only=А,Б    выполнить только этапы: packages,dotfiles,theme,shell,vscode,wallpapers,verify
#       --no-upgrade  не делать полное обновление системы (pacman -Syu)
#       --in-session  разрешить запуск из графической сессии (по умолчанию — только из TTY)
#       --reinstall   не предлагать обновление, если проект уже установлен
#   -h, --help        справка
# =============================================================================
NL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; export NL_ROOT
set -uo pipefail

DRY_RUN=0; ASSUME_YES=0; ONLY=""; NO_UPGRADE=0; UPDATE_MODE=0; FAST=0; IN_SESSION_OK=0; REINSTALL=0

usage() { sed -n '2,13p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

for a in "$@"; do
  case "$a" in
    -y|--yes) ASSUME_YES=1 ;;
    -n|--dry-run) DRY_RUN=1 ;;
    --only=*) ONLY="${a#--only=}" ;;
    --no-upgrade) NO_UPGRADE=1 ;;
    --update) UPDATE_MODE=1 ;;            # служебный: вызывается из update.sh
    --fast) FAST=1 ;;                     # служебный: обновление только конфигов/дизайна
    --in-session) IN_SESSION_OK=1 ;;
    --reinstall) REINSTALL=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Неизвестный параметр: $a (справка: bash install.sh --help)" >&2; exit 2 ;;
  esac
done
export DRY_RUN ASSUME_YES IN_SESSION_OK

# shellcheck disable=SC1091
for m in lib checks packages nvidia backup dotfiles shell vscode wallpapers widgets sddm verify; do . "$NL_ROOT/installer/$m.sh"; done
trap nl_cleanup EXIT

stage_on() { [ -z "$ONLY" ] || [[ ",$ONLY," == *",$1,"* ]]; }
if [ "$UPDATE_MODE" = 1 ] && [ -z "$ONLY" ]; then
  if [ "$FAST" = 1 ]; then ONLY="dotfiles,theme,widgets,vscode,wallpapers,sddm,verify"
  else ONLY="packages,dotfiles,theme,widgets,vscode,wallpapers,sddm,verify"; fi
fi

nl_log_init install
banner
choices_load
IN_HYPRLAND=0

# Уже установлено → не переустанавливаем, а предлагаем обновление
if [ "$UPDATE_MODE" != 1 ] && [ "$REINSTALL" != 1 ] && [ "$DRY_RUN" != 1 ] && [ -s "$NL_MANIFEST" ]; then
  info "Northling Arch уже установлен. Для этого есть обновление — переустанавливать с нуля не нужно."
  if ask "Запустить обновление вместо переустановки?" y; then
    a=(); [ "$ASSUME_YES" = 1 ] && a+=(--yes); [ "$IN_SESSION_OK" = 1 ] && a+=(--in-session)
    exec bash "$NL_ROOT/update.sh" "${a[@]}"
  fi
fi

# ── 1. Проверка системы ─────────────────────────────────────────────────────
step 1 "Проверка системы"
run_checks
[ "$FAST" = 1 ] || [ "$DRY_RUN" = 1 ] || guard_session

# ── 2. Проверка пакетов и выбор компонентов ─────────────────────────────────
step 2 "Проверка прав и доступности пакетов"
nv_detect
if [ "$UPDATE_MODE" != 1 ]; then
  say "Что ставим? (Enter — вариант по умолчанию)"
  ask "Инструменты разработчика: Git, GitHub CLI, Node.js, npm?" y && WITH_DEV=1 || WITH_DEV=0
  ask "Официальный Visual Studio Code (из AUR) и тема Northling Midnight?" y && WITH_VSCODE=1 || WITH_VSCODE=0
  ask "Zsh + Oh My Zsh + Powerlevel10k и терминальные утилиты (fzf, zoxide, eza, bat, ripgrep, btop, fastfetch)?" y && WITH_ZSH=1 || WITH_ZSH=0
  ask "Docker?" n && WITH_DOCKER=1 || WITH_DOCKER=0
  ask "Виджеты рабочего стола (часы, календарь, погода, плеер, нагрузка, сеть)?" y && WITH_WIDGETS=1 || WITH_WIDGETS=0
  ask "Тема экрана входа SDDM «Northling Midnight»? (включение спросим отдельно, с проверкой)" y && WITH_SDDM=1 || WITH_SDDM=0
  ask "Центр управления, снимки системы (Timeshift), KDE Connect, ночной режим?" y && WITH_EXTRAS=1 || WITH_EXTRAS=0
  ask "Игры: Steam, MangoHud, GameMode (нужен включённый multilib)?" n && WITH_GAMING=1 || WITH_GAMING=0
fi
pkg_classify
pkg_report

# ── 3. NVIDIA ───────────────────────────────────────────────────────────────
step 3 "Проверка NVIDIA (только диагностика, драйвер не трогаю)"
check_nvidia
# после проверки список мог измениться (nv:-пакеты)
pkg_classify

# ── План и подтверждение ────────────────────────────────────────────────────
if [ "$UPDATE_MODE" != 1 ]; then
  printf '\n%s━━ ПЛАН ДЕЙСТВИЙ%s\n' "$C_LAV$C_B" "$C_RESET"
  stage_on packages && {
    [ "$NO_UPGRADE" = 1 ] || info "Полное обновление системы (sudo pacman -Syu) — обязательно перед установкой пакетов в Arch"
    info "Установка пакетов: ${#P_NEW[@]} новых (уже стоит: ${#P_HAVE[@]})"
  }
  [ "$WITH_VSCODE" = 1 ] && info "VS Code: официальный (AUR visual-studio-code-bin) или Code - OSS из репозитория — спрошу на своём этапе"
  stage_on dotfiles && info "Конфиги: Hyprland (Lua), Waybar, Rofi, Kitty, SwayNC, Hyprlock/Hypridle, GTK/Qt, fastfetch, команда northling"
  [ "$WITH_ZSH" = 1 ] && info "Zsh: Oh My Zsh и Powerlevel10k в твой домашний каталог, тема Northling Midnight"
  info "Обои: 3 стандартных + 2 фурри → ~/Pictures/Wallpapers/Northling (твои файлы не перезаписываются)"
  info "Перед заменой любого файла — копия в ~/.local/share/northling/backups/"
  info "НЕ трогаю: Windows и загрузчик, драйвер NVIDIA, личные документы, твои обои"
  echo
  ask "Всё верно, начинаем?" y || die "Отменено тобой — ничего не изменено."
fi

# ── 4–5. Система и пакеты ───────────────────────────────────────────────────
if stage_on packages; then
  step 4 "Обновление системы"
  if [ "$NO_UPGRADE" = 1 ]; then
    info "Пропущено (--no-upgrade)."
  elif ask "Выполнить полное обновление системы (sudo pacman -Syu)?" y; then
    sys_upgrade || die "Обновление системы не удалось. Пакеты не устанавливаю: частичные обновления в Arch ломают систему."
    pkg_classify
  else
    die "Без обновления системы пакеты ставить небезопасно (в Arch нет «частичных» обновлений). Запусти позже."
  fi

  step 5 "Установка пакетов"
  pkg_report
  if [ ${#P_MISS[@]} -gt 0 ] && ! ask "Продолжить, пропустив отсутствующие пакеты?" y; then die "Остановлено: поправим имена пакетов и повторим."; fi
  pkg_install_new || die "Установка пакетов не удалась (см. сообщения pacman выше). Ничего из конфигов ещё не менялось."
  pkg_docker_setup
  # старый mako (если был) мешает SwayNC — закрываем процесс, пакет не удаляем
  have pkill && [ "$DRY_RUN" != 1 ] && pkill -x mako 2>/dev/null
fi

# ── 6. Конфиги ──────────────────────────────────────────────────────────────
if stage_on dotfiles; then
  step 6 "Установка конфигураций"
  dotfiles_install
  dotfiles_summary
fi

# ── 7. Тема ─────────────────────────────────────────────────────────────────
if stage_on theme; then
  step 7 "Установка темы Northling Midnight"
  theme_apply
  ok "Тема применена (палитра: ~/.config/northling/colors.env)"
fi
if stage_on sddm; then sddm_install; fi

# ── 8. Виджеты ──────────────────────────────────────────────────────────────
step 8 "Виджеты рабочего стола"
if stage_on widgets; then widgets_install; fi

# ── 9–11. Zsh, VS Code, обои ────────────────────────────────────────────────
if stage_on shell;      then step 9  "Настройка Zsh";       shell_install; fi
if stage_on vscode;     then step 10 "Настройка VS Code";   vscode_install; fi
if stage_on wallpapers; then step 11 "Настройка обоев";     wall_install; fi

# ── 12. Применение и проверка ───────────────────────────────────────────────
if stage_on verify; then
  step 12 "Проверка результата"
  restart_bg() { # имя команда…
    local n="$1"; shift
    if [ "$DRY_RUN" = 1 ]; then printf '  %s[пробный запуск]%s перезапуск %s\n' "$C_SKY" "$C_RESET" "$n"; return 0; fi
    pkill -x "$n" 2>/dev/null; sleep 0.3
    have "$1" && setsid -f "$@" >/dev/null 2>&1 </dev/null
  }
  if [ "$IN_HYPRLAND" = 1 ]; then
    info "Применяю конфиги в живой сессии…"
    run hyprctl reload
    restart_bg swaync swaync
    restart_bg waybar waybar
    [ "${WITH_WIDGETS:-1}" = 1 ] && [ -x "$HOME/.local/bin/northling-widgets" ] && { [ "$DRY_RUN" = 1 ] || "$HOME/.local/bin/northling-widgets" restart >/dev/null 2>&1; }
    [ -e "$WALL_LINK" ] && restart_bg swaybg swaybg -i "$WALL_LINK" -m fill
    restart_bg hypridle hypridle
    if [ "$DRY_RUN" != 1 ]; then
      pgrep -f 'wl-paste --type text' >/dev/null || setsid -f wl-paste --type text  --watch cliphist store >/dev/null 2>&1 </dev/null
      pgrep -f 'wl-paste --type image' >/dev/null || setsid -f wl-paste --type image --watch cliphist store >/dev/null 2>&1 </dev/null
      sleep 1.5
    fi
  fi
  nl_verify
fi

choices_save

# ── Итог ────────────────────────────────────────────────────────────────────
printf '\n%s━━ ГОТОВО%s\n' "$C_GRN$C_B" "$C_RESET"
if [ "$DRY_RUN" = 1 ]; then
  info "Это был пробный запуск. Чтобы установить по-настоящему: bash install.sh"
else
  [ ! -d "/usr/lib/modules/$(uname -r)" ] && warn "Ядро было обновлено — ПЕРЕЗАГРУЗИСЬ перед тем, как пользоваться системой."
  if [ "$IN_HYPRLAND" = 1 ]; then
    info "Конфиги уже применены. Если что-то выглядит криво — выйди из сессии (Super+M) и войди снова."
  else
    info "Войди в Hyprland через экран входа — всё подхватится."
  fi
  [ "${WITH_ZSH:-0}" = 1 ] && info "Zsh станет основным после перезахода. При первом запуске p10k может предложить мастер настройки — можно отказаться, тема уже задана."
  say ""
  say "${C_B}Горячие клавиши${C_RESET}"
  say "  Super+Q терминал · Super+E файлы · Super+R поиск приложений · Super+C закрыть окно"
  say "  Super+L блокировка · Super+V история буфера · Super+1…0 рабочие столы · Print скриншот"
  say "  Alt+Shift раскладка RU/EN · Super+M выход из сессии"
  say ""
  say "${C_B}Если что-то пошло не так${C_RESET}"
  say "  • Проверка:            northling doctor    (или Super+R → «Northling: проверка»)"
  say "  • Обновление дизайна:  northling update    (быстро и безопасно; пакеты и система — northling update --full из TTY)"
  say "  • Сменить обои:        northling wallpaper (или Super+R → «Northling: обои»)"
  say "  • Откат всего:         bash $(tilde "$NL_ROOT")/uninstall.sh   (вернёт твои прежние файлы из бэкапа)"
  say "  • Бэкапы лежат тут:    ~/.local/share/northling/backups/"
  say "  • Журнал установки:    $(tilde "$NL_LOG")"
fi
exit 0
