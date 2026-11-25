# n. Northling Arch — v0.1.0 Beta

Личное окружение **Arch Linux + Hyprland** в тёмной индиго-лавандовой теме **Northling Midnight**
(палитра сайта [northling.space](https://northling.space)). Один установщик — и конфиги на месте.

> Beta: написано и проверено на тестовой «поддельной» системе, на живом Arch ещё не обкатано.
> Если что-то сломалось — смотри раздел «Если всё плохо» ниже.

## Что внутри

- **Hyprland** (конфиг на Lua, синтаксис 0.57), Hyprlock, Hypridle (блокировка 10 мин, сон 30 мин)
- **Waybar**, **SwayNC** (уведомления), **Rofi** (лаунчер), **Kitty**, **Dolphin**
- **Zsh** + Oh My Zsh + Powerlevel10k, fastfetch
- Тема GTK/Qt, **официальный VS Code** (из AUR) с темой Northling Midnight
- Обои: 3 стандартных + 2 фурри, смена через `northling wallpaper`
- NVIDIA-настройки включаются только если найдена видеокарта NVIDIA

Не делает: не трогает Windows и загрузчик, не меняет драйвер NVIDIA, не ставит Bluetooth,
не удаляет твои файлы и обои.

## Установка

В терминале (один раз):

```bash
cd ~/nyarch && git fetch && git reset --hard origin/main && bash install.sh
```

Если папки ещё нет:

```bash
git clone https://github.com/Oxiety/nyarch.git ~/nyarch && cd ~/nyarch && bash install.sh
```

Установщик сам всё спросит (ответы «д» / «н»), покажет план и только потом начнёт.
Перед заменой любого конфига делается **бэкап** в `~/.local/share/northling/backups/`.
Сначала можно посмотреть, что произойдёт: `bash install.sh --dry-run`.

Флаги: `-y` (не спрашивать), `-n` (пробный запуск), `--no-upgrade` (не делать `pacman -Syu`), `--only=...`.

## Обновление и удаление без мучений

После установки есть команда `northling`, а в Rofi (Super+R) — пункты **Northling Update / Doctor / Wallpaper**.

| Что | Команда |
|---|---|
| Обновить проект и систему | `northling update` |
| Проверить, всё ли в порядке | `northling doctor` |
| Сменить обои | `northling wallpaper` (или ПКМ по значку `n.` в Waybar) |
| Собрать диагностику | `northling diag` |
| Удалить конфиги и вернуть старые | `northling uninstall` |

Твои правки в файлах `~/.zshrc`, `~/.p10k.zsh`, `kdeglobals`, GTK и VS Code `settings.json`
установщик **не перезаписывает**. Остальные конфиги проекта заменяются с бэкапом.

## Горячие клавиши

| Клавиши | Действие |
|---|---|
| Super+Q | Терминал |
| Super+E | Файлы (Dolphin) |
| Super+R | Лаунчер |
| Super+C | Закрыть окно |
| Super+L | Блокировка |
| Super+V | История буфера обмена |
| Super+Space / F / P / J | Плавающее / полный экран / pseudo / раскладка |
| Super+1…0 | Рабочие столы (Shift — перенести окно) |
| Print / Shift+Print | Скриншот области / экрана |
| Alt+Shift | Раскладка us/ru |
| Super+M | Выход из Hyprland |

## Настройка

- **Монитор**: строка `hl.monitor` в `~/.config/hypr/hyprland.lua` (сейчас 1920x1080@120).
- **Сон/блокировка**: `~/.config/hypr/hypridle.conf` (`timeout = 600` и `1800`).
- **Цвета**: `themes/northling-midnight/colors.env`, активная палитра — в конфигах.
- **Ошибки конфига**: `hyprctl configerrors`.

## Если всё плохо

1. Ctrl+Alt+F3 → логин → `northling doctor` (или `bash ~/nyarch/uninstall.sh`).
2. Старый `hyprland.lua` лежит в `~/.local/share/northling/backups/`.
3. Пришли вывод установщика или `hyprctl configerrors` — разберёмся.

## Известные ограничения (v0.2)

- Виджеты рабочего стола (часы, календарь, погода, плеер, сеть, GPU) — в v0.2.
- Тема SDDM и разбор чёрного экрана (~3 с) — после диагностики логов.
- Имена пакетов сверяются с репозиториями во время установки; отсутствующие пропускаются с предупреждением.
- Старые wofi / mako / thunar остаются в системе, но не используются.

## Тесты

`bash tests/run-mock-tests.sh` — прогон установки, повтора, правок, удаления и обновления на моках.

## Лицензия

MIT
