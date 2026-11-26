#!/usr/bin/env python3
"""Northling Start — «Пуск»: поиск, приложения, гайд по биндам, настройки, питание.
Открывается по Super+R или кликом по «n.» в панели. Esc — закрыть.
Умная строка: «2+2*3» — калькулятор, «> htop» — команда в терминале, «? запрос» — поиск в интернете."""
import ast, getpass, datetime, json, math, operator, os, re, shlex, subprocess, sys, threading

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import nl_data as data

import gi
gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gtk, Gdk, GLib, Gio, GdkPixbuf, GtkLayerShell  # noqa: E402

# LD_PRELOAD нужен только для создания окна; детям (запускаемым программам) он вредит
os.environ.pop("LD_PRELOAD", None)

HERE = os.path.dirname(os.path.abspath(__file__))
WALL_DIR = os.path.expanduser("~/Pictures/Wallpapers")
TERMINAL = "kitty"

# ── гайд по биндам (Super = клавиша Windows) ───────────────────────────
BINDS = [
    ("Главное", [
        ("Super + R", "Этот «Пуск»: поиск и приложения"),
        ("Super + Q", "Терминал (Kitty)"),
        ("Super + E", "Файлы (Dolphin)"),
        ("Super + C", "Закрыть окно"),
        ("Super + L", "Заблокировать экран"),
        ("Super + V", "Буфер обмена (история и закрепы)"),
        ("Super + A", "Центр управления (звук, Wi-Fi, режимы)"),
        ("Super + G", "Игровой режим вкл/выкл"),
        ("Super + Shift + R", "Запасной лаунчер rofi"),
        ("Super + M", "Выйти из сессии"),
    ]),
    ("Окна", [
        ("Super + Space", "Окно плавающее / обычное"),
        ("Super + F", "На весь экран"),
        ("Super + J", "Сменить раскладку деления"),
        ("Super + P", "Псевдо-тайлинг"),
        ("Super + стрелки", "Переключить фокус между окнами"),
        ("Super + ЛКМ (тянуть)", "Двигать окно мышью"),
        ("Super + ПКМ (тянуть)", "Менять размер окна мышью"),
    ]),
    ("Рабочие столы", [
        ("Super + 1…9", "Перейти на рабочий стол"),
        ("Super + Shift + 1…9", "Перенести окно на рабочий стол"),
        ("Super + колесо мыши", "Листать рабочие столы"),
        ("Super + S", "Скрытый рабочий стол (scratchpad)"),
        ("Super + Shift + S", "Убрать окно в scratchpad"),
    ]),
    ("Скриншоты и звук", [
        ("Print", "Скриншот области"),
        ("Shift + Print", "Скриншот всего экрана"),
        ("Громкость / Mute", "Мультимедийные клавиши"),
        ("Play / Next / Prev", "Управление плеером"),
    ]),
    ("Панель", [
        ("Клик по времени", "Показать дату вместо времени"),
        ("Клик по EN/RU", "Сменить раскладку"),
        ("ПКМ по «n.»", "Настройки"),
    ]),
]

POWER = [
    ("󰌾", "Заблокировать", ["hyprlock"]),
    ("󰤄", "Сон", ["systemctl", "suspend"]),
    ("󰍃", "Выйти", ["hyprctl", "dispatch", "exit"]),
    ("󰜉", "Перезагрузка", ["systemctl", "reboot"]),
    ("󰐥", "Выключить", ["systemctl", "poweroff"]),
]

QUICK = [
    ("Перезапустить панель", ["sh", "-c", "pkill waybar; sleep 0.3; waybar"]),
    ("Перезагрузить Hyprland", ["hyprctl", "reload"]),
    ("Обновить систему", [TERMINAL, "-e", "northling", "update", "--fast"]),
    ("Диагностика", [TERMINAL, "-e", "northling", "diag"]),
    ("Конфиг Hyprland", ["xdg-open", os.path.expanduser("~/.config/hypr/hyprland.lua")]),
    ("Конфиг виджетов", ["xdg-open", os.path.expanduser("~/.config/northling/widgets.json")]),
]

PINNED = [  # (подстрока id, запасное название)
    "firefox", "kitty", "dolphin", "code", "discord", "vlc", "systemsettings", "nm-connection-editor",
]


