<script setup>
import { ref, onMounted, onUnmounted, computed, nextTick, watch } from 'vue';
import axios from 'axios';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import 'leaflet.markercluster/dist/MarkerCluster.css';
import 'leaflet.markercluster/dist/MarkerCluster.Default.css';
import 'leaflet.markercluster';
import { useRouter } from 'vue-router';
import mqtt from 'mqtt';

const router = useRouter();

const loading = ref(true);
const alsintanList = ref([]);
const searchQuery = ref('');
const filterStatus = ref('ALL');

let map = null;
let markerClusterGroup = null;
let markers = {};
let mqttClient = null;
let offlineTimers = {};
const TIMEOUT_BATAS_MS = 600000;

const MQTT_HOST = import.meta.env.VITE_MQTT_HOST;
const MQTT_PORT = Number(import.meta.env.VITE_MQTT_PORT);
const MQTT_TOPIC = import.meta.env.VITE_MQTT_TOPIC;
const MQTT_USERNAME = import.meta.env.VITE_MQTT_USERNAME;
const MQTT_PASSWORD = import.meta.env.VITE_MQTT_PASSWORD;

const filteredAlsintan = computed(() => {
    return alsintanList.value.filter(item => {
        const matchSearch = item.nama_alat.toLowerCase().includes(searchQuery.value.toLowerCase()) ||
                            item.kode_perangkat.toLowerCase().includes(searchQuery.value.toLowerCase());

        let matchStatus = false;
        if (filterStatus.value === 'ALL') matchStatus = true;
        else if (filterStatus.value === 'ON') matchStatus = item.status_iot === 'ON' && item.status_mesin === 'ON';
        else if (filterStatus.value === 'OFF') matchStatus = item.status_iot === 'ON' && item.status_mesin === 'OFF';
        else if (filterStatus.value === 'OFFLINE') matchStatus = item.status_iot !== 'ON';

        return matchSearch && matchStatus;
    });
});

const fetchAllData = async () => {
    try {
        const response = await axios.get(`${import.meta.env.VITE_API_BASE_URL}/alsintan`);
        alsintanList.value = Array.isArray(response.data) ? response.data : [];
        await nextTick();
        if (!map) initMap();
        renderGlobalMarkers();
    } catch (error) {
        console.error("Gagal load data:", error);
    } finally {
        loading.value = false;
    }
};

const initMap = () => {
    const container = document.getElementById('main-map');
    if (!container || map) return;

    map = L.map('main-map', { zoomControl: false }).setView([-6.9175, 107.6191], 11);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '&copy; OpenStreetMap'
    }).addTo(map);
    L.control.zoom({ position: 'bottomright' }).addTo(map);

    markerClusterGroup = L.markerClusterGroup({
        maxClusterRadius: 50,
        spiderfyOnMaxZoom: true,
        showCoverageOnHover: false,
        zoomToBoundsOnClick: true,
        disableClusteringAtZoom: 16
    });
    map.addLayer(markerClusterGroup);

    setTimeout(() => { if (map) map.invalidateSize(); }, 300);
};

const createIcon = (status_mesin, status_iot) => {
    let border = 'border-danger';
    let bg = 'bg-danger bg-opacity-10';
    let isON = false;

    if (status_iot === 'ON') {
        if (status_mesin === 'ON') {
            border = 'border-success'; bg = 'bg-success bg-opacity-10'; isON = true;
        } else if (status_mesin === 'OFF') {
            border = 'border-dark'; bg = 'bg-dark bg-opacity-10';
        }
    }

    return L.divIcon({
        className: 'custom-tractor-icon',
        html: `
            <div class="d-flex justify-content-center align-items-center rounded-circle border border-2 ${border} ${bg} shadow-sm position-relative"
                style="width: 36px; height: 36px; background-color: white;">
                <img src="/ikon-traktor.png" style="width: 22px; height: 22px; object-fit: contain;">
                ${isON ? '<div class="pulse-ring"></div>' : ''}
            </div>
        `,
        iconSize: [36, 36],
        iconAnchor: [18, 18],
        popupAnchor: [0, -20]
    });
};

const renderGlobalMarkers = () => {
    if (!markerClusterGroup) return;
    markerClusterGroup.clearLayers();
    markers = {};

    let group = [];
    filteredAlsintan.value.forEach(alat => {
        if (alat.latitude && alat.longitude) {
            const latLng = [parseFloat(alat.latitude), parseFloat(alat.longitude)];
            const marker = L.marker(latLng, { icon: createIcon(alat.status_mesin, alat.status_iot) });

            const statusTeks = alat.status_iot === 'ON' ? alat.status_mesin : 'OFFLINE';
            marker.bindTooltip(`<b>${alat.kode_perangkat}</b><br><small>${statusTeks}</small>`, { direction: 'top', offset: [0, -15] });
            marker.on('click', () => goToDetail(alat.alsintan_id));

            markers[alat.alsintan_id] = marker;
            markerClusterGroup.addLayer(marker);
            group.push(latLng);
        }
    });

    if (group.length > 0) {
        map.fitBounds(group, { padding: [50, 50] });
    }
};

