#!/usr/bin/env bash
# Проверяет, что update snapshot включает все персональные Zsh-файлы.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export HOME="$TMP/home"
export XDG_CONFIG="$HOME/.config"
export NL_BACKUPS="$HOME/.local/share/northling/backups"
export NL_STATE="$HOME/.local/share/northling"
export NL_MANIFEST="$NL_STATE/manifest.tsv"
export DRY_RUN=0
mkdir -p "$XDG_CONFIG/hypr" "$HOME/.local/share/northling"

printf 'hypr-config\n' > "$XDG_CONFIG/hypr/hyprland.lua"
printf 'personal-zshrc\n' > "$HOME/.zshrc"
printf 'personal-local\n' > "$HOME/.zshrc.local"
printf 'personal-p10k\n' > "$HOME/.p10k.zsh"
printf 'northling-p10k\n' > "$HOME/.p10k.northling.zsh"

info() { :; }
ok() { :; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
tilde() { printf '%s' "$1"; }

# shellcheck disable=SC1091
. "$ROOT/installer/backup.sh"
nl_snapshot

archive="$(find "$NL_BACKUPS" -maxdepth 1 -name 'pre-update-*.tar.gz' -print -quit)"
[ -n "$archive" ] || { echo "FAIL: архив снимка не создан" >&2; exit 1; }

for member in \
  "config/hypr/hyprland.lua" \
  "home/.zshrc" \
  "home/.zshrc.local" \
  "home/.p10k.zsh" \
  "home/.p10k.northling.zsh"; do
  tar -tzf "$archive" | grep -Fxq "$member" || {
    echo "FAIL: в снимке отсутствует $member" >&2
    exit 1
  }
done

[ "$(tar -xOf "$archive" home/.zshrc)" = "personal-zshrc" ]
[ "$(tar -xOf "$archive" home/.zshrc.local)" = "personal-local" ]
[ "$(tar -xOf "$archive" home/.p10k.zsh)" = "personal-p10k" ]
[ "$(tar -xOf "$archive" home/.p10k.northling.zsh)" = "northling-p10k" ]

echo "PASS: конфиги и все персональные Zsh-файлы попали в pre-update snapshot."
