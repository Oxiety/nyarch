#!/usr/bin/env bash
# Этап 10: официальный Visual Studio Code (AUR, не VSCodium) + тема и настройки Northling Midnight.
# Расширения НЕ ставятся — только список рекомендаций (dotfiles/vscode/extensions.txt).

VSC_THEME_SRC="$NL_ROOT/themes/vscode/northling-midnight"
VSC_USER_DIR="$XDG_CONFIG/Code/User"

vscode_install() {
  [ "${WITH_VSCODE:-1}" = 1 ] || { info "VS Code пропущен по твоему выбору"; return 0; }

  if have code; then ok_dim "VS Code уже установлен: $(code --version 2>/dev/null | head -n1)"
  else
    info "Официальный VS Code есть только в AUR (пакет visual-studio-code-bin)."
    pkg_install code || warn "VS Code не установлен — настройки всё равно положу, они подхватятся позже."
  fi

  # настройки редактора: «твой» файл — первый раз кладём (со старым в бэкап), дальше не перезаписываем
  nl_put "$NL_ROOT/dotfiles/vscode/settings.json" "$VSC_USER_DIR/settings.json" 644 seed
  nl_put "$NL_ROOT/dotfiles/vscode/extensions.txt" "$NL_CONF/vscode-extensions.txt" 644 own

  # тема — локальное расширение; папка именуется publisher.name-version
  local ver dest cur
  ver="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$VSC_THEME_SRC/package.json" | head -n1)"
  dest="$HOME/.vscode/extensions/northling.northling-midnight-$ver"
  nl_install_tree "$VSC_THEME_SRC" "$dest" own
  # убрать устаревшие версии НАШЕЙ темы (только папки с нашим именем)
  if [ "$DRY_RUN" != 1 ]; then
    for cur in "$HOME"/.vscode/extensions/northling.northling-midnight-*; do
      [ -d "$cur" ] && [ "$cur" != "$dest" ] && grep -q '"name"[[:space:]]*:[[:space:]]*"northling-midnight"' "$cur/package.json" 2>/dev/null \
        && { rm -rf "$cur"; info "удалена старая версия темы: $(tilde "$cur")"; }
    done
  fi
  info "Рекомендуемые расширения: $(tilde "$NL_CONF/vscode-extensions.txt") (ставь только нужные)."
  return 0
}
