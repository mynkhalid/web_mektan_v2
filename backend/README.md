# MyMektan Backend

REST API and MQTT ingestion service for MyMektan, an IoT platform for monitoring agricultural machinery (alsintan). The service handles authentication, asset management, loan requests, telemetry ingestion, and historical tracking data.

## Overview

The backend is an Express application that:

- Exposes REST endpoints under `/api`.
- Authenticates users with JWT and maintains a single active session per account.
- Subscribes to an MQTT topic and persists telemetry and location data to PostgreSQL.
- Stores asset images and profile photos in Cloudinary.
- Provides data for the Vue frontend and external IoT devices.

## Architecture

```text
ESP32 ──MQTT/TLS──> HiveMQ Cloud ──MQTT──> Backend (Node.js)
                                              │
                                              ├──> Supabase PostgreSQL
                                              └──> Cloudinary

Vue frontend ──REST API──> Backend
Vue frontend ──MQTT over WSS──> HiveMQ Cloud
```

## Tech Stack

| Component | Technology |
| --- | --- |
| Runtime | Node.js |
| Web framework | Express 5 |
| Database | PostgreSQL (Supabase) |
| Authentication | JSON Web Token, bcrypt |
| Messaging | MQTT (`mqtt` package) |
| File storage | Cloudinary with Multer |
| Deployment | Render |

## Requirements

- Node.js 22 LTS or newer.
- npm.
- A Supabase project or another PostgreSQL instance.
- A HiveMQ Cloud broker (or another MQTT broker with TLS support).
- A Cloudinary account.
- Git.

## Project Structure

```text
backend/
├── config/
│   └── database.js          # PostgreSQL connection pool
├── controllers/             # Request handlers
├── middleware/
│   ├── authMiddleware.js    # JWT verification and single-session check
│   └── upload.js            # Cloudinary upload configuration
├── routes/                  # Express route definitions
├── services/
│   └── mqttServices.js      # MQTT subscriber, telemetry processing, watchdog
├── .env.example             # Environment variable template
├── db_alsintan.sql          # Database schema
├── index.js                 # Application entry point
└── package.json
```

## Environment Variables

Create a `.env` file from `.env.example` and fill in the values.

| Variable | Required | Example | Description |
| --- | --- | --- | --- |
| `PORT` | No | `3000` | HTTP port. Render provides this automatically. |
| `DATABASE_URL` | Yes | `postgresql://postgres:password@db.<project-ref>.supabase.co:5432/postgres` | PostgreSQL connection string. SSL is enabled by the application. |
| `JWT_SECRET` | Yes | `replace-with-a-long-random-string` | Secret used to sign and verify JWTs. |
| `MQTT_HOST` | Yes | `<cluster>.s1.eu.hivemq.cloud` | MQTT broker hostname. Do not include a protocol. |
| `MQTT_PORT` | Yes | `8883` | MQTT TLS port. |
| `MQTT_USERNAME` | Yes | `your-mqtt-username` | MQTT username. |
| `MQTT_PASSWORD` | Yes | `your-mqtt-password` | MQTT password. |
| `MQTT_TOPIC` | Yes | `project-mektan/v1/data` | Topic subscribed by the backend and used by devices. |
| `CLOUDINARY_CLOUD_NAME` | Yes | `your-cloud-name` | Cloudinary cloud name. |
| `CLOUDINARY_API_KEY` | Yes | `your-api-key` | Cloudinary API key. |
| `CLOUDINARY_API_SECRET` | Yes | `your-api-secret` | Cloudinary API secret. |

## Local Setup

### 1. Install dependencies

```bash
cd backend
npm install
```

### 2. Configure the database

1. Create a project in Supabase.
2. Open the Supabase SQL Editor.
3. Run the entire contents of [`db_alsintan.sql`](db_alsintan.sql).
4. Open **Project Settings → Database** and copy the PostgreSQL connection string.
5. Set the connection string as `DATABASE_URL` in `.env`.

If the direct connection is not reachable from your hosting environment, use the Supabase Session Pooler connection string instead.

### 3. Configure environment variables

```bash
cp .env.example .env
```

On Windows:

```powershell
copy .env.example .env
```

Then edit `.env` with your database, JWT, MQTT, and Cloudinary credentials.

### 4. Create an initial admin account

Public registration creates `upja` accounts with `pending` status. To access administrator features, create a `mektan` account manually.

Generate a bcrypt password hash:

```bash
node -e "console.log(require('bcrypt').hashSync('your-password', 10))"
```

Insert the account through the Supabase SQL Editor:

