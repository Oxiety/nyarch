#!/usr/bin/env python3
"""Northling Dock — док внизу экрана: закреплённые и запущенные программы.
Прячется у края; наведи мышь на нижний край — выедет. Закреплённые — в ~/.config/northling/dock.json."""
import json, os, subprocess, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import nl_data as data

import gi
gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gtk, Gdk, GLib, Gio, GtkLayerShell  # noqa: E402

os.environ.pop("LD_PRELOAD", None)
HERE = os.path.dirname(os.path.abspath(__file__))
CONF = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")), "northling", "dock.json")
DEFAULT = {"enabled": True, "autohide": True, "icon_size": 44,
           "pinned": ["firefox", "kitty", "dolphin", "code", "discord", "steam", "vlc"]}


def load_conf(path=CONF):
    cfg = dict(DEFAULT)
    try:
        with open(path, encoding="utf-8") as f:
            u = json.load(f)
        if isinstance(u, dict):
            cfg.update({k: v for k, v in u.items() if k in DEFAULT})
    except (OSError, ValueError):
        pass
    if not isinstance(cfg["pinned"], list):
        cfg["pinned"] = DEFAULT["pinned"]
    return cfg


def parse_clients(text):
    """`hyprctl clients -j` → [{class, address, title}] (только настоящие окна)."""
    try:
        data = json.loads(text)
    except ValueError:
        return []
    return [{"class": c.get("class", ""), "address": c.get("address", ""), "title": c.get("title", "")}
            for c in data if isinstance(c, dict) and c.get("class") and c.get("mapped", True)]


def match_app(key, apps):
    """Ищем .desktop по подстроке id или по StartupWMClass. apps: [{id, wmclass, ...}]"""
    k = key.lower()
    for a in apps:
        if a["id"].lower().removesuffix(".desktop") == k:
            return a
    for a in apps:
        if a["wmclass"].lower() == k:
            return a
    for a in apps:
        if k in a["id"].lower():
            return a
    return None


