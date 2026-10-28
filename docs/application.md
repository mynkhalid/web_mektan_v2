# Application Layer — MyMektan

> Dokumen ini menjelaskan layer aplikasi MyMektan: antarmuka web Vue 3, API backend Express, database PostgreSQL (Supabase), integrasi MQTT, penyimpanan gambar, dan deployment.

## 1. Ringkasan

MyMektan adalah platform IoT untuk memantau lokasi, status mesin, tegangan aki, jam kerja, dan estimasi luas lahan alsintan. Layer aplikasi terdiri dari:

- **Frontend**: single-page application Vue 3 yang menampilkan dashboard, peta, katalog aset, estimasi lahan, dan alur peminjaman.
- **Backend**: REST API Express yang menangani autentikasi, data aset, pengajuan peminjaman, serta ingestion data MQTT ke database.
- **Database**: PostgreSQL yang di-host di Supabase.
- **Messaging**: HiveMQ Cloud sebagai broker MQTT untuk data realtime dari perangkat ESP32.
- **Storage**: Cloudinary untuk gambar aset dan foto profil.

## 2. Arsitektur Aplikasi

```mermaid
flowchart LR
    device["ESP32<br/>GPS · INA219 · SIM7600G"] -->|"MQTT / TLS"| broker["HiveMQ Cloud"]
    broker --> backend["Backend API<br/>Express + MQTT ingestor"]
    backend --> database[("Supabase<br/>PostgreSQL")]
    backend --> storage["Cloudinary"]
    frontend["Frontend SPA<br/>Vue 3 + Vite"] -->|"REST API"| backend
    frontend -->|"MQTT over WSS"| broker
```

Alur data:

1. Perangkat mengirim data lokasi dan telemetri ke topik MQTT.
2. Backend memvalidasi data, menghitung status mesin, jam kerja, dan jarak kerja, lalu menyimpannya ke database.
3. Frontend memuat data historis melalui REST API dan menerima pembaruan realtime melalui MQTT over WSS.
4. Admin mengelola aset, memverifikasi akun, dan memproses pengajuan peminjaman melalui antarmuka web.

## 3. Fitur Utama

- Pemantauan lokasi dan status mesin secara realtime.
- Telemetri tegangan aki, arus, HDOP, dan jumlah satelit GPS.
- Perhitungan hour meter dan jarak kerja.
- Estimasi luas lahan dan biaya jasa berdasarkan riwayat perjalanan.
- Katalog aset publik dengan detail spesifikasi dan ketersediaan.
- Pengajuan peminjaman alsintan oleh masyarakat.
- Antrean pengajuan dan penerbitan surat jalan digital dengan QR code.
- Registrasi akun UPJA dan verifikasi oleh admin Mektan.
- Manajemen aset dengan unggah gambar.
- Autentikasi JWT dengan satu sesi aktif per akun.

## 4. Peran Pengguna

| Peran | Akses utama |
| --- | --- |
| Guest | Dashboard, katalog aset, detail aset, pengajuan peminjaman, dan registrasi akun. |
| UPJA | Login, profil, monitoring peta, estimasi lahan, dan pengajuan peminjaman. |
| Mektan | Seluruh fitur UPJA ditambah manajemen aset, verifikasi akun, pengelolaan antrean, dan transaksi peminjaman. |

Registrasi publik membuat akun dengan role `upja` dan status `pending`. Akun baru dapat digunakan setelah diverifikasi oleh admin `mektan`.

## 5. Struktur Layer Aplikasi

```text
web_mektan_v2/
├── backend/
│   ├── config/          # Koneksi PostgreSQL
│   ├── controllers/     # Handler request
│   ├── middleware/      # Autentikasi JWT dan upload
│   ├── routes/          # Definisi endpoint API
│   ├── services/        # MQTT subscriber dan pemrosesan telemetri
│   ├── db_alsintan.sql  # Schema database
│   ├── .env.example     # Template environment backend
│   └── index.js         # Entry point backend
└── frontend/
    ├── public/          # Aset publik
    ├── src/
    │   ├── components/  # Sidebar, topbar, footer
    │   ├── router/      # Route dan navigation guard
    │   ├── utils/       # Helper notifikasi
    │   └── views/       # Halaman aplikasi
    ├── .env.example     # Template environment frontend
    ├── vite.config.js
    └── vercel.json
```

## 6. Teknologi

| Layer | Teknologi |
| --- | --- |
| Frontend | Vue 3, Vite, Vue Router, Bootstrap 5, Leaflet, MQTT.js, Axios, SweetAlert2 |
| Backend | Node.js, Express 5, JWT, bcrypt, Multer, Cloudinary |
| Database | PostgreSQL (Supabase) |
| Messaging | MQTT over TLS (HiveMQ Cloud) |
| Deployment | Render (backend) dan Vercel (frontend) |

