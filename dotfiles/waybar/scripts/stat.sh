#!/usr/bin/env bash
# Мини-метрики для Waybar: stat.sh cpu|mem|gpu → JSON {text,class,tooltip}
# Столбик ▁▂▃▄▅▆▇█ показывает загрузку; класс ok/warn/crit красит его в CSS.
spark() { local p=$1 s=(▁ ▂ ▃ ▄ ▅ ▆ ▇ █); local i=$(( p * 8 / 101 )); echo "${s[$i]}"; }
cls()   { local p=$1; if [ "$p" -ge 90 ]; then echo crit; elif [ "$p" -ge 70 ]; then echo warn; else echo ok; fi; }
emit()  { printf '{"text":"%s %s %s%%","class":"%s","tooltip":"%s"}\n' "$1" "$(spark "$2")" "$2" "$(cls "$2")" "$3"; }

case "${1:-}" in
  cpu)
    read -r _ a1 b1 c1 d1 e1 f1 g1 _ < /proc/stat; sleep 0.4; read -r _ a2 b2 c2 d2 e2 f2 g2 _ < /proc/stat
    t1=$((a1+b1+c1+d1+e1+f1+g1)); t2=$((a2+b2+c2+d2+e2+f2+g2))
    dt=$((t2-t1)); di=$(( (d2+e2) - (d1+e1) ))
    p=0; [ "$dt" -gt 0 ] && p=$(( (dt-di) * 100 / dt ))
    emit CPU "$p" "Загрузка процессора" ;;
  mem)
    awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{u=t-a; p=int(u*100/t); printf "%d %.1f %.1f\n",p,u/1048576,t/1048576}' /proc/meminfo | {
      read -r p u t; emit RAM "$p" "Занято ${u} из ${t} ГиБ"; } ;;
  gpu)
    command -v nvidia-smi >/dev/null 2>&1 || exit 0
    out=$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null) || exit 0
    IFS=, read -r u t mu mt <<<"$out"; u=${u// /}; t=${t// /}; mu=${mu// /}; mt=${mt// /}
    emit GPU "${u:-0}" "Температура ${t}°C, видеопамять ${mu}/${mt} МиБ" ;;
  *) exit 1 ;;
esac
