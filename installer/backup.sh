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

# Снимок конфигов проекта и пользовательских Zsh-файлов одним архивом.
# Zsh-файлы не принадлежат updater: это страховочная копия, а не источник для восстановления.
nl_snapshot() {
  local out="$NL_BACKUPS/pre-update-$(date +%Y%m%d-%H%M%S).tar.gz"
  local stage p
  local cfg=(hypr waybar rofi kitty swaync fastfetch gtk-3.0 gtk-4.0 northling kdeglobals)
  local home=(.zshrc .zshrc.local .p10k.zsh .p10k.northling.zsh)
  local found=0

  for p in "${cfg[@]}"; do
    [ -e "$XDG_CONFIG/$p" ] && { found=1; break; }
  done
  if [ "$found" = 0 ]; then
    for p in "${home[@]}"; do
      [ -e "$HOME/$p" ] && { found=1; break; }
    done
  fi
  if [ "$found" = 0 ]; then info "Снимок: пока нечего сохранять."; return 0; fi
  if [ "$DRY_RUN" = 1 ]; then
    info "[пробный запуск] снимок конфигов и Zsh → $(tilde "$out")"
    return 0
  fi

  mkdir -p "$NL_BACKUPS" || {
    warn "Не удалось создать каталог бэкапов — снимок пропущен."
    return 0
  }
  stage="$(mktemp -d "${TMPDIR:-/tmp}/northling-snapshot.XXXXXX")" || {
    warn "Не удалось подготовить временный каталог снимка."
    return 0
  }
  mkdir -p "$stage/config" "$stage/home" || {
    warn "Не удалось подготовить структуру снимка."
    rm -rf "$stage"
    return 0
  }

  for p in "${cfg[@]}"; do
    if [ -e "$XDG_CONFIG/$p" ]; then
      cp -a "$XDG_CONFIG/$p" "$stage/config/$p" || {
        warn "Не удалось добавить в снимок: $XDG_CONFIG/$p"
        rm -rf "$stage"
        return 0
      }
    fi
  done
  for p in "${home[@]}"; do
    if [ -e "$HOME/$p" ]; then
      cp -a "$HOME/$p" "$stage/home/$p" || {
        warn "Не удалось добавить в снимок: $HOME/$p"
        rm -rf "$stage"
        return 0
      }
    fi
  done

  if tar czf "$out" -C "$stage" config home 2>/dev/null; then
    ok "Снимок конфигов и Zsh: $(tilde "$out")"
  else
    warn "Не удалось создать снимок конфигов (продолжаю: остальные бэкапы делаются по файлам)."
    rm -f "$out"
  fi
  rm -rf "$stage"
}
