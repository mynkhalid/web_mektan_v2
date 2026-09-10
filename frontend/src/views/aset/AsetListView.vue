<script setup>
import { ref, computed, onMounted, onUnmounted } from 'vue';
import axios from 'axios';
import { useRouter } from 'vue-router';
import Swal from 'sweetalert2';
import { loading as showLoadingAlert, success, error } from '../../utils/feedback';
import mqtt from 'mqtt';

const IMAGE_BASE_URL = import.meta.env.VITE_IMAGE_BASE_URL;
const MQTT_HOST = import.meta.env.VITE_MQTT_HOST;
const MQTT_PORT = Number(import.meta.env.VITE_MQTT_PORT);
const MQTT_TOPIC = import.meta.env.VITE_MQTT_TOPIC;
const MQTT_USERNAME = import.meta.env.VITE_MQTT_USERNAME;
const MQTT_PASSWORD = import.meta.env.VITE_MQTT_PASSWORD;

const router = useRouter();
const items = ref([]);
const loading = ref(true);
const userRole = ref('');

// P1: Filter cepat + indikator geser tabel
const searchQuery = ref('');
const tableScroll = ref({ left: false, right: true });

const filteredItems = computed(() => {
    const q = searchQuery.value.trim().toLowerCase();
    if (!q) return items.value;
    return items.value.filter(item =>
        (item.nama_alat || '').toLowerCase().includes(q) ||
        (item.kode_perangkat || '').toLowerCase().includes(q) ||
        (item.nomor_seri || '').toLowerCase().includes(q)
    );
});

const onTableScroll = (e) => {
    const el = e.target;
    tableScroll.value.left = el.scrollLeft > 24;
    tableScroll.value.right = el.scrollLeft + el.clientWidth < el.scrollWidth - 24;
};

let mqttClient = null;

const fetchData = async () => {
    try {
        const response = await axios.get(`${import.meta.env.VITE_API_BASE_URL}/alsintan`);
        items.value = response.data;
    } catch (error) {
        console.error("Gagal mengambil data:", error);
    } finally {
        loading.value = false;
    }
};

const getTractorClass = (status) => {
    if (status === 'ON') return 'bg-success text-white animate-pulse shadow-sm';
    if (status === 'OFF') return 'bg-dark text-white-50';
    return 'bg-secondary text-white';
};

const connectMqtt = () => {
    const options = { host: MQTT_HOST, port: MQTT_PORT, protocol: 'wss', path: '/mqtt', username: MQTT_USERNAME, password: MQTT_PASSWORD };
    mqttClient = mqtt.connect(options);
    
    mqttClient.on('connect', () => { mqttClient.subscribe(MQTT_TOPIC); });

    mqttClient.on('message', (topic, message) => {
        try {
            const data = JSON.parse(message.toString());
            const targetIndex = items.value.findIndex(item => item.alsintan_id == data.id);
            if (targetIndex !== -1) {
                const vAki = parseFloat(data.V) || 0;
                let statusBaru = items.value[targetIndex].status_mesin;
                if (vAki > 13.4) statusBaru = 'ON';
                else if (vAki < 13.0) statusBaru = 'OFF';
                items.value[targetIndex].status_mesin = statusBaru;
            }
        } catch (err) {}
    });
};

const goToAdd = () => router.push({ name: 'aset-add' });
const goToEdit = (id) => router.push({ name: 'aset-edit', params: { id } });
const goToDetail = (id) => router.push({ name: 'aset-detail', params: { id } });
const goToMonitoring = (id) => router.push({ name: 'monitoring-detail', params: { id } });