## 7. Prasyarat

- Node.js 22 LTS dan npm.
- Proyek Supabase (PostgreSQL).
- Broker HiveMQ Cloud.
- Akun Cloudinary.
- Git.

## 8. Konfigurasi Database

1. Buat proyek baru di Supabase.
2. Buka **SQL Editor** pada dashboard Supabase.
3. Jalankan seluruh isi file [`backend/db_alsintan.sql`](../backend/db_alsintan.sql).
4. Buka **Project Settings → Database**, lalu salin connection string PostgreSQL.
5. Gunakan connection string tersebut sebagai `DATABASE_URL` pada environment backend.

Jika koneksi langsung tidak tersedia dari platform hosting, gunakan connection string **Session Pooler** dari Supabase.

### Tabel utama

| Tabel | Fungsi |
| --- | --- |
| `users` | Akun, role, profil, status verifikasi, dan token sesi aktif. |
| `alsintan` | Data master aset, status operasional, ketersediaan, koordinat, dan gambar. |
| `monitoring_status` | Status live per aset: status mesin, status IoT, tegangan aki, hour meter, jarak kerja, HDOP, dan satelit. |
| `riwayat_perjalanan` | Riwayat koordinat per aset. |
| `riwayat_telemetri` | Riwayat tegangan dan arus per aset. |
| `pengajuan_publik` | Pengajuan peminjaman dari masyarakat. |
| `transaksi_peminjaman` | Transaksi peminjaman resmi dan pengembalian aset. |
| `pengaturan_sistem` | Pengaturan sistem, termasuk tarif jasa per hektar. |

## 9. Konfigurasi Backend

### Instalasi

```bash
cd backend
npm install
cp .env.example .env
# Windows: copy .env.example .env
```

### Environment variable

| Variable | Contoh | Keterangan |
| --- | --- | --- |
| `PORT` | `3000` | Port HTTP. Render menyediakan nilai ini otomatis. |
| `DATABASE_URL` | `postgresql://postgres:password@db.<project-ref>.supabase.co:5432/postgres` | Connection string PostgreSQL Supabase. SSL diaktifkan oleh aplikasi. |
| `JWT_SECRET` | `replace-with-a-long-random-secret` | Secret untuk menandatangani dan memverifikasi JWT. |
| `MQTT_HOST` | `<cluster>.s1.eu.hivemq.cloud` | Hostname broker MQTT tanpa protokol. |
| `MQTT_PORT` | `8883` | Port MQTT TLS. |
| `MQTT_USERNAME` | `your-mqtt-username` | Username MQTT. |
| `MQTT_PASSWORD` | `your-mqtt-password` | Password MQTT. |
| `MQTT_TOPIC` | `project-mektan/v1/data` | Topik yang digunakan perangkat dan backend. |
| `CLOUDINARY_CLOUD_NAME` | `your-cloud-name` | Nama cloud Cloudinary. |
| `CLOUDINARY_API_KEY` | `your-api-key` | API key Cloudinary. |
| `CLOUDINARY_API_SECRET` | `your-api-secret` | API secret Cloudinary. |

### Menjalankan backend

```bash
node index.js
```

Backend berjalan di `http://localhost:3000`. Endpoint root `GET /` dapat digunakan untuk mengecek status server.

> Saat ini belum ada script `npm start` atau `npm run dev`. Jalankan entry point langsung dengan `node index.js`.

### Akun admin awal

Registrasi publik hanya membuat akun `upja` dengan status `pending`. Akun `mektan` perlu dibuat manual. Panduan lengkap, termasuk pembuatan hash bcrypt dan query SQL, tersedia di [README backend](../backend/README.md).

### Ringkasan endpoint API

| Grup | Prefix | Fungsi |
| --- | --- | --- |
| Users | `/api/users` | Login, registrasi, profil, daftar akun pending, dan verifikasi akun. |
| Alsintan | `/api/alsintan` | CRUD aset, riwayat perjalanan, reset trip, dan registrasi perangkat IoT. |
| Monitoring | `/api/monitoring` | Update dan pembacaan status mesin. |
| Peminjaman | `/api/peminjaman` | Peminjaman, pengecekan transaksi aktif, dan pengembalian. |
| Pengajuan | `/api/pengajuan` | Pengajuan publik, antrean admin, ACC, dan penolakan. |
| Settings | `/api/settings` | Pembacaan dan pembaruan tarif jasa. |

Detail endpoint, contoh request/response, dan aturan akses tersedia di [README backend](../backend/README.md).

## 10. Konfigurasi Frontend

### Instalasi

```bash
cd frontend
npm install
cp .env.example .env
# Windows: copy .env.example .env
```

### Environment variable

