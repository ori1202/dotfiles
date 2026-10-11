#!/usr/bin/env bash
set -euo pipefail
action=${1:-}
COBBLE='{"name":"Cobble","slug":"cobble","colors":{"bg_dim":"#0d090a","bg0":"#140c0e","bg1":"#1c1214","bg2":"#2a1a1e","bg3":"#3a282c","bg4":"#4a3236","primary_container":"#3a1218","secondary_container":"#2a1a14","foreground":"#e8e4e4","muted":"#9a9090","muted_dark":"#6a6060","red":"#c23b3b","yellow":"#c95d0f","green":"#6e1c28","primary":"#8b1e2d","blue":"#7a6a6a","aqua":"#8a7a7a","orange":"#c95d0f","purple":"#8b1e2d"}}'
case "$action" in
  current-json) printf '%s\n' "$COBBLE" ;;
  list) printf '[%s]\n' "$COBBLE" ;;
  wallpapers) echo '[]' ;;
  apply|wallpaper|open-wallpapers|restore-wallpaper) exit 0 ;;
  *) echo "usage: theme-system.sh current-json|list|wallpapers|..." >&2; exit 1 ;;
esac