// =====================================================================
// [DIPERBARUI] FORMULIR PENGAJUAN (DROPDOWN API + TITLE CASE + HYBRID DESA)
// =====================================================================
const ajukanPinjaman = async (item) => {
    const session = JSON.parse(sessionStorage.getItem('user')) || {};
    const namaAkunUPJA = session.nama || session.nama_lengkap || session.username || '';

    // Fungsi Pengubah Huruf Kapital menjadi Title Case (Huruf depan besar)
    const toTitleCase = (str) => {
        return str.toLowerCase().split(' ').map(word => {
            return word.charAt(0).toUpperCase() + word.slice(1);
        }).join(' ');
    };

    const { value: formValues } = await Swal.fire({
        title: `Form Reservasi Alsintan<br><span class="text-primary fs-5">${item.nama_alat}</span>`,
        html: `
            <div class="text-start" style="font-size: 0.9rem;">
                <div class="alert alert-info py-2 small mb-3">
                    <i class="bi bi-info-circle-fill me-1"></i>Mektan akan memverifikasi jadwal dan menghubungi No. WhatsApp Anda
                </div>
                
                <div class="row g-2 mb-2">
                    <div class="col-12 col-sm-6"><label class="fw-bold small">Rencana Mulai <span class="text-danger">*</span></label><input type="date" id="swal-mulai" class="form-control form-control-sm" required></div>
                    <div class="col-12 col-sm-6"><label class="fw-bold small">Rencana Selesai <span class="text-danger">*</span></label><input type="date" id="swal-akhir" class="form-control form-control-sm" required></div>
                </div>
                <hr class="my-2">
                
                <div class="mb-2">
                    <label class="fw-bold small text-primary"> Poktan/Gapoktan/UPJA/Petani <span class="text-danger">*</span></label>
                    <input type="text" id="swal-poktan" class="form-control form-control-sm bg-light text-muted fw-bold" value="${namaAkunUPJA}" readonly>
                </div>

                <div class="mb-2">
                    <label class="fw-bold small text-primary">Nama Individu Penanggung Jawab <span class="text-danger">*</span></label>
                    <input type="text" id="swal-nama" class="form-control form-control-sm" placeholder="Sesuai KTP (Misal: Ujang)" required>
                </div>

                <div class="row g-2 mb-2">
                    <div class="col-12 col-sm-6"><label class="fw-bold small text-primary">Jabatan</label><input type="text" id="swal-jabatan" class="form-control form-control-sm" placeholder="Misal: Operator"></div>
                    <div class="col-12 col-sm-6"><label class="fw-bold small text-primary">WhatsApp Aktif <span class="text-danger">*</span></label><input type="text" id="swal-kontak" class="form-control form-control-sm" placeholder="08..." required></div>
                </div>
                
                <hr class="my-2">
                
                <div class="row g-2 mb-2">
                    <div class="col-12 mb-1">
                        <label class="fw-bold small text-success">Kabupaten/Kota (Jawa Barat) <span class="text-danger">*</span></label>
                        <select id="swal-kab" class="form-select form-select-sm border-success"><option value="">Memuat data...</option></select>
                    </div>
                    <div class="col-12 col-sm-6">
                        <label class="fw-bold small text-success">Kecamatan <span class="text-danger">*</span></label>
                        <select id="swal-kec" class="form-select form-select-sm border-success" disabled><option value="">Pilih Kab/Kota dahulu</option></select>
                    </div>
                    <div class="col-12 col-sm-6">
                        <label class="fw-bold small text-success">Desa/Kelurahan Utama <span class="text-danger">*</span></label>
                        <select id="swal-desa" class="form-select form-select-sm border-success" disabled><option value="">Pilih Kecamatan dahulu</option></select>
                        
                        <!-- [BARU] Input Text Rahasia jika Desa tidak ada / Lebih dari 1 -->
                        <input type="text" id="swal-desa-custom" class="form-control form-control-sm border-primary mt-1 d-none" placeholder="Ketik nama desa / desa lainnya...">
                    </div>
                </div>
            </div>
        `,
        width: '600px',
        focusConfirm: false,
        showCancelButton: true,
        confirmButtonText: '<i class="bi bi-send-fill"></i> Kirim Pengajuan',
        cancelButtonText: 'Batal',
        confirmButtonColor: '#198754',
        
        didOpen: async () => {
            const kabSelect = document.getElementById('swal-kab');
            const kecSelect = document.getElementById('swal-kec');
            const desaSelect = document.getElementById('swal-desa');
            const desaCustom = document.getElementById('swal-desa-custom'); // Referensi input rahasia

            // 1. Tarik Data Kabupaten (ID Jabar = 32)
            try {
                const res = await fetch('https://www.emsifa.com/api-wilayah-indonesia/api/regencies/32.json');
                const kabs = await res.json();
                kabSelect.innerHTML = '<option value="">-- Pilih Kabupaten/Kota --</option>' + 
                    kabs.map(k => `<option value="${k.id}">${toTitleCase(k.name)}</option>`).join('');
            } catch (e) {
                kabSelect.innerHTML = '<option value="">Gagal memuat data API</option>';
            }

            // 2. Saat Kabupaten Dipilih -> Tarik Data Kecamatan
            kabSelect.addEventListener('change', async (e) => {
                const kabId = e.target.value;
                kecSelect.innerHTML = '<option value="">Memuat...</option>';
                kecSelect.disabled = true;
                desaSelect.innerHTML = '<option value="">Pilih Kecamatan dahulu</option>';
                desaSelect.disabled = true;
                desaCustom.classList.add('d-none'); // Sembunyikan input custom

                if (!kabId) return;

                try {
                    const res = await fetch(`https://www.emsifa.com/api-wilayah-indonesia/api/districts/${kabId}.json`);
                    const kecs = await res.json();
                    kecSelect.innerHTML = '<option value="">-- Pilih Kecamatan --</option>' + 
                        kecs.map(k => `<option value="${k.id}">${toTitleCase(k.name)}</option>`).join('');
                    kecSelect.disabled = false;
                } catch (e) {}
            });

            // 3. Saat Kecamatan Dipilih -> Tarik Data Desa
            kecSelect.addEventListener('change', async (e) => {
                const kecId = e.target.value;
                desaSelect.innerHTML = '<option value="">Memuat...</option>';
                desaSelect.disabled = true;
                desaCustom.classList.add('d-none');

                if (!kecId) return;

                try {
                    const res = await fetch(`https://www.emsifa.com/api-wilayah-indonesia/api/villages/${kecId}.json`);
                    const desas = await res.json();
                    
                    let options = '<option value="">-- Pilih Desa/Kelurahan --</option>';
                    options += desas.map(d => `<option value="${d.id}">${toTitleCase(d.name)}</option>`).join('');
                    
                    // [BARU] Tambahkan opsi manual di paling bawah
                    options += '<option value="lainnya" class="fw-bold text-primary">Lainnya</option>';
                    
                    desaSelect.innerHTML = options;
                    desaSelect.disabled = false;
                } catch (e) {}
            });

            // 4. [BARU] Logika memunculkan Input Text Rahasia
            desaSelect.addEventListener('change', (e) => {
                if (e.target.value === 'lainnya') {
                    desaCustom.classList.remove('d-none'); // Tampilkan input
                    desaCustom.focus();
                } else {
                    desaCustom.classList.add('d-none'); // Sembunyikan input
                    desaCustom.value = ''; // Kosongkan isinya
                }
            });
        },
        
        preConfirm: () => {
            const kabEl = document.getElementById('swal-kab');
            const kecEl = document.getElementById('swal-kec');
            const desaEl = document.getElementById('swal-desa');
            const desaCustomEl = document.getElementById('swal-desa-custom');

            const namaKab = kabEl.options[kabEl.selectedIndex]?.text || '';
            const namaKec = kecEl.options[kecEl.selectedIndex]?.text || '';
            let namaDesa = desaEl.options[desaEl.selectedIndex]?.text || '';

            // Jika milih "Lainnya", ambil nama desa dari ketikan manual pengguna
            if (desaEl.value === 'lainnya') {
                namaDesa = desaCustomEl.value.trim();
            }

            const data = {
                alsintan_id: item.alsintan_id,
                tanggal_mulai: document.getElementById('swal-mulai').value,
                tanggal_berakhir: document.getElementById('swal-akhir').value,
                nama_peminjam: document.getElementById('swal-nama').value,
                jabatan_peminjam: document.getElementById('swal-jabatan').value,
                kontak_peminjam: document.getElementById('swal-kontak').value,
                nama_kelompok: document.getElementById('swal-poktan').value,
                
                kabupaten: namaKab.includes('--') ? '' : namaKab,
                kecamatan: namaKec.includes('--') ? '' : namaKec,
                desa: namaDesa.includes('--') ? '' : namaDesa
            };
            
            if(!data.tanggal_mulai || !data.tanggal_berakhir || !data.nama_peminjam || !data.kontak_peminjam || !data.kabupaten || !data.kecamatan || !data.desa) {
                Swal.showValidationMessage('Isi semua kolom yang bertanda bintang (*), termasuk lokasi lengkap!');
                return false;
            }
            return data;
        }
    });

    if (formValues) {
        try {
            showLoadingAlert('Mengirim Pengajuan...', '');
            await axios.post(`${import.meta.env.VITE_API_BASE_URL}/pengajuan/public`, formValues);
            success('Terkirim!', 'Pengajuan Anda berhasil masuk antrean. Kami akan segera menghubungi nomor WA Anda.');
        } catch (error) {
            error('Gagal', error.response?.data?.message || 'Terjadi kesalahan server.');
        }
    }
};

