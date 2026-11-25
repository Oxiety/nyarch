#!/usr/bin/env bash
# Раскладка конфигов. Главная функция — nl_put: безопасно кладёт ОДИН файл.
#
# Политики:
#   own  — файл принадлежит проекту: при обновлении перезаписывается (старый — в бэкап)
#   seed — файл «твой» (.zshrc, настройки VS Code…): кладём при первой установке
#          (если там что-то было — сначала бэкап), а потом НЕ трогаем, если ты его менял
#
# Всё, что мы положили, записывается в манифест — по нему работают update/uninstall.

NL_CNT_NEW=0; NL_CNT_UPD=0; NL_CNT_SAME=0; NL_CNT_SKIP=0; NL_CNT_BAK=0

# Подстановка @HOME@ и вырезание NVIDIA-блока (если видеокарты NVIDIA нет)
nl_render() {
  local src="$1" out="$1" base="${1##*/}" strip_nv=0
  [ "$base" = hyprland.lua ] && [ "${HAS_NVIDIA:-1}" = 0 ] && strip_nv=1
  if grep -qs '@HOME@' "$src" || [ $strip_nv = 1 ]; then
    out="$(mktemp "${TMPDIR:-/tmp}/nl-render.XXXXXX")"; NL_TMPS+=("$out")
    sed "s|@HOME@|$HOME|g" "$src" > "$out"
    [ $strip_nv = 1 ] && sed -i '/NORTHLING:NVIDIA:BEGIN/,/NORTHLING:NVIDIA:END/d' "$out"
  fi
  printf '%s' "$out"
}

# nl_put исходник назначение [режим=644] [политика=own]
nl_put() {
  local src="$1" dst="$2" mode="${3:-644}" policy="${4:-own}"
  local file sha cur action need_bk=0 bk="-"
  [ -f "$src" ] || { warn "нет исходника: $src"; return 1; }
  file="$(nl_render "$src")"; sha="$(sha_of "$file")"
  manifest_get "$dst"

  if [ -e "$dst" ] || [ -L "$dst" ]; then
    cur="$(sha_of "$dst")"
    if [ "$cur" = "$sha" ]; then
      NL_CNT_SAME=$((NL_CNT_SAME+1)); ok_dim "без изменений: $(tilde "$dst")"
      if [ -z "$MF_SHA" ]; then manifest_set "$dst" "$sha" "-"; fi
      return 0
    fi
    if [ -n "$MF_SHA" ] && [ "$MF_SHA" = "$cur" ]; then
      action="обновлён"; bk="$MF_BK"                       # это наша прежняя версия, ты её не менял
    elif [ -n "$MF_SHA" ] && [ "$policy" = seed ]; then
      NL_CNT_SKIP=$((NL_CNT_SKIP+1)); warn "ты менял этот файл сам — не трогаю: $(tilde "$dst")"; return 0
    else
      action="заменён, старый сохранён в бэкап"; need_bk=1
    fi
  else
    action="создан"
  fi

  if [ "$DRY_RUN" = 1 ]; then
    printf '  %s[пробный запуск]%s %s: %s\n' "$C_SKY" "$C_RESET" "$action" "$(tilde "$dst")"
    NL_CNT_NEW=$((NL_CNT_NEW+1)); return 0
  fi

  if [ $need_bk = 1 ]; then
    bk="$(nl_backup_file "$dst")" || { err "не удалось сделать бэкап $(tilde "$dst") — файл НЕ тронут"; return 1; }
    NL_CNT_BAK=$((NL_CNT_BAK+1))
  fi
  install -Dm"$mode" "$file" "$dst" || { err "не удалось записать $(tilde "$dst")"; return 1; }
  manifest_set "$dst" "$sha" "$bk"
  case "$action" in создан) NL_CNT_NEW=$((NL_CNT_NEW+1)) ;; *) NL_CNT_UPD=$((NL_CNT_UPD+1)) ;; esac
  ok "$action: $(tilde "$dst")"
}

# Каталог целиком: nl_install_tree откуда куда [политика]
nl_install_tree() {
  local srcdir="$1" destdir="$2" policy="${3:-own}" f rel mode
  [ -d "$srcdir" ] || { warn "нет каталога $srcdir"; return 1; }
  while IFS= read -r -d '' f; do
    rel="${f#"$srcdir"/}"; mode=644; [ -x "$f" ] && mode=755
    nl_put "$f" "$destdir/$rel" "$mode" "$policy"
  done < <(find "$srcdir" -type f -print0 | sort -z)
}

dotfiles_install() {
  local d="$NL_ROOT/dotfiles" c
  for c in hypr waybar rofi kitty swaync fastfetch; do
    nl_install_tree "$d/$c" "$XDG_CONFIG/$c" own
  done
  nl_install_tree "$d/gtk-3.0" "$XDG_CONFIG/gtk-3.0" seed
  nl_install_tree "$d/gtk-4.0" "$XDG_CONFIG/gtk-4.0" seed
  nl_put "$d/qt/kdeglobals" "$XDG_CONFIG/kdeglobals" 644 seed

  nl_install_tree "$NL_ROOT/scripts/bin"      "$HOME/.local/bin"                own
  nl_install_tree "$NL_ROOT/share/applications" "$HOME/.local/share/applications" own
  nl_put "$NL_ROOT/themes/northling-midnight/colors.env" "$NL_CONF/colors.env" 644 own

  if [ "${WITH_ZSH:-1}" = 1 ]; then
    nl_put "$d/zsh/zshrc"    "$HOME/.zshrc"    644 seed
    nl_put "$d/zsh/p10k.zsh" "$HOME/.p10k.zsh" 644 seed
  fi

  # путь к репозиторию — чтобы команда `northling` и ярлыки находили скрипты
  if [ "$DRY_RUN" != 1 ]; then
    mkdir -p "$NL_CONF"; printf '%s\n' "$NL_ROOT" > "$NL_CONF/repo-path"
  fi
}

dotfiles_summary() {
  say ""
  info "Файлы: создано $NL_CNT_NEW, обновлено $NL_CNT_UPD, без изменений $NL_CNT_SAME, пропущено (твои правки) $NL_CNT_SKIP"
  [ "$NL_CNT_BAK" -gt 0 ] && info "Старые версии $NL_CNT_BAK файл(ов) сохранены: $(tilde "$NL_BK_DIR")"
  return 0
}

# Оформление не из файлов: кэш шрифтов, тёмная тема GTK, меню приложений для Dolphin
theme_apply() {
  if have fc-cache; then run fc-cache -f; fi
  if have gsettings; then
    run gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
    run gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'   2>/dev/null || true
    run gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'  2>/dev/null || true
  fi
  # Dolphin без Plasma иначе показывает пустое «Открыть с помощью…»
  if have kbuildsycoca6; then XDG_MENU_PREFIX=arch- run kbuildsycoca6 --noincremental >/dev/null 2>&1 || true; fi
  if have update-desktop-database; then run update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true; fi
  # hyprpolkitagent — окна запроса пароля (Dolphin, монтирование и т.п.)
  if have systemctl && [ "$DRY_RUN" != 1 ]; then systemctl --user enable --now hyprpolkitagent.service >/dev/null 2>&1 || true; fi
  return 0
}
