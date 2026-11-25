#!/usr/bin/env bash
# =============================================================================
# Northling Arch — общая библиотека установщика (подключается через `source`).
# Ничего не делает сама по себе: только функции и переменные.
# =============================================================================

: "${NL_ROOT:?NL_ROOT не задан}"
NL_VERSION="$(cat "$NL_ROOT/VERSION" 2>/dev/null || echo dev)"

XDG_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
NL_STATE="${XDG_DATA_HOME:-$HOME/.local/share}/northling"
NL_CONF="$XDG_CONFIG/northling"
NL_LOGDIR="${XDG_STATE_HOME:-$HOME/.local/state}/northling"
NL_MANIFEST="$NL_STATE/manifest.tsv"
NL_BACKUPS="$NL_STATE/backups"
NL_CHOICES="$NL_CONF/choices.env"

DRY_RUN="${DRY_RUN:-0}"
ASSUME_YES="${ASSUME_YES:-0}"
NL_TMPS=()

# ── Цвета (Northling Midnight). Без терминала / при NO_COLOR — без цветов ───
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_RESET=$'\e[0m'; C_B=$'\e[1m'
  C_LAV=$'\e[38;2;167;139;250m'; C_SKY=$'\e[38;2;130;191;255m'
  C_PINK=$'\e[38;2;210;132;229m'; C_RED=$'\e[38;2;242;122;156m'
  C_GRN=$'\e[38;2;127;224;176m'; C_DIM=$'\e[38;2;158;148;205m'
else
  C_RESET=""; C_B=""; C_LAV=""; C_SKY=""; C_PINK=""; C_RED=""; C_GRN=""; C_DIM=""
fi

# ── Лог ──────────────────────────────────────────────────────────────────────
NL_LOG=/dev/null
nl_log_init() {
  [ "$DRY_RUN" = 1 ] && return 0
  mkdir -p "$NL_LOGDIR" 2>/dev/null || return 0
  NL_LOG="$NL_LOGDIR/$1-$(date +%Y%m%d-%H%M%S).log"
}
log() { printf '%s %s\n' "$(date +%T)" "$*" >> "$NL_LOG" 2>/dev/null || true; }

# ── Вывод ────────────────────────────────────────────────────────────────────
say()    { printf '%s\n' "$*"; log "$*"; }
info()   { printf '  %s•%s %s\n' "$C_DIM" "$C_RESET" "$*"; log "info: $*"; }
ok()     { printf '  %s✓%s %s\n' "$C_GRN" "$C_RESET" "$*"; log "ok: $*"; }
ok_dim() { printf '  %s✓ %s%s\n' "$C_DIM" "$*" "$C_RESET"; log "same: $*"; }
warn()   { printf '  %s!%s %s\n' "$C_PINK" "$C_RESET" "$*"; log "warn: $*"; }
err()    { printf '  %s✗%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; log "ERR: $*"; }
die()    { err "$*"; printf '\n  %sУстановка остановлена. Ничего страшного не произошло: изменения до этой точки перечислены выше.%s\n' "$C_DIM" "$C_RESET" >&2; exit 1; }
step()   { printf '\n%s━━ [%s/12] %s%s\n' "$C_LAV$C_B" "$1" "$2" "$C_RESET"; log "STEP $1 $2"; }
have()   { command -v "$1" >/dev/null 2>&1; }
tilde()  { printf '%s' "${1/#$HOME/~}"; }

banner() {
  printf '\n%s' "$C_LAV$C_B"
  cat <<'EOF'
  ┌──────────────────────────────────────────┐
  │   n.  N O R T H L I N G   A R C H        │
  └──────────────────────────────────────────┘
EOF
  printf '%s  версия %s%s\n' "$C_RESET$C_DIM" "$NL_VERSION" "$C_RESET"
  [ "$DRY_RUN" = 1 ] && printf '  %s▶ ПРОБНЫЙ ЗАПУСК: ничего не будет изменено, только показываю, что произошло бы%s\n' "$C_SKY" "$C_RESET"
  return 0
}

# ── Вопросы ──────────────────────────────────────────────────────────────────
# ask "вопрос" y|n  → код 0 = да. Enter = значение по умолчанию.
# С флагом --yes (или без терминала) молча берёт значение по умолчанию.
ask() {
  local q="$1" def="${2:-y}" hint ans
  if [ "$def" = y ]; then hint="[Д/н]"; else hint="[д/Н]"; fi
  if [ "$ASSUME_YES" = 1 ] || [ ! -t 0 ]; then
    log "ask(авто:$def): $q"
    [ "$def" = y ]; return
  fi
  while true; do
    read -r -p "${C_SKY}?${C_RESET} $q $hint " ans || ans=""
    ans="${ans,,}"
    case "$ans" in
      "")            [ "$def" = y ]; return ;;
      д|да|y|yes)    return 0 ;;
      н|нет|n|no)    return 1 ;;
    esac
    echo "  Ответь «д» или «н» (или просто Enter — это вариант по умолчанию)."
  done
}

# choose "заголовок" номер_по_умолчанию вариант1 вариант2 …  → переменная CHOICE
choose() {
  local title="$1" def="$2" i=1 o ans; shift 2
  printf '%s%s%s\n' "$C_B" "$title" "$C_RESET"
  for o in "$@"; do printf '  %d) %s\n' "$i" "$o"; i=$((i+1)); done
  CHOICE="$def"
  if [ "$ASSUME_YES" = 1 ] || [ ! -t 0 ]; then return 0; fi
  read -r -p "  Номер [$def]: " ans || ans=""
  if [[ "$ans" =~ ^[0-9]+$ ]] && [ "$ans" -ge 1 ] && [ "$ans" -le $# ]; then CHOICE="$ans"; fi
  return 0
}

pause() {
  [ "$ASSUME_YES" = 1 ] || [ ! -t 0 ] && return 0
  read -r -p "  ${C_DIM}Нажми Enter, чтобы продолжить…${C_RESET}" _ || true
}

# run КОМАНДА… — выполняет, а в пробном запуске только печатает
run() {
  if [ "$DRY_RUN" = 1 ]; then
    printf '  %s[пробный запуск]%s %s\n' "$C_SKY" "$C_RESET" "$*"
    return 0
  fi
  log "run: $*"
  "$@"
}

sha_of() { sha256sum "$1" 2>/dev/null | cut -d' ' -f1; }

nl_cleanup() { local f; for f in "${NL_TMPS[@]:-}"; do [ -n "$f" ] && rm -f "$f" 2>/dev/null; done; return 0; }

# ── Сохранённые ответы (чтобы update.sh не спрашивал заново) ────────────────
choices_save() {
  [ "$DRY_RUN" = 1 ] && return 0
  mkdir -p "$NL_CONF"
  {
    echo "# Выбор, сделанный при установке Northling Arch (используется update.sh)"
    echo "WITH_DEV=$WITH_DEV"; echo "WITH_VSCODE=$WITH_VSCODE"
    echo "WITH_ZSH=$WITH_ZSH"; echo "WITH_DOCKER=$WITH_DOCKER"
  } > "$NL_CHOICES"
}
choices_load() {
  # shellcheck disable=SC1090
  [ -f "$NL_CHOICES" ] && . "$NL_CHOICES"
  WITH_DEV="${WITH_DEV:-1}"; WITH_VSCODE="${WITH_VSCODE:-1}"
  WITH_ZSH="${WITH_ZSH:-1}"; WITH_DOCKER="${WITH_DOCKER:-0}"
}
