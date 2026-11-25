#!/usr/bin/env python3
"""Northling Widgets — виджеты рабочего стола для Hyprland (GTK3 + wlr-layer-shell).
Слева: часы, дата, календарь. Справа: погода, система, плеер. Всё настраивается в
~/.config/northling/widgets.json (город для погоды, что показывать, отступы)."""
import os, sys, threading, datetime

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import nl_data as data

import gi
gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gtk, Gdk, GLib, GtkLayerShell  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
DAYS = ["Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота", "Воскресенье"]
MONTHS = ["января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа", "сентября", "октября", "ноября", "декабря"]


def label(text="", css=None, xalign=0.0, wrap=False):
    l = Gtk.Label(label=text)
    l.set_xalign(xalign)
    if wrap:
        l.set_line_wrap(True)
    if css:
        l.get_style_context().add_class(css)
    return l


def card(*children, css="card"):
    box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
    box.get_style_context().add_class(css)
    for c in children:
        box.pack_start(c, False, False, 0)
    return box


def bar_row(name, css):
    """Строка «имя ▮▮▮▮ значение»: возвращает (виджет, функция-обновления)."""
    row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
    name_l = label(name, "metric-name")
    name_l.set_size_request(40, -1)
    bar = Gtk.ProgressBar()
    bar.set_hexpand(True)
    bar.set_valign(Gtk.Align.CENTER)
    bar.get_style_context().add_class(css)
    val = label("", "metric-val", xalign=1.0)
    val.set_size_request(56, -1)
    row.pack_start(name_l, False, False, 0)
    row.pack_start(bar, True, True, 0)
    row.pack_start(val, False, False, 0)

    def update(frac, text, level="ok"):
        bar.set_fraction(max(0.0, min(1.0, frac)))
        val.set_text(text)
        ctx = bar.get_style_context()
        for lv in ("warn", "crit"):
            ctx.remove_class(lv)
        if level != "ok":
            ctx.add_class(level)
    return row, update


def level(p):
    return "crit" if p >= 90 else "warn" if p >= 70 else "ok"


class Column(Gtk.Window):
    def __init__(self, anchor_right, cfg):
        super().__init__(type=Gtk.WindowType.TOPLEVEL)
        lay = cfg["layout"]
        self.set_title("northling-widgets")
        self.set_app_paintable(True)
        self.set_decorated(False)
        self.set_resizable(False)
        self.set_accept_focus(False)
        scr = Gdk.Screen.get_default()
        vis = scr.get_rgba_visual()
        if vis is not None:
            self.set_visual(vis)
        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_namespace(self, "northling-widgets")
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.BOTTOM)
        GtkLayerShell.set_keyboard_mode(self, GtkLayerShell.KeyboardMode.NONE)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.TOP, True)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.RIGHT if anchor_right else GtkLayerShell.Edge.LEFT, True)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.TOP, int(lay["top"]))
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.RIGHT if anchor_right else GtkLayerShell.Edge.LEFT, int(lay["side"]))
        self.box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
        self.box.set_size_request(int(lay["width"]), -1)
        self.add(self.box)

    def add_card(self, w):
        self.box.pack_start(w, False, False, 0)