const getDotClass = (iot, mesin) => {
    if (iot !== 'ON') return 'bg-danger';
    if (mesin === 'ON') return 'bg-success';
    return 'bg-dark';
};

const goToDetail = (id) => {
    router.push({ name: 'monitoring-detail', params: { id } });
};

const connectMqtt = () => {
    const options = {
        host: MQTT_HOST, port: MQTT_PORT, protocol: 'wss', path: '/mqtt',
        username: MQTT_USERNAME, password: MQTT_PASSWORD
    };
    mqttClient = mqtt.connect(options);

    mqttClient.on('connect', () => { mqttClient.subscribe(MQTT_TOPIC); });

    mqttClient.on('message', (topic, message) => {
        try {
            const data = JSON.parse(message.toString());
            const index = alsintanList.value.findIndex(i => i.alsintan_id == data.id);

            if (index !== -1) {
                if (offlineTimers[data.id]) clearTimeout(offlineTimers[data.id]);
                offlineTimers[data.id] = setTimeout(() => {
                    const idx = alsintanList.value.findIndex(i => i.alsintan_id == data.id);
                    if (idx !== -1) {
                        alsintanList.value[idx].status_iot = 'OFF';
                        alsintanList.value[idx].status_mesin = 'UNKNOWN';
                        const marker = markers[data.id];
                        if (marker) marker.setIcon(createIcon('UNKNOWN', 'OFF'));
                    }
                }, TIMEOUT_BATAS_MS);

                const tegangan = parseFloat(data.V) || 0;
                const statusMesinBaru = tegangan >= 13.0 ? 'ON' : 'OFF';
                const lat = parseFloat(data.lat);
                const long = parseFloat(data.long || data.lng);
                const isGpsValid = lat && long && !isNaN(lat) && !isNaN(long) && lat !== 0 && long !== 0;

                alsintanList.value[index].status_iot = 'ON';
                alsintanList.value[index].status_mesin = statusMesinBaru;
                if (isGpsValid) {
                    alsintanList.value[index].latitude = lat;
                    alsintanList.value[index].longitude = long;
                }

                const currentId = alsintanList.value[index].alsintan_id;
                const marker = markers[currentId];
                if (marker) {
                    marker.setIcon(createIcon(statusMesinBaru, 'ON'));
                    marker.setTooltipContent(`<b>${alsintanList.value[index].kode_perangkat}</b><br><small>${statusMesinBaru}</small>`);
                    if (isGpsValid) marker.setLatLng([lat, long]);
                }
            }
        } catch (err) {}
    });
};

watch([searchQuery, filterStatus], () => {
    renderGlobalMarkers();
});

onMounted(() => {
    fetchAllData();
    connectMqtt();
});

onUnmounted(() => {
    if (mqttClient) mqttClient.end();
    if (map) { map.remove(); map = null; }
    Object.values(offlineTimers).forEach(timer => clearTimeout(timer));
});
</script>

<template>
  <div class="monitoring-container">

    <!-- List Panel -->
    <div class="list-panel">
      <div class="list-panel-inner">
        <div class="list-panel-header">
          <h5 class="fw-bold mb-0">
            <i class="bi bi-geo-alt-fill me-1 text-primary"></i> Lokasi Alsintan
          </h5>
        </div>

        <div class="list-panel-filters">
          <input v-model="searchQuery" type="text" class="form-control bg-light border-0" placeholder="Cari nama / kode alat...">

          <div class="d-flex w-100 gap-2 flex-wrap">
            <input type="radio" class="btn-check" name="btnradio" id="btnAll" value="ALL" v-model="filterStatus">
            <label class="btn btn-outline-primary btn-sm rounded-pill flex-fill shadow-sm fw-bold px-0" for="btnAll" style="font-size: 11px; padding-block: 6px;">Semua</label>

            <input type="radio" class="btn-check" name="btnradio" id="btnOn" value="ON" v-model="filterStatus">
            <label class="btn btn-outline-success btn-sm rounded-pill flex-fill shadow-sm fw-bold px-0" for="btnOn" style="font-size: 11px; padding-block: 6px;">Kerja</label>

            <input type="radio" class="btn-check" name="btnradio" id="btnOff" value="OFF" v-model="filterStatus">
            <label class="btn btn-outline-dark btn-sm rounded-pill flex-fill shadow-sm fw-bold px-0" for="btnOff" style="font-size: 11px; padding-block: 6px;">Parkir</label>

            <input type="radio" class="btn-check" name="btnradio" id="btnOffline" value="OFFLINE" v-model="filterStatus">
            <label class="btn btn-outline-danger btn-sm rounded-pill flex-fill shadow-sm fw-bold px-0" for="btnOffline" style="font-size: 11px; padding-block: 6px;">Offline</label>
          </div>
        </div>

        <div class="list-panel-body custom-scrollbar">
          <div v-if="loading" class="text-center py-4 text-muted"><div class="spinner-border spinner-border-sm"></div> Memuat...</div>

          <div v-else-if="filteredAlsintan.length === 0" class="text-center py-4 text-muted small">
            Tidak ada armada yang sesuai filter.
          </div>

          <div v-for="alat in filteredAlsintan" :key="alat.alsintan_id"
              @click="goToDetail(alat.alsintan_id)"
              class="card border-0 shadow-sm mb-2 alat-card">
            <div class="card-body p-3 d-flex align-items-center">
              <div class="me-3 position-relative">
                <div class="rounded-circle d-flex align-items-center justify-content-center bg-light" style="width: 40px; height: 40px;">
                  <i class="bi bi-truck-front fs-5 text-secondary"></i>
                </div>
                <span class="position-absolute bottom-0 end-0 p-1 border border-white rounded-circle"
                    :class="getDotClass(alat.status_iot, alat.status_mesin)"
                    style="width: 14px; height: 14px;"></span>
              </div>
              <div class="flex-grow-1">
                <h6 class="mb-0 fw-bold">{{ alat.kode_perangkat }}</h6>
                <small class="text-muted" style="font-size: 11px;">
                  {{ alat.nama_alat }} <br>
                  <span v-if="alat.status_iot !== 'ON'" class="text-danger"><i class="bi bi-wifi-off"></i> Offline / Sinyal Hilang</span>
                  <span v-else-if="alat.status_mesin === 'OFF'" class="text-dark"><i class="bi bi-pause-circle"></i> Mesin Parkir</span>
                </small>
              </div>
              <i class="bi bi-chevron-right text-muted opacity-50"></i>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Map -->
    <div class="map-panel">
      <div id="main-map" style="height: 100%; width: 100%;"></div>
    </div>

  </div>
