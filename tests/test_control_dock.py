"""Центр управления и док без GTK: разбор данных и сборка окон на пустышках."""
import sys, types, os, json
from unittest import mock

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "widgets")
sys.path.insert(0, ROOT)
gi = types.ModuleType("gi"); gi.require_version = lambda *a, **k: None
repo = types.ModuleType("gi.repository")
for n in ("Gtk", "Gdk", "GLib", "Gio", "GtkLayerShell"):
    setattr(repo, n, mock.MagicMock(name=n))
repo.Gtk.Window = type("Window", (), {"__init__": lambda s, **k: None, "__getattr__": lambda s, n: mock.MagicMock()})
repo.Gtk.Button = type("Button", (), {"__init__": lambda s, **k: None, "__getattr__": lambda s, n: mock.MagicMock()})
repo.Gio.AppInfo.get_all.return_value = []
repo.GLib.timeout_add_seconds = lambda *a, **k: 1
repo.GLib.timeout_add = lambda *a, **k: 1
sys.modules.update({"gi": gi, "gi.repository": repo}); gi.repository = repo

import northling_control as nc
assert nc.parse_volume("Volume: 0.45") == (0.45, False)
assert nc.parse_volume("Volume: 1.00 [MUTED]") == (1.0, True)
assert nc.parse_volume("") == (None, False)
assert nc.parse_brightness("nvidia_0,backlight,50,50%,100") == 50 and nc.parse_brightness("") is None
nc.sh = lambda *a, **k: (1, "")
nc.Control()

import northling_dock as nd
cl = nd.parse_clients(json.dumps([{"class": "firefox", "address": "0x1", "title": "t", "mapped": True}, {"class": "", "address": "0x2"}]))
assert len(cl) == 1 and cl[0]["address"] == "0x1"
apps = [{"id": "firefox.desktop", "wmclass": "firefox", "name": "Firefox"}, {"id": "org.kde.dolphin.desktop", "wmclass": "", "name": "Files"}]
assert nd.match_app("firefox", apps)["name"] == "Firefox" and nd.match_app("dolphin", apps)["name"] == "Files" and nd.match_app("zzz", apps) is None
assert nd.load_conf("/nonexistent")["pinned"][0] == "firefox"
nd.subprocess.run = lambda *a, **k: types.SimpleNamespace(stdout="[]", returncode=0)
nd.Dock()
print("Control/Dock OK")

import nl_data
assert nl_data.glass_on() in (True, False)
nl_data.GLASS_FLAG = "/tmp/nl-glass-flag-test"
open(nl_data.GLASS_FLAG, "w").close(); assert nl_data.glass_on(); os.remove(nl_data.GLASS_FLAG); assert not nl_data.glass_on()
assert os.path.getsize(os.path.join(ROOT, "glass.css")) > 500
print("Glass OK")