const deleteItem = async (id) => {
    const confirm = await Swal.fire({
        title: 'Hapus Aset ini?',
        text: "Data yang dihapus tidak bisa dikembalikan!",
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: '#d33',
        cancelButtonColor: '#3085d6',
        confirmButtonText: 'Ya, Hapus!'
    });

    if (confirm.isConfirmed) {
        try {
            await axios.delete(`${import.meta.env.VITE_API_BASE_URL}/alsintan/${id}`);
            success('Terhapus!', 'Data aset telah dihapus.');
            fetchData();
        } catch (error) {
            error('Error', 'Gagal menghapus aset.');
        }
    }
};

onMounted(() => {
    const session = JSON.parse(sessionStorage.getItem('user'));
    if (session) userRole.value = session.role;
    fetchData();
    connectMqtt();
});

onUnmounted(() => {
    if (mqttClient) mqttClient.end();
});
</script>

<template>
    <div class="container-fluid pb-4">
        
        <div class="page-header">
            <div>
                <h2 class="fw-bold text-dark mb-0">Manajemen & Katalog Aset</h2>
                <small class="text-muted">Cek ketersediaan inventaris dan status operasional alsintan</small>
            </div>
            
            <div v-if="userRole === 'mektan'" class="page-header-actions">
                <button @click="router.push('/antrean')" class="btn btn-warning fw-bold shadow-sm">
                    <i class="bi bi-inboxes-fill"></i> Cek Antrean Masuk
                </button>
                <button @click="goToAdd" class="btn btn-primary fw-bold shadow-sm">
                    <i class="bi bi-plus-lg"></i> Tambah Aset Baru
                </button>
            </div>
        </div>

        <!-- P1: Pencarian cepat -->
        <div class="d-flex flex-wrap align-items-center gap-2 mb-3">
            <div class="input-group flex-grow-1" style="max-width: 420px;">
                <span class="input-group-text bg-white"><i class="bi bi-search text-muted"></i></span>
                <input v-model="searchQuery" type="text" class="form-control" placeholder="Cari nama alat / kode / no. seri...">
            </div>
            <small class="text-muted fw-bold">{{ filteredItems.length }} dari {{ items.length }} unit</small>
        </div>

        <div v-if="loading" class="text-center py-5 my-5">
            <div class="spinner-border text-primary" role="status"></div>
            <p class="mt-2 text-muted fw-bold">Memuat inventaris...</p>
        </div>

        <!-- [MOBILE] Semua info tampil utuh tanpa scroll horizontal (seperti Beranda) -->
        <div v-if="!loading" class="d-md-none">
            <div v-for="item in filteredItems" :key="'card' + item.alsintan_id"
                 class="card border-0 shadow-sm mb-3 overflow-hidden">
                <div class="card-body p-3">
                    <div class="d-flex gap-3">
                        <div class="position-relative">
                            <img :src="item.gambar && item.gambar.startsWith('http') ? item.gambar : `${IMAGE_BASE_URL}/${item.gambar}`"
                                 class="rounded object-fit-cover shadow-sm transition-img"
                                 :class="{'grayscale-dim': item.status_ketersediaan === 'Sedang Dipinjam'}"
                                 style="width: 64px; height: 64px;"
                                 @error="$event.target.src='https://via.placeholder.com/150'">
                            <span class="position-absolute top-0 start-100 translate-middle p-2 border border-2 border-white rounded-circle shadow-sm"
                                  :class="item.status_ketersediaan === 'Tersedia di Balai' ? 'bg-success' : 'bg-warning'">
                            </span>
                        </div>
                        <div class="flex-grow-1" style="min-width: 0;">
                            <h6 class="fw-bold text-dark mb-1" :class="{'text-muted': item.status_ketersediaan === 'Sedang Dipinjam'}">
                                {{ item.nama_alat }}
                            </h6>
                            <div class="d-flex flex-wrap gap-2 align-items-center mb-1">
                                <span v-if="item.status_ketersediaan === 'Tersedia di Balai'" class="badge bg-success bg-opacity-10 text-success border border-success" style="font-size: 0.65rem;">
                                    <i class="bi bi-building-check me-1"></i>TERSEDIA
                                </span>
                                <span v-else-if="item.status_ketersediaan === 'Sedang Dipinjam'" class="badge bg-warning bg-opacity-10 text-warning-emphasis border border-warning" style="font-size: 0.65rem;">
                                    <i class="bi bi-signpost-2-fill me-1"></i>DIPINJAM
                                </span>
                                <span v-else class="badge bg-secondary bg-opacity-10 text-secondary border border-secondary" style="font-size: 0.65rem;">
                                    {{ item.status_ketersediaan?.toUpperCase() || 'MAINTENANCE' }}
                                </span>
                                <span class="badge bg-light text-muted border border-secondary" style="font-size: 0.65rem;">
                                    <i class="bi bi-wrench-adjustable me-1"></i>{{ item.kondisi_fisik || 'Baik' }}
                                </span>
                            </div>
                            <small class="text-muted d-block" style="font-size: 0.75rem;">
                                {{ item.kategori_alat }} • {{ item.merk_alat || '-' }}
                            </small>
                        </div>
                    </div>

                    <hr class="my-3">

                    <div class="d-flex flex-wrap gap-2">
                        <span class="badge border border-primary text-primary px-2 py-1">
                            <i class="bi bi-qr-code me-1"></i>{{ item.kode_perangkat }}
                        </span>
                        <span class="badge bg-light text-muted border border-secondary px-2 py-1">
                            <i class="bi bi-cpu me-1"></i>SN: {{ item.nomor_seri || '-' }}
                        </span>
                        <span class="badge bg-light text-muted border border-secondary px-2 py-1">
                            <i class="bi bi-rulers me-1"></i>{{ item.kapasitas_lahan || '-' }} Ha/Hari
                        </span>
                        <span class="badge bg-light text-muted border border-secondary px-2 py-1">
                            <i class="bi bi-speedometer2 me-1"></i>{{ (parseFloat(item.total_jarak_kerja || 0) / 1000).toFixed(2) }} Km
                        </span>
                    </div>

                    <div class="d-flex flex-column gap-1 mt-2">
                        <span class="badge w-100 py-2 text-center" :class="getTractorClass(item.status_mesin)">
                            <i class="bi bi-power me-1"></i> MESIN: {{ item.status_mesin || 'OFF' }}
                        </span>
                    </div>
                </div>

                <div class="card-footer bg-white border-top p-3">
                    <div v-if="userRole === 'mektan'" class="row g-2">
                        <div class="col-6">
                            <button @click="goToDetail(item.alsintan_id)" class="btn btn-sm btn-outline-info btn-aksi w-100"><i class="bi bi-info-circle me-1"></i>Detail</button>
                        </div>
                        <div class="col-6">
                            <button @click="goToMonitoring(item.alsintan_id)" class="btn btn-sm btn-outline-primary btn-aksi w-100"><i class="bi bi-geo-alt-fill me-1"></i>Peta</button>
                        </div>
                        <div class="col-6">
                            <button @click="goToEdit(item.alsintan_id)" class="btn btn-sm btn-outline-warning btn-aksi w-100"><i class="bi bi-pencil-square me-1"></i>Edit</button>
                        </div>
                        <div class="col-6">
                            <button @click="deleteItem(item.alsintan_id)" class="btn btn-sm btn-outline-danger btn-aksi w-100"><i class="bi bi-trash me-1"></i>Hapus</button>
                        </div>
                    </div>

                    <div v-else-if="['upja', 'operator'].includes(userRole)" class="row g-2">
                        <div class="col-6">
                            <button @click="goToDetail(item.alsintan_id)" class="btn btn-sm btn-outline-info btn-aksi w-100"><i class="bi bi-info-circle me-1"></i>Detail</button>
                        </div>
                        <div class="col-6">
                            <button @click="goToMonitoring(item.alsintan_id)" class="btn btn-sm btn-outline-primary btn-aksi w-100"><i class="bi bi-geo-alt-fill me-1"></i>Peta</button>
                        </div>
                        <div v-if="item.status_ketersediaan === 'Tersedia di Balai' && userRole === 'upja'" class="col-12">
                            <button @click="ajukanPinjaman(item)" class="btn btn-sm btn-success btn-aksi w-100"><i class="bi bi-calendar-plus-fill me-1"></i>Booking Alat</button>
                        </div>
                    </div>

                    <div v-else>
                        <button @click="goToDetail(item.alsintan_id)" class="btn btn-sm btn-outline-info btn-aksi w-100"><i class="bi bi-info-circle me-1"></i>Lihat Detail</button>
                    </div>
                </div>
            </div>
        </div>

        <div v-if="!loading" class="card border-0 shadow-sm overflow-hidden d-none d-md-block">
            <div class="card-body p-0 position-relative">
                <div class="aset-table-wrap" @scroll="onTableScroll">
                    <table class="table table-hover align-middle mb-0 aset-table">
                        <thead class="bg-light text-muted small text-uppercase" style="letter-spacing: 0.5px;">
                            <tr>
                                <th class="ps-4 py-3">Aset & Ketersediaan</th>
                                <th class="text-center pe-5 py-3">ID / Mesin</th>
                                <th class="text-center pe-5 py-3">Kapasitas</th>
                                <th class="text-center pe-4 py-3">Status (IoT)</th>
                                <th class="text-center pe-4 py-3">Aksi</th>
                            </tr>
                        </thead>
                        <tbody>
                            <tr v-for="item in filteredItems" :key="item.alsintan_id" :class="{'bg-dipinjam': item.status_ketersediaan === 'Sedang Dipinjam'}">
                                
                                <td class="ps-4 py-3">
                                    <div class="d-flex align-items-center">
                                        <div class="position-relative me-3">
                                            <img :src="item.gambar && item.gambar.startsWith('http') ? item.gambar : `${IMAGE_BASE_URL}/${item.gambar}`" 
                                                 class="rounded object-fit-cover shadow-sm transition-img" 
                                                 :class="{'grayscale-dim': item.status_ketersediaan === 'Sedang Dipinjam'}"
                                                 style="width: 55px; height: 55px;"
                                                 @error="$event.target.src='https://via.placeholder.com/150'">
                                            
                                            <span class="position-absolute top-0 start-100 translate-middle p-2 border border-2 border-white rounded-circle shadow-sm"
                                                  :class="item.status_ketersediaan === 'Tersedia di Balai' ? 'bg-success' : 'bg-warning'">
                                            </span>
                                        </div>
                                        
                                        <div>
                                            <h6 class="fw-bold mb-1 text-dark" :class="{'text-muted': item.status_ketersediaan === 'Sedang Dipinjam'}">
                                                {{ item.nama_alat }}
                                            </h6>
                                            
                                            <div class="d-flex flex-wrap gap-2 align-items-center mb-1">
                                                <span v-if="item.status_ketersediaan === 'Tersedia di Balai'" class="badge bg-success bg-opacity-10 text-success border border-success" style="font-size: 0.65rem;">
                                                    <i class="bi bi-building-check me-1"></i>TERSEDIA
                                                </span>
                                                <span v-else-if="item.status_ketersediaan === 'Sedang Dipinjam'" class="badge bg-warning bg-opacity-10 text-warning-emphasis border border-warning" style="font-size: 0.65rem;">
                                                    <i class="bi bi-signpost-2-fill me-1"></i>DIPINJAM
                                                </span>
                                                <span v-else class="badge bg-secondary bg-opacity-10 text-secondary border border-secondary" style="font-size: 0.65rem;">
                                                    {{ item.status_ketersediaan?.toUpperCase() || 'MAINTENANCE' }}
                                                </span>

                                                <span class="badge bg-light text-muted border border-secondary" style="font-size: 0.65rem;">
                                                    <i class="bi bi-wrench-adjustable me-1"></i>{{ item.kondisi_fisik || 'Baik' }}
                                                </span>
                                            </div>
                                            
                                            <small class="text-muted d-block mt-1" style="font-size: 0.75rem;">
                                                {{ item.kategori_alat }} • {{ item.merk_alat || '-' }}
                                            </small>
                                        </div>
                                    </div>
                                </td>

                                <td class="text-center pe-5 py-3">
                                    <span class="badge border border-primary text-primary px-2 mb-1">{{ item.kode_perangkat }}</span>
                                    <br>
                                    <small class="text-muted fw-bold">SN: {{ item.nomor_seri || '-' }}</small>
                                </td>

                                <td class="text-center pe-5 py-3">
                                    <span class="fw-bold text-dark">{{ item.kapasitas_lahan || '-' }}</span>
                                    <small class="text-muted ms-1">Ha / Hari</small>
                                </td>

                                <td class="text-center pe-4 py-3">
                                    <div class="d-flex flex-column gap-1">
                                        <span class="badge w-100 py-2 text-center" :class="getTractorClass(item.status_mesin)">
                                            <i class="bi bi-power me-1"></i> MESIN: {{ item.status_mesin || 'OFF' }}
                                        </span>
                                        <small class="text-muted text-center w-75 mt-1" style="font-size: 0.7rem;">
                                            <i class="bi bi-speedometer2"></i> {{ (parseFloat(item.total_jarak_kerja || 0) / 1000).toFixed(2) }} Km
                                        </small>
                                    </div>
                                </td>

                                <!-- [DIPERBARUI] PEMBAGIAN HAK AKSES TOMBOL AKSI -->
                                <td class="text-center pe-4">
                                    
                                    <!-- Jika Role = Mektan (Akses Penuh tanpa Booking) -->
                                    <div v-if="userRole === 'mektan'" class="btn-group flex-wrap">
                                        <button @click="goToDetail(item.alsintan_id)" class="btn btn-sm btn-outline-info btn-aksi" title="Detail Administrasi"><i class="bi bi-info-circle"></i></button>
                                        <button @click="goToMonitoring(item.alsintan_id)" class="btn btn-sm btn-outline-primary btn-aksi" title="Kendali Peta & Argo"><i class="bi bi-geo-alt-fill"></i></button>
                                        <button @click="goToEdit(item.alsintan_id)" class="btn btn-sm btn-outline-warning btn-aksi" title="Edit Data"><i class="bi bi-pencil-square"></i></button>
                                        <button @click="deleteItem(item.alsintan_id)" class="btn btn-sm btn-outline-danger btn-aksi" title="Hapus Permanen"><i class="bi bi-trash"></i></button>
                                    </div>

                                    <!-- Jika Role = UPJA / Operator (Fokus Operasional) -->
                                    <div v-else-if="['upja', 'operator'].includes(userRole)">
                                        <div class="btn-group flex-wrap">
                                            <button @click="goToDetail(item.alsintan_id)" class="btn btn-sm btn-outline-info btn-aksi" title="Detail Alat"><i class="bi bi-info-circle"></i></button>
                                            <button @click="goToMonitoring(item.alsintan_id)" class="btn btn-sm btn-outline-primary btn-aksi" title="Kendali Peta & Argo"><i class="bi bi-geo-alt-fill"></i></button>
                                        </div>
                                        <!-- HANYA UPJA YANG BISA MELIHAT TOMBOL BOOKING -->
                                        <button v-if="item.status_ketersediaan === 'Tersedia di Balai' && userRole === 'upja'" @click="ajukanPinjaman(item)" class="btn btn-sm btn-success fw-bold shadow-sm btn-aksi ms-2" title="Booking Alat Ini">
                                            <i class="bi bi-calendar-plus-fill"></i> Booking
                                        </button>
                                    </div>

                                    <!-- Jika Guest / Publik (Tanpa Login) -->
                                    <div v-else>
                                        <button @click="goToDetail(item.alsintan_id)" class="btn btn-sm btn-outline-info btn-aksi" title="Lihat Spesifikasi">
                                            <i class="bi bi-info-circle"></i> Detail
                                        </button>
                                        <!-- Tombol Booking dihilangkan sepenuhnya dari publik -->
                                    </div>

                                </td>

                            </tr>
                        </tbody>
                    </table>
                </div>

                <!-- Indikator visual: geser tabel -->
                <div class="aset-scroll-edge" :class="{ 'show': tableScroll.right }">
                    <i class="bi bi-chevron-right"></i>
                </div>
                <div v-if="tableScroll.right" class="aset-scroll-hint d-md-none">
                    <i class="bi bi-arrow-left-right me-1"></i> Geser tabel untuk kolom lainnya
                </div>
            </div>
        </div>

    </div>
