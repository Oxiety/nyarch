#!/usr/bin/env bash
# GPU load and temperature for waybar (NVIDIA only; prints nothing otherwise)
command -v nvidia-smi >/dev/null 2>&1 || exit 0
out=$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null) || exit 0
util=$(echo "$out" | cut -d, -f1 | tr -d ' ')
temp=$(echo "$out" | cut -d, -f2 | tr -d ' ')
echo "gpu ${util}% ${temp}°"
