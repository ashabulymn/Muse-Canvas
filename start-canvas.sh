#!/usr/bin/env bash
# Menjalankan situs statis Kanvas Tak Terbatas (dipanggil 1Panel "Supervisor", bisa juga dijalankan manual)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$ROOT/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$ROOT/.env"
  set +a
fi

export CANVAS_HOST="${CANVAS_HOST:-0.0.0.0}"
export CANVAS_PORT="${CANVAS_PORT:-521}"
export CANVAS_ROOT="${CANVAS_ROOT:-$ROOT/canvas/dist}"

exec "$ROOT/.venv/bin/python" "$ROOT/canvas_server.py"
