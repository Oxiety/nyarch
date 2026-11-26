-- =============================================================================
-- Northling Arch — hyprland.lua  (Hyprland 0.57, Lua)
-- Тема Northling Midnight. Синтаксис взят из твоей РАБОЧЕЙ конфигурации nyarch
-- (проверено на 0.57) + официальной вики. Ничего «на всякий случай» не добавлено.
--
-- Хочешь поменять: монитор → блок D, клавиши → блок F, автозапуск → блок H.
-- После правки:  hyprctl reload  (ошибки покажет:  hyprctl configerrors)
-- Файл принадлежит проекту: при обновлении перезаписывается (старая версия — в бэкап).
-- =============================================================================

local HOME = os.getenv("HOME")

-- ── A. Программы ─────────────────────────────────────────────────────────────
local terminal    = "kitty"
local fileManager = "dolphin"
local menu        = "~/.local/bin/northling-start"
local lock        = "pidof hyprlock || hyprlock"
local shot        = HOME .. "/.local/bin/northling-screenshot"
local mainMod     = "SUPER"

-- ── B. Окружение ─────────────────────────────────────────────────────────────
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XDG_MENU_PREFIX", "arch-")                  -- Dolphin: меню «Открыть с помощью…»
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")      -- VS Code / Discord нативно на Wayland

-- NVIDIA (RTX 4060, одна видеокарта). Источник: wiki.hypr.land/Nvidia
-- Блок вырезается установщиком, если видеокарты NVIDIA нет.
-- >>> NORTHLING:NVIDIA:BEGIN
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
-- hl.env("NVD_BACKEND", "direct")
-- <<< NORTHLING:NVIDIA:END

-- ── C. Палитра Northling Midnight (themes/northling-midnight/colors.env) ─────
--   фон 0E0A24 · панели 1C1155 · окна 342676 · лаванда A78BFA · голубой 82BFFF
--   розовый D284E5 · текст E5E7F5

-- ── D. Монитор: 1920×1080 @ 120 Гц. VRR не включаем ──────────────────────────
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "0x0",
    scale    = 1,
})

-- ── E. Внешний вид ───────────────────────────────────────────────────────────
hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 12,
        border_size = 2,
        col = {
            active_border   = { colors = {"rgba(a78bfaee)", "rgba(82bfffee)", "rgba(d284e5ee)", "rgba(a78bfaee)"}, angle = 45 },
            inactive_border = "rgba(34304faa)",
        },
        resize_on_border = false,
        allow_tearing = false,
        layout = "dwindle",
    },

    decoration = {
        rounding       = 16,
        rounding_power = 2,
        active_opacity   = 1.0,
        inactive_opacity = 0.94,
        shadow = {
            enabled      = true,
            range        = 14,
            render_power = 3,
            color        = 0xee0e0a24,
        },
        blur = {
            enabled   = true,
            size      = 8,
            passes    = 3,
            vibrancy  = 0.2,
            noise     = 0.015,
        },
    },

    animations = {
        enabled = true,
    },
})

hl.config({ dwindle = { preserve_split = true } })

hl.config({
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
    },
})

hl.config({
    input = {
        kb_layout  = "us,ru",
        kb_variant = "",
        kb_model   = "",
        kb_options = "grp:alt_shift_toggle",     -- Alt+Shift — раскладка RU/EN
        kb_rules   = "",
        follow_mouse = 1,
        sensitivity = 0,
    },
})

-- Анимации Northling: мягкое «пружинистое» появление окон, скольжение столов, вращающаяся рамка.
-- Кривые: silk — резкий старт и долгое плавное затухание, spring — лёгкий перелёт.
hl.curve("silk",   { type = "bezier", points = { {0.16, 1.00}, {0.30, 1.00} } })
hl.curve("spring", { type = "bezier", points = { {0.34, 1.35}, {0.64, 1.00} } })
hl.curve("linear", { type = "bezier", points = { {0.00, 0.00}, {1.00, 1.00} } })
hl.animation({ leaf = "windowsIn",    enabled = true, speed = 5.5, bezier = "spring", style = "popin 80%" })
hl.animation({ leaf = "windowsOut",   enabled = true, speed = 4.0, bezier = "silk",   style = "popin 86%" })
hl.animation({ leaf = "windowsMove",  enabled = true, speed = 4.5, bezier = "silk" })
hl.animation({ leaf = "fade",         enabled = true, speed = 3.5, bezier = "silk" })
hl.animation({ leaf = "border",       enabled = true, speed = 6.0, bezier = "silk" })
hl.animation({ leaf = "borderangle",  enabled = true, speed = 60,  bezier = "linear", style = "loop" })
hl.animation({ leaf = "layers",       enabled = true, speed = 4.5, bezier = "spring", style = "popin 90%" })
hl.animation({ leaf = "workspaces",   enabled = true, speed = 5.0, bezier = "silk",   style = "slidefade 18%" })

-- ── F. Горячие клавиши ───────────────────────────────────────────────────────
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))                  -- терминал
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))               -- файлы
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(menu))                      -- «Пуск» Northling
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("rofi -show drun"))   -- запасной лаунчер (rofi)
hl.bind(mainMod .. " + C", hl.dsp.window.close())                      -- закрыть окно
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd(lock))                      -- блокировка
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd(HOME .. "/.local/bin/northling-start clip"))   -- буфер обмена
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd(HOME .. "/.local/bin/northling-control"))      -- центр управления
hl.bind(mainMod .. " + G", hl.dsp.exec_cmd(HOME .. "/.local/bin/northling-gamemode toggle")) -- игровой режим
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))

hl.bind(mainMod .. " + SPACE", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F",     hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind(mainMod .. " + P",     hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J",     hl.dsp.layout("togglesplit"))

hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Рабочие столы Super+1…0 (0 = десятый); с Shift — перенести окно
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Скриншоты: Print — выделить область, Shift+Print — весь экран (в буфер обмена + файл)
hl.bind("Print",         hl.dsp.exec_cmd(shot .. " area"))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd(shot .. " full"))

-- Громкость и медиа-клавиши
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioPlay",        hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext",        hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPrev",        hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- ── G. Правила окон ──────────────────────────────────────────────────────────
hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

hl.window_rule({
    name  = "northling-float-pavucontrol",
    match = { class = "^(org.pulseaudio.pavucontrol)$" },
    float = true,
})

hl.window_rule({
    name  = "northling-float-nm-editor",
    match = { class = "^(nm-connection-editor)$" },
    float = true,
})

-- ── H. Автозапуск ────────────────────────────────────────────────────────────
-- Обои: swaybg читает симлинк ~/.config/northling/wallpaper — меняй картинку командой
-- northling-wallpaper, этот файл править не нужно.
hl.on("hyprland.start", function()
    hl.exec_cmd("swaybg -i " .. HOME .. "/.config/northling/wallpaper -m fill")
    hl.exec_cmd("swaync")
    hl.exec_cmd("waybar")
    hl.exec_cmd(HOME .. "/.local/bin/northling-widgets start")
    hl.exec_cmd(HOME .. "/.local/bin/northling-dock start")
    hl.exec_cmd("sh -c 'command -v kdeconnect-indicator >/dev/null && kdeconnect-indicator'")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("nm-applet --indicator")
    hl.exec_cmd("wl-paste --type text  --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)
