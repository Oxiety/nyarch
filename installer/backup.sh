#!/usr/bin/env bash
# Резервные копии и манифест установленных файлов.
#
# Манифест  ~/.local/share/northling/manifest.tsv  — строки:  sha256<TAB>путь<TAB>бэкап
#   sha256 — хэш файла, который положили МЫ (по нему отличаем «наш» файл от изменённого тобой)
#   бэкап  — путь внутри ~/.local/share/northling/backups/ к тому, что лежало ДО нас, или «-»
# Бэкапы лежат зеркально абсолютным путям: backups/<дата>/home/<user>/.config/…

NL_BK_DIR=""
MF_SHA=""; MF_BK=""

nl_backup_session() {
  [ -n "$NL_BK_DIR" ] && return 0
  NL_BK_DIR="$NL_BACKUPS/$(date +%Y%m%d-%H%M%S)"
}

# nl_backup_file /abs/path → печатает ссылку на бэкап (относительно $NL_BACKUPS)
nl_backup_file() {
  local src="$1" rel
  nl_backup_session
  mkdir -p "$NL_BK_DIR$(dirname "$src")"
  cp -a "$src" "$NL_BK_DIR$src" || return 1
  rel="${NL_BK_DIR#"$NL_BACKUPS"/}$src"
  printf '%s' "$rel"
}

manifest_get() {
  MF_SHA=""; MF_BK=""
  [ -f "$NL_MANIFEST" ] || return 0
  local line
  line="$(awk -F'\t' -v p="$1" '$2==p{print $1 "\t" $3; exit}' "$NL_MANIFEST")"
  [ -n "$line" ] || return 0
  MF_SHA="${line%%$'\t'*}"; MF_BK="${line#*$'\t'}"
}

manifest_set() { # путь sha бэкап
  [ "$DRY_RUN" = 1 ] && return 0
  mkdir -p "$NL_STATE"
  local tmp="$NL_MANIFEST.tmp.$$"
  { [ -f "$NL_MANIFEST" ] && awk -F'\t' -v p="$1" '$2!=p' "$NL_MANIFEST"; printf '%s\t%s\t%s\n' "$2" "$1" "$3"; } > "$tmp"
  mv "$tmp" "$NL_MANIFEST"
}

manifest_del() {
  [ "$DRY_RUN" = 1 ] && return 0
  [ -f "$NL_MANIFEST" ] || return 0
  local tmp="$NL_MANIFEST.tmp.$$"
  awk -F'\t' -v p="$1" '$2!=p' "$NL_MANIFEST" > "$tmp"; mv "$tmp" "$NL_MANIFEST"
}

# Снимок всех конфигов проекта одним архивом (для update.sh)
nl_snapshot() {
  local out="$NL_BACKUPS/pre-update-$(date +%Y%m%d-%H%M%S).tar.gz" cfg=() home=() p
  for p in hypr waybar rofi kitty swaync fastfetch gtk-3.0 gtk-4.0 northling kdeglobals; do
    [ -e "$XDG_CONFIG/$p" ] && cfg+=("$p")
  done
  for p in .zshrc .p10k.zsh; do [ -e "$HOME/$p" ] && home+=("$p"); done
  if [ ${#cfg[@]} -eq 0 ] && [ ${#home[@]} -eq 0 ]; then info "Снимок: пока нечего сохранять."; return 0; fi
  if [ "$DRY_RUN" = 1 ]; then info "[пробный запуск] снимок конфигов → $(tilde "$out")"; return 0; fi
  mkdir -p "$NL_BACKUPS"
  # два корня в одном архиве: ~/.config/* и ~/.zshrc, ~/.p10k.zsh (в архиве: config/… и home/…)
  local args=()
  [ ${#cfg[@]}  -gt 0 ] && args+=(--transform 's|^|config/|' -C "$XDG_CONFIG" "${cfg[@]}")
  if tar czf "$out" "${args[@]}" 2>/dev/null; then
    ok "Снимок конфигов: $(tilde "$out")"
  else
    warn "Не удалось создать снимок конфигов (продолжаю: остальные бэкапы делаются по файлам)."
  fi
}
