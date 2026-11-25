#!/usr/bin/env bash
# Instalasi satu-klik Muse + Kanvas Tak Terbatas + Agent server (Debian / Ubuntu, host 1Panel)
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_DIR="$APP_DIR/agent"
AGENT_CONFIG="$AGENT_DIR/.infinite-canvas/canvas-agent.json"
API_PORT="${API_PORT:-1314}"
CANVAS_PORT="${CANVAS_PORT:-521}"
AGENT_PUBLIC_URL="${AGENT_PUBLIC_URL:-https://agent.example.com}"
AGENT_ORIGINS="${AGENT_ORIGINS:-https://muse.example.com https://canvas.example.com}"
cd "$APP_DIR"

say() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

if [ "$(id -u)" -ne 0 ]; then
  die "Jalankan sebagai root: sudo -E bash install.sh"
fi

say "1/7 Menginstal dependensi sistem (Python, Chromium, Node.js, font)"
if command -v apt-get >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y || warn "apt-get update gagal, lanjut mencoba instalasi"
  apt-get install -y python3 python3-venv python3-pip ca-certificates curl openssl git ripgrep bubblewrap fonts-wqy-zenhei || true
  apt-get install -y chromium || apt-get install -y chromium-browser || \
    warn "Instalasi otomatis Chromium gagal, silakan instal manual: Debian pakai apt install chromium, Ubuntu bisa pakai snap install chromium"
elif command -v dnf >/dev/null 2>&1; then
  dnf install -y python3 python3-pip python3-virtualenv nodejs npm openssl git ripgrep bubblewrap chromium google-noto-sans-cjk-fonts || true
elif command -v yum >/dev/null 2>&1; then
  yum install -y python3 python3-pip nodejs npm openssl git ripgrep bubblewrap chromium google-noto-sans-cjk-fonts || true
else
  warn "Manajer paket tidak dikenali, pastikan python3 / venv / chromium / node / npm sudah terinstal"
fi

if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1 || [ "$(node -p 'Number(process.versions.node.split(".")[0])' 2>/dev/null || echo 0)" -lt 18 ]; then
  say "Menginstal Node.js 20 (Agent butuh Node 18+ dan npm)"
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get install -y nodejs
fi
node -v
npm -v

CHROME_BIN="$(command -v chromium || command -v chromium-browser || command -v google-chrome || command -v google-chrome-stable || true)"
if [ -n "$CHROME_BIN" ]; then
  say "Chromium: $CHROME_BIN"
else
  warn "Chromium tidak ditemukan. muse2api tidak bisa menjalankan browser, instal dulu lalu atur MUSE2API_CHROMIUM di .env"
fi

say "2/7 Membuat virtual environment Python dan menginstal dependensi Muse API"
PY_VER="$(python3 -c 'import sys;print("%d.%d" % sys.version_info[:2])' 2>/dev/null || echo "0.0")"
case "$PY_VER" in
  3.10|3.11|3.12|3.13|3.14) ;;
  *) die "Python saat ini $PY_VER, muse2api butuh Python 3.10+ (disarankan Ubuntu 22.04+ / Debian 12+)" ;;
esac
if [ ! -x "$APP_DIR/.venv/bin/python" ]; then
  python3 -m venv "$APP_DIR/.venv"
fi
"$APP_DIR/.venv/bin/python" -m pip install --disable-pip-version-check -q -r "$APP_DIR/muse2api/requirements.txt"

say "3/7 Membuat konfigurasi lokal .env"
IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
if [ -z "${IP:-}" ]; then
  IP="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}')"
fi
IP="${PUBLIC_HOST:-${IP:-127.0.0.1}}"

