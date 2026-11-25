# Zsh: защита пользовательских конфигов

Northling Arch treats the following files as personal user configuration:

- `~/.zshrc`
- `~/.p10k.zsh`
- `~/.p10k.northling.zsh`
- `~/.zshrc.local`

The installer manages only the template files `dotfiles/zsh/zshrc` and
`dotfiles/zsh/p10k.zsh`. They are installed with the `seed` policy:
they are created on first install, but if a user changes an installed file,
subsequent installs and updates leave it untouched. The two `.northling` /
`.local` files are never deployed from the repository.

The default Zsh template loads `~/.p10k.northling.zsh` first and falls back
to `~/.p10k.zsh`. It also loads `~/.zshrc.local` for user additions.

Before an update, `northling update` creates a compressed snapshot containing
project config directories and any existing personal Zsh files listed above.
The archive stores home files under `home/` and XDG config files under
`config/` inside `~/.local/share/northling/backups/`.

Run the focused snapshot test with:

```bash
bash tests/test-zsh-snapshot.sh
```

This is a safety copy only; update does not restore or overwrite these files.
