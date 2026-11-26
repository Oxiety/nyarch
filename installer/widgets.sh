#!/usr/bin/env bash
# Этап 8: виджеты рабочего стола (GTK3 + layer-shell). Свой код ставится в ~/.local/share/northling/widgets,
# настройки пользователя — ~/.config/northling/widgets.json (не перезаписывается).

WIDGETS_SRC="$NL_ROOT/widgets"
WIDGETS_DST="$NL_STATE/widgets"
WIDGETS_CONF="$NL_CONF/widgets.json"

widgets_set_city() { # город → в widgets.json (через python, без правки руками)
  python3 - "$WIDGETS_CONF" "$1" <<'PY'
import json, sys
p, city = sys.argv[1], sys.argv[2]
d = json.load(open(p, encoding="utf-8"))
d.setdefault("weather", {})["city"] = city
json.dump(d, open(p, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PY
}

widgets_install() {
  [ "${WITH_WIDGETS:-1}" = 1 ] || { info "Виджеты пропущены по твоему выбору"; return 0; }
  nl_install_tree "$WIDGETS_SRC" "$WIDGETS_DST" own
  # конфиг — «твой»: кладём один раз, дальше не трогаем
  local fresh=0; [ -e "$WIDGETS_CONF" ] || fresh=1
  nl_put "$WIDGETS_SRC/widgets.json" "$WIDGETS_CONF" 644 seed
  nl_put "$WIDGETS_SRC/dock.json" "$NL_CONF/dock.json" 644 seed
  if [ "$fresh" = 1 ] && [ "$DRY_RUN" != 1 ] && [ "$ASSUME_YES" != 1 ] && [ -t 0 ]; then
    local city
    read -r -p "${C_SKY}?${C_RESET} Город для виджета погоды (Enter — пропустить, потом: northling widgets config): " city || city=""
    [ -n "$city" ] && widgets_set_city "$city" && ok "Город для погоды: $city"
  fi
  if python3 -c "import gi; gi.require_version('GtkLayerShell','0.1')" >/dev/null 2>&1; then
    ok "Зависимости виджетов на месте (python-gobject, gtk-layer-shell)"
  else
    warn "Нет python-gobject / gtk-layer-shell — виджеты заработают после полного обновления:  northling update --full  (из TTY)"
  fi
  info "Запуск: автоматически при входе в Hyprland; вручную — northling widgets restart. Настройки: $(tilde "$WIDGETS_CONF")"
  return 0
}
