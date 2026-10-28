# Panduan Kontribusi

Terima kasih atas ketertarikan Anda untuk berkontribusi pada MyMektan, platform IoT untuk pemantauan dan pengelolaan alsintan (alat dan mesin pertanian). Dokumen ini menjelaskan alur kerja, standar kode, dan pelaporan masalah pada repositori ini.

## Sebelum Mulai

- Baca [README utama](README.md) untuk memahami arsitektur dan fitur proyek.
- Siapkan environment sesuai layer yang akan dikerjakan:
  - [Backend](backend/README.md) — Express, PostgreSQL, MQTT, dan Cloudinary.
  - [Frontend](frontend/README.md) — Vue 3 dan Vite.
  - [Firmware ESP32](esp/README.md) — PlatformIO dan Arduino C++.

## Alur Kontribusi

1. Buat branch baru dari `main`.
2. Lakukan perubahan dan uji secara lokal.
3. Buat commit dengan format pesan yang disepakati.
4. Push branch ke repositori dan buka pull request ke `main`.
5. Tunggu review dan selesaikan catatan bila ada.
6. Setelah disetujui, branch akan di-merge ke `main`.

### Penamaan Branch

| Prefix | Penggunaan |
| --- | --- |
| `feat/` | Fitur baru. |
| `fix/` | Perbaikan bug. |
| `docs/` | Perubahan dokumentasi. |
| `chore/` | Pemeliharaan, konfigurasi, atau dependensi. |

Gunakan nama branch yang ringkas dan deskriptif, misalnya `fix/mqtt-reconnect` atau `docs/backend-setup`.

### Pesan Commit

Gunakan format berikut agar riwayat commit mudah dibaca:

```text
<tipe>: <ringkasan singkat>

<deskripsi opsional>
```

Tipe yang digunakan: `feat`, `fix`, `docs`, `chore`, `refactor`, atau `test`.

Contoh:

```text
fix: cegah lonjakan GPS tersimpan sebagai koordinat

Tambahkan validasi kecepatan sebelum posisi masuk ke riwayat perjalanan.
```

## Standar Kode

- Ikuti struktur folder, penamaan, dan pola yang sudah ada pada masing-masing layer.
- Frontend: jalankan `npm run format` di folder `frontend` sebelum membuka pull request.
- Backend: gunakan gaya CommonJS dan pola route, controller, serta service yang berlaku.
- Perubahan skema database harus disertai pembaruan [`backend/db_alsintan.sql`](backend/db_alsintan.sql).
- Perubahan atau penambahan endpoint API harus disertai pembaruan [README backend](backend/README.md).
- Perubahan route atau halaman harus disertai pembaruan [README frontend](frontend/README.md).

## Hal yang Tidak Boleh Di-commit

- File `.env` atau kredensial dalam bentuk apa pun.
- `node_modules/`, hasil build `dist/`, dan file cache.
- Kredensial perangkat pada `esp/include/secrets.h`.
- Data pengguna atau data operasional yang bersifat sensitif.

## Melaporkan Bug

Sertakan informasi berikut saat membuka laporan:

- Layer yang terdampak: firmware, backend, atau frontend.
- Langkah reproduksi secara berurutan.
- Hasil yang diharapkan dan hasil aktual.
- Pesan error, log, atau tangkapan layar bila tersedia.
- Versi Node.js atau PlatformIO yang digunakan, jika relevan.

## Usulan Fitur

Jelaskan masalah yang ingin diselesaikan, solusi yang diusulkan, dan dampaknya terhadap layer lain. Usulan yang mengubah skema database atau kontrak MQTT perlu dijelaskan secara terpisah.

## Kontributor

| Nama | GitHub | Area kontribusi |
| --- | --- | --- |
| Yozarino Hady | [@lbmu](https://github.com/lbmu) | Mikrokontroler, Jaringan |
| Khalid Nurahman | [@mynkhalid](https://github.com/mynkhalid) | Jaringan, Website, Database |
| Kiay Ahmadjaya Cendekia | [@Ayy1818](https://github.com/Ayy1818) | PCB, Skematik |
| Ahmassubhan Saha | — | — |