def spawn(cmd):
    try:
        subprocess.Popen(cmd, start_new_session=True, stdin=subprocess.DEVNULL,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return True
    except OSError:
        return False


def hypr_focus(address):
    """Фокус окна: сначала классический синтаксис dispatch, потом Lua-вариант Hyprland 0.5x."""
    for arg in (f"focuswindow address:{address}", f'hl.dsp.focus({{ window = "address:{address}" }})'):
        try:
            r = subprocess.run(["hyprctl", "dispatch", arg], capture_output=True, text=True, timeout=2)
            if r.returncode == 0 and "ok" in r.stdout.lower() and "error" not in r.stdout.lower():
                return True
        except (OSError, subprocess.SubprocessError):
            pass
    return False


class Dock(Gtk.Window):
    def __init__(self):
        super().__init__(title="Northling Dock")
        self.cfg = load_conf()
        self.apps = []
        for a in Gio.AppInfo.get_all():
            try:
                if a.should_show():
                    self.apps.append({"id": a.get_id() or "", "name": a.get_name() or "", "icon": a.get_icon(),
                                      "wmclass": (a.get_startup_wm_class() or "") if hasattr(a, "get_startup_wm_class") else "", "info": a})
            except Exception:
                continue
        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_namespace(self, "northling-dock")
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.TOP)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.BOTTOM, True)
        GtkLayerShell.set_exclusive_zone(self, 0)
        GtkLayerShell.set_keyboard_mode(self, GtkLayerShell.KeyboardMode.NONE)
        self.set_app_paintable(True)
        scr = Gdk.Screen.get_default()
        if scr and scr.get_rgba_visual():
            self.set_visual(scr.get_rgba_visual())
        p = Gtk.CssProvider()
        try:
            p.load_from_path(os.path.join(HERE, "dock.css"))
            Gtk.StyleContext.add_provider_for_screen(scr, p, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
        except Exception as e:
            print("dock.css:", e, file=sys.stderr)

        self.ev = Gtk.EventBox()
        self.ev.add_events(Gdk.EventMask.ENTER_NOTIFY_MASK | Gdk.EventMask.LEAVE_NOTIFY_MASK)
        self.ev.connect("enter-notify-event", lambda *_: self.reveal(True))
        self.ev.connect("leave-notify-event", self.on_leave)
        self.add(self.ev)
        outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.ev.add(outer)
        self.rev = Gtk.Revealer()
        self.rev.set_transition_type(Gtk.RevealerTransitionType.SLIDE_UP)
        self.rev.set_transition_duration(220)
        self.row = Gtk.Box(spacing=6)
        self.row.get_style_context().add_class("dock")
        self.rev.add(self.row)
        outer.pack_start(self.rev, False, False, 0)
        strip = Gtk.Box()  # невидимая полоска у края: на неё наводим мышь
        strip.set_size_request(280, 6)
        outer.pack_start(strip, False, False, 0)
        self.hide_id = None
        self.sig = None
        self.refresh()
        GLib.timeout_add_seconds(2, self.refresh)
        self.connect("destroy", lambda *_: Gtk.main_quit())
        self.show_all()
        if not self.cfg["autohide"]:
            self.rev.set_reveal_child(True)

    def on_leave(self, w, ev):
        # ушли «внутрь» иконки — это не уход из дока; раньше из-за этого док уезжал под курсором
        if ev.detail == Gdk.NotifyType.INFERIOR:
            return False
        a = self.get_allocation()
        if 0 <= ev.x < a.width and 0 <= ev.y < a.height:
            return False
        self.reveal(False)
        return False

    def reveal(self, on):
        if not self.cfg["autohide"]:
            return
        if self.hide_id:
            GLib.source_remove(self.hide_id)
            self.hide_id = None
        if on:
            self.rev.set_reveal_child(True)
        else:
            self.hide_id = GLib.timeout_add(450, self._hide)

    def _hide(self):
        self.rev.set_reveal_child(False)
        self.hide_id = None
        return False

    def entries(self):
        try:
            out = subprocess.run(["hyprctl", "clients", "-j"], capture_output=True, text=True, timeout=2).stdout
        except (OSError, subprocess.SubprocessError):
            out = ""
        clients = parse_clients(out)
        items, used = [], set()
        for key in self.cfg["pinned"]:
            app = match_app(str(key), self.apps)
            if not app:
                continue
            wins = [c for c in clients if c["class"].lower() in (str(key).lower(), app["wmclass"].lower(), app["id"].lower().removesuffix(".desktop"))]
            used.update(w["address"] for w in wins)
            items.append((app, wins))
        for c in clients:
            if c["address"] in used:
                continue
            app = match_app(c["class"], self.apps)
            if app is None:
                app = {"id": "", "name": c["class"], "icon": None, "wmclass": c["class"], "info": None}
            items.append((app, [c]))
            used.add(c["address"])
        return items

    def refresh(self):
        items = self.entries()
        sig = [(a["id"] or a["name"], len(w)) for a, w in items]
        if sig == self.sig:
            return True
        self.sig = sig
        for c in self.row.get_children():
            self.row.remove(c)
        for app, wins in items:
            b = Gtk.Button()
            b.get_style_context().add_class("dock-item")
            v = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
            img = Gtk.Image.new_from_gicon(app["icon"], Gtk.IconSize.DIALOG) if app["icon"] else Gtk.Image.new_from_icon_name("application-x-executable", Gtk.IconSize.DIALOG)
            img.set_pixel_size(int(self.cfg["icon_size"]))
            v.pack_start(img, False, False, 0)
            dot = Gtk.Label(label="●" if wins else " ")
            dot.get_style_context().add_class("dock-dot")
            v.pack_start(dot, False, False, 0)
            b.add(v)
            b.set_tooltip_text(app["name"] + (f" — окон: {len(wins)}" if wins else ""))
            b.connect("clicked", lambda _b, a=app, w=wins: self.activate(a, w))
            self.row.pack_start(b, False, False, 0)
        self.row.show_all()
        return True

    def activate(self, app, wins):
        if wins and hypr_focus(wins[0]["address"]):
            return
        if app["id"] and spawn(["gtk-launch", app["id"]]):
            return
        try:
            app["info"].launch([], None)
        except Exception as e:
            print("dock launch:", e, file=sys.stderr)


def main():
    if not load_conf()["enabled"]:
        return
    Dock()
    Gtk.main()


if __name__ == "__main__":
    main()
