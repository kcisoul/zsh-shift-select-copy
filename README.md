# zsh-shift-select-copy

Editor-like keyboard text selection with **auto-copy** for the Zsh command line.

Select text with `Shift+Arrow` / `Option+Shift+Arrow` (macOS) — the selected
region is automatically pushed to your system clipboard, ready to paste with
`Cmd+V` / `Ctrl+V` anywhere. No need to press Copy.

- Pure zsh, ~120 lines, single file
- No native agents, no accessibility permissions, no daemons
- macOS, Linux (X11 / Wayland), WSL out of the box

## Installation

### Manual

```sh
git clone https://github.com/kcisoul/zsh-shift-select-copy ~/.zsh/zsh-shift-select-copy
```

Then add to your `~/.zshrc`:

```sh
source ~/.zsh/zsh-shift-select-copy/zsh-shift-select-copy.plugin.zsh
```

### Oh My Zsh

```sh
git clone https://github.com/kcisoul/zsh-shift-select-copy \
  ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-shift-select-copy
```

Add to your `plugins=(...)` list in `~/.zshrc`:

```sh
plugins=(... zsh-shift-select-copy)
```

### Antidote

```sh
kcisoul/zsh-shift-select-copy
```

### Zinit

```sh
zinit light kcisoul/zsh-shift-select-copy
```

### Zplug

```sh
zplug "kcisoul/zsh-shift-select-copy"
```

After installation, restart your shell (`exec zsh`).

## Default keybindings

### Selection (Shift + motion)

| Key | Action |
|---|---|
| `Shift + ←` / `→` | Select character left / right |
| `Shift + ↑` / `↓` | Select line up / down |
| `Shift + Home` / `End` | Select to line start / end |
| `Option+Shift + ←` / `→` (macOS)<br>`Ctrl+Shift + ←` / `→` (Linux/WSL) | Select word left / right |
| `Option+Shift + Home` / `End` (macOS)<br>`Ctrl+Shift + Home` / `End` (Linux/WSL) | Select to buffer start / end |

### Cursor motion (no selection)

| Key | Action |
|---|---|
| `Option + ←` / `→` (macOS)<br>`Ctrl + ←` / `→` (Linux/WSL) | Move cursor word left / right |
| `Cmd + ←` / `→` (macOS) | Move cursor to line start / end |

### While a selection is active

| Key | Action |
|---|---|
| Any printable key | Replace the selection with the typed character |
| `Backspace` / `Delete` | Delete the selection |
| Any unmodified arrow key | Deselect (cursor moves, buffer unchanged) |

Every selection-changing motion **automatically copies** the new region to
the system clipboard. Paste anywhere with your OS's normal paste shortcut.

## Configuration

The plugin exposes two environment variables. Export them **before** sourcing
the plugin.

### `ZSC_AUTO_COPY` (default: `1`)

Set to `0` to disable auto-copy. Selection still works; the clipboard is
just never written.

```sh
export ZSC_AUTO_COPY=0
source ~/.zsh/zsh-shift-select-copy/zsh-shift-select-copy.plugin.zsh
```

### `ZSC_CLIPBOARD_CMD` (default: auto-detected)

The shell command used to write to the clipboard. Detection order:

1. macOS: `pbcopy`
2. Wayland (when `$WAYLAND_DISPLAY` is set): `wl-copy`
3. `xclip -selection clipboard -in`
4. `xsel --clipboard --input`
5. WSL: `clip.exe`

Override with anything that reads from stdin:

```sh
export ZSC_CLIPBOARD_CMD='wl-copy --primary'
```

If detection fails *and* the user does not override, auto-copy silently
becomes a no-op (selection still works; clipboard is just untouched).

## What this plugin does NOT do

**This plugin handles only keyboard-based selection** inside the Zsh command
line buffer (ZLE region). Mouse selection auto-copy is a **terminal emulator
feature**, not a zsh feature — it cannot be implemented in a zsh plugin
because zsh has no visibility into the terminal's screen-level selection.

If you also want mouse-drag → auto-copy, enable it in your terminal:

| Terminal | Setting |
|---|---|
| iTerm2 | Preferences → Selection → enable "Copy to pasteboard on selection" |
| Wave Terminal | `"term:copyonselect": true` in `settings.json` |
| Kitty | `copy_on_select yes` in `kitty.conf` |
| WezTerm | mouse binding action `CopyTo("Clipboard")` |
| Alacritty | `selection.save_to_clipboard: true` in `alacritty.toml` |
| Ghostty | `copy-on-select = clipboard` in config |
| GNOME Terminal | enabled by default for PRIMARY selection (middle-click paste) |

The mouse setting and this plugin are **independent and complementary** —
you can run both, or either, or neither.

## How it works (brief)

The plugin creates a dedicated zsh ZLE keymap (`zsc-select`) and a set of
widgets. The first Shift+motion calls `zle set-mark-command`, switches to
the new keymap, performs the motion, and pipes the resulting `BUFFER[MARK..CURSOR]`
to `$ZSC_CLIPBOARD_CMD` via stdin. Subsequent Shift+motions extend the region
(re-copying each time). Any non-shift key falls back through the keymap's
catch-all to either `kill-region` + replay (printable → replace) or
`deactivate-region` + replay (control char → deselect and execute the user's
normal binding).

All state lives in standard ZLE variables (`REGION_ACTIVE`, `MARK`,
`CURSOR`, `BUFFER`); there is no background process and no IPC.

## License

MIT — see [LICENSE](LICENSE).
