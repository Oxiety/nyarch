#!/usr/bin/env bash
# nyarch dotfiles installer. Safe to re-run: existing files are backed up with a timestamp.
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"

echo "==> Пакеты (спросит пароль sudo)"
sudo pacman -S --needed --noconfirm \
    waybar swaybg kitty wofi mako \
    thunar thunar-volman gvfs \
    grim slurp wl-clipboard \
    starship fastfetch papirus-icon-theme \
    ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji

echo "==> Панели настроек (по одной, чтобы один сбой не ломал остальное)"
for p in pavucontrol network-manager-applet nm-connection-editor blueman nwg-look hyprpolkitagent udiskie; do
    sudo pacman -S --needed --noconfirm "$p" || echo "    пропустил $p"
done
systemctl --user enable --now hyprpolkitagent.service 2>/dev/null || true

echo "==> Конфиги"
find "$DIR/dotfiles" -type f | while read -r src; do
    rel="${src#$DIR/dotfiles/}"
    dst="$HOME/.config/$rel"
    mkdir -p "$(dirname "$dst")"
    if [ -e "$dst" ] && ! cmp -s "$src" "$dst"; then
        cp -a "$dst" "$dst.bak.$STAMP"
        echo "    бэкап: $dst.bak.$STAMP"
    fi
    cp "$src" "$dst"
done
chmod +x "$HOME/.config/waybar/scripts/"*.sh

echo "==> Обои"
mkdir -p "$HOME/Pictures"
if [ -f "$HOME/Pictures/wall.jpg" ]; then
    echo "    ~/Pictures/wall.jpg уже есть, не трогаю"
elif [ -f "$DIR/wall" ]; then
    cp "$DIR/wall" "$HOME/Pictures/wall.jpg"
    echo "    скопировал wall из репо в ~/Pictures/wall.jpg"
else
    echo "    ВНИМАНИЕ: нет ~/Pictures/wall.jpg"
fi

echo "==> Промпт starship и алиасы"
if ! grep -q 'starship init bash' "$HOME/.bashrc" 2>/dev/null; then
    printf '\neval "$(starship init bash)"\n' >> "$HOME/.bashrc"
fi
if ! grep -q '# nyarch aliases' "$HOME/.bashrc" 2>/dev/null; then
    printf "\n# nyarch aliases\nalias ff=fastfetch\nalias update='sudo pacman -Syu'\n" >> "$HOME/.bashrc"
fi

echo "==> Тёмная тема GTK"
fc-cache -f >/dev/null 2>&1 || true
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark' 2>/dev/null || true
gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark' 2>/dev/null || true

echo "==> Перезапуск"
hyprctl reload || true
pkill -x waybar 2>/dev/null || true
pkill -x mako 2>/dev/null || true
pkill -x swaybg 2>/dev/null || true
sleep 0.5
nohup waybar >/dev/null 2>&1 </dev/null &
nohup mako >/dev/null 2>&1 </dev/null &
if [ -f "$HOME/Pictures/wall.jpg" ]; then
    nohup swaybg -i "$HOME/Pictures/wall.jpg" -m fill >/dev/null 2>&1 </dev/null &
fi
disown -a 2>/dev/null || true

echo
echo "Готово. Если что-то выглядит криво, закрой терминал и открой новый (SUPER+Q)."
