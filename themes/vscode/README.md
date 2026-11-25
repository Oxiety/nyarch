# Northling Midnight для VS Code

**Linux** — ставит `install.sh` (папка расширения кладётся в `~/.vscode/extensions`).

**Windows** — запусти `install-windows.ps1` (нужна команда `code`), либо вручную:
`code --install-extension dist/northling-midnight-<версия>.vsix`, затем Ctrl+K Ctrl+T → Northling Midnight.

Пересобрать .vsix после правок темы: `python3 scripts/dev/build-vsix.py`.