# ── чистая логика (проверяется тестами без GTK) ─────────────────────────
_OPS = {ast.Add: operator.add, ast.Sub: operator.sub, ast.Mult: operator.mul, ast.Div: operator.truediv,
        ast.FloorDiv: operator.floordiv, ast.Mod: operator.mod, ast.Pow: operator.pow}
_FUNCS = {"sqrt": math.sqrt, "sin": math.sin, "cos": math.cos, "tan": math.tan, "log": math.log10, "ln": math.log,
          "abs": abs, "round": round}
_CONST = {"pi": math.pi, "e": math.e}


def _ev(n):
    if isinstance(n, ast.Constant) and isinstance(n.value, (int, float)) and not isinstance(n.value, bool):
        return n.value
    if isinstance(n, ast.BinOp) and type(n.op) in _OPS:
        a, b = _ev(n.left), _ev(n.right)
        if isinstance(n.op, ast.Pow) and abs(b) > 1000:
            raise ValueError("слишком большая степень")
        return _OPS[type(n.op)](a, b)
    if isinstance(n, ast.UnaryOp) and isinstance(n.op, (ast.UAdd, ast.USub)):
        return _ev(n.operand) if isinstance(n.op, ast.UAdd) else -_ev(n.operand)
    if isinstance(n, ast.Name) and n.id in _CONST:
        return _CONST[n.id]
    if isinstance(n, ast.Call) and isinstance(n.func, ast.Name) and n.func.id in _FUNCS and len(n.args) == 1 and not n.keywords:
        return _FUNCS[n.func.id](_ev(n.args[0]))
    raise ValueError("не выражение")


def safe_calc(text):
    """«2+2*3» → '8'. Не математика → None. Никакого eval: разбираем через ast."""
    t = text.strip().replace(",", ".").replace("×", "*").replace("÷", "/").replace("^", "**")
    if not t or not any(c.isdigit() for c in t):
        return None
    if not any(c in t for c in "+-*/%()") and not any(f in t for f in _FUNCS):
        return None
    try:
        v = _ev(ast.parse(t, mode="eval").body)
    except Exception:
        return None
    if isinstance(v, float):
        if math.isnan(v) or math.isinf(v):
            return None
        v = round(v, 10)
        return ("%.10f" % v).rstrip("0").rstrip(".") if v != int(v) else str(int(v))
    return str(v)


def filter_binds(q):
    q = q.strip().lower()
    out = []
    for title, rows in BINDS:
        hit = [r for r in rows if not q or q in r[0].lower() or q in r[1].lower() or q in title.lower()]
        if hit:
            out.append((title, hit))
    return out


def score_app(name, keywords, q):
    """Чем меньше — тем выше в списке. None — не подходит."""
    n, q = name.lower(), q.lower()
    if n == q:
        return 0
    if n.startswith(q):
        return 1
    if any(w.startswith(q) for w in n.replace("-", " ").split()):
        return 2
    if q in n:
        return 3
    if q in keywords.lower():
        return 4
    return None


def greeting(now=None):
    h = (now or datetime.datetime.now()).hour
    return "Доброй ночи" if h < 5 else "Доброе утро" if h < 12 else "Добрый день" if h < 18 else "Добрый вечер"


