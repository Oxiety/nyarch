#!/usr/bin/env bash
# Пакеты: чтение списков, проверка наличия, установка.
#
# Формат packages/*.txt — одно имя в строке, «#» — комментарий.
#   имя            — обычный пакет из официальных репозиториев
#   a|b            — альтернативы: берётся установленный, иначе первый, что есть в репо
#   nv:имя         — только если найдена видеокарта NVIDIA
# Bluetooth-компоненты сюда не попадают принципиально.

P_HAVE=(); P_NEW=(); P_MISS=()

pkg_read() { sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^[[:space:]]*$/d' "$1" | awk '{print $1}'; }
pkg_installed() { pacman -Qq "$1" >/dev/null 2>&1; }
pkg_in_repo()   { pacman -Si "$1" >/dev/null 2>&1; }

# имя или a|b → реальное имя пакета (пусто, если нигде нет)
pkg_resolve() {
  local alt c; IFS='|' read -ra alt <<<"$1"
  for c in "${alt[@]}"; do if pkg_installed "$c"; then echo "$c"; return 0; fi; done
  for c in "${alt[@]}"; do if pkg_in_repo "$c"; then echo "$c"; return 0; fi; done
  return 0
}

# Какие списки нужны при текущих ответах
pkg_lists() {
  echo "$NL_ROOT/packages/core.txt"
  echo "$NL_ROOT/packages/desktop.txt"
  [ "${WITH_ZSH:-1}"    = 1 ] && echo "$NL_ROOT/packages/shell.txt"
  [ "${WITH_DEV:-1}"    = 1 ] && echo "$NL_ROOT/packages/development.txt"
  [ "${WITH_DOCKER:-0}" = 1 ] && echo "$NL_ROOT/packages/optional.txt"
  [ "${WITH_WIDGETS:-1}" = 1 ] && echo "$NL_ROOT/packages/widgets.txt"
  [ "${WITH_SDDM:-1}"    = 1 ] && echo "$NL_ROOT/packages/sddm.txt"
  return 0
}

# Разбирает все нужные списки на три группы: P_HAVE / P_NEW / P_MISS
pkg_classify() {
  P_HAVE=(); P_NEW=(); P_MISS=()
  local list entry name real seen=" "
  while IFS= read -r list; do
    [ -f "$list" ] || continue
    while IFS= read -r entry; do
      name="$entry"
      case "$name" in
        nv:*) [ "${HAS_NVIDIA:-0}" = 1 ] || continue; name="${name#nv:}" ;;
      esac
      [[ "$seen" == *" $name "* ]] && continue
      seen+="$name "
      real="$(pkg_resolve "$name")"
      if [ -z "$real" ]; then
        P_MISS+=("$name")
      elif pkg_installed "$real"; then
        P_HAVE+=("$real")
      else
        P_NEW+=("$real")
      fi
    done < <(pkg_read "$list")
  done < <(pkg_lists)
  return 0
}

pkg_report() {
  info "Уже установлено: ${#P_HAVE[@]} (повторно не ставлю)"
  if [ ${#P_NEW[@]} -gt 0 ]; then info "Будет установлено (${#P_NEW[@]}): ${P_NEW[*]}"; else info "Новых пакетов ставить не нужно"; fi
  if [ ${#P_MISS[@]} -gt 0 ]; then
    warn "Нет в официальных репозиториях: ${P_MISS[*]}"
    warn "Эти пункты будут пропущены (возможно, пакет переименовали — напиши мне, поправлю)."
  fi
  return 0
}

pkg_noconfirm() { [ "$ASSUME_YES" = 1 ] && echo "--noconfirm"; return 0; }

# Полное обновление системы. Arch НЕ поддерживает «частичные» обновления,
# поэтому ставить пакеты, не обновив базу и систему, нельзя.
sys_upgrade() {
  info "Arch требует обновлять систему целиком перед установкой новых пакетов."
  info "Может обновиться ядро/драйвер NVIDIA — тогда после установки нужна перезагрузка."
  # shellcheck disable=SC2046
  run sudo pacman -Syu $(pkg_noconfirm)
}

pkg_install_new() {
  [ ${#P_NEW[@]} -eq 0 ] && { ok "Все нужные пакеты уже стоят"; return 0; }
  # shellcheck disable=SC2046
  run sudo pacman -S --needed $(pkg_noconfirm) "${P_NEW[@]}"
}

# ── AUR (только paru, только от обычного пользователя) ──────────────────────
aur_ready() {
  have paru && return 0
  warn "paru не найден. Он нужен только для официального VS Code (AUR)."
  if ask "Собрать и поставить paru из AUR (сборка идёт от твоего пользователя, не от root)?" n; then
    local tmp; tmp="$(mktemp -d)"
    run sudo pacman -S --needed $(pkg_noconfirm) base-devel git || return 1
    run git clone --depth=1 https://aur.archlinux.org/paru-bin.git "$tmp/paru-bin" || return 1
    if [ "$DRY_RUN" = 1 ]; then return 0; fi
    ( cd "$tmp/paru-bin" && makepkg -si $(pkg_noconfirm) ) || return 1
    rm -rf "$tmp"
    have paru; return
  fi
  return 1
}

aur_install() { # имя…
  [ "$(id -u)" -eq 0 ] && [ "${NL_ALLOW_ROOT:-0}" != 1 ] && { err "AUR от root запрещён."; return 1; }
  aur_ready || { warn "AUR-пакеты пропущены: $*"; return 1; }
  # shellcheck disable=SC2046
  run paru -S --needed $(pkg_noconfirm) "$@"
}

pkg_docker_setup() {
  [ "${WITH_DOCKER:-0}" = 1 ] || return 0
  if ask "Включить службу Docker при загрузке?" n; then run sudo systemctl enable --now docker.service; fi
  if ask "Добавить тебя в группу docker (удобно, но по сути даёт права root)?" n; then run sudo usermod -aG docker "$USER"; info "Группа применится после перезахода в систему."; fi
  return 0
}
