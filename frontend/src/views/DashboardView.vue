<script setup>
import { ref, onMounted, onUnmounted, computed, nextTick } from 'vue';
import axios from 'axios';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { useRouter } from 'vue-router';
import mqtt from 'mqtt';
import 'leaflet.markercluster/dist/MarkerCluster.css';
import 'leaflet.markercluster/dist/MarkerCluster.Default.css';
import 'leaflet.markercluster';

const router = useRouter();
const items = ref([]); 
const loading = ref(true);
const selectedAlat = ref(null);

let map = null;
let markers = {}; 
let markerClusterGroup = null;
let mqttClient = null;
let chartInstance = null;

const MQTT_HOST = import.meta.env.VITE_MQTT_HOST;
const MQTT_PORT = Number(import.meta.env.VITE_MQTT_PORT);
const MQTT_TOPIC = import.meta.env.VITE_MQTT_TOPIC;
const MQTT_USERNAME = import.meta.env.VITE_MQTT_USERNAME;
const MQTT_PASSWORD = import.meta.env.VITE_MQTT_PASSWORD;

// --- 1. FETCH DATA UTAMA ---
const fetchData = async () => {
  try {
    const response = await axios.get(`${import.meta.env.VITE_API_BASE_URL}/alsintan`);
    items.value = Array.isArray(response.data) ? response.data : [];
  } catch (error) {
    console.error("Gagal load dashboard:", error);
  } finally {
    loading.value = false;
    await nextTick();
    initGlobalMap();
    initChart(); 
    connectMqtt();
  }
};

// --- 2. LOGIKA STATISTIK ---
const totalAset = computed(() => items.value.length);
const totalLive = computed(() => items.value.filter(i => i.status_mesin === 'ON').length);

const totalLuasLahanGlobal = computed(() => {
    const totalJarakMeter = items.value.reduce((sum, item) => {
        return sum + (parseFloat(item.total_jarak_kerja) || 0);
    }, 0);
    return (totalJarakMeter / 10000).toFixed(3); 
});

const warningList = computed(() => {
    return items.value.filter(item => {
        const aki = parseFloat(item.tegangan_aki) || 0;
        const isRusak = item.status_operasional === 'Rusak' || item.status_operasional === 'Maintenance';
        const isAkiLemah = aki > 0 && aki < 11.5; 
        return isRusak || isAkiLemah;
    });
});

// --- 3. MQTT ---
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
            const index = items.value.findIndex(i => i.alsintan_id == data.id);
            if (index !== -1) {
                const tegangan = parseFloat(data.V) || 0;
                const statusMesinBaru = tegangan >= 12.8 ? 'ON' : 'OFF'; 
                const lat = parseFloat(data.lat);
                const long = parseFloat(data.long || data.lng);

                items.value[index].status_mesin = statusMesinBaru;
                items.value[index].latitude = lat;
                items.value[index].longitude = long;
                items.value[index].tegangan_aki = tegangan; 
                items.value[index].arus = parseFloat(data.I) || 0;
                items.value[index].hdop = parseInt(data.hd) || 0;
                items.value[index].satelit = parseInt(data.st) || 0;
                
                if (selectedAlat.value && selectedAlat.value.alsintan_id == data.id) {
                    selectedAlat.value = items.value[index];
                }

                if (lat !== 0 && long !== 0 && !isNaN(lat)) {
                    updateMarker(data.id, lat, long, statusMesinBaru);
                }
                initChart(); 
            }
        } catch (err) {}
    });
};

// --- 4. MAPS LEAFLET ---
const initGlobalMap = () => {
    if (map) return;
    const container = document.getElementById('global-map');
    if (!container) return;

    map = L.map('global-map', { zoomControl: false }).setView([-6.9175, 107.6191], 10);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', { attribution: '&copy; OpenStreetMap' }).addTo(map);
    L.control.zoom({ position: 'bottomright' }).addTo(map);

    container._resizeObserver = new ResizeObserver(() => { if (map) map.invalidateSize(); });
    container._resizeObserver.observe(container);

    markerClusterGroup = L.markerClusterGroup({
        maxClusterRadius: 50,
        spiderfyOnMaxZoom: true,
        showCoverageOnHover: false,
        zoomToBoundsOnClick: true,
        disableClusteringAtZoom: 16
    });
    map.addLayer(markerClusterGroup);

    items.value.forEach(alat => {
        if (alat.latitude && alat.longitude) {
            addMarkerToCluster(alat);
        }
    });

    const group = items.value.filter(a => a.latitude && a.longitude).map(a => [a.latitude, a.longitude]);
    if (group.length > 0) map.fitBounds(group, { padding: [30, 30] });

    setTimeout(() => { if (map) map.invalidateSize(); }, 300);
};