def spawn(cmd):
    try:
        subprocess.Popen(cmd, start_new_session=True, stdin=subprocess.DEVNULL,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return True
    except OSError:
        return False


PKG_RE = re.compile(r"^[A-Za-z0-9@._+-]+$")


def parse_pacman_ss(text):
    """Вывод `pacman -Ss` / `paru -Ssa` → [{repo,name,ver,installed,desc}]."""
    out, cur = [], None
    for line in (text or "").splitlines():
        m = re.match(r"^(\S+)/(\S+)\s+(\S+)(.*)$", line)
        if m and not line.startswith(" "):
            cur = {"repo": m.group(1), "name": m.group(2), "ver": m.group(3),
                   "installed": "nstalled" in m.group(4), "desc": ""}
            out.append(cur)
        elif cur is not None and line.startswith(" "):
            cur["desc"] = (cur["desc"] + " " + line.strip()).strip()
    return out


def install_cmd(pkg, remove=False):
    """Команда для терминала. Имя пакета проверяем строго — в оболочку попадает только безопасное."""
    if not PKG_RE.match(pkg["name"]):
        return None
    n = shlex.quote(pkg["name"])
    if remove:
        body = f"sudo pacman -Rns {n}"
    elif pkg["repo"] == "aur":
        body = f"paru -S {n}"
    else:
        body = f"sudo pacman -S --needed {n}"
    return [TERMINAL, "sh", "-c", body + "; echo; read -r -p 'Готово. Enter — закрыть… ' _"]


def parse_cliphist(text):
    """`cliphist list`: «id<TAB>текст» → [(id, текст, бинарное?)]."""
    out = []
    for line in (text or "").splitlines():
        if "\t" not in line:
            continue
        i, t = line.split("\t", 1)
        if i.isdigit():
            binary = t.startswith("[[ binary")
            out.append((i, "🖼  изображение" if binary else t.strip(), binary))
    return out


PINS_PATH = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")), "northling", "pins.json")


def load_pins(path=None):
    try:
        with open(path or PINS_PATH, encoding="utf-8") as f:
            v = json.load(f)
        return [x for x in v if isinstance(x, str)]
    except (OSError, ValueError):
        return []


def save_pins(pins, path=None):
    path = path or PINS_PATH
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(pins[:50], f, ensure_ascii=False, indent=2)


def save_widgets_conf(updates, path=data.CONF_PATH):
    """Точечно меняем widgets.json: {"clock": {"style": "digital"}, ...}. Остальное не трогаем."""
    try:
        with open(path, encoding="utf-8") as f:
            cfg = json.load(f)
    except (OSError, ValueError):
        cfg = {}
    for sec, vals in updates.items():
        cfg.setdefault(sec, {}).update(vals)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(cfg, f, ensure_ascii=False, indent=2)
    os.replace(tmp, path)


# ── интерфейс ───────────────────────────────────────────────────────────
def add_classes(w, css):
    for c in (css or "").split():
        w.get_style_context().add_class(c)


def lbl(text, css=None, xalign=0.0, chars=48):
    l = Gtk.Label(label=text)
    l.set_xalign(xalign)
    l.set_max_width_chars(chars)
    l.set_ellipsize(3)
    add_classes(l, css)
    return l


def btn(text, css, cb):
    b = Gtk.Button(label=text)
    add_classes(b, css)
    b.connect("clicked", lambda *_: cb())
    return b


class Start(Gtk.Window):
    TABS = [("apps", "Приложения"), ("store", "Установка"), ("clip", "Буфер"), ("binds", "Бинды"), ("settings", "Настройки"), ("power", "Система")]

    def __init__(self, tab="apps"):
        super().__init__(title="Northling Start")
        self.apps = self.load_apps()
        self.rows = []
        self.wall_loaded = False

        GtkLayerShell.init_for_window(self)
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
        self.load_css()

        scrim = Gtk.EventBox()
        scrim.get_style_context().add_class("scrim")
        scrim.connect("button-press-event", self.on_scrim_click)
        self.add(scrim)

        self.card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
        add_classes(self.card, "start-card")
        self.card.set_size_request(900, 620)
        self.card.set_halign(Gtk.Align.CENTER)
        self.card.set_valign(Gtk.Align.CENTER)
        scrim.add(self.card)

        self.card.pack_start(self.build_header(), False, False, 0)
        self.card.pack_start(self.build_tabs(), False, False, 0)

        self.stack = Gtk.Stack()
        self.stack.set_transition_type(Gtk.StackTransitionType.CROSSFADE)
        self.stack.set_transition_duration(160)
        self.stack.add_named(self.build_apps(), "apps")
        self.stack.add_named(self.build_store(), "store")
        self.stack.add_named(self.build_clip(), "clip")
        self.stack.add_named(self.build_binds(), "binds")
        self.stack.add_named(self.build_settings(), "settings")
        self.stack.add_named(self.build_power(), "power")
        self.card.pack_start(self.stack, True, True, 0)
        self.card.pack_start(lbl("Esc — закрыть   ·   Enter — открыть   ·   ↑↓ — выбор   ·   Ctrl+1…6 — вкладки   ·   2+2 · > команда · ? поиск в сети",
                                 "hint", 0.5, 120), False, False, 0)

        self.connect("key-press-event", self.on_key)
        self.connect("destroy", lambda *_: Gtk.main_quit())
        self.show_tab(tab)
        self.refresh_results("")
        self.show_all()
        self.entry.grab_focus()

    # --- данные ---
    @staticmethod
    def load_apps():
        out = []
        for a in Gio.AppInfo.get_all():
            try:
                if not a.should_show():
                    continue
                kw = " ".join(a.get_keywords() or []) if hasattr(a, "get_keywords") else ""
                out.append({"name": a.get_name() or "", "id": a.get_id() or "", "kw": kw + " " + (a.get_description() or ""),
                            "icon": a.get_icon(), "info": a})
            except Exception:
                continue
        out.sort(key=lambda x: x["name"].lower())
        return out

    def load_css(self):
        p = Gtk.CssProvider()
        try:
            p.load_from_path(os.path.join(HERE, "start.css"))
            Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), p, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
        except Exception as e:
            print("start.css:", e, file=sys.stderr)

    # --- шапка ---
    def build_header(self):
        box = Gtk.Box(spacing=18)
        logo = lbl("n.", "start-logo")
        box.pack_start(logo, False, False, 0)
        right = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        now = datetime.datetime.now()
        right.pack_start(lbl(f"{greeting(now)}, {getpass.getuser()}", "start-hello"), False, False, 0)
        self.entry = Gtk.SearchEntry()
        self.entry.set_placeholder_text("Поиск: приложения, бинды, калькулятор…")
        add_classes(self.entry, "start-search")
        self.entry.connect("search-changed", lambda e: self.on_search(e.get_text()))
        self.entry.connect("activate", lambda e: self.activate_selected())
        right.pack_start(self.entry, False, False, 0)
        box.pack_start(right, True, True, 0)
        return box

    def build_tabs(self):
        box = Gtk.Box(spacing=8)
        self.tab_btns = {}
        for i, (key, title) in enumerate(self.TABS, 1):
            b = Gtk.Button(label=f"{title}")
            add_classes(b, "tab")
            b.connect("clicked", lambda _b, k=key: self.show_tab(k))
            box.pack_start(b, False, False, 0)
            self.tab_btns[key] = b
        return box

    def show_tab(self, key):
        self.stack.set_visible_child_name(key)
        for k, b in self.tab_btns.items():
            ctx = b.get_style_context()
            (ctx.add_class if k == key else ctx.remove_class)("tab-on")
        if key == "store":
            self.store_entry.grab_focus()
        elif key == "clip":
            self.refresh_clip()
        elif key == "apps":
            self.entry.grab_focus()
        if key == "settings" and not self.wall_loaded:
            self.wall_loaded = True
            GLib.idle_add(self.load_wallpapers)

    # --- вкладка «Приложения» ---
    def build_apps(self):
        page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        self.pinned_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        self.pinned_box.pack_start(lbl("ЗАКРЕПЛЁННОЕ", "section"), False, False, 0)
        flow = Gtk.FlowBox()
        flow.set_max_children_per_line(8)
        flow.set_min_children_per_line(4)
        flow.set_selection_mode(Gtk.SelectionMode.NONE)
        flow.set_homogeneous(True)
        used = set()
        for key in PINNED:
            for a in self.apps:
                if key in a["id"].lower() and a["id"] not in used:
                    used.add(a["id"])
                    flow.add(self.pin_button(a))
                    break
        self.pinned_box.pack_start(flow, False, False, 0)
        page.pack_start(self.pinned_box, False, False, 0)
        self.res_title = lbl("ВСЕ ПРИЛОЖЕНИЯ", "section")
        page.pack_start(self.res_title, False, False, 0)
        sw = Gtk.ScrolledWindow()
        sw.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        self.list = Gtk.ListBox()
        self.list.set_selection_mode(Gtk.SelectionMode.SINGLE)
        self.list.connect("row-activated", lambda lb_, row: self.run_row(row))
        add_classes(self.list, "results")
        sw.add(self.list)
        page.pack_start(sw, True, True, 0)
        return page

    def pin_button(self, a):
        b = Gtk.Button()
        add_classes(b, "pin")
        v = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        img = Gtk.Image.new_from_gicon(a["icon"], Gtk.IconSize.DIALOG) if a["icon"] else Gtk.Image()
        v.pack_start(img, False, False, 0)
        v.pack_start(lbl(a["name"], "pin-name", 0.5, 12), False, False, 0)
        b.add(v)
        b.connect("clicked", lambda *_: self.launch(a))
        return b

    def on_search(self, text):
        if text.strip():
            self.stack.set_visible_child_name("apps")
            for k, b in self.tab_btns.items():
                (b.get_style_context().add_class if k == "apps" else b.get_style_context().remove_class)("tab-on")
        self.refresh_results(text)
        self.filter_bind_page(text)

    def refresh_results(self, q):
        for r in self.list.get_children():
            self.list.remove(r)
        self.rows = []
        q = q.strip()
        self.pinned_box.set_visible(not q)
        items = []
        if q:
            calc = safe_calc(q)
            if calc is not None:
                items.append(("calc", "󰃬", f"= {calc}", "Enter — скопировать результат", calc))
            if q.startswith(">") and q[1:].strip():
                items.append(("run", "", q[1:].strip(), "Выполнить в терминале", q[1:].strip()))
            if q.startswith("?") and q[1:].strip():
                items.append(("web", "󰖟", q[1:].strip(), "Искать в интернете (DuckDuckGo)", q[1:].strip()))
            scored = []
            for a in self.apps:
                s = score_app(a["name"], a["kw"], q)
                if s is not None:
                    scored.append((s, a["name"].lower(), a))
            scored.sort(key=lambda x: (x[0], x[1]))
            for _, _, a in scored[:30]:
                items.append(("app", None, a["name"], a["id"], a))
            for title, rows in filter_binds(q)[:3]:
                for keys, desc in rows[:3]:
                    items.append(("bind", "󰌌", desc, keys, None))
            if not items:
                items.append(("web", "󰖟", q, "Ничего не нашёл — искать в интернете", q))
            self.res_title.set_text("РЕЗУЛЬТАТЫ")
        else:
            for a in self.apps:
                items.append(("app", None, a["name"], "", a))
            self.res_title.set_text("ВСЕ ПРИЛОЖЕНИЯ")
        for it in items:
            row = self.make_row(it)
            self.list.add(row)
            self.rows.append(row)
        self.list.show_all()
        if self.rows:
            self.list.select_row(self.rows[0])

    def make_row(self, it):
        kind, glyph, title, sub, payload = it
        row = Gtk.ListBoxRow()
        row.nl = (kind, payload)
        h = Gtk.Box(spacing=12)
        add_classes(h, "row")
        if kind == "app" and payload["icon"]:
            h.pack_start(Gtk.Image.new_from_gicon(payload["icon"], Gtk.IconSize.LARGE_TOOLBAR), False, False, 0)
        else:
            h.pack_start(lbl(glyph or "", "row-glyph", 0.5, 3), False, False, 0)
        v = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        v.pack_start(lbl(title, "row-title", 0.0, 60), False, False, 0)
        if sub and kind != "app":
            v.pack_start(lbl(sub, "row-sub", 0.0, 70), False, False, 0)
        h.pack_start(v, True, True, 0)
        if kind == "bind":
            h.pack_end(lbl(sub, "keycap", 1.0, 30), False, False, 0)
        row.add(h)
        return row

    def run_row(self, row):
        kind, payload = row.nl
        if kind == "app":
            self.launch(payload)
        elif kind == "calc":
            spawn(["sh", "-c", f"printf %s '{payload}' | wl-copy"])
            self.close_now()
        elif kind == "run":
            spawn([TERMINAL, "--hold", "sh", "-c", payload])
            self.close_now()
        elif kind == "web":
            from urllib.parse import quote
            spawn(["xdg-open", "https://duckduckgo.com/?q=" + quote(payload)])
            self.close_now()
        elif kind == "bind":
            self.show_tab("binds")

    def activate_selected(self):
        row = self.list.get_selected_row() or (self.rows[0] if self.rows else None)
        if row is not None:
            self.run_row(row)

    def launch(self, a):
        ok = spawn(["gtk-launch", a["id"]]) if a["id"] else False
        if not ok:
            try:
                a["info"].launch([], None)
            except Exception as e:
                print("launch:", e, file=sys.stderr)
        self.close_now()

    # --- вкладка «Установка» (pacman + AUR) ---
    def build_store(self):
        page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        self.store_entry = Gtk.SearchEntry()
        self.store_entry.set_placeholder_text("Название программы — найду в репозиториях Arch и AUR, поставлю в один клик")
        add_classes(self.store_entry, "start-search")
        self.store_entry.connect("activate", lambda e: self.store_search(e.get_text()))
        page.pack_start(self.store_entry, False, False, 0)
        self.store_status = lbl("Введи название и нажми Enter. Установка идёт в терминале — там спросит пароль.", "hint")
        page.pack_start(self.store_status, False, False, 0)
        sw = Gtk.ScrolledWindow()
        sw.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        self.store_list = Gtk.ListBox()
        self.store_list.set_selection_mode(Gtk.SelectionMode.NONE)
        add_classes(self.store_list, "results")
        sw.add(self.store_list)
        page.pack_start(sw, True, True, 0)
        return page

    def store_search(self, q):
        q = q.strip()
        if len(q) < 2:
            return
        self.store_status.set_text("Ищу…")

        def work():
            found = []
            try:
                r = subprocess.run(["pacman", "-Ss", q], capture_output=True, text=True, timeout=20)
                found += parse_pacman_ss(r.stdout)
            except (OSError, subprocess.SubprocessError):
                pass
            if subprocess.run(["sh", "-c", "command -v paru"], capture_output=True).returncode == 0:
                try:
                    r = subprocess.run(["paru", "-Ssa", q], capture_output=True, text=True, timeout=25)
                    seen = {x["name"] for x in found}
                    found += [x for x in parse_pacman_ss(r.stdout) if x["repo"] == "aur" and x["name"] not in seen]
                except (OSError, subprocess.SubprocessError):
                    pass
            GLib.idle_add(self.store_show, found[:40], q)
        threading.Thread(target=work, daemon=True).start()

    def store_show(self, found, q):
        for r in self.store_list.get_children():
            self.store_list.remove(r)
        for pkg in found:
            row = Gtk.ListBoxRow()
            h = Gtk.Box(spacing=12)
            add_classes(h, "row")
            v = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
            v.pack_start(lbl(f"{pkg['name']}   {pkg['ver']}", "row-title", 0.0, 60), False, False, 0)
            v.pack_start(lbl(pkg["desc"] or "—", "row-sub", 0.0, 90), False, False, 0)
            h.pack_start(v, True, True, 0)
            h.pack_start(lbl(pkg["repo"], "keycap", 1.0, 10), False, False, 0)
            rm = pkg["installed"]
            h.pack_start(btn("Удалить" if rm else "Установить", "chip" if rm else "primary",
                             lambda p=pkg, r=rm: self.store_do(p, r)), False, False, 0)
            row.add(h)
            self.store_list.add(row)
        self.store_list.show_all()
        self.store_status.set_text(f"Найдено: {len(found)}" if found else f"По запросу «{q}» ничего нет")
        return False

    def store_do(self, pkg, remove):
        cmd = install_cmd(pkg, remove)
        if cmd and spawn(cmd):
            self.store_status.set_text(("Удаляю " if remove else "Ставлю ") + pkg["name"] + " — смотри терминал")
        else:
            self.store_status.set_text("Не смог запустить терминал или странное имя пакета")

    # --- вкладка «Буфер» ---
    def build_clip(self):
        page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        self.clip_entry = Gtk.SearchEntry()
        self.clip_entry.set_placeholder_text("Фильтр по истории буфера обмена")
        add_classes(self.clip_entry, "start-search")
        self.clip_entry.connect("search-changed", lambda e: self.refresh_clip())
        page.pack_start(self.clip_entry, False, False, 0)
        sw = Gtk.ScrolledWindow()
        sw.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        self.clip_list = Gtk.ListBox()
        self.clip_list.set_selection_mode(Gtk.SelectionMode.NONE)
        add_classes(self.clip_list, "results")
        sw.add(self.clip_list)
        page.pack_start(sw, True, True, 0)
        return page

    def refresh_clip(self):
        for r in self.clip_list.get_children():
            self.clip_list.remove(r)
        q = self.clip_entry.get_text().strip().lower()
        pins = load_pins()
        entries = []
        for t in pins:
            if not q or q in t.lower():
                entries.append(("pin", t, t, False))
        try:
            out = subprocess.run(["cliphist", "list"], capture_output=True, text=True, timeout=3).stdout
        except (OSError, subprocess.SubprocessError):
            out = ""
        for i, t, binary in parse_cliphist(out)[:80]:
            if not q or q in t.lower():
                entries.append(("hist", i, t, binary))
        if not entries:
            entries.append(("none", "", "Пусто. Скопируй что-нибудь — оно появится здесь (нужен cliphist).", True))
        for kind, key, text, binary in entries:
            row = Gtk.ListBoxRow()
            h = Gtk.Box(spacing=12)
            add_classes(h, "row")
            h.pack_start(lbl("󰐃" if kind == "pin" else "󰅍", "row-glyph", 0.5, 3), False, False, 0)
            h.pack_start(lbl(text.replace("\n", " ")[:160], "row-title", 0.0, 80), True, True, 0)
            if kind in ("pin", "hist"):
                h.pack_start(btn("Копировать", "chip", lambda k=kind, kk=key: self.clip_copy(k, kk)), False, False, 0)
                if kind == "pin":
                    h.pack_start(btn("Открепить", "chip", lambda t=text: self.clip_unpin(t)), False, False, 0)
                elif not binary:
                    h.pack_start(btn("Закрепить", "chip", lambda t=text: self.clip_pin(t)), False, False, 0)
            row.add(h)
            self.clip_list.add(row)
        self.clip_list.show_all()

    def clip_copy(self, kind, key):
        if kind == "pin":
            p = subprocess.Popen(["wl-copy"], stdin=subprocess.PIPE, start_new_session=True)
            p.stdin.write(key.encode()); p.stdin.close()
        elif key.isdigit():
            spawn(["sh", "-c", f"cliphist decode {key} | wl-copy"])
        self.close_now()

    def clip_pin(self, text):
        pins = [t for t in load_pins() if t != text]
        save_pins([text] + pins)
        self.refresh_clip()

    def clip_unpin(self, text):
        save_pins([t for t in load_pins() if t != text])
        self.refresh_clip()

    # --- вкладка «Бинды» ---
    def build_binds(self):
        sw = Gtk.ScrolledWindow()
        sw.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        self.binds_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        sw.add(self.binds_box)
        self.filter_bind_page("")
        return sw

    def filter_bind_page(self, q):
        for c in self.binds_box.get_children():
            self.binds_box.remove(c)
        for title, rows in filter_binds(q):
            self.binds_box.pack_start(lbl(title.upper(), "section"), False, False, 4)
            for keys, desc in rows:
                h = Gtk.Box(spacing=12)
                add_classes(h, "row")
                h.pack_start(lbl(keys, "keycap", 0.0, 28), False, False, 0)
                h.pack_start(lbl(desc, "row-title", 0.0, 60), True, True, 0)
                self.binds_box.pack_start(h, False, False, 0)
        self.binds_box.show_all()

    # --- вкладка «Настройки» ---
    def build_settings(self):
        sw = Gtk.ScrolledWindow()
        sw.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        cfg = data.load_config()
        self.sw = {}

        box.pack_start(lbl("ВИДЖЕТЫ НА РАБОЧЕМ СТОЛЕ", "section"), False, False, 0)
        grid = Gtk.Grid(column_spacing=24, row_spacing=8)
        for i, (key, title) in enumerate([("clock", "Часы"), ("calendar", "Календарь"), ("system", "Система"),
                                          ("weather", "Погода"), ("player", "Плеер")]):
            s = Gtk.Switch()
            s.set_active(bool(cfg.get(key, {}).get("enabled", True)))
            s.set_halign(Gtk.Align.START)
            self.sw[key] = s
            grid.attach(lbl(title, "row-title"), (i % 2) * 2, i // 2, 1, 1)
            grid.attach(s, (i % 2) * 2 + 1, i // 2, 1, 1)
        box.pack_start(grid, False, False, 0)

        r = Gtk.Box(spacing=10)
        r.pack_start(lbl("Часы:", "row-title", 0.0, 10), False, False, 0)
        self.clock_style = Gtk.ComboBoxText()
        self.clock_style.append("analog", "Аналоговые")
        self.clock_style.append("digital", "Цифровые")
        self.clock_style.set_active_id(cfg["clock"].get("style", "analog"))
        r.pack_start(self.clock_style, False, False, 0)
        r.pack_start(lbl("Город:", "row-title", 0.0, 10), False, False, 8)
        self.city = Gtk.Entry()
        self.city.set_text(cfg["weather"].get("city", "") or "")
        self.city.set_placeholder_text("например, Калининград")
        add_classes(self.city, "start-input")
        r.pack_start(self.city, True, True, 0)
        r.pack_start(btn("Применить", "primary", self.apply_widgets), False, False, 0)
        box.pack_start(r, False, False, 0)
        self.status = lbl("", "hint")
        box.pack_start(self.status, False, False, 0)

        box.pack_start(lbl("ОБОИ  (клик — поставить; свои кидай в ~/Pictures/Wallpapers)", "section"), False, False, 6)
        self.walls = Gtk.FlowBox()
        self.walls.set_selection_mode(Gtk.SelectionMode.NONE)
        self.walls.set_max_children_per_line(4)
        box.pack_start(self.walls, False, False, 0)

        box.pack_start(lbl("БЫСТРЫЕ ДЕЙСТВИЯ", "section"), False, False, 6)
        q = Gtk.FlowBox()
        q.set_selection_mode(Gtk.SelectionMode.NONE)
        q.set_max_children_per_line(3)
        for title, cmd in QUICK:
            q.add(btn(title, "chip", lambda c=cmd: (spawn(c), self.close_now())))
        box.pack_start(q, False, False, 0)
        sw.add(box)
        return sw

    def apply_widgets(self):
        upd = {k: {"enabled": s.get_active()} for k, s in self.sw.items()}
        upd["clock"]["style"] = self.clock_style.get_active_id() or "analog"
        city = self.city.get_text().strip()
        upd["weather"].update({"city": city, "latitude": None, "longitude": None})
        try:
            save_widgets_conf(upd)
        except OSError as e:
            self.status.set_text(f"Не смог сохранить: {e}")
            return
        spawn(["northling-widgets", "restart"])
        self.status.set_text("Сохранено, виджеты перезапускаются…")

    def load_wallpapers(self):
        files = []
        try:
            for n in sorted(os.listdir(WALL_DIR)):
                if n.lower().endswith((".png", ".jpg", ".jpeg", ".webp")):
                    files.append(os.path.join(WALL_DIR, n))
        except OSError:
            pass
        for f in files[:24]:
            try:
                pb = GdkPixbuf.Pixbuf.new_from_file_at_scale(f, 190, 107, True)
            except Exception:
                continue
            b = Gtk.Button()
            add_classes(b, "wall")
            b.add(Gtk.Image.new_from_pixbuf(pb))
            b.set_tooltip_text(os.path.basename(f))
            b.connect("clicked", lambda _b, p=f: (spawn(["northling-wallpaper", p]), self.status.set_text("Обои сменены")))
            self.walls.add(b)
        if not files:
            self.walls.add(lbl("В ~/Pictures/Wallpapers пока пусто", "hint"))
        self.walls.show_all()
        return False

    # --- вкладка «Система» ---
    def build_power(self):
        outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
        outer.set_valign(Gtk.Align.CENTER)
        row = Gtk.Box(spacing=14)
        row.set_halign(Gtk.Align.CENTER)
        for glyph, title, cmd in POWER:
            b = Gtk.Button()
            add_classes(b, "power")
            v = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
            v.pack_start(lbl(glyph, "power-glyph", 0.5, 4), False, False, 0)
            v.pack_start(lbl(title, "power-name", 0.5, 14), False, False, 0)
            b.add(v)
            b.connect("clicked", lambda _b, c=cmd: (spawn(c), self.close_now()))
            row.pack_start(b, False, False, 0)
        outer.pack_start(row, False, False, 0)
        outer.pack_start(lbl("Windows не затронут: перезагрузка вернёт тебя в обычное меню загрузки.", "hint", 0.5, 90), False, False, 0)
        return outer

    # --- события ---
    def on_scrim_click(self, w, ev):
        a = self.card.get_allocation()
        if not (a.x <= ev.x <= a.x + a.width and a.y <= ev.y <= a.y + a.height):
            self.close_now()
        return False

    def on_key(self, w, ev):
        k = ev.keyval
        if k == Gdk.KEY_Escape:
            self.close_now()
            return True
        if ev.state & Gdk.ModifierType.CONTROL_MASK and Gdk.KEY_1 <= k < Gdk.KEY_1 + len(self.TABS):
            self.show_tab(self.TABS[k - Gdk.KEY_1][0])
            return True
        if k in (Gdk.KEY_Down, Gdk.KEY_Up) and self.stack.get_visible_child_name() == "apps" and self.rows:
            cur = self.list.get_selected_row()
            i = self.rows.index(cur) if cur in self.rows else -1
            i = max(0, min(len(self.rows) - 1, i + (1 if k == Gdk.KEY_Down else -1)))
            self.list.select_row(self.rows[i])
            return True
        return False

    def close_now(self):
        Gtk.main_quit()


def main():
    tab = sys.argv[1] if len(sys.argv) > 1 and sys.argv[1] in dict(Start.TABS) else "apps"
    Start(tab)
    Gtk.main()


if __name__ == "__main__":
    main()
