#!/usr/bin/env python3
"""Northling Control — центр управления: громкость, микрофон, яркость, Wi-Fi, «не беспокоить»,
ночной режим, игровой режим. Открывается по Super+A, Esc или клик мимо — закрыть."""
import getpass, os, re, subprocess, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import nl_data as data

import gi
gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gtk, Gdk, GLib, GtkLayerShell  # noqa: E402

os.environ.pop("LD_PRELOAD", None)
HERE = os.path.dirname(os.path.abspath(__file__))
SINK, SRC = "@DEFAULT_AUDIO_SINK@", "@DEFAULT_AUDIO_SOURCE@"
BIN = os.path.expanduser("~/.local/bin/")


def sh(cmd, timeout=2):
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return r.returncode, (r.stdout or "").strip()
    except (OSError, subprocess.SubprocessError):
        return 1, ""


def spawn(cmd):
    try:
        subprocess.Popen(cmd, start_new_session=True, stdin=subprocess.DEVNULL,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except OSError:
        pass


def parse_volume(text):
    """'Volume: 0.45 [MUTED]' → (0.45, True). Не разобралось → (None, False)."""
    m = re.search(r"([0-9]*\.?[0-9]+)", text or "")
    return (float(m.group(1)) if m else None), "MUTED" in (text or "")


def parse_brightness(text):
    """Вывод `brightnessctl -m`: 'nvidia_0,backlight,50,50%,100' → 50. Нет подсветки → None."""
    parts = (text or "").split(",")
    if len(parts) >= 4 and parts[3].endswith("%"):
        try:
            return int(parts[3][:-1])
        except ValueError:
            return None
    return None


def have(cmd):
    return sh(["sh", "-c", f"command -v {cmd}"])[0] == 0


def add_classes(w, css):
    for c in (css or "").split():
        w.get_style_context().add_class(c)


def lbl(t, css=None, xalign=0.0):
    l = Gtk.Label(label=t)
    l.set_xalign(xalign)
    l.set_ellipsize(3)
    l.set_max_width_chars(28)
    add_classes(l, css)
    return l


class Tile(Gtk.Button):
    """Плитка-переключатель: значок, подпись, состояние (подсвечена, когда включено)."""
    def __init__(self, glyph, title, getter, toggler):
        super().__init__()
        add_classes(self, "tile")
        self.getter, self.toggler = getter, toggler
        box = Gtk.Box(spacing=10)
        box.pack_start(lbl(glyph, "tile-glyph", 0.5), False, False, 0)
        v = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        v.pack_start(lbl(title, "tile-title"), False, False, 0)
        self.sub = lbl("", "tile-sub")
        v.pack_start(self.sub, False, False, 0)
        box.pack_start(v, True, True, 0)
        self.add(box)
        self.connect("clicked", self.on_click)
        self.refresh()

    def refresh(self):
        try:
            on = bool(self.getter())
        except Exception:
            on = False
        ctx = self.get_style_context()
        (ctx.add_class if on else ctx.remove_class)("tile-on")
        self.sub.set_text("Вкл" if on else "Выкл")

    def on_click(self, *_):
        try:
            self.toggler()
        except Exception as e:
            print("tile:", e, file=sys.stderr)
        GLib.timeout_add(450, lambda: (self.refresh(), False)[1])


class Control(Gtk.Window):
    def __init__(self):
        super().__init__(title="Northling Control")
        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_namespace(self, "northling-control")
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.OVERLAY)
        GtkLayerShell.set_keyboard_mode(self, GtkLayerShell.KeyboardMode.EXCLUSIVE)
        for edge in (GtkLayerShell.Edge.TOP, GtkLayerShell.Edge.BOTTOM, GtkLayerShell.Edge.LEFT, GtkLayerShell.Edge.RIGHT):
            GtkLayerShell.set_anchor(self, edge, True)
        GtkLayerShell.set_exclusive_zone(self, -1)
        self.set_app_paintable(True)
        scr = Gdk.Screen.get_default()
        vis = scr.get_rgba_visual() if scr else None
        if vis:
            self.set_visual(vis)
        p = Gtk.CssProvider()
        try:
            p.load_from_path(os.path.join(HERE, "control.css"))
            Gtk.StyleContext.add_provider_for_screen(scr, p, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
            if data.glass_on():
                g = Gtk.CssProvider()
                g.load_from_path(os.path.join(HERE, "glass.css"))
                Gtk.StyleContext.add_provider_for_screen(scr, g, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 1)
        except Exception as e:
            print("control.css:", e, file=sys.stderr)

        scrim = Gtk.EventBox()
        scrim.connect("button-press-event", self.on_click_outside)
        self.add(scrim)
        outer = Gtk.Box()
        scrim.add(outer)
        self.card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        add_classes(self.card, "cc-card")
        self.card.set_size_request(380, -1)
        self.card.set_halign(Gtk.Align.END)
        self.card.set_valign(Gtk.Align.START)
        self.card.set_margin_top(64)
        self.card.set_margin_end(24)
        outer.pack_end(self.card, False, False, 0)

        self.card.pack_start(lbl("Центр управления", "cc-title"), False, False, 0)
        self.card.pack_start(lbl(getpass.getuser(), "cc-sub"), False, False, 0)
        self.sliders = []
        self.card.pack_start(self.slider("󰕾", "Громкость", self.get_vol(SINK), lambda v: self.set_vol(SINK, v)), False, False, 0)
        self.card.pack_start(self.slider("󰍬", "Микрофон", self.get_vol(SRC), lambda v: self.set_vol(SRC, v)), False, False, 0)
        b = self.get_bright()
        if b is not None:
            self.card.pack_start(self.slider("󰃟", "Яркость", b, lambda v: spawn(["brightnessctl", "set", f"{max(1, int(v*100))}%"])), False, False, 0)

        grid = Gtk.Grid(column_spacing=10, row_spacing=10, column_homogeneous=True)
        self.tiles = [
            Tile("󰖩", "Wi-Fi", lambda: sh(["nmcli", "radio", "wifi"])[1] == "enabled",
                 lambda: spawn(["nmcli", "radio", "wifi", "off" if sh(["nmcli", "radio", "wifi"])[1] == "enabled" else "on"])),
            Tile("󰂛", "Не беспокоить", lambda: sh(["swaync-client", "-D"])[1] == "true", lambda: spawn(["swaync-client", "-d", "-sw"])),
            Tile("󰌵", "Ночной режим", lambda: sh(["pgrep", "-x", "hyprsunset"])[0] == 0, self.toggle_night),
            Tile("󰊖", "Игровой режим", lambda: sh([BIN + "northling-gamemode", "status"])[1] == "on", lambda: spawn([BIN + "northling-gamemode", "toggle"])),
            Tile("󰔡", "Liquid Glass", data.glass_on, lambda: spawn([BIN + "northling-glass", "toggle"])),
            Tile("󰝟", "Звук", lambda: "MUTED" not in sh(["wpctl", "get-volume", SINK])[1], lambda: spawn(["wpctl", "set-mute", SINK, "toggle"])),
            Tile("󰍭", "Микрофон", lambda: "MUTED" not in sh(["wpctl", "get-volume", SRC])[1], lambda: spawn(["wpctl", "set-mute", SRC, "toggle"])),
        ]
        for i, t in enumerate(self.tiles):
            grid.attach(t, i % 2, i // 2, 1, 1)
        self.card.pack_start(grid, False, False, 0)

        row = Gtk.Box(spacing=8)
        for title, cmd in [("Сеть", ["nm-connection-editor"]), ("Скриншот", [BIN + "northling-screenshot", "area"]),
                           ("Настройки", [BIN + "northling-start", "settings"])]:
            bt = Gtk.Button(label=title)
            add_classes(bt, "chip")
            bt.connect("clicked", lambda _b, c=cmd: (spawn(c), Gtk.main_quit()))
            row.pack_start(bt, True, True, 0)
        self.card.pack_start(row, False, False, 0)

        self.connect("key-press-event", lambda w, e: (Gtk.main_quit(), True)[1] if e.keyval == Gdk.KEY_Escape else False)
        self.connect("destroy", lambda *_: Gtk.main_quit())
        self.show_all()

    def on_click_outside(self, w, ev):
        a = self.card.get_allocation()
        if not (a.x <= ev.x <= a.x + a.width and a.y <= ev.y <= a.y + a.height):
            Gtk.main_quit()
        return False

    def toggle_night(self):
        if sh(["pgrep", "-x", "hyprsunset"])[0] == 0:
            spawn(["pkill", "-x", "hyprsunset"])
        else:
            spawn(["hyprsunset", "-t", "4000"])

    @staticmethod
    def get_vol(target):
        v, _ = parse_volume(sh(["wpctl", "get-volume", target])[1])
        return min(v, 1.0) if v is not None else 0.0

    @staticmethod
    def set_vol(target, v):
        spawn(["wpctl", "set-volume", "-l", "1", target, f"{v:.2f}"])

    @staticmethod
    def get_bright():
        if not have("brightnessctl"):
            return None
        pct = parse_brightness(sh(["brightnessctl", "-m"])[1])
        return None if pct is None else pct / 100.0

    def slider(self, glyph, title, value, setter):
        box = Gtk.Box(spacing=12)
        box.pack_start(lbl(glyph, "tile-glyph", 0.5), False, False, 0)
        v = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        v.pack_start(lbl(title, "tile-title"), False, False, 0)
        sc = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 1, 0.01)
        sc.set_draw_value(False)
        sc.set_value(value)
        sc.set_size_request(250, -1)
        sc.connect("value-changed", lambda s: setter(s.get_value()))
        add_classes(sc, "cc-scale")
        v.pack_start(sc, False, False, 0)
        box.pack_start(v, True, True, 0)
        self.sliders.append(sc)
        return box


def main():
    Control()
    Gtk.main()


if __name__ == "__main__":
    main()
