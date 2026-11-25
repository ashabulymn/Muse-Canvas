# Muse—Canvas

> Menghubungkan kemampuan **Muse (muse.ai)** untuk membuat gambar / membuat video / percakapan ke **Kanvas Tak Terbatas**, lalu memakai **DeepSeek + Codex Agent** agar AI langsung mengoperasikan kanvas.
>
> A self-hosted AI canvas that connects **Muse(muse.ai)** image / video / chat models to **Infinite Canvas**, with a server-side **DeepSeek + Codex Agent** that can operate the canvas.

[Bahasa Indonesia](#bahasa-indonesia) · [English](#english) · [GitHub](https://github.com/ashabulymn/Muse-Canvas)

---

## Bahasa Indonesia

### Apa ini

Repo ini menggabungkan dua proyek open-source yang sangat bagus menjadi satu sistem lengkap yang bisa di-deploy:

1. **[muse2api](https://github.com/czg86389-hub/muse2api)**: membungkus kemampuan web Muse menjadi API yang kompatibel dengan OpenAI, mendukung text-to-image, image-to-image, text-to-video, image-to-video, dan percakapan.
2. **[infinite-canvas](https://github.com/basketikun/infinite-canvas)**: meja kerja kanvas tak terbatas untuk kreasi AI, yang memanggil interface yang kompatibel dengan OpenAI langsung dari browser.
3. **Lapisan perekat baru di repo ini**:
   - Membuat channel default kanvas tak terbatas dikunci oleh `.env` server, halaman web tidak bisa mengubah alamat, Key, dan model;
   - Mengunci alamat dan Token Agent ke `canvas-agent.json`, halaman web hanya-baca dan terhubung otomatis;
   - Menyediakan `canvas_server.py`, yang meng-host frontend hasil build dengan Python murni, tanpa bergantung pada Node;
   - Menyediakan `install.sh`, konfigurasi Supervisor 1Panel, contoh reverse proxy Nginx SSE, dan tutorial dwibahasa;
   - Memberi patch kompatibilitas pada muse2api: mendukung parameter video `multipart/form-data` dari kanvas, `n` gambar, `first_frame` / `last_frame` / `image[]` gambar referensi, dan lain-lain.

### Fitur

- Kanvas tak terbatas: node teks, gambar, video, audio, gambar referensi, manajemen proyek kanvas.
- Channel Muse: `muse-image` membuat gambar, `muse-video` membuat video, `muse-spark` percakapan/kode.
- Agent server: Codex App Server memakai DeepSeek Responses API, langsung mengoperasikan kanvas lewat tool MCP.
- Penguncian channel: `MUSE_API_BASE`, `MUSE_API_KEY`, daftar model hanya dikelola di `.env` server.
- Penguncian Agent: alamat dan Token browser hanya dibaca dari `agent/.infinite-canvas/canvas-agent.json`.
- Satu `install.sh` menyelesaikan lingkungan Python, Node Agent, konfigurasi Codex, key, dan pembuatan parameter Supervisor.
- Dokumentasi dwibahasa + langkah deploy 1Panel / Nginx yang bisa direproduksi.

### Arsitektur

```text
┌──────────────────────────────┐
│ Browser                      │
│ https://canvas.example.com   │
│  ├─ Kanvas Tak Terbatas (frontend statis) │
│  ├─ /config.js disuntik oleh backend      │
│  └─ Panel Agent (alamat/Token hanya-baca) │
└──────────────┬───────────────┘
               │ HTTPS
     ┌─────────┴──────────┐
     │                    │
┌────▼─────────┐   ┌──────▼─────────────┐
│ canvas_server│   │ agent.example.com  │
│ :521         │   │ Nginx → 127.0.0.1  │
│ File statis  │   │ :17371             │
└────┬─────────┘   └──────┬─────────────┘
     │                    │
     │ /config.js         │ SSE + HTTP
     │                    │
┌────▼─────────┐   ┌──────▼─────────────┐
│ muse2api     │   │ canvas-agent        │
│ :1314        │   │ Codex app-server    │
│ FastAPI      │   │ DeepSeek Responses  │
└────┬─────────┘   └──────┬─────────────┘
     │                    │
┌────▼─────────┐   ┌──────▼─────────────┐
│ Kolam akun Muse │ │ api.deepseek.com   │
│ Chromium CDP │   │ MCP → tool kanvas  │
└──────────────┘   └────────────────────┘
```

### Struktur direktori

```text
Muse-Canvas/
├── README.md                     # File ini (Bahasa Indonesia + English)
├── LICENSE                       # MIT
├── NOTICE                        # Atribusi proyek hulu
├── .env.example                  # Template variabel lingkungan server
├── Dockerfile                    # Deploy Dokploy canvas-only (fork ini)
├── DOKPLOY.md                    # Panduan deploy Dokploy (fork ini)
├── install.sh                    # Instalasi satu-klik (Debian / Ubuntu)
├── start-api.sh                  # Menjalankan muse2api
├── start-canvas.sh               # Menjalankan layanan statis kanvas
├── canvas_server.py              # Server statis Python murni + injeksi /config.js
├── supervisor.conf.example       # Referensi Supervisor 1Panel
├── nginx-agent.conf.example      # Referensi Nginx/SSE untuk Agent
├── muse2api/                     # Kode sumber Muse API yang sudah dipatch (versi lama, tidak dipakai di Dokploy — lihat bagian Deploy di Dokploy)
├── canvas/
│   └── dist/                     # Frontend Kanvas Tak Terbatas hasil build
├── agent/
│   ├── package.json              # @basketikun/canvas-agent
│   ├── start-agent.sh            # Skrip peluncur Agent server
│   └── codex/                    # Konfigurasi Codex + DeepSeek dan katalog model
└── source/
    └── infinite-canvas/          # Kode sumber Kanvas Tak Terbatas hulu (untuk pengembangan lanjutan)
```

### Kebutuhan lingkungan

- Linux: Debian 12+ / Ubuntu 22.04+ (distro lain perlu menginstal dependensi sendiri).
- Python 3.10+.
- Node.js 18+ (disarankan 20/22).
- Chromium atau Google Chrome (dibutuhkan muse2api).
- Minimal 2 core 4 GB; pembuatan video disarankan 4 core 8 GB.
- Satu akun yang bisa login ke Muse (lewat impor Cookie).
- Satu DeepSeek API Key (untuk Agent, diawali `sk-`).

### Mulai cepat

#### 1. Unggah dan ekstrak

```bash
sudo mkdir -p /Muse
sudo tar -xzf Muse-Canvas.tar.gz -C /Muse --strip-components=1
cd /Muse
```

Bisa juga langsung `git clone` repo ini ke `/Muse`.

#### 2. Siapkan variabel lingkungan

```bash
cp .env.example .env
nano .env
```

Minimal diubah:

```ini
MUSE_API_BASE=https://api.example.com
MUSE_API_KEY=ganti-dengan-string-acak-yang-panjang
DEEPSEEK_API_KEY=sk-DeepSeekKey-Anda
```

Penjelasan:

- `MUSE_API_BASE` adalah alamat Muse API yang diakses **browser**, jangan diakhiri `/`, jangan tambahkan `/v1`;
- Jika kanvas dibuka dengan HTTPS, alamat ini juga harus HTTPS, kalau tidak browser akan memblokir mixed content;
- `MUSE_API_KEY` adalah kunci akses muse2api, bukan kata sandi akun Muse;
- `DEEPSEEK_API_KEY` hanya dipakai Agent server, tidak ditulis ke frontend.

#### 3. Instalasi satu-klik

```bash
sudo -E bash install.sh
```

Skrip instalasi akan:

1. Menginstal dependensi Python, Chromium, Node, font, dan lain-lain;
2. Membuat `.venv` dan menginstal dependensi muse2api;
3. Mempertahankan `.env` yang sudah ada, jika belum ada akan membuat `MUSE_API_KEY` acak;
4. Memvalidasi dan menulis `DEEPSEEK_API_KEY`;
5. Menginstal `@basketikun/canvas-agent@0.6.0` di `agent/`;
6. Membuat `agent/.infinite-canvas/canvas-agent.json` (Token, alamat publik, asal yang diizinkan, workspace);
7. Mencetak tiga parameter Supervisor 1Panel, Token Agent, dan alamat panel admin.

Jika domain bukan `agent.example.com` / `muse.example.com`, timpa saat instalasi:

```bash
sudo -E env \
  AGENT_PUBLIC_URL="https://agent.example.com" \
  AGENT_ORIGINS="https://canvas.example.com https://muse.example.com" \
  bash install.sh
```

#### 4. Supervisor 1Panel

Di 1Panel, pada "Toolbox → Supervisor", instal Supervisor, lalu buat tiga entri:

| Nama | Pengguna | Direktori kerja | Perintah |
| --- | --- | --- | --- |
| `muse2api` | root | `/Muse` | `/bin/bash /Muse/start-api.sh` |
| `muse-canvas` | root | `/Muse` | `/bin/bash /Muse/start-canvas.sh` |
| `muse-agent` | root | `/Muse/agent` | `/bin/bash /Muse/agent/start-agent.sh` |

Jumlah proses masing-masing diisi `1`, simpan lalu jalankan. Log ada di `/Muse/logs/`.

#### 5. Reverse proxy dan HTTPS

Disarankan tiga domain:

| Domain | Diteruskan ke | Kegunaan |
| --- | --- | --- |
| `canvas.example.com` | `127.0.0.1:521` | Kanvas Tak Terbatas |
| `api.example.com` | `127.0.0.1:1314` | Muse API |
| `agent.example.com` | `127.0.0.1:17371` | Agent server |

Konfigurasi Nginx penting untuk API (membuat gambar/video bisa lebih dari 60 detik):

```nginx
proxy_connect_timeout 60s;
proxy_send_timeout    600s;
proxy_read_timeout    600s;
proxy_buffering       off;
client_max_body_size  200M;
```

Konfigurasi Nginx penting untuk Agent (SSE tidak boleh di-buffer):

```nginx
proxy_http_version 1.1;
proxy_set_header   Host $host;
proxy_set_header   X-Real-IP $remote_addr;
proxy_buffering    off;
proxy_cache        off;
gzip               off;
proxy_read_timeout 3600s;
client_max_body_size 100M;
```

> Kanvas dan API harus sama-sama HTTPS, atau sama-sama HTTP. Kanvas HTTPS yang memanggil API HTTP akan diblokir browser.

#### 6. Impor akun Muse

Buka di browser:

```text
https://api.example.com/admin?key=MUSE_API_KEY-Anda
```

Di panel admin, impor Cookie Muse:

- Pakai ekstensi Chrome di `muse2api/extension/`; atau
- Dari DevTools browser → Application → Cookies → `muse.ai`, salin `hatch_sess`, `hatch_vml`, lalu tempel sebagai:

```text
hatch_sess=......; hatch_vml=......
```

Setelah impor, klik "Test" pada akun, pastikan statusnya bisa dipakai.

#### 7. Konfigurasi Agent dan channel tetap

Backend kanvas hanya perlu mengelola dua file:

**`/Muse/.env`** (sumber penguncian channel)

```ini
MUSE_API_BASE=https://api.example.com
MUSE_API_KEY=key-acak-panjang-Anda
MUSE_CHANNEL_NAME=Muse
DEEPSEEK_API_KEY=sk-...
```

**`/Muse/agent/.infinite-canvas/canvas-agent.json`** (satu-satunya sumber Agent)

```json
{
  "url": "http://127.0.0.1:17371",
  "publicUrl": "https://agent.example.com",
  "token": "Token 36 karakter hasil skrip instalasi",
  "origins": [
    "https://canvas.example.com"
  ],
  "workspace": {
    "workspacePath": "/Muse/agent/workspace"
  }
}
```

Setelah diubah:

```bash
supervisorctl restart muse2api muse-canvas muse-agent
```

Refresh kanvas:

- "Pengaturan → Channel" menampilkan pemberitahuan hanya-baca, alamat, Key, dan model tidak bisa diubah;
- Kolom alamat dan Token panel Agent dikunci (disabled);
- Di kanan atas halaman, Agent terhubung otomatis, modelnya `DeepSeek-Flash`.

### Membangun frontend dari source

Repo ini sudah berisi `canvas/dist` hasil build, umumnya tidak perlu build ulang. Setelah mengubah `source/infinite-canvas/web`:

```bash
cd source/infinite-canvas/web
npm install --legacy-peer-deps --ignore-scripts
npm run build
rm -rf ../../../canvas/dist
cp -a dist ../../../canvas/dist
```

Lalu restart `muse-canvas`.

### Variabel lingkungan umum

| Variabel | Nilai default | Penjelasan |
| --- | --- | --- |
| `MUSE_API_BASE` | `http://127.0.0.1:1314` | Alamat API yang diakses browser, tanpa `/v1` |
| `MUSE_API_KEY` | dibuat acak | Kunci akses muse2api |
| `MUSE_CHANNEL_NAME` | `Muse` | Nama tampil channel kanvas |
| `MUSE2API_HOST` | `0.0.0.0` | Alamat bind API |
| `MUSE2API_PORT` | `1314` | Port API |
| `MUSE2API_CONCURRENCY` | `2` | Jumlah tugas Muse yang berjalan bersamaan |
| `MUSE2API_CHROMIUM` | kosong | Kosongkan untuk deteksi otomatis, atau isi `/usr/bin/chromium` |
| `DEEPSEEK_API_KEY` | kosong | DeepSeek Key untuk Agent server |
| `CANVAS_HOST` | `0.0.0.0` | Alamat bind kanvas |
| `CANVAS_PORT` | `521` | Port kanvas |
| `CANVAS_ROOT` | kosong | Default `canvas/dist` |
| `TZ` | `Asia/Jakarta` | Zona waktu |

### Pemecahan masalah

**Kanvas meminta `http://.../v1` dan kembali `{"detail":"Not Found"}`**
Isi alamat interface hanya sampai domain atau IP, jangan tambahkan `/v1`. Kanvas otomatis menambahkan `/v1/models`, `/v1/images/generations`.

**Membuka `/v1/models` langsung di browser kembali 401**
Normal. Address bar browser tidak membawa `Authorization`, kanvas otomatis membawa `Bearer`.

**`Failed to fetch` / mixed content**
Kanvas HTTPS tidak bisa meminta API HTTP. Ubah `MUSE_API_BASE` ke HTTPS, atau akses kanvas lewat HTTP.

**Membuat gambar lebih dari 60 detik kembali 504**
Default Nginx 60 detik terlalu pendek, ubah sesuai `proxy_read_timeout 600s` di atas.

**Agent melaporkan `DEEPSEEK_API_KEY ... belum dikonfigurasi`**
Di `/Muse/.env` belum ada Key. Tulis `DEEPSEEK_API_KEY=sk-...`, `chmod 600`, restart `muse-agent`.

**Panel Agent `origin not allowed`**
Buka kanvas lewat `https://canvas.example.com`, atau tambahkan sumber itu ke `origins` di `canvas-agent.json`.

**Agent tampil terhubung, tetapi mengirim pesan kembali 401**
DeepSeek Key tidak valid, saldo kurang, atau tersalin dengan spasi. Tulis ulang lalu restart `muse-agent`.

**Pembuatan video timeout**
Pastikan timeout baca Nginx ≥ 600 detik, dan sesuaikan `MUSE2API_CONCURRENCY` di `.env` dengan kemampuan mesin.

### Keamanan

- Proyek ini secara default menjalankan Agent sebagai **root**, Codex bisa menjalankan perintah; jangan mengekspos port Agent ke jaringan yang tidak dipercaya.
- `token` di `canvas-agent.json` akan terekspos lewat `/config.js` ke siapa pun yang bisa membuka kanvas; tambahkan kontrol akses, whitelist firewall, atau autentikasi reverse proxy.
- `.env`, `canvas-agent.json`, dan Cookie Muse adalah kredensial sensitif, jaga izinnya `600`, jangan di-commit ke Git.
- Jika proyek ini di-deploy secara publik, tambahkan login, rate limiting, dan audit sendiri.

### Ucapan terima kasih

Dengan tulus berterima kasih kepada penulis dua proyek hulu, tanpa mereka kombinasi ini tidak ada:

- **muse2api** — penulis [@czg86389-hub](https://github.com/czg86389-hub)
  Repo: <https://github.com/czg86389-hub/muse2api>
  Terima kasih sudah membungkus Muse menjadi interface yang kompatibel dengan OpenAI dan stabil, serta menyediakan kolam akun, antrean tugas, dan panel admin.
- **infinite-canvas** — penulis [@basketikun](https://github.com/basketikun)
  Repo: <https://github.com/basketikun/infinite-canvas>
  Terima kasih sudah membuat kanvas tak terbatas yang sangat bagus, protokol Agent, dan rekayasa frontend.

Kedua proyek hulu berlisensi **MIT License**; kode integrasi repo ini juga dirilis dengan MIT, lihat `LICENSE` dan `NOTICE`.

---

## Deploy di Dokploy (fork ini)

Fork ini di-deploy **canvas-only** di Dokploy LABS: hanya `canvas_server.py` + `canvas/dist` yang berjalan di container. Tanpa Chromium, tanpa Node, tanpa bundle muse2api di repo ini.

- **muse2api yang dipakai** adalah layanan muse2api yang sudah live di https://muse2api.masyamin.biz.id — bukan bundle `muse2api/` di repo ini. Bundle itu versi lama (v1.6.7) dan **TIDAK dipakai** di deploy Dokploy ini.
- **MUSE_API_BASE** di env Dokploy: `https://muse2api.masyamin.biz.id` (tanpa `/` di akhir, tanpa `/v1`).
- **MUSE_API_KEY** disetel di env Dokploy (jangan tulis nilainya di repo mana pun).
- **Agent DeepSeek nonaktif dulu**: Agent butuh `DEEPSEEK_API_KEY` (diawali `sk-`), dan key itu belum ada. Tanpa key tersebut, panel Agent tidak terhubung — kanvas tetap bisa dipakai untuk membuat gambar/video/percaturan lewat channel Muse. Untuk mengaktifkan Agent nanti, tambahkan `DEEPSEEK_API_KEY` di env Dokploy dan deploy layanan Agent secara terpisah.
- **Dockerfile**: `Dockerfile` di root repo ini (base `python:3.11-slim-bookworm`, hanya menyalin `canvas_server.py` + `canvas/dist/`, port 521).
- **Dokploy**: buat Application di project LABS dari repo fork https://github.com/ashabulymn/Muse-Canvas, branch `main`, Build Type Dockerfile, Dockerfile Path `./Dockerfile`, Docker Context Path `/`, port 521, domain `muse-canvas.masyamin.biz.id` (HTTPS). Env: `MUSE_API_BASE=https://muse2api.masyamin.biz.id`, `MUSE_API_KEY` (disetel di Dokploy), `MUSE_CHANNEL_NAME=Muse`, `CANVAS_HOST=0.0.0.0`, `CANVAS_PORT=521`, `TZ=Asia/Jakarta`.
- **Verifikasi**: buka `https://muse-canvas.masyamin.biz.id/healthz` (harus `ok`), lalu `https://muse-canvas.masyamin.biz.id/config.js` (harus memuat `MUSE_API_BASE` ke muse2api live). Detail langkah ada di `DOKPLOY.md`.
- **Akun Muse** belum diimpor di muse2api live (masih 0 akun) — impor dulu lewat panel admin muse2api live, kanvas memakai akun yang sama.

---

## English

### What is this

This repository combines two excellent open-source projects into one deployable system:

1. **[muse2api](https://github.com/czg86389-hub/muse2api)** — reverse-engineers Muse(muse.ai) into an OpenAI-compatible API for image generation/editing, video generation, and chat.
2. **[infinite-canvas](https://github.com/basketikun/infinite-canvas)** — an infinite canvas workspace for AI creation that calls OpenAI-compatible APIs directly from the browser.
3. **The integration layer added here**:
   - Locks the default canvas provider to server-side `.env` values; the browser cannot edit the base URL, key, or models.
   - Locks the Agent URL/token to `canvas-agent.json`; the browser shows read-only fields and auto-connects.
   - Adds `canvas_server.py`, a dependency-free Python static server for the built frontend.
   - Adds `install.sh`, 1Panel Supervisor examples, Nginx SSE examples, and bilingual docs.
   - Patches muse2api to accept canvas multipart video requests, `n` images, and `first_frame` / `last_frame` / `image[]` references.

### Features

- Infinite canvas with text, image, video, and audio nodes, references, and projects.
- Muse models: `muse-image`, `muse-video`, `muse-spark`.
- Server-side Agent: Codex App Server talks to DeepSeek's Responses API and controls the canvas through MCP tools.
- Provider lock: `MUSE_API_BASE`, `MUSE_API_KEY`, and the model list live only in server `.env`.
- Agent lock: browser URL and token come only from `agent/.infinite-canvas/canvas-agent.json`.
- One `install.sh` sets up Python, the Node Agent, Codex, secrets, and Supervisor arguments.
- Bilingual documentation and reproducible 1Panel / Nginx deployment steps.

### Architecture

```text
Browser (https://canvas.example.com)
  ├─ Infinite Canvas static app
  ├─ /config.js injected by canvas_server.py
  └─ Agent panel (read-only URL/token)
        │
        ├── HTTPS ──> canvas_server :521
        │                 └─ static files + /config.js
        │
        └── HTTPS ──> Nginx ──> canvas-agent :17371
                              └─ Codex app-server
                                   ├─ DeepSeek Responses API
                                   └─ MCP tools → canvas

canvas ──> muse2api :1314 ──> Muse account pool + Chromium CDP
```

### Repository layout

```text
Muse-Canvas/
├── README.md                     # This file (Bahasa Indonesia + English)
├── LICENSE                       # MIT
├── NOTICE                        # Upstream attribution
├── .env.example                  # Server environment template
├── install.sh                    # One-shot installer (Debian / Ubuntu)
├── start-api.sh                  # Start muse2api
├── start-canvas.sh               # Start the canvas static server
├── canvas_server.py              # Python static server + /config.js injection
├── supervisor.conf.example       # 1Panel Supervisor reference
├── nginx-agent.conf.example      # Nginx/SSE reference for the Agent
├── muse2api/                     # Patched Muse API source
├── canvas/dist/                  # Prebuilt Infinite Canvas frontend
├── agent/
│   ├── package.json              # @basketikun/canvas-agent
│   ├── start-agent.sh            # Server-side Agent launcher
│   └── codex/                    # Codex + DeepSeek config and model catalog
└── source/infinite-canvas/       # Upstream Infinite Canvas source
```

### Requirements

- Debian 12+ / Ubuntu 22.04+ (other distros: install dependencies manually).
- Python 3.10+.
- Node.js 18+ (20/22 recommended).
- Chromium or Google Chrome (required by muse2api).
- 2 vCPU / 4 GB RAM minimum; 4 vCPU / 8 GB recommended for video.
- A Muse account (Cookie import).
- A DeepSeek API key (`sk-...`) for the Agent.

### Quick start

#### 1. Upload and extract

```bash
sudo mkdir -p /Muse
sudo tar -xzf Muse-Canvas.tar.gz -C /Muse --strip-components=1
cd /Muse
```

You can also `git clone` the repository into `/Muse`.

#### 2. Configure environment

```bash
cp .env.example .env
nano .env
```

At minimum:

```ini
MUSE_API_BASE=https://api.example.com
MUSE_API_KEY=replace-with-a-long-random-string
DEEPSEEK_API_KEY=sk-your-deepseek-key
```

Notes:

- `MUSE_API_BASE` is the **browser-facing** Muse API URL. No trailing `/`, no `/v1`.
- If the canvas is served over HTTPS, this must also be HTTPS, otherwise browsers block mixed content.
- `MUSE_API_KEY` is the muse2api access key, not the Muse account password.
- `DEEPSEEK_API_KEY` is only used by the server-side Agent and is never shipped to the frontend.

#### 3. Install

```bash
sudo -E bash install.sh
```

The installer:

1. Installs Python, Chromium, Node, fonts, and related packages.
2. Creates `.venv` and installs muse2api dependencies.
3. Keeps an existing `.env`; generates a random `MUSE_API_KEY` when creating a new one.
4. Validates and stores `DEEPSEEK_API_KEY`.
5. Installs `@basketikun/canvas-agent@0.6.0` under `agent/`.
6. Creates `agent/.infinite-canvas/canvas-agent.json` (token, public URL, allowed origins, workspace).
7. Prints the three Supervisor entries, the Agent token, and the admin URL.

Override the placeholders when your domains differ:

```bash
sudo -E env \
  AGENT_PUBLIC_URL="https://agent.example.com" \
  AGENT_ORIGINS="https://canvas.example.com https://muse.example.com" \
  bash install.sh
```

#### 4. 1Panel Supervisor

Install Supervisor from 1Panel's Toolbox, then create:

| Name | User | Working directory | Command |
| --- | --- | --- | --- |
| `muse2api` | root | `/Muse` | `/bin/bash /Muse/start-api.sh` |
| `muse-canvas` | root | `/Muse` | `/bin/bash /Muse/start-canvas.sh` |
| `muse-agent` | root | `/Muse/agent` | `/bin/bash /Muse/agent/start-agent.sh` |

Use one process per entry. Logs are under `/Muse/logs/`.

#### 5. Reverse proxy and HTTPS

Recommended domains:

| Domain | Upstream | Purpose |
| --- | --- | --- |
| `canvas.example.com` | `127.0.0.1:521` | Infinite Canvas |
| `api.example.com` | `127.0.0.1:1314` | Muse API |
| `agent.example.com` | `127.0.0.1:17371` | Server-side Agent |

API Nginx settings (generation can exceed 60 seconds):

```nginx
proxy_connect_timeout 60s;
proxy_send_timeout    600s;
proxy_read_timeout    600s;
proxy_buffering       off;
client_max_body_size  200M;
```

Agent Nginx settings (SSE must not be buffered):

```nginx
proxy_http_version 1.1;
proxy_set_header   Host $host;
proxy_set_header   X-Real-IP $remote_addr;
proxy_buffering    off;
proxy_cache        off;
gzip               off;
proxy_read_timeout 3600s;
client_max_body_size 100M;
```

> The canvas and API must both use HTTPS or both use HTTP. An HTTPS canvas cannot call an HTTP API.

#### 6. Import a Muse account

Open:

```text
https://api.example.com/admin?key=YOUR_MUSE_API_KEY
```

Import Muse cookies with the Chrome extension in `muse2api/extension/`, or paste `hatch_sess` / `hatch_vml` from DevTools:

```text
hatch_sess=......; hatch_vml=......
```

Then click "Test" on the account.

#### 7. Locked configuration

Only two files matter:

**`/Muse/.env`** — provider lock:

```ini
MUSE_API_BASE=https://api.example.com
MUSE_API_KEY=your-random-key
MUSE_CHANNEL_NAME=Muse
DEEPSEEK_API_KEY=sk-...
```

**`/Muse/agent/.infinite-canvas/canvas-agent.json`** — Agent lock:

```json
{
  "url": "http://127.0.0.1:17371",
  "publicUrl": "https://agent.example.com",
  "token": "36-char token generated by the installer",
  "origins": ["https://canvas.example.com"],
  "workspace": { "workspacePath": "/Muse/agent/workspace" }
}
```

Restart after changes:

```bash
supervisorctl restart muse2api muse-canvas muse-agent
```

On refresh:

- Settings → Providers shows a read-only notice; URL, key, and models cannot be edited.
- The Agent URL/token fields are disabled.
- The Agent auto-connects with `DeepSeek-Flash`.

### Build the frontend from source

A prebuilt `canvas/dist` is included. To rebuild:

```bash
cd source/infinite-canvas/web
npm install --legacy-peer-deps --ignore-scripts
npm run build
rm -rf ../../../canvas/dist
cp -a dist ../../../canvas/dist
```

Restart `muse-canvas`.

### Environment variables

| Variable | Default | Description |
| --- | --- | --- |
| `MUSE_API_BASE` | `http://127.0.0.1:1314` | Browser-facing API URL; no `/v1` |
| `MUSE_API_KEY` | random | muse2api access key |
| `MUSE_CHANNEL_NAME` | `Muse` | Provider display name |
| `MUSE2API_HOST` | `0.0.0.0` | API bind address |
| `MUSE2API_PORT` | `1314` | API port |
| `MUSE2API_CONCURRENCY` | `2` | Concurrent Muse tasks |
| `MUSE2API_CHROMIUM` | empty | Auto-detect, or set `/usr/bin/chromium` |
| `DEEPSEEK_API_KEY` | empty | DeepSeek key for the Agent |
| `CANVAS_HOST` | `0.0.0.0` | Canvas bind address |
| `CANVAS_PORT` | `521` | Canvas port |
| `CANVAS_ROOT` | empty | Defaults to `canvas/dist` |
| `TZ` | `Asia/Jakarta` | Time zone |

### Troubleshooting

**`{"detail":"Not Found"}` for `http://.../v1`**
Use the root URL only; the canvas appends `/v1/...` itself.

**401 when opening `/v1/models` in a browser**
Expected: browsers do not send `Authorization`. The canvas sends the Bearer token.

**`Failed to fetch` / mixed content**
An HTTPS canvas cannot call an HTTP API. Switch `MUSE_API_BASE` to HTTPS or serve the canvas over HTTP.

**Image generation returns 504 after ~60s**
Raise Nginx `proxy_read_timeout` to 600s and disable buffering.

**Agent reports `DEEPSEEK_API_KEY ... not configured`**
Add `DEEPSEEK_API_KEY=sk-...` to `/Muse/.env`, `chmod 600`, restart `muse-agent`.

**Agent says `origin not allowed`**
Open the canvas at `https://canvas.example.com` or add that origin to `canvas-agent.json`.

**Agent connects but a turn returns 401**
The DeepSeek key is invalid, out of credit, or has whitespace. Rewrite it and restart `muse-agent`.

**Video generation times out**
Set Nginx read timeout ≥ 600s and tune `MUSE2API_CONCURRENCY`.

### Security

- The Agent runs as **root** and Codex can execute commands. Do not expose `agent.example.com` to untrusted networks.
- The `token` in `canvas-agent.json` is embedded in `/config.js` and is visible to anyone who can open the canvas. Add access control, firewall rules, or reverse-proxy auth.
- `.env`, `canvas-agent.json`, and Muse cookies are secrets. Keep them `600` and never commit them.
- Add login, rate limiting, and auditing before exposing this publicly.

### Credits

Huge thanks to the upstream authors:

- **muse2api** — [@czg86389-hub](https://github.com/czg86389-hub)
  <https://github.com/czg86389-hub/muse2api>
  For turning Muse into a stable OpenAI-compatible API, with account pooling, task queues, and an admin UI.
- **infinite-canvas** — [@basketikun](https://github.com/basketikun)
  <https://github.com/basketikun/infinite-canvas>
  For the excellent infinite canvas, Agent protocol, and frontend engineering.

Both upstream projects are **MIT licensed**. The integration code here is also released under MIT; see `LICENSE` and `NOTICE`.

---

If this project helps you, please star the two upstream repositories as well — most of the credit belongs to their authors.
