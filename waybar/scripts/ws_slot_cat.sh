#!/bin/sh
# Reads cached JSON from waybar-hypr-ws daemon (no hyprctl per tab).
i="${1:-0}"
d="${XDG_CACHE_HOME:-$HOME/.cache}/waybar-hypr-slots"
f="$d/$i.json"
test -f "$f" && cat "$f" || printf '%s\n' '{"text":""}'