class App:
    def __init__(self):
        self.cfg = data.load_config()
        self.left, self.right = Column(False, self.cfg), Column(True, self.cfg)
        self.cpu, self.net = data.Cpu(), data.Network()
        self.updaters = []
        if self.cfg["clock"]["enabled"]:
            self.build_clock()
        if self.cfg["calendar"]["enabled"]:
            self.build_calendar()
        if self.cfg["weather"]["enabled"]:
            self.build_weather()
        if self.cfg["system"]["enabled"]:
            self.build_system()
        if self.cfg["player"]["enabled"]:
            self.build_player()
        for w in (self.left, self.right):
            w.show_all()
        if hasattr(self, "player_card"):
            self.player_card.hide()

    # ── часы ──────────────────────────────────────────────
    def build_clock(self):
        self.l_time = label("", "clock-time")
        self.l_day = label("", "clock-day")
        self.l_date = label("", "clock-date")
        self.left.add_card(card(self.l_time, self.l_day, self.l_date, css="card hero"))
        self.tick_clock()
        GLib.timeout_add_seconds(1, self.tick_clock)

    def tick_clock(self):
        n = datetime.datetime.now()
        fmt = "%H:%M" if self.cfg["clock"].get("hour24", True) else "%I:%M"
        self.l_time.set_text(n.strftime(fmt))
        self.l_day.set_text(DAYS[n.weekday()])
        self.l_date.set_text(f"{n.day} {MONTHS[n.month - 1]} {n.year}")
        return True

    # ── календарь ─────────────────────────────────────────
    def build_calendar(self):
        cal = Gtk.Calendar()
        cal.set_property("show-week-numbers", False)
        cal.get_style_context().add_class("cal")
        self.left.add_card(card(cal))

    # ── погода ────────────────────────────────────────────
    def build_weather(self):
        self.w_icon, self.w_temp = label("·", "w-icon"), label("--", "w-temp")
        self.w_text, self.w_place = label("Загружаю…", "w-text"), label("", "w-place")
        self.w_extra = label("", "w-extra")
        top = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=14)
        top.pack_start(self.w_icon, False, False, 0)
        top.pack_start(self.w_temp, False, False, 0)
        self.right.add_card(card(self.w_place, top, self.w_text, self.w_extra))
        self.refresh_weather()
        GLib.timeout_add_seconds(900, self.refresh_weather)

    def refresh_weather(self):
        def work():
            try:
                res, err = data.weather(self.cfg), None
            except Exception as e:  # сеть/город — показываем понятную подсказку
                res, err = None, str(e)
            GLib.idle_add(self.show_weather, res, err)
        threading.Thread(target=work, daemon=True).start()
        return True

    def show_weather(self, w, err):
        if w is None:
            self.w_icon.set_text("☁")
            self.w_temp.set_text("")
            self.w_place.set_text("ПОГОДА")
            if "не задан город" in (err or ""):
                self.w_text.set_text("Город не указан")
                self.w_extra.set_text("В терминале:  northling widgets city Название")
            elif "не найден" in (err or ""):
                self.w_text.set_text("Такой город не найден")
                self.w_extra.set_text("Попробуй другое написание:  northling widgets city Название")
            else:
                self.w_text.set_text("Нет данных (проверь сеть)")
                self.w_extra.set_text("")
            return False
        self.w_icon.set_text(w["icon"])
        self.w_temp.set_text(f"{w['temp']}{w['unit']}")
        self.w_place.set_text(w["place"])
        self.w_text.set_text(w["text"])
        self.w_extra.set_text(f"ощущается {w['feels']}{w['unit']}  ·  {w['lo']}…{w['hi']}{w['unit']}  ·  ветер {w['wind']} {w['wind_unit']}")
        return False

    # ── система ───────────────────────────────────────────
    def build_system(self):
        r1, self.u_cpu = bar_row("CPU", "b-cpu")
        r2, self.u_mem = bar_row("RAM", "b-mem")
        r3, self.u_gpu = bar_row("GPU", "b-gpu")
        self.row_gpu = r3
        self.l_net = label("", "net")
        self.l_net_rate = label("", "net-rate")
        self.right.add_card(card(label("Система", "card-title"), r1, r2, r3, self.l_net, self.l_net_rate))
        self.tick_system()
        GLib.timeout_add_seconds(2, self.tick_system)

    def tick_system(self):
        p = self.cpu.percent()
        self.u_cpu(p / 100, f"{p}%", level(p))
        mp, used, total = data.memory()
        self.u_mem(mp / 100, f"{mp}%", level(mp))
        g = data.gpu()
        if g:
            self.row_gpu.show()
            self.u_gpu(g[0] / 100, f"{g[0]}%  {g[1]}°", level(g[0]))
        else:
            self.row_gpu.hide()
        n = self.net.poll()
        if n["state"] == "online":
            self.l_net.set_text(f"● {n['name']}")
            self.l_net_rate.set_text(f"↓ {data.human_rate(n['down'])}   ↑ {data.human_rate(n['up'])}")
        else:
            self.l_net.set_text("○ нет сети")
            self.l_net_rate.set_text("")
        return True

    # ── плеер ─────────────────────────────────────────────
    def build_player(self):
        self.p_title, self.p_artist = label("", "p-title"), label("", "p-artist")
        self.p_title.set_ellipsize(3)
        self.p_artist.set_ellipsize(3)
        self.p_bar = Gtk.ProgressBar()
        self.p_bar.get_style_context().add_class("b-player")
        ctrl = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        ctrl.set_halign(Gtk.Align.CENTER)
        self.p_btn = None
        for text, cmd in (("⏮", "previous"), ("▶", "play-pause"), ("⏭", "next")):
            b = Gtk.Button(label=text)
            b.get_style_context().add_class("pbtn")
            b.connect("clicked", lambda _b, c=cmd: (data.player_cmd(c), GLib.timeout_add(250, self.tick_player)))
            if cmd == "play-pause":
                self.p_btn = b
            ctrl.pack_start(b, False, False, 0)
        self.player_card = card(label("Сейчас играет", "card-title"), self.p_title, self.p_artist, self.p_bar, ctrl)
        self.right.add_card(self.player_card)
        self.tick_player()
        GLib.timeout_add_seconds(2, self.tick_player)

    def tick_player(self):
        p = data.player()
        if not p:
            self.player_card.hide()
            return True
        self.player_card.show()
        self.p_title.set_text(p["title"])
        self.p_artist.set_text(p["artist"] or "—")
        self.p_btn.set_label("❚❚" if p["status"] == "Playing" else "▶")
        self.p_bar.set_fraction(p["pos"] / p["length"] if p["length"] else 0)
        return True


def main():
    css = Gtk.CssProvider()
    css.load_from_path(os.path.join(HERE, "style.css"))
    Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
    App()
    Gtk.main()


if __name__ == "__main__":
    main()
