"""Сбор данных для виджетов Northling. Только стандартная библиотека — легко тестировать."""
import json, os, subprocess, time, urllib.parse, urllib.request

CACHE_DIR = os.path.join(os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")), "northling")
CONF_PATH = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")), "northling", "widgets.json")

DEFAULT_CONFIG = {
    "clock":    {"enabled": True, "hour24": True},
    "calendar": {"enabled": True},
    "system":   {"enabled": True},
    "weather":  {"enabled": True, "city": "", "latitude": None, "longitude": None, "units": "metric"},
    "player":   {"enabled": True},
    "layout":   {"top": 64, "side": 24, "width": 340},
}


def load_config(path=CONF_PATH):
    cfg = json.loads(json.dumps(DEFAULT_CONFIG))
    try:
        with open(path, encoding="utf-8") as f:
            user = json.load(f)
        for k, v in user.items():
            if isinstance(v, dict) and isinstance(cfg.get(k), dict):
                cfg[k].update(v)
            else:
                cfg[k] = v
    except (OSError, ValueError):
        pass
    return cfg


def _read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


class Cpu:
    """Загрузка CPU в процентах между двумя вызовами."""
    def __init__(self):
        self.prev = self._stat()

    @staticmethod
    def _stat():
        parts = _read("/proc/stat").splitlines()[0].split()[1:8]
        v = [int(x) for x in parts]
        return sum(v), v[3] + v[4]

    def percent(self):
        t, idle = self._stat()
        pt, pidle = self.prev
        self.prev = (t, idle)
        dt = t - pt
        return 0 if dt <= 0 else max(0, min(100, round((dt - (idle - pidle)) * 100 / dt)))


def memory():
    """(процент, занято ГиБ, всего ГиБ)"""
    info = {}
    for line in _read("/proc/meminfo").splitlines():
        k, _, rest = line.partition(":")
        info[k] = int(rest.split()[0])
    total, avail = info["MemTotal"], info.get("MemAvailable", info.get("MemFree", 0))
    used = total - avail
    return round(used * 100 / total), used / 1048576, total / 1048576


def gpu():
    """NVIDIA: (загрузка %, темп °C, память МиБ занято, всего) или None."""
    try:
        out = subprocess.run(
            ["nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total",
             "--format=csv,noheader,nounits"], capture_output=True, text=True, timeout=3)
        if out.returncode != 0:
            return None
        u, t, mu, mt = [int(x.strip()) for x in out.stdout.strip().splitlines()[0].split(",")]
        return u, t, mu, mt
    except (OSError, ValueError, subprocess.SubprocessError, IndexError):
        return None


class Network:
    """Состояние сети и скорость (байт/с) по активному интерфейсу."""
    def __init__(self):
        self.prev = None

    @staticmethod
    def _active():
        try:
            out = subprocess.run(["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device"],
                                 capture_output=True, text=True, timeout=3).stdout
        except (OSError, subprocess.SubprocessError):
            return None
        for line in out.splitlines():
            dev, typ, state, conn = (line.split(":") + ["", "", "", ""])[:4]
            if state == "connected" and typ in ("wifi", "ethernet"):
                return dev, typ, conn
        return None

    def poll(self):
        """→ dict(state, name, kind, down, up) ; state: online/offline"""
        act = self._active()
        if not act:
            self.prev = None
            return {"state": "offline", "name": "нет сети", "kind": "", "down": 0, "up": 0}
        dev, typ, conn = act
        rx = tx = 0
        try:
            for line in _read("/proc/net/dev").splitlines()[2:]:
                name, _, data = line.partition(":")
                if name.strip() == dev:
                    f = data.split()
                    rx, tx = int(f[0]), int(f[8])
        except (OSError, ValueError, IndexError):
            pass
        now = time.monotonic()
        down = up = 0
        if self.prev and self.prev[0] == dev and now > self.prev[3]:
            dt = now - self.prev[3]
            down, up = max(0, (rx - self.prev[1]) / dt), max(0, (tx - self.prev[2]) / dt)
        self.prev = (dev, rx, tx, now)
        return {"state": "online", "name": conn or dev, "kind": typ, "down": down, "up": up}


def human_rate(bps):
    for unit in ("Б/с", "КБ/с", "МБ/с", "ГБ/с"):
        if bps < 1024 or unit == "ГБ/с":
            return f"{bps:.0f} {unit}" if unit == "Б/с" else f"{bps:.1f} {unit}"
        bps /= 1024


def player():
    """dict(status, artist, title, pos, length) или None, если ничего нет."""
    try:
        out = subprocess.run(
            ["playerctl", "metadata", "--format",
             "{{status}}|{{artist}}|{{title}}|{{position}}|{{mpris:length}}"],
            capture_output=True, text=True, timeout=2)
    except (OSError, subprocess.SubprocessError):
        return None
    if out.returncode != 0 or not out.stdout.strip():
        return None
    p = out.stdout.rstrip("\n").split("|")
    if len(p) < 5 or p[0] not in ("Playing", "Paused") or not p[2]:
        return None
    try:
        pos, length = int(p[3] or 0), int(p[4] or 0)
    except ValueError:
        pos = length = 0
    return {"status": p[0], "artist": p[1], "title": p[2], "pos": pos, "length": length}


def player_cmd(cmd):
    if cmd in ("play-pause", "next", "previous"):
        try:
            subprocess.run(["playerctl", cmd], timeout=2)
        except (OSError, subprocess.SubprocessError):
            pass


WEATHER_CODES = {
    0: ("☀", "Ясно"), 1: ("☀", "Почти ясно"), 2: ("⛅", "Переменная облачность"), 3: ("☁", "Пасмурно"),
    45: ("≋", "Туман"), 48: ("≋", "Изморозь"), 51: ("☂", "Лёгкая морось"), 53: ("☂", "Морось"), 55: ("☂", "Сильная морось"),
    61: ("☂", "Небольшой дождь"), 63: ("☂", "Дождь"), 65: ("☂", "Сильный дождь"),
    71: ("❄", "Небольшой снег"), 73: ("❄", "Снег"), 75: ("❄", "Сильный снег"), 77: ("❄", "Снежная крупа"),
    80: ("☂", "Ливень"), 81: ("☂", "Ливень"), 82: ("☂", "Сильный ливень"), 85: ("❄", "Снегопад"), 86: ("❄", "Сильный снегопад"),
    95: ("⚡", "Гроза"), 96: ("⚡", "Гроза с градом"), 99: ("⚡", "Сильная гроза"),
}


def _get_json(url, timeout=8):
    req = urllib.request.Request(url, headers={"User-Agent": "northling-widgets/0.1"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode("utf-8"))


def geocode(city):
    """Город → (lat, lon, красивое имя). Результат кешируется. Адрес нигде не зашит."""
    os.makedirs(CACHE_DIR, exist_ok=True)
    cache = os.path.join(CACHE_DIR, "geocode.json")
    try:
        c = json.loads(_read(cache))
        if c.get("query") == city:
            return c["lat"], c["lon"], c["name"]
    except (OSError, ValueError, KeyError):
        pass
    url = "https://geocoding-api.open-meteo.com/v1/search?" + urllib.parse.urlencode(
        {"name": city, "count": 1, "language": "ru"})
    res = _get_json(url).get("results") or []
    if not res:
        raise LookupError(f"город «{city}» не найден")
    r = res[0]
    out = (r["latitude"], r["longitude"], r.get("name", city))
    with open(cache, "w", encoding="utf-8") as f:
        json.dump({"query": city, "lat": out[0], "lon": out[1], "name": out[2]}, f, ensure_ascii=False)
    return out


def weather(cfg):
    """→ dict(place, temp, feels, icon, text, wind, hi, lo, unit) ; бросает исключение при ошибке."""
    w = cfg["weather"]
    if w.get("latitude") is not None and w.get("longitude") is not None:
        lat, lon, place = float(w["latitude"]), float(w["longitude"]), w.get("city") or "Моё место"
    elif w.get("city"):
        lat, lon, place = geocode(w["city"])
    else:
        raise LookupError("не задан город")
    imperial = w.get("units") == "imperial"
    q = {"latitude": lat, "longitude": lon, "timezone": "auto", "forecast_days": 1,
         "current": "temperature_2m,apparent_temperature,weather_code,wind_speed_10m",
         "daily": "temperature_2m_max,temperature_2m_min"}
    if imperial:
        q.update({"temperature_unit": "fahrenheit", "wind_speed_unit": "mph"})
    d = _get_json("https://api.open-meteo.com/v1/forecast?" + urllib.parse.urlencode(q))
    cur, day = d["current"], d["daily"]
    icon, text = WEATHER_CODES.get(int(cur["weather_code"]), ("·", "—"))
    return {"place": place, "temp": round(cur["temperature_2m"]), "feels": round(cur["apparent_temperature"]),
            "icon": icon, "text": text, "wind": round(cur["wind_speed_10m"]),
            "hi": round(day["temperature_2m_max"][0]), "lo": round(day["temperature_2m_min"][0]),
            "unit": "°F" if imperial else "°C", "wind_unit": "mph" if imperial else "км/ч"}
