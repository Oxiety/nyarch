#!/usr/bin/env bash
# Этап 3: проверка NVIDIA. ТОЛЬКО ДИАГНОСТИКА — драйвер, ядро, initramfs
# и параметры загрузки этот скрипт НЕ меняет (правило проекта №3).

HAS_NVIDIA=0; NV_DRIVER=""; NV_MODESET=""; NV_PKGS=""

nv_detect() {
  if [ -n "${NL_FORCE_NVIDIA:-}" ]; then HAS_NVIDIA="$NL_FORCE_NVIDIA"; return 0; fi   # только для отладки
  local v
  for v in /sys/class/drm/card*/device/vendor; do
    [ -r "$v" ] && grep -qi '^0x10de' "$v" && { HAS_NVIDIA=1; return 0; }
  done
  HAS_NVIDIA=0
}

check_nvidia() {
  nv_detect
  if [ "$HAS_NVIDIA" != 1 ]; then
    info "Видеокарта NVIDIA не найдена — NVIDIA-настройки не применяю."
    return 0
  fi
  ok "Найдена видеокарта NVIDIA"

  NV_PKGS="$(pacman -Qq nvidia-open nvidia nvidia-dkms nvidia-open-dkms 2>/dev/null | tr '\n' ' ')"
  [ -n "$NV_PKGS" ] && info "Установленный драйвер: $NV_PKGS" || warn "Пакет драйвера (nvidia-open / nvidia) не найден через pacman."

  if have nvidia-smi && NV_DRIVER="$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -n1)" && [ -n "$NV_DRIVER" ]; then
    ok "Драйвер работает, версия $NV_DRIVER ($(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n1))"
  else
    # Критическая проверка: без рабочего драйвера графическое окружение не имеет смысла.
    warn "nvidia-smi не отвечает: драйвер не загружен или не подходит к ядру."
    warn "Частая причина — обновили ядро и не перезагрузились. Перезагрузись и запусти установщик снова."
    if ! ask "Всё равно продолжить установку (не рекомендуется)?" n; then
      die "Остановлено по NVIDIA-проверке. Драйвер я не трогаю — сначала надо разобраться, почему он не загружен."
    fi
  fi

  if [ -r /sys/module/nvidia_drm/parameters/modeset ]; then
    NV_MODESET="$(cat /sys/module/nvidia_drm/parameters/modeset)"
    if [ "$NV_MODESET" = Y ]; then ok "DRM modeset включён (nvidia_drm.modeset=Y)"
    else
      warn "nvidia_drm.modeset = $NV_MODESET (нужно Y для Wayland)."
      warn "Я это не меняю сам. Нужен параметр ядра nvidia_drm.modeset=1 — скажи мне, пройдём по шагам."
    fi
  else
    warn "Параметр nvidia_drm.modeset недоступен (модуль не загружен?)."
  fi

  if grep -q 'Open Kernel Module' /proc/driver/nvidia/version 2>/dev/null; then
    ok "Используются открытые модули ядра NVIDIA (рекомендуется для RTX 40-й серии)"
  elif [ -r /proc/driver/nvidia/version ]; then
    info "Используются закрытые модули. Для RTX 4060 лучше nvidia-open, но менять драйвер без нужды не буду."
  fi

  local s st
  for s in nvidia-suspend nvidia-resume; do
    st="$(systemctl is-enabled "$s.service" 2>/dev/null)"; [ -n "$st" ] || st="нет"
    info "$s.service: $st"
  done
  nvidia_audit_extra
  info "Если после сна экран не просыпается — скажи мне, включим эти службы осознанно."
  info "VRR принудительно не включается (монитор 1920×1080 @ 120 Гц)."
  return 0
}

# Дополнительный аудит (только чтение): GBM, Vulkan, видеоускорение, версии драйвера и Hyprland
nvidia_audit_extra() {
  local f
  # GBM — нужен Wayland-композиторам (Hyprland/aquamarine)
  if [ -e /usr/lib/gbm/nvidia-drm_gbm.so ] || ls /usr/lib/libnvidia-allocator.so* >/dev/null 2>&1; then ok "GBM: библиотека NVIDIA на месте"
  else warn "GBM: библиотека NVIDIA не найдена (пакет nvidia-utils установлен?)"; fi
  # Vulkan
  if [ -f /usr/share/vulkan/icd.d/nvidia_icd.json ]; then ok "Vulkan: ICD NVIDIA на месте"
  else warn "Vulkan: нет /usr/share/vulkan/icd.d/nvidia_icd.json (пакет nvidia-utils / vulkan-icd-loader)"; fi
  if have vulkaninfo && vulkaninfo --summary 2>/dev/null | grep -qi nvidia; then ok "vulkaninfo видит NVIDIA"; fi
  # Аппаратное ускорение видео (VA-API через NVDEC)
  if pacman -Qq libva-nvidia-driver >/dev/null 2>&1; then ok "Видеоускорение: libva-nvidia-driver установлен"
  else info "Видеоускорение: libva-nvidia-driver будет поставлен (список packages/core.txt)"; fi
  if have vainfo; then
    LIBVA_DRIVER_NAME=nvidia vainfo 2>/dev/null | grep -qi 'VAProfile' && ok "vainfo: профили VA-API доступны" || info "vainfo не показал профили (проверь после входа в Hyprland)"
  fi
  # Версии для сверки с матрицей совместимости
  local hv dv; hv="$(pacman -Q hyprland 2>/dev/null | awk '{print $2}')"; dv="${NV_DRIVER:-$(pacman -Q nvidia-utils 2>/dev/null | awk '{print $2}')}"
  [ -n "$hv" ] && info "Hyprland $hv  ·  драйвер NVIDIA ${dv:-?}  ·  ядро $(uname -r)"
  # Ранний KMS: частая причина чёрного экрана/мигания — но initramfs я сам не трогаю
  if [ -r /etc/mkinitcpio.conf ] && ! grep -Eq '^MODULES=.*nvidia_drm' /etc/mkinitcpio.conf 2>/dev/null; then
    info "Ранний KMS (nvidia в MODULES mkinitcpio) не включён. Если экран входа мигает/чёрный — это кандидат на исправление; скажи, пройдём по шагам."
  fi
  return 0
}
