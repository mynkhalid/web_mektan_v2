# MyMektan Frontend

Single-page application for MyMektan, an IoT platform for monitoring agricultural machinery (alsintan). The frontend provides live maps, telemetry views, an asset catalog, loan request workflows, and administrative tools.

## Overview

The application is built with Vue 3 and Vite. It communicates with the backend through a REST API and receives realtime updates directly from the MQTT broker over WebSocket Secure (WSS).

Main capabilities:

- Public dashboard with fleet statistics and live map.
- Asset catalog and asset detail pages.
- Public loan request form with region selection.
- Authenticated monitoring, trip history, and telemetry views.
- Area and service-cost estimation based on travel history.
- Administrative pages for asset management, account verification, and loan queues.
- User profile management with photo upload.

## Tech Stack

| Component | Technology |
| --- | --- |
| Framework | Vue 3 |
| Build tool | Vite 7 |
| Routing | Vue Router 4 |
| UI | Bootstrap 5, Bootstrap Icons |
| Maps | Leaflet, Leaflet MarkerCluster |
| Realtime | MQTT.js over WSS |
| HTTP client | Axios |
| Notifications | SweetAlert2 |
| Deployment | Vercel |

## Requirements

- Node.js `^20.19.0` or `>=22.12.0`. Node.js 22 LTS is recommended.
- npm.
- A running MyMektan backend.
- Access to the MQTT broker.

## Project Setup

```bash
cd frontend
npm install
cp .env.example .env
```

On Windows:

```powershell
copy .env.example .env
```

Edit `.env` and set the API and MQTT values for your environment, then start the development server:

```bash
npm run dev
```

The application runs at `http://localhost:5173` by default.

## Environment Variables

| Variable | Local example | Production example | Description |
| --- | --- | --- | --- |
| `VITE_API_BASE_URL` | `http://localhost:3000/api` | `https://<backend-service>.onrender.com/api` | Base URL for the backend REST API. |
| `VITE_IMAGE_BASE_URL` | `http://localhost:3000/uploads` | `https://<backend-service>.onrender.com/uploads` | Base URL for relative image paths. Cloudinary images use absolute URLs and do not depend on this value. |
| `VITE_MQTT_HOST` | `<cluster>.s1.eu.hivemq.cloud` | `<cluster>.s1.eu.hivemq.cloud` | MQTT broker hostname only. Do not include `ws://`, `wss://`, or a path. |
| `VITE_MQTT_PORT` | `8884` | `8884` | MQTT WebSocket Secure port. The application uses the `wss` protocol and the `/mqtt` path. |
| `VITE_MQTT_TOPIC` | `project-mektan/v1/data` | `project-mektan/v1/data` | Topic subscribed by the frontend for live updates. |
| `VITE_MQTT_USERNAME` | `your-mqtt-username` | `your-mqtt-username` | MQTT username. |
| `VITE_MQTT_PASSWORD` | `your-mqtt-password` | `your-mqtt-password` | MQTT password. |

The MQTT connection is created with:

```js
{
  host: import.meta.env.VITE_MQTT_HOST,
  port: Number(import.meta.env.VITE_MQTT_PORT),
  protocol: 'wss',
  path: '/mqtt',
  username: import.meta.env.VITE_MQTT_USERNAME,
  password: import.meta.env.VITE_MQTT_PASSWORD
}
```

Use port `8884` for HiveMQ Cloud WSS unless your broker uses a different WebSocket Secure port.

## Available Scripts

| Command | Description |
| --- | --- |
| `npm run dev` | Start the Vite development server with hot reload. |
| `npm run build` | Build the production bundle to `dist/`. |
| `npm run preview` | Serve the production build locally. |
| `npm run format` | Format files under `src/` with Prettier. |

There is no lint or automated test script in the current project.

## Routes and Access

| Path | Name | Access | Description |
| --- | --- | --- | --- |
| `/` | `home` | Public | Dashboard with statistics, map, and live status. |
| `/aset` | `aset-list` | Public | Asset catalog and loan request entry point. |
| `/aset/:id` | `aset-detail` | Public | Asset detail, availability, and loan information. |
| `/login` | `login` | Public | Login page. |
| `/register` | `register` | Public | UPJA account registration. |
| `/profile` | `profile` | Authenticated | User and UPJA profile management. |
| `/monitoring` | `monitoring` | Authenticated | Fleet map with status filters. |
| `/monitoring/:id` | `monitoring-detail` | Authenticated | Live and historical monitoring for one asset. |
| `/estimasi` | `estimasi` | Authenticated | Area and service-cost estimation. |
| `/antrean` | `antrean` | Authenticated | Loan request queue for administrators. |
| `/aset/tambah` | `aset-add` | Authenticated, role `mektan` | Create a new asset. |
| `/aset/edit/:id` | `aset-edit` | Authenticated, role `mektan` | Edit an existing asset. |
| `/verifikasi-akun` | `verifikasi-akun` | Administrator UI | Review and verify pending UPJA accounts. |

Role checks are implemented in the router for `/aset/tambah` and `/aset/edit/:id`. The `/antrean` and `/verifikasi-akun` pages are intended for the `mektan` role; review route guards before production deployment.

## Features by Page

### Dashboard

- Fleet totals and live machine count.
- Global map with clustered markers.
- Battery and operational warnings.
- Realtime updates from MQTT.

### Asset Catalog and Detail

- Search by asset name, device code, or serial number.
- Asset specifications, condition, availability, and image.
- Public loan request form with West Java region selection.
- Administrative actions for creating, editing, deleting, lending, and returning assets.

### Monitoring

- Map view with status filters: all, on, off, and offline.
- Offline detection after 10 minutes without telemetry.
- Asset detail view with live and historical tabs.
- Trip history, telemetry values, and trip reset action.

