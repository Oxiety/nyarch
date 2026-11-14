# nyarch

Dotfiles для Hyprland 0.57 (Lua-конфиг) на Arch: бирюзовая тема под обои.

## Установка

```
sudo pacman -S --needed git
git clone https://github.com/Oxiety/nyarch ~/nyarch
bash ~/nyarch/install.sh
```

Скрипт ставит пакеты, раскладывает конфиги в `~/.config` (старые файлы сохраняет как `.bak.<дата>`) и перезапускает бар, уведомления и обои. Запускать можно повторно.

## Что внутри

- `dotfiles/hypr`: Hyprland (рамки, блюр, us/ru на Alt+Shift, переменные NVIDIA)
- `dotfiles/waybar`: плавающий бар из пилюль, меню питания
- `dotfiles/wofi`: лаунчер приложений
- `dotfiles/mako`: уведомления
- `dotfiles/kitty`: терминал
- `dotfiles/gtk-3.0`, `dotfiles/gtk-4.0`: тёмная тема и иконки
- `dotfiles/starship.toml`: промпт
- `dotfiles/fastfetch`: инфо о системе (команда `ff`)

Клик по звуку в баре открывает микшер (pavucontrol), клик по сети открывает настройки сети, правый клик по звуку включает и выключает звук. Wi-Fi, Bluetooth и флешки живут в трее. Внешний вид программ настраивается через `nwg-look`.
- `wall`: обои

## Клавиши

| Клавиши | Действие |
| --- | --- |
| SUPER+Q | терминал |
| SUPER+R | лаунчер |
| SUPER+E | файлы (Thunar) |
| SUPER+C | закрыть окно |
| SUPER+1..0 | рабочие столы |
| Print | скриншот области в буфер |
| Alt+Shift | раскладка us/ru |
