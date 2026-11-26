"""Проверка кода интерфейса виджетов без GTK: подставляем «пустышки» вместо gi и прогоняем сборку окон.
Ловит опечатки, неверные имена и падения при сборке. Реальный вид проверяется только на машине с Hyprland."""
import sys, types, os
from unittest import mock

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "widgets")
sys.path.insert(0, ROOT)

class Dummy(mock.MagicMock):
    pass

gi = types.ModuleType("gi"); gi.require_version = lambda *a, **k: None
repo = types.ModuleType("gi.repository")
for n in ("Gtk", "Gdk", "GLib", "GdkPixbuf", "GtkLayerShell"):
    setattr(repo, n, Dummy(name=n))
repo.Gtk.Window = type("Window", (), {"__init__": lambda s, **k: None, "__getattr__": lambda s, n: Dummy()})
repo.GLib.timeout_add_seconds = lambda *a, **k: 1
repo.GLib.timeout_add = lambda *a, **k: 1
sys.modules.update({"gi": gi, "gi.repository": repo})
gi.repository = repo

import nl_data
nl_data.weather = lambda cfg: {"place": "Тест", "temp": 5, "feels": 3, "icon": "☀", "text": "Ясно", "wind": 4, "hi": 7, "lo": 1, "unit": "°C", "wind_unit": "км/ч"}
nl_data.player = lambda: {"status": "Playing", "artist": "A", "title": "T", "pos": 5, "length": 10}
import northling_widgets as nw

app = nw.App()
app.tick_clock(); app.tick_system(); app.tick_player()
area = mock.MagicMock(); area.get_allocated_width.return_value = 230; area.get_allocated_height.return_value = 230
assert app.draw_clock(area, mock.MagicMock()) is False
assert nw.add_classes is not None
app.show_weather(nl_data.weather({}), None)
app.show_weather(None, "не задан город")
app.show_weather(None, "сеть")
print("UI smoke test OK")
