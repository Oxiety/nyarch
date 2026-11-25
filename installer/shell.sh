#!/usr/bin/env bash
# Этап 9: Zsh + Oh My Zsh + Powerlevel10k.
# Oh My Zsh и Powerlevel10k ставятся официальным способом (git clone) в твой домашний каталог —
# без AUR и без root. Если уже стоят — не трогаются.

OMZ_DIR="${ZSH:-$HOME/.oh-my-zsh}"
P10K_DIR="$OMZ_DIR/custom/themes/powerlevel10k"

shell_install() {
  [ "${WITH_ZSH:-1}" = 1 ] || { info "Zsh пропущен по твоему выбору"; return 0; }

  if [ -d "$OMZ_DIR" ]; then ok_dim "Oh My Zsh уже установлен: $(tilde "$OMZ_DIR")"
  else run git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$OMZ_DIR" || { warn "Не удалось скачать Oh My Zsh — Zsh-этап пропущен"; return 0; }; fi

  if [ -d "$P10K_DIR" ]; then ok_dim "Powerlevel10k уже установлен"
  else run git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR" || warn "Не удалось скачать Powerlevel10k (без него prompt будет обычным)"; fi

  local zsh_path; zsh_path="$(command -v zsh || true)"
  if [ -z "$zsh_path" ] && [ "$DRY_RUN" != 1 ]; then warn "zsh не найден в системе"; return 0; fi
  if [ "$(basename "${SHELL:-}")" = zsh ]; then
    ok_dim "Zsh уже оболочка по умолчанию"
  elif ask "Сделать Zsh оболочкой по умолчанию? (спросит пароль пользователя)" y; then
    run chsh -s "${zsh_path:-/usr/bin/zsh}" || warn "chsh не сработал — можно позже: chsh -s /usr/bin/zsh"
  fi
  info "Шрифт для значков prompt — JetBrainsMono Nerd Font (kitty уже настроен на него)."
  return 0
}