</template>

<style scoped>
.monitoring-container {
  position: relative;
  height: calc(100vh - var(--topbar-height) - 3rem);
  border-radius: 12px;
  overflow: hidden;
  box-shadow: 0 4px 15px rgba(0,0,0,0.05);
}

/* ── Map fills entire container ── */
.map-panel {
  position: absolute;
  top: 0; left: 0; right: 0; bottom: 0;
  background: #1e293b;
}

/* ── Mobile toggle button ── */

/* ── List Panel base (desktop sidebar) ── */
.list-panel {
  position: absolute;
  top: 0; bottom: 0; left: 0;
  width: 380px;
  background: white;
  border-right: 1px solid #e5e7eb;
  z-index: 700;
  display: flex;
  flex-direction: column;
}

.list-panel-inner {
  display: flex;
  flex-direction: column;
  height: 100%;
}

.list-panel-header {
  padding: 1rem 1rem 0.75rem;
  border-bottom: 1px solid #e5e7eb;
  display: flex;
  justify-content: space-between;
  align-items: center;
  flex-shrink: 0;
}

.list-panel-filters {
  padding: 0.75rem 1rem;
  border-bottom: 1px solid #e5e7eb;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  flex-shrink: 0;
}

.list-panel-body {
  flex: 1;
  overflow-y: auto;
  padding: 0.5rem;
}

/* ── Desktop: sidebar offset ── */
@media (min-width: 768px) {
  .map-panel {
    left: 380px;
  }
}

/* ── Mobile: susun vertikal seperti Beranda (semua konten tampil, tanpa overlay) ── */
@media (max-width: 767.98px) {
  .monitoring-container {
    height: auto;
    display: flex;
    flex-direction: column;
    gap: 1rem;
    overflow: visible;
    box-shadow: none;
  }

  .list-panel {
    position: static;
    width: 100%;
    transform: none;
    z-index: auto;
    border: 1px solid #e5e7eb;
    border-radius: 16px;
    box-shadow: 0 4px 20px rgba(0, 0, 0, 0.04);
    overflow: hidden;
  }

  .list-panel-body {
    overflow: visible;
    max-height: none;
  }

  .map-panel {
    position: static;
    height: 40vh;
    min-height: 300px;
    border-radius: 16px;
    overflow: hidden;
  }
}

/* ── Card interaction ── */
.alat-card {
  transition: all 0.2s;
  border: 1px solid transparent !important;
  cursor: pointer;
}
.alat-card:hover {
  border-color: #0d6efd !important;
  background-color: #f8f9fa;
  transform: translateX(4px);
}

/* ── Scrollbar ── */
.custom-scrollbar::-webkit-scrollbar { width: 6px; }
.custom-scrollbar::-webkit-scrollbar-track { background: transparent; }
.custom-scrollbar::-webkit-scrollbar-thumb { background: #dee2e6; border-radius: 4px; }
.custom-scrollbar::-webkit-scrollbar-thumb:hover { background: #adb5bd; }

/* ── Marker icon & pulse ── */
.custom-tractor-icon { background: transparent; border: none; }
.pulse-ring {
  position: absolute;
  top: 50%; left: 50%;
  transform: translate(-50%, -50%);
  width: 36px; height: 36px;
  border-radius: 50%;
  border: 2px solid #198754;
  animation: mapPulse 1.5s infinite;
  z-index: -1;
}
@keyframes mapPulse {
  0% { width: 36px; height: 36px; opacity: 1; }
  100% { width: 70px; height: 70px; opacity: 0; }
}
</style>
