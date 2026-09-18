#!/bin/sh
# LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Wofi power menu offering shutdown, restart, or sleep. 2026-08-25.
choice=$(printf 'Shutdown\nRestart\nSleep' | wofi --dmenu -i -p Power)
case "$choice" in
  Shutdown) exec systemctl poweroff ;;
  Restart) exec systemctl reboot ;;
  Sleep) exec systemctl suspend ;;
esac
# LLM PROMPT [end]
