"""Логика «Пуска» без GTK: калькулятор, поиск, бинды, сохранение настроек, сборка окна на пустышках."""
import sys, types, os, json, tempfile
from unittest import mock

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "widgets")
sys.path.insert(0, ROOT)
gi = types.ModuleType("gi"); gi.require_version = lambda *a, **k: None
repo = types.ModuleType("gi.repository")
for n in ("Gtk", "Gdk", "GLib", "Gio", "GdkPixbuf", "GtkLayerShell"):
    setattr(repo, n, mock.MagicMock(name=n))
repo.Gtk.Window = type("Window", (), {"__init__": lambda s, **k: None, "__getattr__": lambda s, n: mock.MagicMock()})
repo.Gio.AppInfo.get_all.return_value = []
repo.GLib.idle_add = lambda *a, **k: 1
sys.modules.update({"gi": gi, "gi.repository": repo}); gi.repository = repo
import northling_start as ns

c = ns.safe_calc
assert c("2+2*3") == "8" and c("10/4") == "2.5" and c("2^10") == "1024" and c("sqrt(16)") == "4"
assert c("1,5*2") == "3" and c("firefox") is None and c("2") is None and c("__import__('os')") is None
assert c("9**9**9") is None  # защита от огромных степеней
assert c("1/0") is None
assert ns.score_app("Firefox", "web browser", "fire") == 1 and ns.score_app("Firefox", "web browser", "xyz") is None
assert ns.score_app("Files", "dolphin", "dolph") == 4
assert ns.filter_binds("скриншот") and not ns.filter_binds("qwertyzzz")
assert any("Super + R" in r[0] for _, rows in ns.filter_binds("пуск") for r in rows)
assert ns.greeting(__import__("datetime").datetime(2026, 1, 1, 20)) == "Добрый вечер"

d = tempfile.mkdtemp(); p = os.path.join(d, "n", "widgets.json")
ns.save_widgets_conf({"clock": {"style": "digital"}}, p)
ns.save_widgets_conf({"weather": {"city": "Калининград"}}, p)
j = json.load(open(p, encoding="utf-8"))
assert j["clock"]["style"] == "digital" and j["weather"]["city"] == "Калининград"

ns.WALL_DIR = d
w = ns.Start("apps")
w.refresh_results("2+2"); w.refresh_results("fire"); w.refresh_results("")
print("Start smoke test OK")

# ── «Установка», «Буфер» ──
pk = ns.parse_pacman_ss("extra/firefox 130.0-1 [installed]\n    Fast, Private & Safe Web Browser\naur/foo-bin 1.2-1 (+5 0.10)\n    Some tool\n")
assert len(pk) == 2 and pk[0]["installed"] and pk[0]["desc"].startswith("Fast") and pk[1]["repo"] == "aur" and not pk[1]["installed"]
assert ns.install_cmd({"name": "firefox", "repo": "extra"})[-1].startswith("sudo pacman -S --needed firefox")
assert "paru -S foo-bin" in ns.install_cmd({"name": "foo-bin", "repo": "aur"})[-1]
assert "pacman -Rns" in ns.install_cmd({"name": "x", "repo": "extra"}, remove=True)[-1]
assert ns.install_cmd({"name": "x; rm -rf ~", "repo": "extra"}) is None and ns.install_cmd({"name": "$(id)", "repo": "aur"}) is None
cl = ns.parse_cliphist("12\tпривет мир\n11\t[[ binary data 1 KiB png 10x10 ]]\nмусор\n")
assert cl == [("12", "привет мир", False), ("11", "🖼  изображение", True)]
pp = os.path.join(d, "pins.json"); ns.save_pins(["a", "б"], pp); assert ns.load_pins(pp) == ["a", "б"]
w.store_show(pk, "fire"); w.refresh_clip(); w.store_search("x")
print("Start store/clip OK")

# ── закрепы дока ──
dp = os.path.join(d, "dock.json")
assert ns.load_dock_pins(dp)[0] == "firefox"
ns.save_dock_pins(["kitty", "org.kde.dolphin"], dp)
assert ns.load_dock_pins(dp) == ["kitty", "org.kde.dolphin"] and ns.app_key("a.desktop") == "a"
print("Dock pins OK")