```sql
INSERT INTO users (username, email, nama_lengkap, password, role, status_akun)
VALUES ('admin', 'admin@example.com', 'Administrator', '<bcrypt-hash>', 'mektan', 'aktif');
```

### 5. Start the server

```bash
node index.js
```

The API is available at `http://localhost:3000`. The root endpoint `GET /` returns a plain-text health message.

> There is no `npm start` or `npm run dev` script in the current `package.json`. Run the entry point directly with `node index.js`.

### 6. Verify the service

```bash
curl http://localhost:3000/
```

Expected response:

```text
Server Backend Alsintan Berjalan
```

## Authentication

### Login

`POST /api/users/login` accepts either a username or an email address.

```json
{
  "identifier": "admin",
  "password": "your-password"
}
```

On success, the API returns a JWT valid for 8 hours. The token is also stored in `users.current_token`. A new login invalidates the previous token, so only one session can be active per account.

Authenticated requests must include:

```http
Authorization: Bearer <token>
```

### Roles and account status

| Value | Description |
| --- | --- |
| `mektan` | Administrator role for asset management, account verification, and loan processing. |
| `upja` | Regular user role created by public registration. |

| Status | Description |
| --- | --- |
| `pending` | Account is waiting for administrator verification. |
| `aktif` | Account can log in. |
| `ditolak` | Account registration was rejected. |

The backend validates the JWT and the active session. Role-specific restrictions are primarily implemented in the frontend UI; review server-side authorization before exposing the API publicly.

## API Reference

All endpoints are prefixed with `/api`.

### Users

| Method | Endpoint | Access | Description |
| --- | --- | --- | --- |
| `POST` | `/users/login` | Public | Login with username or email. |
| `POST` | `/users/register` | Public | Register a new `upja` account with `pending` status. |
| `GET` | `/users/pending` | Public\* | List accounts waiting for verification. Intended for administrators. |
| `GET` | `/users/profile/:id` | Bearer | Get a user profile. |
| `PUT` | `/users/update/:id` | Bearer | Update a profile. Supports multipart upload with field `foto`. |
| `POST` | `/users/verify/:id` | Public\* | Approve or reject an account. Body: `{ "action": "aktif" }` or `{ "action": "ditolak" }`. Intended for administrators. |

\* These administrator routes do not have token middleware in the current implementation. Protect them before exposing the service publicly.

### Alsintan

| Method | Endpoint | Access | Description |
| --- | --- | --- | --- |
| `POST` | `/alsintan` | Bearer | Create an asset. Multipart form with optional `gambar`. |
| `GET` | `/alsintan` | Public | List all assets with live monitoring status. |
| `GET` | `/alsintan/:id` | Public | Get asset details. |
| `PUT` | `/alsintan/:id` | Bearer | Update an asset. Multipart form with optional `gambar`. |
| `DELETE` | `/alsintan/:id` | Bearer | Delete an asset and its related monitoring and history rows. |
| `GET` | `/alsintan/:id/riwayat` | Bearer | Get travel history. Optional query: `?tanggal=YYYY-MM-DD`. |
| `POST` | `/alsintan/:id/reset` | Bearer | Reset the trip session and working distance. |
| `POST` | `/alsintan/register` | Public | Register an IoT device. Body: `{ "id_alat": "<device-id>" }`. |

Asset creation requires `kode_perangkat` and `nama_alat`. Other supported fields are `kode_unit`, `kategori_alat`, `merk_alat`, `nomor_mesin`, `nomor_seri`, `status_sensor`, `status_operasional`, `deskripsi`, `kapasitas_lahan`, `lebar_implemen`, `tahun_penerimaan`, and `kondisi_fisik`.

### Monitoring

| Method | Endpoint | Access | Description |
| --- | --- | --- | --- |
| `POST` | `/monitoring/update-status` | Public | Upsert machine status and coordinates. |
| `GET` | `/monitoring/status/:id` | Public | Get monitoring status for an asset. |

Body for `POST /monitoring/update-status`:

```json
{
  "alsintan_id": 1,
  "status_mesin": "ON",
  "latitude": -6.9175,
  "longitude": 107.6191
}
```

### Peminjaman

| Method | Endpoint | Access | Description |
| --- | --- | --- | --- |
| `POST` | `/peminjaman/admin-pinjam` | Bearer | Create a loan transaction and mark the asset as borrowed. |
| `GET` | `/peminjaman/aktif/:alsintan_id` | Public | Get the active loan for an asset. |
| `POST` | `/peminjaman/selesai/:id_transaksi` | Bearer | Complete a loan. Body: `{ "alsintan_id": 1 }`. |

### Pengajuan

