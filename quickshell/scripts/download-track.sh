#!/bin/sh
# LLM PROMPT [start](YET TO BE CLASSIFIED BY A CERTIFYING AUTHORITY) description: Thin wrapper around the Rust download-track binary. 2026-10-13.
exec "$(dirname "$0")/download-track" download ${1:+--url "$1"}
# LLM PROMPT [end]
