#!/usr/bin/env bash
# Прогон сценариев установки/обновления/удаления на поддельной системе.  bash tests/run-mock-tests.sh
set -u
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
. "$R/tests/mock-env.sh"
PASS=0; FAIL=0
t() { if eval "$2"; then PASS=$((PASS+1)); echo "  PASS  $1"; else FAIL=$((FAIL+1)); echo "  FAIL  $1   [$2]"; fi; }
snap() { ( cd "$HOME" && find . -type f -o -type l | sort ) ; }
yes_pty() { python3 -I - "$@" <<'PY'
import os,pty,sys,time
cmd=sys.argv[1:]
pid,fd=pty.fork()
if pid==0: os.execvp(cmd[0],cmd)
out=b""; sent=0
while True:
    try: d=os.read(fd,4096)
    except OSError: break
    if not d: break
    out+=d
    if "д/Н]".encode() in d or "Д/н]".encode() in d:
        os.write(fd,"д\n".encode())
_,st=os.waitpid(pid,0); sys.stdout.write(out.decode("utf-8","replace")); sys.exit(os.WEXITSTATUS(st))
PY
}

echo "== 0. Синтаксис всех скриптов"
for f in "$R"/install.sh "$R"/update.sh "$R"/uninstall.sh "$R"/installer/*.sh "$R"/scripts/bin/* "$R"/dotfiles/waybar/scripts/*.sh "$R"/tests/*.sh; do
  t "bash -n $(basename "$f")" "bash -n '$f'"
done
if command -v shellcheck >/dev/null; then t "shellcheck (ошибки)" "shellcheck -S error -x '$R'/install.sh '$R'/update.sh '$R'/uninstall.sh '$R'/installer/*.sh"; fi
for f in "$R"/dotfiles/waybar/config.jsonc "$R"/dotfiles/swaync/config.json "$R"/dotfiles/vscode/settings.json "$R"/themes/vscode/northling-midnight/package.json "$R"/themes/vscode/northling-midnight/themes/*.json; do
  t "JSON $(basename "$f")" "python3 -c \"import json,sys;json.load(open(sys.argv[1]))\" '$f'"
done

echo "== 1. Пробный запуск ничего не меняет"
mock_setup
mkdir -p "$HOME/.config/hypr"; echo "-- OLD HYPR (мой старый конфиг) --" > "$HOME/.config/hypr/hyprland.lua"; echo "# old zshrc" > "$HOME/.zshrc"
before="$(snap)"; bash "$R/install.sh" --dry-run --yes >"$T/dry.log" 2>&1; rc=$?
t "dry-run завершился успешно" "[ $rc -eq 0 ]"
t "dry-run не изменил файлы в HOME" "[ \"\$before\" = \"\$(snap)\" ]"
t "dry-run не создал бэкапов/манифеста" "[ ! -e '$HOME/.local/share/northling' ]"
t "dry-run ничего не поставил в pacman" "[ ! -s '$FAKE/installed' ]"

echo "== 2. Реальная установка"
bash "$R/install.sh" --yes >"$T/i1.log" 2>&1; rc=$?
t "установка завершилась кодом 0" "[ $rc -eq 0 ]"
t "pacman -Syu вызван" "grep -q 'system upgraded' '$T/i1.log'"
t "новые пакеты установлены" "grep -qx hyprland '$FAKE/installed' && grep -qx waybar '$FAKE/installed' && grep -qx swaync '$FAKE/installed'"
t "nv-пакет libva-nvidia-driver поставлен (GPU=1)" "grep -qx libva-nvidia-driver '$FAKE/installed'"
t "драйвер nvidia НЕ ставился/не трогался" "! grep -qE '^nvidia' '$FAKE/installed'"
t "Bluetooth не ставился" "! grep -qiE 'bluez|blueman' '$FAKE/installed'"
t "пакет без репо (nm-connection-editor) пропущен с предупреждением" "grep -q 'nm-connection-editor' '$T/i1.log' && ! grep -qx nm-connection-editor '$FAKE/installed'"
t "VS Code ставился через paru" "grep -qx code '$FAKE/installed'"
for f in .config/hypr/hyprland.lua .config/hypr/hyprlock.conf .config/hypr/hypridle.conf .config/waybar/config.jsonc .config/waybar/style.css .config/waybar/scripts/gpu.sh \
         .config/rofi/config.rasi .config/rofi/northling.rasi .config/kitty/kitty.conf .config/swaync/config.json .config/swaync/style.css .config/kdeglobals \
         .config/fastfetch/config.jsonc .config/gtk-3.0/settings.ini .zshrc .p10k.zsh .config/Code/User/settings.json .local/bin/northling .local/bin/northling-wallpaper \
         .local/share/applications/northling-update.desktop .config/northling/colors.env .config/northling/repo-path; do
  t "создан ~/$f" "[ -s '$HOME/$f' ]"
done
t "VS Code тема лежит в ~/.vscode/extensions" "[ -s '$HOME/.vscode/extensions/northling.northling-midnight-0.1.0/package.json' ]"
t "скрипты исполняемые" "[ -x '$HOME/.local/bin/northling' ] && [ -x '$HOME/.config/waybar/scripts/gpu.sh' ]"
t "@HOME@ подставлен в hyprlock.conf" "grep -q \"$HOME/.config/northling/wallpaper\" '$HOME/.config/hypr/hyprlock.conf' && ! grep -q '@HOME@' '$HOME/.config/hypr/hyprlock.conf'"
t "@HOME@ подставлен в .desktop" "grep -q \"Exec=kitty --title .* $HOME/.local/bin/northling-run\" '$HOME/.local/share/applications/northling-update.desktop'"
t "NVIDIA-блок остался в hyprland.lua (GPU=1)" "grep -q 'LIBVA_DRIVER_NAME' '$HOME/.config/hypr/hyprland.lua'"
t "мой старый hyprland.lua сохранён в бэкап" "grep -rq 'OLD HYPR' '$HOME/.local/share/northling/backups'"
t "мой старый .zshrc сохранён в бэкап" "grep -rq '# old zshrc' '$HOME/.local/share/northling/backups'"
t "обои скопированы (3 стандартных + 2 фурри)" "[ \$(ls '$HOME/Pictures/Wallpapers/Northling/default' | wc -l) -eq 3 ] && [ \$(ls '$HOME/Pictures/Wallpapers/Northling/furry' | wc -l) -eq 2 ]"
t "симлинк активных обоев рабочий" "[ -L '$HOME/.config/northling/wallpaper' ] && [ -e '$HOME/.config/northling/wallpaper' ]"
t "манифест записан" "[ \$(wc -l < '$HOME/.local/share/northling/manifest.tsv') -gt 20 ]"
t "Oh My Zsh/p10k «склонированы»" "[ -d '$HOME/.oh-my-zsh/custom/themes/powerlevel10k' ]"
t "install.sh НЕ трогал обои в манифесте" "! grep -q Wallpapers '$HOME/.local/share/northling/manifest.tsv'"

echo "== 3. Повторный запуск (идемпотентность)"
nb_before="$(find "$HOME/.local/share/northling/backups" -type f | wc -l)"; snap_before="$(snap | grep -v '/logs\|\.log$')"
: > "$FAKE/installed.keep"; cp "$FAKE/installed" "$FAKE/installed.keep"
bash "$R/install.sh" --yes >"$T/i2.log" 2>&1; rc=$?
t "повторная установка: код 0" "[ $rc -eq 0 ]"
t "повтор: новых бэкапов не появилось" "[ \$(find '$HOME/.local/share/northling/backups' -type f | wc -l) -eq $nb_before ]"
t "повтор: файлы без изменений" "grep -q 'создано 0, обновлено 0' '$T/i2.log'"
t "повтор: пакеты не переустанавливаются" "[ \$(wc -l < '$FAKE/installed') -eq \$(wc -l < '$FAKE/installed.keep') ]"

echo "== 4. Мои правки: seed не трогаем, own — заменяем с бэкапом"
echo "# my own alias line" >> "$HOME/.zshrc"
echo "-- user tweak --" >> "$HOME/.config/hypr/hyprland.lua"
bash "$R/install.sh" --yes >"$T/i3.log" 2>&1
t ".zshrc с моими правками не перезаписан" "grep -q 'my own alias line' '$HOME/.zshrc'"
t "об этом предупреждено" "grep -q 'ты менял этот файл сам' '$T/i3.log'"
t "hyprland.lua (own) заменён на версию проекта" "! grep -q 'user tweak' '$HOME/.config/hypr/hyprland.lua'"
t "моя правка hyprland.lua попала в бэкап" "grep -rq 'user tweak' '$HOME/.local/share/northling/backups'"

echo "== 5. Ошибка конфига Hyprland → предлагается откат"
export HYPRLAND_INSTANCE_SIGNATURE=mock; echo "Config error in file hyprland.lua at line 5: boom" > "$FAKE/hypr_error"
yes_pty bash "$HOME/.local/bin/northling" doctor > "$T/v.log" 2>&1
t "doctor видит ошибку конфига" "grep -q 'ошибках в конфиге' '$T/v.log'"
unset HYPRLAND_INSTANCE_SIGNATURE; rm -f "$FAKE/hypr_error"

echo "== 6. Без NVIDIA: блок вырезается, nv-пакеты не ставятся"
NL_FORCE_NVIDIA=0 mock_setup; export NL_FORCE_NVIDIA=0
bash "$R/install.sh" --yes >"$T/i4.log" 2>&1
t "в hyprland.lua нет NVIDIA-переменных" "! grep -q 'LIBVA_DRIVER_NAME\|NORTHLING:NVIDIA' '$HOME/.config/hypr/hyprland.lua'"
t "libva-nvidia-driver не ставился" "! grep -qx libva-nvidia-driver '$FAKE/installed'"
export NL_FORCE_NVIDIA=1

echo "== 7. Удаление: возвращает мои старые файлы, не трогает обои и изменённое"
mock_setup
mkdir -p "$HOME/.config/hypr"; echo "-- OLD HYPR --" > "$HOME/.config/hypr/hyprland.lua"; echo "# old zshrc" > "$HOME/.zshrc"; mkdir -p "$HOME/Documents"; echo "doc" > "$HOME/Documents/a.txt"
bash "$R/install.sh" --yes >/dev/null 2>&1
echo "# мои правки" >> "$HOME/.config/kitty/kitty.conf"
bash "$R/uninstall.sh" --yes >"$T/u0.log" 2>&1
t "--yes при удалении НЕ удаляет (деструктивное по умолчанию «нет»)" "[ -s '$HOME/.config/waybar/config.jsonc' ]"
yes_pty bash "$R/uninstall.sh" > "$T/u1.log" 2>&1; rc=$?
t "удаление: код 0" "[ $rc -eq 0 ]"
t "старый hyprland.lua возвращён" "grep -q 'OLD HYPR' '$HOME/.config/hypr/hyprland.lua'"
t "старый .zshrc возвращён" "grep -q '# old zshrc' '$HOME/.zshrc'"
t "waybar удалён" "[ ! -e '$HOME/.config/waybar/config.jsonc' ]"
t "kitty.conf с моими правками оставлен" "grep -q 'мои правки' '$HOME/.config/kitty/kitty.conf'"
t "документы целы" "grep -q doc '$HOME/Documents/a.txt'"
t "обои не удалены" "[ -s '$HOME/Pictures/Wallpapers/Northling/furry/01-leopard-night.png' ]"
t "манифест без удалённых файлов" "! grep -q waybar '$HOME/.local/share/northling/manifest.tsv'"

echo "== 8. update.sh (пробный)"
mock_setup
bash "$R/install.sh" --yes >/dev/null 2>&1
bash "$R/update.sh" --dry-run --yes >"$T/up.log" 2>&1; rc=$?
t "update --dry-run: код 0" "[ $rc -eq 0 ]"
t "update: показан снимок и обновление конфигов" "grep -q 'Снимок' '$T/up.log' && grep -q 'Обновление конфигов проекта' '$T/up.log'"
bash "$R/update.sh" --yes >"$T/up2.log" 2>&1; rc=$?
t "update (реальный на моках): код 0" "[ $rc -eq 0 ]"
t "update: снимок-архив создан" "ls '$HOME/.local/share/northling/backups'/pre-update-*.tar.gz >/dev/null 2>&1"

echo; echo "ИТОГО: PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]