const createMarkerIcon = (alat) => {
    const colorClass = alat.status_mesin === 'ON' ? 'text-success' : 'text-secondary';
    const bgClass = alat.status_mesin === 'ON' ? 'bg-success bg-opacity-10' : 'bg-light';
    const borderClass = alat.status_mesin === 'ON' ? 'border-success' : 'border-secondary';

    return L.divIcon({
        className: 'custom-tractor-icon',
        html: `
          <div class="d-flex justify-content-center align-items-center rounded-circle border border-2 ${borderClass} ${bgClass} shadow-sm" 
               style="width: 32px; height: 32px; background-color: white;">
               <img src="/ikon-traktor.png" style="width: 20px; height: 20px; object-fit: contain;">
          </div>
          ${alat.status_mesin === 'ON' ? '<div class="pulse-ring"></div>' : ''} 
        `,
        iconSize: [32, 32],
        iconAnchor: [16, 16],
        popupAnchor: [0, -20]
    });
};

const addMarkerToCluster = (alat) => {
    const lat = parseFloat(alat.latitude);
    const lng = parseFloat(alat.longitude);
    const colorClass = alat.status_mesin === 'ON' ? 'text-success' : 'text-secondary';

    const marker = L.marker([lat, lng], { icon: createMarkerIcon(alat) })
        .bindPopup(`<b>${alat.nama_alat}</b><br>
                    Status: <b class="${colorClass}">${alat.status_mesin}</b><br>
                    Lat: ${lat.toFixed(4)}, Long: ${lng.toFixed(4)}`)
        .on('click', () => { selectedAlat.value = alat; });

    markers[alat.alsintan_id] = marker;
    markerClusterGroup.addLayer(marker);
};

const updateMarker = (id, lat, lng, status) => {
    const marker = markers[id];
    if (marker) {
        marker.setLatLng([lat, lng]);
        marker.setIcon(createMarkerIcon({ status_mesin: status }));
        const popupContent = marker.getPopup().getContent();
        const colorClass = status === 'ON' ? 'text-success' : 'text-secondary';
        marker.setPopupContent(popupContent.replace(/Status: <b class=".*?">.*?<\/b>/, `Status: <b class="${colorClass}">${status}</b>`));
    }
};

// --- 5. CHART.JS ---
const initChart = () => {
    const ctx = document.getElementById('statusChart');
    if (!ctx || typeof Chart === 'undefined') return;
    
    const beroperasi = items.value.filter(i => i.status_mesin === 'ON').length;
    const parkir = items.value.filter(i => i.status_mesin === 'OFF' && (i.status_operasional || '').includes('Siap')).length;
    const maintenance = items.value.filter(i => i.status_operasional === 'Maintenance').length;
    const rusak = items.value.filter(i => i.status_operasional === 'Rusak').length;
    const newData = [beroperasi, parkir, maintenance, rusak];

    if (chartInstance) {
        const oldData = chartInstance.data.datasets[0].data;
        if (JSON.stringify(oldData) !== JSON.stringify(newData)) {
            chartInstance.data.datasets[0].data = newData;
            chartInstance.update(); 
        }
    } else {
        chartInstance = new Chart(ctx, {
            type: 'doughnut',
            data: {
                labels: ['Sedang Beroperasi', 'Parkir (Siap)', 'Maintenance', 'Rusak'],
                datasets: [{
                    data: newData,
                    backgroundColor: ['#198754', '#6c757d', '#ffc107', '#dc3545'],
                    hoverOffset: 4, borderWidth: 0
                }]
            },
            options: {
                responsive: true, maintainAspectRatio: false, animation: false,
                plugins: { legend: { position: 'bottom', labels: { usePointStyle: true, padding: 20 } } },
                cutout: '78%'
            }
        });
    }
};

const goToDetail = (id) => router.push({ name: 'monitoring-detail', params: { id } });

onMounted(() => { fetchData(); });
onUnmounted(() => { 
    const container = document.getElementById('global-map');
    if (container && container._resizeObserver) container._resizeObserver.disconnect();
    if (mqttClient) mqttClient.end(); 
    if (map) { map.remove(); map = null; }
});
</script>