### Estimation

- Daily hour meter and distance calculated from travel history.
- Area calculation using distance and implement width.
- Service cost calculation using the configured tariff per hectare.
- Tariff configuration in the system settings.

### Loan Requests and Administration

- Public loan request submission.
- Pending request queue.
- Approval with BA number and service fee.
- Digital permit with QR code.
- Rejection and loan completion flows.
- UPJA account verification.

### Profile

- Personal and UPJA data.
- Region selection for West Java.
- Profile photo upload.

## Project Structure

```text
frontend/
├── public/
│   └── logo-mektan.jpeg
├── src/
│   ├── assets/          # Global CSS and bundled images
│   ├── components/      # AppTopbar, AppFooter, Sidebar
│   ├── composables/     # Layout composable
│   ├── router/          # Routes and navigation guards
│   ├── stores/          # Reserved for shared state
│   ├── utils/           # SweetAlert feedback helpers
│   ├── views/           # Page components
│   ├── App.vue
│   ├── Layout.vue
│   └── main.js
├── .env.example
├── index.html
├── package.json
├── vercel.json
└── vite.config.js
```

## Authentication and Session Flow

The frontend uses `sessionStorage` for session state:

- `user`: JSON object with user data from the login response.
- `token`: JWT returned by the backend.

`src/main.js` configures Axios interceptors:

- The request interceptor adds `Authorization: Bearer <token>` when a token exists.
- The response interceptor handles `401` responses by clearing session storage, showing a warning, and redirecting to the login page.

The router guard checks `meta.requiresAuth` and `meta.allowedRoles` before navigation. Login stores the session and redirects to the dashboard. Logout clears both session storage keys.

## Realtime MQTT

The frontend subscribes directly to the broker over WSS. The backend subscribes to the same topic to persist data.

Realtime subscriptions are used on:

- Dashboard.
- Asset catalog.
- Monitoring map.
- Monitoring detail.
- Estimation page.

The frontend updates in-memory state from MQTT messages. Historical data and persistent values are loaded from the backend REST API.

## API Integration

The frontend calls the following backend endpoint groups:

| Group | Examples |
| --- | --- |
| Users | `POST /users/login`, `POST /users/register`, `GET /users/profile/:id`, `PUT /users/update/:id`, `GET /users/pending`, `POST /users/verify/:id` |
| Assets | `GET /alsintan`, `GET /alsintan/:id`, `POST /alsintan`, `PUT /alsintan/:id`, `DELETE /alsintan/:id`, `GET /alsintan/:id/riwayat`, `POST /alsintan/:id/reset` |
| Monitoring | Asset status is included in `/alsintan` responses; live values arrive through MQTT. |
| Loans | `POST /peminjaman/admin-pinjam`, `GET /peminjaman/aktif/:alsintan_id`, `POST /peminjaman/selesai/:id_transaksi` |
| Requests | `POST /pengajuan/public`, `GET /pengajuan/admin`, `POST /pengajuan/admin/acc/:id_pengajuan`, `POST /pengajuan/admin/tolak/:id_pengajuan` |
| Settings | `GET /settings/tarif`, `PUT /settings/tarif` |

See the [backend README](../backend/README.md) for request and response details.

## External Services

| Service | Purpose |
| --- | --- |
| HiveMQ Cloud | MQTT broker for realtime telemetry. |
| OpenStreetMap | Map tiles for Leaflet. |
| Cloudinary | Asset images and profile photos, served as absolute URLs. |
| `emsifa.com` region API | Regency, district, and village dropdowns for West Java. |
| QR Server | QR code generation for digital loan permits. |
| UI Avatars | Fallback avatar when a user has no profile photo. |
| CDN assets | Bootstrap Icons, Google Fonts, Chart.js, MQTT.js, Animate.css, and Lottie Player loaded from CDNs in `index.html`. |

## Deployment on Vercel

1. Import the repository into Vercel.
2. Set the project root to `frontend`.
3. Use the Vite framework preset.
4. Set the build command to `npm run build`.
5. Set the output directory to `dist`.
6. Add all `VITE_*` environment variables in the Vercel project settings.
7. Deploy.

The repository includes [`vercel.json`](vercel.json) with a rewrite from all paths to `/` so that client-side routes work on refresh.

Make sure the backend CORS configuration allows the Vercel domain. The backend currently allows `https://mymektan.vercel.app` and `http://localhost:5173`.

## Troubleshooting

| Symptom | Likely cause | Resolution |
| --- | --- | --- |
| MQTT connection fails | Wrong host, port, or protocol. | Use the broker hostname without a protocol, WSS port `8884`, and the `/mqtt` path configured in the code. |
| Live data does not update | Topic mismatch or broker credentials are invalid. | Verify `VITE_MQTT_TOPIC`, username, and password. |
| API requests return `401` | Token expired or the account logged in elsewhere. | Log in again. The response interceptor clears the old session. |
| API requests are blocked by CORS | Backend does not allow the frontend origin. | Add the frontend domain to `corsOptions.origin` in `backend/index.js`. |
| Images do not load | Relative image path or missing Cloudinary URL. | Check `VITE_IMAGE_BASE_URL` and the image value stored by the backend. |
| Blank page after refresh in production | SPA rewrite is missing or misconfigured. | Confirm `vercel.json` is deployed and the output directory is `dist`. |
| Build fails on older Node.js | Unsupported Node version. | Use Node.js `^20.19.0` or `>=22.12.0`; Node.js 22 LTS is recommended. |

## Related Documentation

- [Project README](../README.md)
- [Backend README](../backend/README.md)
- [Application Layer](../docs/application.md)