| Method | Endpoint | Access | Description |
| --- | --- | --- | --- |
| `POST` | `/pengajuan/public` | Public | Submit a public loan request. |
| `GET` | `/pengajuan/admin` | Bearer | List pending loan requests. |
| `POST` | `/pengajuan/admin/acc/:id_pengajuan` | Bearer | Approve a request and create an official loan. Body: `{ "nomor_ba": "...", "biaya_jasa": 0 }`. |
| `POST` | `/pengajuan/admin/tolak/:id_pengajuan` | Bearer | Reject a request. |

### Settings

| Method | Endpoint | Access | Description |
| --- | --- | --- | --- |
| `GET` | `/settings/tarif` | Public | Get the service tariff per hectare. Defaults to `1500000` when unset. |
| `PUT` | `/settings/tarif` | Public\* | Update the tariff. Body: `{ "nilai": 1500000 }`. Intended for administrators. |

`Public*` indicates an administrator operation that is not protected by token middleware in the current implementation.

## Request Examples

### Login

```bash
curl -X POST http://localhost:3000/api/users/login \
  -H "Content-Type: application/json" \
  -d '{"identifier":"admin","password":"your-password"}'
```

Successful response:

```json
{
  "status": true,
  "message": "Login berhasil",
  "token": "<jwt>",
  "data": {
    "id": 1,
    "username": "admin",
    "nama": "Administrator",
    "nama_lengkap": "Administrator",
    "role": "mektan",
    "foto": null
  }
}
```

### Create an asset

```bash
curl -X POST http://localhost:3000/api/alsintan \
  -H "Authorization: Bearer <jwt>" \
  -F "kode_perangkat=TRK-001" \
  -F "kode_unit=UNIT-01" \
  -F "nama_alat=Traktor Roda 4" \
  -F "kategori_alat=Traktor" \
  -F "merk_alat=Yanmar" \
  -F "nomor_mesin=MESIN-001" \
  -F "nomor_seri=SERI-001" \
  -F "status_sensor=Normal" \
  -F "status_operasional=Siap Digunakan" \
  -F "deskripsi=Traktor untuk pengolahan lahan" \
  -F "kapasitas_lahan=2 ha/hari" \
  -F "lebar_implemen=1.89" \
  -F "tahun_penerimaan=2025" \
  -F "kondisi_fisik=Baik" \
  -F "gambar=@traktor.jpg"
```

Successful response (`201 Created`):

```json
{
  "pesan": "Berhasil menambahkan alsintan baru!",
  "data": {
    "id": 1,
    "kode_perangkat": "TRK-001",
    "nama_alat": "Traktor Roda 4"
  }
}
```

### Submit a public loan request

```bash
curl -X POST http://localhost:3000/api/pengajuan/public \
  -H "Content-Type: application/json" \
  -d '{
    "alsintan_id": 1,
    "tanggal_mulai": "2026-11-01",
    "tanggal_berakhir": "2026-11-03",
    "nama_peminjam": "Nama Peminjam",
    "jabatan_peminjam": "Ketua",
    "kontak_peminjam": "081234567890",
    "nama_kelompok": "Poktan Contoh",
    "desa": "Desa Contoh",
    "kecamatan": "Kecamatan Contoh",
    "kabupaten": "Kabupaten Contoh"
  }'
```

Successful response:

```json
{
  "status": true,
  "message": "Pengajuan berhasil dikirim! Silakan tunggu admin menghubungi Anda."
}
```

Response shapes vary by module. Some endpoints return `{ "status": ..., "message": ... }`, while others return `{ "pesan": ... }` or `{ "error": ... }`.

## MQTT Contract

The backend connects with the `mqtts` protocol and subscribes to `MQTT_TOPIC`.

### Payload

```json
{
  "id": 1,
  "lat": -6.9175,
  "lng": 107.6191,
  "V": 13.8,
  "I": 2.1,
  "hd": 0.8,
  "st": 12,
  "ts": 1760000000
}
```

| Field | Type | Description |
| --- | --- | --- |
| `id` | Number | `alsintan_id` of the device. |
| `lat` | Number | Latitude. |
| `lng` | Number | Longitude. |
| `V` | Number | Battery voltage. |
| `I` | Number | Current. |
| `hd` | Number | GPS HDOP. |
| `st` | Number | Number of satellites. |
| `ts` | Number | Device timestamp. Accepted by the parser but not used by the current persistence logic. |

### Processing rules

