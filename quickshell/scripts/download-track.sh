#!/bin/sh
# LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Thin wrapper around download-track.py for compatibility. 2026-10-11.
exec /usr/bin/python3 "$(dirname "$0")/download-track.py" download ${1:+--url "$1"}
# LLM PROMPT [end]
