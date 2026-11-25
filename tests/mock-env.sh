#!/usr/bin/env bash
# Тестовая среда: поддельные pacman/sudo/paru/systemctl/… и временный HOME.
# Нужна, чтобы проверять логику установщика (бэкапы, повторный запуск, откат) без реального Arch.
#   source tests/mock-env.sh && mock_setup
mock_setup() {
  T="${NL_TEST_DIR:-/tmp/nl-mock}"; rm -rf "$T"; mkdir -p "$T/bin" "$T/home" "$T/fake"
  export HOME="$T/home" XDG_CONFIG_HOME="" XDG_DATA_HOME="" XDG_STATE_HOME="" FAKE="$T/fake"
  unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME HYPRLAND_INSTANCE_SIGNATURE
  export NL_SDDM_THEMES="$T/sddm/themes" NL_SDDM_CONFD="$T/sddm/conf.d" NL_ALLOW_NONARCH=1 NL_ALLOW_ROOT=1 NO_COLOR=1 PATH="$T/bin:$PATH" NL_FORCE_NVIDIA="${NL_FORCE_NVIDIA:-1}"
  : > "$FAKE/installed"
  # «репозиторий»: всё, кроме двух пакетов (проверяем ветку «нет в репо»)
  ( cd "$(dirname "${BASH_SOURCE[0]}")/../packages" && cat *.txt ) | sed -e 's/#.*//' -e 's/nv://' | tr -s ' \t|' '\n' | grep -v '^$' \
    | grep -vx -e gtk-layer-shell -e rofi-wayland > "$FAKE/repo"
  cat > "$T/bin/pacman" <<'P'
#!/usr/bin/env bash
state="$FAKE/installed"; repo="$FAKE/repo"
case "$1" in
  -Qq) shift; rc=1; for p in "$@"; do grep -qx "$p" "$state" && { echo "$p"; rc=0; }; done; exit $rc ;;
  -Q)  shift; [ -n "${1:-}" ] && { grep -qx "$1" "$state" && echo "$1 1.0-1"; exit $?; }; sed 's/$/ 1.0-1/' "$state"; exit 0 ;;
  -Qm|-Qe) exit 0 ;;
  -Si) grep -qx "$2" "$repo"; exit $? ;;
  -Syu|-Syu*) echo "[mock] system upgraded"; exit 0 ;;
  -S) shift; for a in "$@"; do case "$a" in -*) ;; *) echo "$a" >> "$state"; echo "[mock] installed $a" ;; esac; done; exit 0 ;;
esac
exit 0
P
  cat > "$T/bin/sudo" <<'P'
#!/usr/bin/env bash
[ "${1:-}" = -v ] && exit 0
exec "$@"
P
  cat > "$T/bin/paru" <<'P'
#!/usr/bin/env bash
if [ "$1" = -S ]; then for a in "$@"; do case "$a" in -*) ;; *) echo "$a" >> "$FAKE/installed"; echo "[mock paru] $a";
  { [ "$a" = code ] || [ "$a" = visual-studio-code-bin ]; } && printf '#!/bin/sh\necho 1.99.0\n' > "$FAKE/../bin/code" && chmod +x "$FAKE/../bin/code" ;; esac; done; fi
exit 0
P
  cat > "$T/bin/git" <<'P'
#!/usr/bin/env bash
if [ "$1" = clone ]; then mkdir -p "${@: -1}"; echo "[mock git clone] ${@: -1}"; exit 0; fi
exec /usr/bin/git "$@"
P
  cat > "$T/bin/systemctl" <<'P'
#!/usr/bin/env bash
case "$*" in *is-active*) echo active ;; *is-enabled*) echo enabled ;; esac; exit 0
P
  cat > "$T/bin/nvidia-smi" <<'P'
#!/usr/bin/env bash
case "$*" in *driver_version*) echo 570.144 ;; *name*) echo "NVIDIA GeForce RTX 4060" ;; *) echo "mock table" ;; esac
P
  cat > "$T/bin/hyprctl" <<'P'
#!/usr/bin/env bash
case "$1" in configerrors) [ -f "$FAKE/hypr_error" ] && cat "$FAKE/hypr_error" ;; monitors) printf 'Monitor mock (ID 0):\n\t1920x1080@120.00000 at 0x0\n' ;; *) echo ok ;; esac; exit 0
P
  cat > "$T/bin/curl" <<'P'
#!/usr/bin/env bash
exit 0
P
  for c in chsh fc-cache gsettings kbuildsycoca6 update-desktop-database hyprland hyprlock hypridle waybar swaync swaync-client kitty dolphin \
           firefox vlc mpv ark swaybg grim slurp wl-copy wl-paste cliphist playerctl wpctl nmcli rofi zsh fastfetch fzf zoxide eza bat rg btop gh node npm notify-send; do
    printf '#!/bin/sh\nexit 0\n' > "$T/bin/$c"
  done
  chmod +x "$T/bin"/*
}