- Messages without `lat`/`lng` or with coordinates `0,0` are discarded.
- Machine status becomes `ON` when `V > 13.4`, `OFF` when `V < 13.0`, and otherwise keeps the previous status.
- `monitoring_status` is updated with the latest status, heartbeat, voltage, coordinates, HDOP, and satellite count.
- `alsintan.latitude` and `alsintan.longitude` are updated with the latest valid coordinates.
- Each message inserts a row into `riwayat_telemetri`.
- Positions are buffered and flushed every 10 seconds.
- Positions moving faster than 20 km/h are treated as GPS spikes and discarded.
- Positions with `hd > 250` and a distance greater than 3 meters are treated as spikes.
- Positions moving less than 1 meter are treated as stationary and reuse the last valid coordinate.
- Moving positions are smoothed with an exponential moving average (`alpha = 0.8`).
- Hour meter and working distance are accumulated only while the machine status is `ON`.
- A watchdog runs every 60 seconds and marks devices with no heartbeat for more than 10 minutes as `status_iot = 'OFF'` and `status_mesin = 'UNKNOWN'`.

## Database Schema

The schema is defined in [`db_alsintan.sql`](db_alsintan.sql).

| Table | Purpose |
| --- | --- |
| `users` | Accounts, roles, profile data, verification status, and active session token. |
| `alsintan` | Asset master data, operational status, availability, coordinates, and image URL. |
| `monitoring_status` | One-to-one live status per asset: machine state, IoT state, battery voltage, hour meter, distance, HDOP, and satellites. |
| `riwayat_perjalanan` | Location history per asset. |
| `riwayat_telemetri` | Voltage and current history per asset. |
| `pengajuan_publik` | Public loan requests awaiting administrator review. |
| `transaksi_peminjaman` | Official loan transactions and returned assets. |
| `pengaturan_sistem` | System settings, including the service tariff per hectare. |

All child tables reference `alsintan.alsintan_id`. The schema file contains table definitions only and does not include seed data.

## File Uploads

Uploads are handled by Multer and stored in Cloudinary.

- Asset images: multipart field `gambar`.
- Profile photos: multipart field `foto`.
- Allowed formats: `jpeg`, `jpg`, `png`.
- Maximum file size: 5 MB.
- Cloudinary applies a `800 × 800` limit transformation.
- Cloudinary returns absolute URLs, which are stored in the database.

## Deployment on Render

1. Create a new **Web Service** in Render and connect this repository.
2. Set **Root Directory** to `backend`.
3. Set **Build Command** to `npm install`.
4. Set **Start Command** to `node index.js`.
5. Set **Health Check Path** to `/`.
6. Add all environment variables from `.env.example` in the Render dashboard.
7. Deploy the service.

Render provides the `PORT` environment variable automatically. The application uses `process.env.PORT` with a fallback to `3000`.

Use the Supabase connection string as `DATABASE_URL`. If the direct connection is unavailable from Render, use the Supabase Session Pooler connection string.

Update the CORS configuration in [`index.js`](index.js) if the frontend domain differs from `https://mymektan.vercel.app`.

## Troubleshooting

| Symptom | Likely cause | Resolution |
| --- | --- | --- |
| `Gagal koneksi ke database PostgreSQL` | Invalid `DATABASE_URL`, unreachable database, or SSL issue. | Verify the Supabase connection string and network access. The application enables SSL with `rejectUnauthorized: false`. |
| `MQTT Error` or repeated reconnect | Wrong host, port, credentials, or topic. | Use the broker hostname without a protocol, port `8883` for TLS, and verify the HiveMQ credentials. |
| `401 Sesi tidak valid atau telah kedaluwarsa` | Token expired or the account logged in on another device. | Log in again to obtain a new token. |
| `403 Akses ditolak. Token tidak ditemukan` | Missing `Authorization` header. | Send `Authorization: Bearer <token>`. |
| Frontend requests blocked by CORS | Frontend origin is not in the allowed list. | Add the frontend domain to `corsOptions.origin` in `index.js`. |
| Image upload fails | Missing or invalid Cloudinary credentials. | Verify `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, and `CLOUDINARY_API_SECRET`. |
| `npm start` fails | No `start` script is defined. | Run `node index.js` directly or add a start script to `package.json`. |

## Security Notes

- Never commit `.env` files or production credentials.
- Use a long, random `JWT_SECRET` and rotate it if it has been exposed.
- The current implementation validates JWTs but does not enforce role-based authorization on every endpoint. Administrator routes such as pending-user listing, account verification, and tariff updates should be protected before public exposure.
- The MQTT broker credentials are used by both the backend and the firmware. Use a dedicated broker user and restrict topic permissions where possible.

## Related Documentation

- [Project README](../README.md)
- [Frontend README](../frontend/README.md)
- [Network Layer](../docs/network.md)
- [Application Layer](../docs/application.md)
