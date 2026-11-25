# Northling Midnight для VS Code на Windows.
# Запуск: ПКМ по файлу → «Выполнить с помощью PowerShell»  (или:  powershell -ExecutionPolicy Bypass -File install-windows.ps1)
# Делает: ставит тему из .vsix и (по желанию) кладёт настройки редактора. Старый settings.json сохраняется копией.
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$vsix = Get-ChildItem (Join-Path $here "dist") -Filter *.vsix | Sort-Object Name | Select-Object -Last 1
if (-not $vsix) { Write-Host "Не найден .vsix в папке dist" -ForegroundColor Red; exit 1 }
$code = Get-Command code -ErrorAction SilentlyContinue
if (-not $code) { Write-Host "Не найдена команда 'code'. Открой VS Code → Ctrl+Shift+P → «Shell Command: Install 'code' command»." -ForegroundColor Red; exit 1 }
& code --install-extension $vsix.FullName --force
Write-Host "Тема установлена. Выбери её: Ctrl+K Ctrl+T → Northling Midnight" -ForegroundColor Green

$settingsSrc = Join-Path $here "..\..\dotfiles\vscode\settings.json"
$settingsDst = Join-Path $env:APPDATA "Code\User\settings.json"
if (Test-Path $settingsSrc) {
  $ans = Read-Host "Положить настройки редактора Northling (старые сохраню копией)? [y/N]"
  if ($ans -match '^(y|д)') {
    if (Test-Path $settingsDst) { Copy-Item $settingsDst "$settingsDst.northling-backup" -Force }
    New-Item -ItemType Directory -Force (Split-Path $settingsDst) | Out-Null
    Copy-Item $settingsSrc $settingsDst -Force
    Write-Host "Готово: $settingsDst" -ForegroundColor Green
  }
}