if [ ! -f "$APP_DIR/.env" ]; then
  cp "$APP_DIR/.env.example" "$APP_DIR/.env"
  KEY="$(openssl rand -hex 24 2>/dev/null || "$APP_DIR/.venv/bin/python" -c 'import secrets;print(secrets.token_hex(24))')"
  sed -i "s|^MUSE_API_KEY=.*|MUSE_API_KEY=$KEY|" "$APP_DIR/.env"
  sed -i "s|^MUSE_API_BASE=.*|MUSE_API_BASE=http://$IP:$API_PORT|" "$APP_DIR/.env"
  sed -i "s|^MUSE2API_PORT=.*|MUSE2API_PORT=$API_PORT|" "$APP_DIR/.env"
  sed -i "s|^CANVAS_PORT=.*|CANVAS_PORT=$CANVAS_PORT|" "$APP_DIR/.env"
  say ".env sudah dibuat (API Key sudah diacak)"
else
  warn ".env sudah ada, konfigurasi lama dipertahankan tanpa ditimpa"
fi
chmod 600 "$APP_DIR/.env"

# Alamat dan Token Agent hanya dibaca dari canvas-agent.json; hapus salinan lama di .env agar tidak ada konfigurasi ganda yang bentrok.
sed -i '/^AGENT_URL=/d;/^AGENT_TOKEN=/d' "$APP_DIR/.env"

if ! grep -qE '^DEEPSEEK_API_KEY=sk-[^[:space:]]+' "$APP_DIR/.env"; then
  DS_KEY="${DEEPSEEK_API_KEY:-}"
  if [ -z "$DS_KEY" ] && [ -t 0 ]; then
    printf 'Masukkan DeepSeek API Key (awalan sk-, tidak ditampilkan saat mengetik):'
    read -r -s DS_KEY
    printf '\n'
  fi
  if [ -n "$DS_KEY" ]; then
    sed -i '/^DEEPSEEK_API_KEY=/d' "$APP_DIR/.env"
    printf 'DEEPSEEK_API_KEY=%s\n' "$DS_KEY" >> "$APP_DIR/.env"
  else
    die "DEEPSEEK_API_KEY belum dikonfigurasi. Jalankan ulang: DEEPSEEK_API_KEY=sk-... sudo -E bash install.sh"
  fi
fi

say "4/7 Menginstal Agent server (canvas-agent + Codex)"
mkdir -p "$AGENT_DIR" "$AGENT_DIR/logs" "$AGENT_DIR/tmp" "$AGENT_DIR/.infinite-canvas"
cd "$AGENT_DIR"
npm_config_cache="$AGENT_DIR/.npm" npm install --prefix "$AGENT_DIR" --omit=dev --ignore-scripts --legacy-peer-deps --no-audit --no-fund
mkdir -p "$AGENT_DIR/.codex" "$AGENT_DIR/.config" "$AGENT_DIR/.cache" "$AGENT_DIR/workspace"
cp "$AGENT_DIR/codex/models.json" "$AGENT_DIR/.codex/models.json"
sed "s|^model_catalog_json = .*|model_catalog_json = \"$AGENT_DIR/.codex/models.json\"|" \
  "$AGENT_DIR/codex/config.toml" > "$AGENT_DIR/.codex/config.toml"
chmod 600 "$AGENT_DIR/.codex/models.json" "$AGENT_DIR/.codex/config.toml"

# Pindahkan data runtime Agent versi lama di /root/.infinite-canvas ke /Muse.
if [ -d /root/.infinite-canvas ]; then
  if [ ! -d "$AGENT_DIR/.infinite-canvas" ] || [ -z "$(ls -A "$AGENT_DIR/.infinite-canvas" 2>/dev/null || true)" ]; then
    rm -rf "$AGENT_DIR/.infinite-canvas"
    mv /root/.infinite-canvas "$AGENT_DIR/.infinite-canvas"
    say "/root/.infinite-canvas sudah dipindahkan ke $AGENT_DIR/.infinite-canvas"
  else
    BACKUP="$AGENT_DIR/.infinite-canvas/root-backup-$(date +%s)"
    mv /root/.infinite-canvas "$BACKUP"
    say "/root/.infinite-canvas sudah dicadangkan ke $BACKUP"
  fi
