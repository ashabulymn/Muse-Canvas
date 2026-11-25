#!/usr/bin/env bash
set -euo pipefail

AGENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$AGENT_DIR")"
ENV_FILE="$ROOT_DIR/.env"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "Tidak ada $ENV_FILE, jalankan dulu $ROOT_DIR/install.sh" >&2
    exit 1
fi

# shellcheck disable=SC1090
set -a
. "$ENV_FILE"
set +a

# Semua data runtime Agent disimpan di /Muse/agent:
# konfigurasi, status Codex, workspace, cache, dan file sementara tidak lagi ditulis ke /root.
export HOME="$AGENT_DIR"
export XDG_CONFIG_HOME="$AGENT_DIR/.config"
export XDG_CACHE_HOME="$AGENT_DIR/.cache"
export CODEX_HOME="$AGENT_DIR/.codex"
export npm_config_cache="$AGENT_DIR/.npm"
export TMPDIR="$AGENT_DIR/tmp"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$CODEX_HOME" "$npm_config_cache" "$TMPDIR"

if [ -z "${DEEPSEEK_API_KEY:-}" ]; then
    echo "Error: tidak ada DEEPSEEK_API_KEY di $ENV_FILE." >&2
    echo "Jalankan: sudo -E bash $ROOT_DIR/install.sh, atau tulis manual ke file itu lalu restart muse-agent." >&2
    exit 1
fi
if [[ "$DEEPSEEK_API_KEY" != sk-* ]]; then
    echo "Error: DEEPSEEK_API_KEY harus diawali sk-, periksa $ENV_FILE." >&2
    exit 1
fi
export DEEPSEEK_API_KEY
export PORT="${PORT:-17371}"

NODE_BIN="${NODE_BIN:-$(command -v node || true)}"
[[ -n "$NODE_BIN" ]] || { echo "node tidak ditemukan, jalankan ulang $ROOT_DIR/install.sh" >&2; exit 1; }

cd "$AGENT_DIR"
exec "$NODE_BIN" "$AGENT_DIR/node_modules/@basketikun/canvas-agent/dist/index.js"
