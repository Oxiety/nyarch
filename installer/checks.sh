#!/usr/bin/env bash
# Этап 1–2: проверка системы, прав и окружения. Только чтение.

CHECK_FAILS=0
check_fail() { err "$*"; CHECK_FAILS=$((CHECK_FAILS+1)); }

check_system() {
  # Не root: AUR и конфиги должны собираться/ставиться от обычного пользователя.
  if [ "$(id -u)" -eq 0 ] && [ "${NL_ALLOW_ROOT:-0}" != 1 ]; then
    check_fail "Запущено от root. Запусти от обычного пользователя: bash install.sh (sudo спросится сам, когда нужно)."
  else
    ok "Запуск от обычного пользователя: $(id -un)"
  fi

  # Arch
  local id="" idlike=""
  if [ -r /etc/os-release ]; then
    id="$(. /etc/os-release; echo "${ID:-}")"; idlike="$(. /etc/os-release; echo "${ID_LIKE:-}")"
  fi
  if [ "$id" = arch ]; then
    ok "Arch Linux"
  elif [ "${NL_ALLOW_NONARCH:-0}" = 1 ]; then
    warn "Не Arch (ID=$id) — разрешено переменной NL_ALLOW_NONARCH (режим отладки)."
  elif [[ " $idlike " == *" arch "* ]]; then
    warn "Производная от Arch (ID=$id). Должно работать, но проверялось только на чистом Arch."
  else
    check_fail "Это не Arch Linux (ID=${id:-?}). Проект рассчитан только на Arch."
  fi

  have pacman && ok "pacman найден" || check_fail "pacman не найден."

  local c missing=()
  for c in git curl sha256sum find install sed awk; do have "$c" || missing+=("$c"); done
  if [ ${#missing[@]} -gt 0 ]; then
    check_fail "Не хватает базовых программ: ${missing[*]}  (поставь: sudo pacman -S --needed git curl)"
  else
    ok "Базовые программы на месте (git, curl, find, sed, awk…)"
  fi

  # Файлы проекта целы
  local f bad=0
  for f in packages/core.txt packages/desktop.txt dotfiles/hypr/hyprland.lua dotfiles/waybar/config.jsonc wallpapers/default; do
    [ -e "$NL_ROOT/$f" ] || { check_fail "В репозитории нет $f — похоже, он скачан не полностью."; bad=1; }
  done
  [ $bad = 0 ] && ok "Файлы проекта целы"
}

check_network() {
  if curl -fsS -m 10 -o /dev/null https://archlinux.org 2>/dev/null; then
    ok "Интернет доступен"
  elif [ "$DRY_RUN" = 1 ]; then
    warn "Нет интернета (в пробном запуске это не критично)."
  else
    check_fail "Нет доступа к интернету (archlinux.org не открывается). Включи VPN/сеть и запусти заново."
  fi
}

check_sudo() {
  if [ "$DRY_RUN" = 1 ]; then info "Права sudo не проверяю (пробный запуск)."; return 0; fi
  have sudo || { check_fail "sudo не установлен."; return 0; }
  info "Сейчас спросит пароль sudo (он нужен только для установки пакетов)."
  if sudo -v; then ok "sudo работает"; else check_fail "sudo не сработал (неверный пароль или нет прав). Пользователь должен быть в группе wheel."; fi
}

check_disk() {
  local avail_kb
  avail_kb="$(df --output=avail -k / 2>/dev/null | tail -n1 | tr -d ' ')"
  if [[ "$avail_kb" =~ ^[0-9]+$ ]]; then
    if [ "$avail_kb" -lt 3145728 ]; then
      check_fail "Мало места на / : свободно $((avail_kb/1024)) МБ, нужно хотя бы 3 ГБ."
    else
      ok "Свободно на / : $((avail_kb/1048576)) ГБ"
    fi
  fi
}

check_context() {
  if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    ok "Запущено внутри Hyprland — после установки конфиги применятся без перезахода"
    IN_HYPRLAND=1
  else
    info "Запущено вне Hyprland (TTY/другая сессия): конфиги применятся при следующем входе в Hyprland."
    IN_HYPRLAND=0
  fi
  # Dual boot: просто сообщаем, что трогать нечего.
  if [ -d /sys/firmware/efi ] && have efibootmgr && efibootmgr 2>/dev/null | grep -qi windows; then
    info "Найден Windows (dual boot). Установщик не трогает загрузчик, разделы и Windows."
  fi
}

# Главная: все проверки подряд; при провале — остановка ДО любых изменений
run_checks() {
  CHECK_FAILS=0
  check_system
  check_network
  check_disk
  check_sudo
  check_context
  if [ "$CHECK_FAILS" -gt 0 ]; then
    die "Проверки не пройдены ($CHECK_FAILS). Исправь пункты с ✗ и запусти снова — это безопасно."
  fi
}
