#!/usr/bin/env bash
# Menjalankan muse2api (dipanggil 1Panel "Supervisor", bisa juga dijalankan manual)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$ROOT/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$ROOT/.env"
  set +a
fi

# .env hanya mengelola satu salinan key/alamat publik, di sini disinkronkan ke variabel lingkungan yang dikenali muse2api
export MUSE2API_KEY="${MUSE_API_KEY:-}"
export MUSE2API_PUBLIC_BASE="${MUSE_API_BASE:-}"
export MUSE2API_HOST="${MUSE2API_HOST:-0.0.0.0}"
export MUSE2API_PORT="${MUSE2API_PORT:-1314}"

cd "$ROOT/muse2api"
exec "$ROOT/.venv/bin/python" -m uvicorn app:app \
  --host "$MUSE2API_HOST" \
  --port "$MUSE2API_PORT" \
  --proxy-headers \
  --forwarded-allow-ips='*'
