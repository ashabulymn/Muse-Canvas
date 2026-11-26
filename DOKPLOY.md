# Deploy di Dokploy (fork ini)

Panduan deploy fork Muse-Canvas ini di Dokploy LABS, mode **canvas-only**: hanya
`canvas_server.py` + `canvas/dist` yang berjalan di container. Tanpa Chromium,
tanpa Node, tanpa bundle muse2api di repo ini.

## Yang dipakai — dan yang tidak

- **muse2api yang dipakai** adalah layanan muse2api yang sudah live di
  https://muse2api.masyamin.biz.id — bukan bundle `muse2api/` di repo ini.
  Bundle itu versi lama (v1.6.7) dan **TIDAK dipakai** di deploy ini.
- **Akun Muse** belum diimpor di muse2api live (masih 0 akun) — impor dulu lewat panel admin muse2api live, kanvas memakai akun yang sama.
- **Bahasa UI** default Bahasa Inggris (en-US) — bundle kanvas di-patch agar default `en-US` (sumber: `source/infinite-canvas/web/src/i18n/index.ts`); tombol `EN`/`中` di kanan atas untuk ganti bahasa.
- **Agent DeepSeek nonaktif dulu**: Agent butuh `DEEPSEEK_API_KEY` (diawali
  `sk-`), dan key itu belum ada. Tanpa key tersebut, panel Agent tidak
  terhubung — kanvas tetap bisa dipakai untuk membuat gambar/video/percaturan
  lewat channel Muse. Untuk mengaktifkan Agent nanti, tambahkan
  `DEEPSEEK_API_KEY` di env Dokploy dan deploy layanan Agent secara terpisah.

## 1. Buat app di Dokploy

1. Di Dokploy, buka project **LABS** → **Create Application**.
2. Nama app: `muse-canvas`.
3. Source: Git provider, repo `https://github.com/ashabulymn/Muse-Canvas`,
   branch `main`.
4. Build Type: **Dockerfile**.
5. Dockerfile Path: `./Dockerfile`.
6. Docker Context Path: `/` (eksplisit, jangan dikosongkan).
7. Port: `521`.
8. Domain: `muse-canvas.masyamin.biz.id`, aktifkan HTTPS (Let's Encrypt).
9. Auto Deploy: OFF (deploy manual setelah perubahan dicek dulu).

## 2. Environment variables

Isi di menu **Environment** app Dokploy (jangan tulis key di repo):

| Variabel | Nilai |
| --- | --- |
| `MUSE_API_BASE` | `https://muse2api.masyamin.biz.id` |
| `MUSE_API_KEY` | disetel di Dokploy (kunci akses muse2api live) |
| `MUSE_CHANNEL_NAME` | `Muse` |
| `CANVAS_HOST` | `0.0.0.0` |
| `CANVAS_PORT` | `521` |
| `TZ` | `Asia/Jakarta` |

Catatan:

- `MUSE_API_BASE` tanpa `/` di akhir dan tanpa `/v1` — kanvas menambahkan
  `/v1/...` sendiri.
- Kanvas dibuka lewat HTTPS, jadi `MUSE_API_BASE` juga harus HTTPS, kalau
  tidak browser memblokir mixed content.
- Jangan pernah menulis nilai `MUSE_API_KEY` atau key lain di repo, di
  `.env.example`, atau di file mana pun di Git.

## 3. Deploy dan verifikasi

1. Klik **Deploy** di Dokploy, tunggu sampai status **Done** dan container
   berjalan tanpa restart loop.
2. Buka `https://muse-canvas.masyamin.biz.id/healthz` — harus mengembalikan
   `ok`.
3. Buka `https://muse-canvas.masyamin.biz.id/config.js` — harus memuat
   `MUSE_API_BASE` ke `https://muse2api.masyamin.biz.id` dan
   `MUSE_API_KEY` (nilainya hanya terlihat di sini, bukan di repo).
4. Buka `https://muse-canvas.masyamin.biz.id/` — kanvas tampil, panel
   **Pengaturan → Channel** menampilkan channel `Muse` dalam keadaan
   terkunci (alamat, Key, dan model tidak bisa diubah dari browser).
5. Coba buat satu gambar lewat channel `muse-image` untuk memastikan
   kanvas → muse2api live tersambung.

## 4. Jika ada masalah

- **`/healthz` tidak `ok` / container restart terus**: cek log container di
  Dokploy; pastikan port 521 tidak bentrok dan `canvas/dist/index.html`
  ikut ter-copy ke image.
- **`/config.js` kosong / tanpa `MUSE_API_BASE`**: cek env
  `MUSE_API_BASE` dan `MUSE_API_KEY` di Dokploy sudah terisi, lalu
  redeploy.
- **`Failed to fetch` di kanvas**: pastikan `MUSE_API_BASE` HTTPS dan
  muse2api live bisa diakses (`https://muse2api.masyamin.biz.id/v1/models`
  harus merespons).
- **Panel Agent tidak terhubung**: itu kondisi yang diharapkan saat ini —
  Agent butuh `DEEPSEEK_API_KEY` yang belum ada (lihat bagian atas).