fi

say "5/7 Membuat konfigurasi Agent (satu-satunya sumber alamat dan Token)"
node - "$AGENT_CONFIG" "$AGENT_PUBLIC_URL" "$AGENT_DIR/workspace" "$AGENT_ORIGINS" <<'NODE'
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const [file, publicUrl, workspace, originsRaw] = process.argv.slice(2);
let config = {};
if (fs.existsSync(file)) {
  try { config = JSON.parse(fs.readFileSync(file, "utf8")); } catch { config = {}; }
}
if (!config.token) config.token = crypto.randomBytes(18).toString("hex");
if (!config.url) config.url = "http://127.0.0.1:17371";
if (!config.publicUrl) config.publicUrl = publicUrl;
const origins = originsRaw.split(/\s+/).filter(Boolean);
config.origins = Array.from(new Set([...(Array.isArray(config.origins) ? config.origins : []), ...origins]));
const oldWorkspace = config.workspace && config.workspace.workspacePath;
if (!oldWorkspace || String(oldWorkspace).startsWith("/root/")) {
  config.workspace = { ...(config.workspace || {}), workspacePath: workspace };
}
fs.mkdirSync(path.dirname(file), { recursive: true, mode: 0o700 });
fs.writeFileSync(file, JSON.stringify(config, null, 2) + "\n", { mode: 0o600 });
fs.chmodSync(path.dirname(file), 0o700);
fs.chmodSync(file, 0o600);
NODE

say "6/7 Memeriksa hasil build"
if [ ! -f "$APP_DIR/canvas/dist/index.html" ]; then
  die "canvas/dist/index.html tidak ada: letakkan hasil build frontend di direktori tersebut"
fi

say "7/7 Mengatur izin file"
chmod +x "$APP_DIR/start-api.sh" "$APP_DIR/start-canvas.sh" "$AGENT_DIR/start-agent.sh" "$APP_DIR/install.sh" 2>/dev/null || true
chmod 700 "$AGENT_DIR/.infinite-canvas" "$AGENT_DIR/.codex" 2>/dev/null || true
mkdir -p "$APP_DIR/logs"
chmod 700 "$APP_DIR/logs" 2>/dev/null || true

KEY_LINE="$(grep -E '^MUSE_API_KEY=' "$APP_DIR/.env" | cut -d= -f2- || true)"
TOKEN="$(node -e 'console.log(require(process.argv[1]).token)' "$AGENT_CONFIG")"
AGENT_URL="$(node -e 'console.log(require(process.argv[1]).publicUrl || require(process.argv[1]).url)' "$AGENT_CONFIG")"

cat <<EOF

============================================================
Instalasi selesai
------------------------------------------------------------
Direktori:     $APP_DIR
Muse API:      http://$IP:$API_PORT
Kanvas:        http://$IP:$CANVAS_PORT
Agent lokal:   http://127.0.0.1:17371
Agent publik:  $AGENT_URL
Konfigurasi Agent: $AGENT_CONFIG
Token Agent:   $TOKEN

Langkah berikutnya (1Panel Toolbox -> Supervisor, pengguna root, jumlah proses 1):
  muse2api     direktori $APP_DIR        perintah /bin/bash $APP_DIR/start-api.sh
  muse-canvas  direktori $APP_DIR        perintah /bin/bash $APP_DIR/start-canvas.sh
  muse-agent   direktori $AGENT_DIR      perintah /bin/bash $AGENT_DIR/start-agent.sh

Buka firewall/security group: $CANVAS_PORT, $API_PORT
Panel admin Muse: http://$IP:$API_PORT/admin?key=$KEY_LINE

Alamat dan Token koneksi default panel Agent hanya dibaca dari
  $AGENT_CONFIG
Untuk mengubah alamat ubah publicUrl, untuk mengganti Token ubah token, lalu restart muse-agent dan muse-canvas.
============================================================
EOF
