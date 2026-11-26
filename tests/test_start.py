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