<template>
  <div class="container-fluid d-flex flex-column pb-1" style="height: calc(100vh - var(--topbar-height) - 3rem);">
    
    <!-- Summary Cards -->
    <div class="flex-shrink-0 mb-3">
        <div v-if="loading" class="stats-grid">
            <div v-for="i in 4" :key="i" class="card border-0 shadow-sm h-100"><div class="card-body py-3 text-center"><div class="spinner-border spinner-border-sm text-muted"></div></div></div>
        </div>
        <div v-else class="stats-grid">
            <div class="card border-0 shadow-sm bg-primary text-white h-100">
                <div class="card-body py-2"><h6 class="text-white-50 mb-1">Total Armada</h6><h3 class="fw-bold mb-0">{{ totalAset }} <small class="fs-6">Unit</small></h3></div>
            </div>
            <div class="card border-0 shadow-sm bg-success text-white h-100 overflow-hidden position-relative">
                <div class="card-body py-2"><h6 class="text-white-50 mb-1">Sedang Aktif</h6><h3 class="fw-bold mb-0">{{ totalLive }} <small class="fs-6">Unit</small></h3></div>
            </div>
            <div class="card border-0 shadow-sm bg-info text-white h-100 position-relative overflow-hidden">
                <div class="card-body py-2"><h6 class="text-white-50 mb-1">Total Cakupan Lahan</h6><h3 class="fw-bold mb-0">{{ totalLuasLahanGlobal }} <small class="fs-6">Ha</small></h3></div>
            </div>
            <div class="card border-0 shadow-sm h-100 bg-danger text-white">
                <div class="card-body py-2"><h6 class="text-white-50 mb-1">Perlu Perhatian</h6><h3 class="fw-bold mb-0">{{ warningList.length }} <small class="fs-6">Isu</small></h3></div>
            </div>
        </div>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="text-center py-5 flex-grow-1">
        <div class="spinner-border text-primary"></div>
    </div>

    <!-- Content: Map + Panel -->
    <div v-else class="dashboard-content flex-grow-1 overflow-auto custom-scrollbar">
        
        <!-- Map Section -->
        <div class="dashboard-map-section">
            <div class="card border-0 shadow-sm h-100 d-flex flex-column">
                <div class="card-header bg-white fw-bold py-2 d-flex justify-content-between align-items-center flex-shrink-0">
                    <span><i class="bi bi-map me-2"></i> Sebaran Armada</span>
                    <span class="badge bg-success" v-if="totalLive > 0"><i class="bi bi-broadcast"></i> Live</span>
                </div>
                <div class="card-body p-0 flex-grow-1 position-relative">
                    <div id="global-map" style="height: 100%; width: 100%;"></div>
                </div>
            </div>
        </div>

        <!-- Panel Section: Chart + Telemetry + Warnings (3-col grid, stacks on mobile) -->
        <div class="dashboard-panel-section">
            <div class="row g-3">
                
                <!-- Chart -->
                <div class="col-md-4">
                    <div class="card border-0 shadow-sm h-100">
                        <div class="card-header bg-white fw-bold py-2"><i class="bi bi-pie-chart-fill me-2 text-primary"></i> Rasio Kondisi Fisik</div>
                        <div class="card-body py-2">
                            <div style="height: 160px; position: relative;">
                                <canvas id="statusChart"></canvas>
                                <div class="position-absolute start-50 translate-middle text-center" style="top: 28%; pointer-events: none;">
                                    <div class="fw-bolder big-number" style="font-size: 2.2rem; color: #1e293b; line-height: 1;">{{ totalAset }}</div>
                                    <div class="text-uppercase fw-bold mt-0" style="font-size: 0.6rem; color: #94a3b8; letter-spacing: 2px;">Unit</div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Telemetry -->
                <div class="col-md-4">
                    <div class="card border-0 shadow-sm h-100">
                        <div class="card-header bg-dark text-white fw-bold py-2 small d-flex justify-content-between align-items-center">
                            <span><i class="bi bi-speedometer2 me-1 text-info"></i> Telemetri Live</span>
                            <span class="badge bg-secondary" v-if="!selectedAlat">Standby</span>
                            <span class="badge bg-primary" v-else>{{ selectedAlat.kode_perangkat }}</span>
                        </div>
                        <div class="card-body p-3 d-flex flex-column justify-content-center align-items-center" v-if="!selectedAlat">
                            <i class="bi bi-cursor-fill fs-3 text-muted opacity-50 mb-2"></i>
                            <span class="text-muted small text-center px-3">Pilih unit pada peta untuk memantau performa mesin.</span>
                        </div>
                        <div class="card-body p-3 d-flex flex-column justify-content-center" v-else>
                            <div class="row g-0">
                                <div class="col-6 border-end text-center px-2">
                                    <small class="text-muted fw-bold d-block mb-2" style="font-size: 11px; letter-spacing: 1px;">VOLTASE AKI</small>
                                    <span class="fw-bolder" :class="selectedAlat.tegangan_aki < 11.5 ? 'text-danger' : 'text-success'" style="font-size: 1.75rem; line-height: 1;">
                                        {{ selectedAlat.tegangan_aki }}<span class="fs-6 fw-normal ms-1 text-muted">V</span>
                                    </span>
                                </div>
                                <div class="col-6 text-center px-2">
                                    <small class="text-muted fw-bold d-block mb-2" style="font-size: 11px; letter-spacing: 1px;">ARUS BEBAN</small>
                                    <span class="fw-bolder text-info" style="font-size: 1.75rem; line-height: 1;">
                                        {{ selectedAlat.arus }}<span class="fs-6 fw-normal ms-1 text-muted">mA</span>
                                    </span>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Warnings -->
                <div class="col-md-4">
                    <div class="card border-0 shadow-sm h-100 d-flex flex-column">
                        <div class="card-header bg-danger text-white fw-bold py-2 small d-flex justify-content-between align-items-center">
                            <span><i class="bi bi-exclamation-triangle-fill me-1"></i> Log Peringatan</span>
                            <span class="badge bg-white text-danger">{{ warningList.length }}</span>
                        </div>
                        <div class="card-body p-0 overflow-auto custom-scrollbar flex-grow-1" style="max-height: 200px;">
                            <ul class="list-group list-group-flush">
                                <li v-for="w in warningList" :key="w.alsintan_id" 
                                    class="list-group-item d-flex justify-content-between align-items-center list-group-item-action"
                                    @click="goToDetail(w.alsintan_id)" style="cursor: pointer;">
                                    <div>
                                        <div class="fw-bold text-danger" style="font-size: 12px;">{{ w.nama_alat }}</div>
                                        <small class="text-muted" style="font-size:10px;">
                                            Aki: <span :class="w.tegangan_aki < 11.5 ? 'text-danger fw-bold' : ''">{{ w.tegangan_aki }}V</span> | {{ w.status_operasional }}
                                        </small>
                                    </div>
                                    <i class="bi bi-chevron-right text-muted small"></i>
                                </li>
                                <li v-if="warningList.length === 0" class="list-group-item text-center text-muted py-3 border-0">
                                    <i class="bi bi-check-circle text-success fs-4 d-block mb-1"></i>
                                    <small>Sistem aman</small>
                                </li>
                            </ul>
                        </div>
                    </div>
                </div>

            </div>
        </div>
    </div>
  </div>