</template>

<style scoped>
.animate-pulse { animation: pulse 1.5s infinite; }
@keyframes pulse {
  0% { opacity: 1; box-shadow: 0 0 0 0 rgba(25, 135, 84, 0.7); }
  70% { opacity: 0.8; box-shadow: 0 0 0 6px rgba(25, 135, 84, 0); }
  100% { opacity: 1; box-shadow: 0 0 0 0 rgba(25, 135, 84, 0); }
}
.transition-img { transition: all 0.3s ease; }
.grayscale-dim { filter: grayscale(100%) contrast(80%); opacity: 0.6; }
.bg-dipinjam td { background-color: #fffff8 !important; }

/* ── Tabel: scroll horizontal terkontrol + kolom sticky ── */
.aset-table-wrap {
    overflow-x: auto;
    -webkit-overflow-scrolling: touch;
    max-width: 100%;
}

.aset-table {
    min-width: 780px;
    border-collapse: separate;
    border-spacing: 0;
}

/* Kolom pertama sticky kiri dengan background solid */
.aset-table thead th:first-child,
.aset-table tbody td:first-child {
    position: sticky;
    left: 0;
    z-index: 2;
    background-color: #ffffff;
    box-shadow: 1px 0 0 rgba(0, 0, 0, 0.04);
}
.aset-table thead th:first-child { z-index: 3; background-color: #f8f9fa; }
.aset-table tbody tr.bg-dipinjam td:first-child { background-color: #fffff8 !important; }
.aset-table tbody tr:hover td:first-child { background-color: #f8f9fa; }
.aset-table tbody tr.bg-dipinjam:hover td:first-child { background-color: #fffff8 !important; }

/* Indikator kanan saat tabel masih punya konten di luar layar */
.aset-scroll-edge {
    position: absolute;
    top: 0; bottom: 8px; right: 0;
    width: 36px;
    display: flex;
    align-items: center;
    justify-content: flex-end;
    padding-right: 6px;
    background: linear-gradient(to right, rgba(248,250,252,0), rgba(248,250,252,0.85));
    color: #94a3b8;
    pointer-events: none;
    opacity: 0;
    transition: opacity 0.2s;
}
.aset-scroll-edge.show { opacity: 1; }

.aset-scroll-hint {
    position: absolute;
    bottom: 10px; right: 10px;
    z-index: 3;
    background: #1e293b;
    color: #fff;
    font-size: 11px;
    font-weight: 600;
    padding: 6px 12px;
    border-radius: 20px;
    box-shadow: 0 2px 8px rgba(0,0,0,0.25);
    pointer-events: none;
}

/* Tombol aksi: target sentuh nyaman */
.btn-aksi {
    min-width: 40px;
    min-height: 40px;
    display: inline-flex;
    align-items: center;
    justify-content: center;
}
@media (max-width: 767.98px) {
    .btn-aksi { min-width: 44px; min-height: 44px; }
}
</style>