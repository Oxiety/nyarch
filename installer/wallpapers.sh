#!/usr/bin/env bash
# Этап 11: обои.
#  • Копии обоев проекта — в ~/Pictures/Wallpapers/Northling/{default,furry}/ (существующие файлы НЕ перезаписываются)
#  • Твои личные обои кладёшь прямо в ~/Pictures/Wallpapers/ — проект их не трогает
#  • Активные обои — симлинк ~/.config/northling/wallpaper; меняй его командой northling-wallpaper,
#    системные конфиги править не нужно. Выбор не сбрасывается при обновлении.

WALL_ROOT="$HOME/Pictures/Wallpapers"
WALL_LINK="$NL_CONF/wallpaper"

wall_install() {
  local sub f dst
  run mkdir -p "$WALL_ROOT"
  for sub in default furry; do
    for f in "$NL_ROOT/wallpapers/$sub"/*; do
      [ -f "$f" ] || continue
      dst="$WALL_ROOT/Northling/$sub/${f##*/}"
      if [ -e "$dst" ]; then ok_dim "уже есть: $(tilde "$dst")"; else run install -Dm644 "$f" "$dst" && ok "обои: $(tilde "$dst")"; fi
    done
  done

  if [ -L "$WALL_LINK" ] && [ -e "$WALL_LINK" ]; then
    ok_dim "активные обои уже выбраны: $(tilde "$(readlink -f "$WALL_LINK")")"
    return 0
  fi

  local opts=() paths=() p
  for p in "$WALL_ROOT"/Northling/default/*.png "$NL_ROOT"/wallpapers/default/*.png; do :; done
  for f in "$NL_ROOT"/wallpapers/default/* "$NL_ROOT"/wallpapers/furry/*; do
    [ -f "$f" ] || continue
    sub="$(basename "$(dirname "$f")")"
    paths+=("$WALL_ROOT/Northling/$sub/${f##*/}")
    opts+=("$sub / ${f##*/}")
  done
  if [ -f "$HOME/Pictures/wall.jpg" ]; then paths+=("$HOME/Pictures/wall.jpg"); opts+=("твои старые обои (~/Pictures/wall.jpg)"); fi
  [ ${#paths[@]} -gt 0 ] || { warn "Нет обоев для выбора"; return 0; }

  choose "Какие обои поставить сейчас? (потом меняются командой northling-wallpaper или из меню приложений)" 1 "${opts[@]}"
  run mkdir -p "$NL_CONF"
  run ln -sfn "${paths[$((CHOICE-1))]}" "$WALL_LINK"
  ok "активные обои: ${opts[$((CHOICE-1))]}"
  return 0
}
