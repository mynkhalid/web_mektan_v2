<script setup>
import { ref, onMounted, onUnmounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';

const props = defineProps({
    pageTitle: { type: String, default: 'MyMektan' }
});

const emit = defineEmits(['toggle-sidebar']);

const route = useRoute();
const router = useRouter();
const currentTime = ref('');
const currentDate = ref('');
const userName = ref('');
const userPhoto = ref('');
const isLoggedIn = ref(false);
let clockInterval = null;

const pageTitles = {
    'home': 'Beranda',
    'aset-list': 'Katalog Aset',
    'aset-detail': 'Detail Aset',
    'aset-add': 'Tambah Aset',
    'aset-edit': 'Edit Aset',
    'monitoring': 'Monitoring Peta',
    'monitoring-detail': 'Detail Monitoring',
    'estimasi': 'Estimasi Lahan',
    'antrean': 'Antrean Pengajuan',
    'profile': 'Profil Saya',
    'verifikasi-akun': 'Verifikasi Akun',
    'login': 'Masuk',
    'register': 'Daftar'
};

const activeTitle = () => {
    if (props.pageTitle && props.pageTitle !== 'MyMektan') return props.pageTitle;
    return pageTitles[route.name] || 'MyMektan';
};

const updateClock = () => {
    const now = new Date();
    currentTime.value = now.toLocaleTimeString('id-ID', {
        hour: '2-digit', minute: '2-digit', second: '2-digit'
    }) + ' WIB';
    currentDate.value = now.toLocaleDateString('id-ID', {
        weekday: 'long', year: 'numeric', month: 'long', day: 'numeric'
    });
};

const IMAGE_BASE_URL = import.meta.env.VITE_IMAGE_BASE_URL;
const isDark = ref(false);

const applyTheme = () => {
    document.documentElement.setAttribute('data-theme', isDark.value ? 'dark' : 'light');
    document.documentElement.setAttribute('data-bs-theme', isDark.value ? 'dark' : 'light');
};

const toggleTheme = () => {
    isDark.value = !isDark.value;
    localStorage.setItem('mektan-theme', isDark.value ? 'dark' : 'light');
    applyTheme();
};

onMounted(() => {
    updateClock();
    clockInterval = setInterval(updateClock, 1000);

    const session = sessionStorage.getItem('user');
    const token = sessionStorage.getItem('token');
    isDark.value = document.documentElement.getAttribute('data-theme') === 'dark';
    if (session && token) {
        try {
            const userData = JSON.parse(session);
            userName.value = userData.nama || userData.nama_lengkap || 'Pengguna';
            isLoggedIn.value = true;
            const foto = userData.foto || userData.foto_profil;
            if (foto) {
                userPhoto.value = foto.startsWith('http') ? foto : `${IMAGE_BASE_URL}/profiles/${foto}`;
            } else {
                userPhoto.value = `https://ui-avatars.com/api/?name=${encodeURIComponent(userName.value)}&background=0D6EFD&color=fff`;
            }
        } catch (e) {}
    }
});

onUnmounted(() => {
    if (clockInterval) clearInterval(clockInterval);
});
</script>

<template>
    <header class="app-topbar">
        <div class="topbar-left">
            <button class="btn btn-sm btn-dark border-0 d-flex align-items-center justify-content-center topbar-hamburger"
                    @click="emit('toggle-sidebar')">
                <i class="bi bi-list fs-5"></i>
            </button>
            <h6 class="topbar-title mb-0 fw-bold text-dark">{{ activeTitle() }}</h6>
        </div>

        <div class="topbar-right">
            <button type="button" class="btn btn-sm border-0 d-flex align-items-center justify-content-center topbar-icon-btn"
                    @click="toggleTheme" :title="isDark ? 'Mode Terang' : 'Mode Gelap'">
                <i :class="isDark ? 'bi bi-sun-fill' : 'bi bi-moon-stars-fill'"></i>
            </button>
            <div class="topbar-clock d-none d-md-flex align-items-center gap-2 text-end">
                <div>
                    <div class="fw-bold text-dark" style="font-size: 0.85rem; line-height: 1.2;">{{ currentTime }}</div>
                    <div class="text-muted d-none d-lg-inline" style="font-size: 0.7rem;">{{ currentDate }}</div>
                </div>
            </div>

            <div class="vr d-none d-md-block"></div>

            <div v-if="isLoggedIn" class="dropdown">
                <a href="#" class="d-flex align-items-center text-decoration-none text-dark dropdown-toggle"
                   data-bs-toggle="dropdown" aria-expanded="false">
                    <img :src="userPhoto" alt="Profile" width="32" height="32" class="rounded-circle object-fit-cover border border-secondary">
                    <span class="ms-2 fw-bold d-none d-sm-inline" style="font-size: 0.85rem;">{{ userName }}</span>
                </a>
                <ul class="dropdown-menu dropdown-menu-end dropdown-menu-dark text-small shadow">
                    <li><RouterLink to="/profile" class="dropdown-item"><i class="bi bi-person me-2"></i>Profil Saya</RouterLink></li>
                    <li><hr class="dropdown-divider"></li>
                    <li><a class="dropdown-item" href="#" @click.prevent="handleLogout"><i class="bi bi-box-arrow-right me-2"></i>Logout</a></li>
                </ul>
            </div>

            <RouterLink v-else to="/login" class="btn btn-primary btn-sm fw-bold">
                <i class="bi bi-box-arrow-in-right me-1"></i> Masuk
            </RouterLink>
        </div>
    </header>
</template>

<script>
import Swal from 'sweetalert2';
export default {
    methods: {
        handleLogout() {
            Swal.fire({
                title: 'Konfirmasi Logout',
                text: 'Apakah Anda yakin ingin logout?',
                icon: 'warning',
                showCancelButton: true,
                confirmButtonColor: '#d33',
                cancelButtonColor: '#3085d6',
                confirmButtonText: 'Ya, Logout',
                cancelButtonText: 'Batal'
            }).then((result) => {
                if (result.isConfirmed) {
                    sessionStorage.removeItem('user');
                    sessionStorage.removeItem('token');
                    window.location.href = '/';
                }
            });
        }
    }
};
</script>

<style scoped>
.app-topbar {
    display: flex;
    align-items: center;
    justify-content: space-between;
    height: var(--topbar-height, 56px);
    padding: 0 1.25rem;
    background: #ffffff;
    border-bottom: 1px solid rgba(0, 0, 0, 0.06);
    flex-shrink: 0;
    position: relative;
    z-index: 1030;
    gap: 1rem;
    min-width: 0;
}

.topbar-left {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    min-width: 0;
    flex: 1 1 auto;
}

.topbar-hamburger {
    width: 34px;
    height: 34px;
    flex-shrink: 0;
}

.topbar-title {
    flex: 0 1 auto;
    min-width: 0;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    font-size: 1rem;
    margin: 0;
}

.topbar-right {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    flex-shrink: 0;
    margin-left: auto;
    min-width: 0;
}

.topbar-icon-btn {
    font-size: 1.1rem;
    color: #475569;
    min-width: 38px;
    min-height: 38px;
}
.topbar-icon-btn:hover {
    color: var(--primary-color);
    background-color: rgba(37, 99, 235, 0.08);
}

@media (max-width: 767.98px) {
    .app-topbar { padding: 0 0.75rem; }
    .topbar-title { font-size: 0.875rem; }
}
</style>