</template>

<style scoped>
.dashboard-content {
    display: flex;
    flex-direction: column;
    gap: 1rem;
}

.dashboard-map-section {
    flex-shrink: 0;
}

.dashboard-map-section .card {
    height: 50vh;
    min-height: 300px;
}

.dashboard-panel-section {
    flex-shrink: 0;
}

/* Desktop: map gets more space */
@media (min-width: 1200px) {
    .dashboard-map-section .card {
        height: 60vh;
        min-height: 400px;
    }
}

/* Mobile: compact stats don't dominate — map flexes to fill first screen */
@media (max-width: 767.98px) {
    .dashboard-map-section {
        display: flex;
        flex-direction: column;
        flex: 1;
        min-height: 45vh;
    }
    .dashboard-map-section .card {
        flex: 1;
        height: auto;
    }
}

.custom-tractor-icon { background: transparent; border: none; }
.pulse-ring {
    position: absolute;
    top: 50%; left: 50%;
    transform: translate(-50%, -50%);
    width: 32px; height: 32px;
    border-radius: 50%;
    border: 2px solid #198754;
    animation: mapPulse 1.5s infinite;
    z-index: -1;
}
@keyframes mapPulse {
    0% { width: 32px; height: 32px; opacity: 1; }
    100% { width: 60px; height: 60px; opacity: 0; }
}

.custom-scrollbar::-webkit-scrollbar { width: 4px; }
.custom-scrollbar::-webkit-scrollbar-thumb { background: #dee2e6; border-radius: 4px; }
</style>
