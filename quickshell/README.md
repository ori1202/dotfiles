# Quickshell (Dotarch notch + OSD)

Based on [vyeos/dotarch](https://github.com/vyeos/dotarch) centered notch shell.

## Features
- Collapsed top notch (clock/date); click to open control center
- Panels: control, launcher, clipboard, todo, notes, theme, wallpaper, capture, power
- Right-edge volume island (0–150%, red above 100%)
- Timer island via `timerd` / `timer` CLI

## Shortcuts (Hyprland, mainMod = ALT)
| Bind | Action |
|------|--------|
| Click notch | Control center |
| ALT+SPACE | Launcher |
| ALT+SHIFT+C | Control |
| ALT+SHIFT+V | Clipboard |
| ALT+Escape | Power |

## Timer
```
timer start 5m -l Tea
timer pause|resume|stop|status
```

## Rollback
Previous full-width bar backup: `~/.config/quickshell-bar-backup-*`
Waybar/syshud still available via commented lines in `hyprland.conf`.