| Variable | Contoh lokal | Keterangan |
| --- | --- | --- |
| `VITE_API_BASE_URL` | `http://localhost:3000/api` | Base URL REST API backend. |
| `VITE_IMAGE_BASE_URL` | `http://localhost:3000/uploads` | Base URL untuk gambar dengan path relatif. Gambar Cloudinary menggunakan URL absolut. |
| `VITE_MQTT_HOST` | `<cluster>.s1.eu.hivemq.cloud` | Hostname broker MQTT tanpa protokol. |
| `VITE_MQTT_PORT` | `8884` | Port WebSocket Secure (WSS). Aplikasi menggunakan protokol `wss` dan path `/mqtt`. |
| `VITE_MQTT_TOPIC` | `project-mektan/v1/data` | Topik untuk pembaruan realtime. |
| `VITE_MQTT_USERNAME` | `your-mqtt-username` | Username MQTT. |
| `VITE_MQTT_PASSWORD` | `your-mqtt-password` | Password MQTT. |

### Menjalankan frontend

```bash
npm run dev
```

Frontend berjalan di `http://localhost:5173`.

### Perintah build

```bash
npm run build
npm run preview
```

Hasil build berada di folder `dist/`.

### Halaman utama

| Route | Akses | Fungsi |
| --- | --- | --- |
| `/` | Public | Dashboard dan peta global. |
| `/aset` | Public | Katalog aset dan pengajuan peminjaman. |
| `/aset/:id` | Public | Detail aset dan informasi peminjaman. |
| `/login` | Public | Login pengguna. |
| `/register` | Public | Registrasi akun UPJA. |
| `/profile` | Login | Profil pengguna dan UPJA. |
| `/monitoring` | Login | Peta monitoring armada. |
| `/monitoring/:id` | Login | Monitoring live dan riwayat per aset. |
| `/estimasi` | Login | Estimasi luas lahan dan biaya jasa. |
| `/antrean` | Login | Antrean pengajuan untuk admin. |
| `/aset/tambah` | Login, role `mektan` | Menambah aset. |
| `/aset/edit/:id` | Login, role `mektan` | Mengubah aset. |
| `/verifikasi-akun` | Area admin | Verifikasi akun UPJA. |

Detail halaman, autentikasi, dan integrasi MQTT tersedia di [README frontend](../frontend/README.md).

## 11. Deployment

| Komponen | Platform | Konfigurasi |
| --- | --- | --- |
| Frontend | Vercel | Root directory `frontend`, build command `npm run build`, output `dist`. Tambahkan seluruh variabel `VITE_*` di dashboard Vercel. |
| Backend | Render | Root directory `backend`, build command `npm install`, start command `node index.js`, health check path `/`. Tambahkan environment backend di dashboard Render. |
| Database | Supabase | Jalankan `backend/db_alsintan.sql`, lalu gunakan connection string Supabase sebagai `DATABASE_URL`. |
| MQTT | HiveMQ Cloud | Port `8883` untuk backend (TLS) dan port `8884` untuk frontend (WSS). |
| Storage | Cloudinary | Digunakan untuk gambar aset dan foto profil. |

Backend saat ini mengizinkan origin `http://localhost:5173` dan `https://mymektan.vercel.app` pada konfigurasi CORS di [`backend/index.js`](../backend/index.js). Sesuaikan daftar tersebut jika domain frontend berubah.

## 12. Troubleshooting

| Gejala | Penyebab umum | Tindakan |
| --- | --- | --- |
| Backend gagal terhubung ke database | `DATABASE_URL` salah, database tidak terjangkau, atau masalah SSL. | Periksa connection string Supabase dan akses jaringan. Aplikasi mengaktifkan SSL dengan `rejectUnauthorized: false`. |
| MQTT terus reconnect | Host, port, kredensial, atau topik salah. | Gunakan hostname broker tanpa protokol, port `8883` untuk TLS, dan periksa kredensial HiveMQ. |
| Frontend mendapat `401` | Token kedaluwarsa atau akun login di perangkat lain. | Login ulang untuk mendapatkan token baru. |
| Request frontend diblokir CORS | Origin frontend tidak ada di daftar backend. | Tambahkan domain frontend ke `corsOptions.origin` pada `backend/index.js`. |
| Gambar tidak tampil | URL gambar relatif atau kredensial Cloudinary salah. | Periksa `VITE_IMAGE_BASE_URL`, nilai `gambar`/`foto_profil`, dan environment Cloudinary. |
| Build frontend gagal | Versi Node.js tidak didukung. | Gunakan Node.js `^20.19.0` atau `>=22.12.0`; Node.js 22 LTS direkomendasikan. |

## 13. Referensi

- [README proyek](../README.md)
- [README backend](../backend/README.md)
- [README frontend](../frontend/README.md)
- [Perception Layer](perception.md)
- [Network Layer](network.md)
