<script setup>
import { onMounted, ref } from 'vue';
import { RouterLink } from 'vue-router';

const props = defineProps({
    isMobile: Boolean,
    isTablet: Boolean,
    isSidebarOpen: Boolean,
    isSidebarCollapsed: Boolean
});

const emit = defineEmits(['toggle-sidebar', 'close-mobile']);

const userRole = ref('');
const isLoggedIn = ref(false);

onMounted(() => {
    const session = sessionStorage.getItem('user');
    const token = sessionStorage.getItem('token');

    if (session && token) {
        try {
            const userData = JSON.parse(session);
            userRole.value = userData.role || '';
            isLoggedIn.value = true;
        } catch (e) {
            console.error("Gagal parsing user data");
        }
    }
});

const handleNavClick = () => {
    if (props.isMobile) {
        emit('close-mobile');
    }
};

const showLabels = () => {
    if (props.isMobile) return !props.isSidebarCollapsed;
    if (props.isTablet) return !props.isSidebarCollapsed;
    return !props.isSidebarCollapsed;
};
</script>

<template>
    <aside class="sidebar-drawer"
           :class="{
               'collapsed': !isMobile && isSidebarCollapsed,
               'expanded': isTablet && !isSidebarCollapsed,
               'mobile-open': isMobile && isSidebarOpen
           }">
        <div class="d-flex flex-column flex-shrink-0 p-3 h-100 sidebar-inner">

            <!-- Brand + Toggle -->
            <div class="d-flex align-items-center justify-content-center mb-3 px-2 w-100">
                <RouterLink
                    v-if="showLabels()"
                    to="/"
                    class="d-flex align-items-center text-white text-decoration-none mx-auto fade-in custom-brand-hover"
                    @click="handleNavClick">
                    <img src="/logo-mektan.jpeg" alt="Logo" width="36" height="36"
                         class="rounded-circle border border-2 border-white me-2 shadow-sm"
                         style="object-fit: cover;">
                    <span class="fs-4 fw-bold text-nowrap">MyMektan</span>
                </RouterLink>

                <RouterLink v-else to="/"
                    class="mx-auto custom-brand-hover"
                    @click="handleNavClick">
                    <img src="/logo-mektan.jpeg" alt="Logo" width="36" height="36"
                         class="rounded-circle border border-2 border-white shadow-sm"
                         style="object-fit: cover;">
                </RouterLink>

                <!-- <button
                    v-if="!isMobile"
                    @click="emit('toggle-sidebar')"
                    class="btn btn-dark border-0 p-1 d-flex align-items-center justify-content-center ms-auto flex-shrink-0"
                    :class="{ 'mx-auto': !showLabels() }"
                    style="width: 28px; height: 28px;">
                    <i class="bi bi-chevron-left transition-icon" :class="{ 'rotate-180': isSidebarCollapsed }"></i>
                </button> -->
            </div>

            <hr class="text-white-50 mx-2 mt-2">

            <!-- Navigation Menu -->
            <ul class="nav nav-pills flex-column mb-auto px-0 w-100">
                <li class="nav-item">
                    <RouterLink to="/" class="nav-link custom-nav-link d-flex align-items-center"
                        :class="{ 'justify-content-center': !showLabels() }"
                        active-class="active"
                        @click="handleNavClick">
                        <i class="bi bi-bar-chart-fill fs-5 flex-shrink-0"></i>
                        <span v-if="showLabels()" class="ms-3 fade-in text-nowrap">Beranda</span>
                    </RouterLink>
                </li>

                <li class="nav-item">
                    <RouterLink to="/aset" class="nav-link custom-nav-link d-flex align-items-center"
                        :class="{ 'justify-content-center': !showLabels() }"
                        active-class="active"
                        @click="handleNavClick">
                        <i class="bi bi-tools fs-5 flex-shrink-0"></i>
                        <span v-if="showLabels()" class="ms-3 fade-in text-nowrap">Katalog Aset</span>
                    </RouterLink>
                </li>

                <li v-if="userRole === 'mektan'" class="nav-item">
                    <RouterLink to="/verifikasi-akun" class="nav-link custom-nav-link d-flex align-items-center"
                        :class="{ 'justify-content-center': !showLabels() }"
                        active-class="active"
                        @click="handleNavClick">
                        <i class="bi bi-shield-check fs-5 flex-shrink-0 text-nowrap"></i>
                        <span v-if="showLabels()" class="ms-3 fade-in text-nowrap">Verifikasi Akun</span>
                    </RouterLink>
                </li>

                <li v-if="isLoggedIn" class="nav-item">
                    <RouterLink to="/monitoring" class="nav-link custom-nav-link d-flex align-items-center"
                        :class="{ 'justify-content-center': !showLabels() }"
                        active-class="active"
                        @click="handleNavClick">
                        <i class="bi bi-globe-americas fs-5 flex-shrink-0"></i>
                        <span v-if="showLabels()" class="ms-3 fade-in text-nowrap">Monitoring Peta</span>
                    </RouterLink>
                </li>

                <li v-if="isLoggedIn" class="nav-item">
                    <RouterLink to="/estimasi" class="nav-link custom-nav-link d-flex align-items-center"
                        :class="{ 'justify-content-center': !showLabels() }"
                        active-class="active"
                        @click="handleNavClick">
                        <i class="bi bi-calculator fs-5 flex-shrink-0"></i>
                        <span v-if="showLabels()" class="ms-3 fade-in text-nowrap">Estimasi Lahan</span>
                    </RouterLink>
                </li>
            </ul>

            <hr class="text-white-50 mx-2">

            <!-- Auth Buttons (logged-out users only; profile/logout lives in topbar) -->
            <div v-if="!isLoggedIn" class="d-flex flex-column gap-2 px-2" :class="{ 'align-items-center': !showLabels() }">
                <RouterLink to="/login" class="btn btn-primary btn-sm fw-bold w-100 d-flex align-items-center justify-content-center"
                    @click="handleNavClick">
                    <i class="bi bi-box-arrow-in-right" :class="{ 'fs-5': !showLabels() }"></i>
                    <span v-if="showLabels()" class="ms-2">Masuk</span>
                </RouterLink>

                <RouterLink to="/register" class="btn btn-outline-light btn-sm fw-bold w-100 d-flex align-items-center justify-content-center"
                    @click="handleNavClick">
                    <i class="bi bi-person-plus-fill" :class="{ 'fs-5': !showLabels() }"></i>
                    <span v-if="showLabels()" class="ms-2">Daftar</span>
                </RouterLink>
            </div>

        </div>
    </aside>
</template>

<style scoped>
.sidebar-inner {
    background-color: inherit;
    overflow-y: auto;
    overflow-x: hidden;
}

.custom-nav-link {
    border-radius: 8px !important;
    margin: 4px 6px;
    color: #e2e8f0;
    transition: all 0.2s ease-in-out;
    padding: 0.65rem 0.95rem;
    font-size: 0.9rem;
}

.sidebar-drawer.collapsed .custom-nav-link,
.sidebar-drawer:not(.expanded) .custom-nav-link {
    margin: 4px auto;
    padding-left: 0.95rem;
    padding-right: 0.95rem;
    width: max-content;
}

.custom-nav-link:hover {
    background-color: rgba(255, 255, 255, 0.1);
    color: #ffffff;
}

.nav-pills .nav-link.active, .nav-pills .show > .nav-link {
    background-color: var(--primary-color, #2563eb) !important;
    color: #ffffff !important;
    box-shadow: 0 3px 6px rgba(0, 0, 0, 0.2);
}

.transition-icon { transition: transform 0.3s ease; }
.rotate-180 { transform: rotate(180deg); }

.fade-in { animation: fadeIn 0.3s ease-in-out; }
@keyframes fadeIn {
    from { opacity: 0; transform: translateX(-5px); }
    to { opacity: 1; transform: translateX(0); }
}

.custom-brand-hover {
    transition: opacity 0.2s ease-in-out;
}
.custom-brand-hover:hover {
    opacity: 0.8;
}

/* Mobile: slightly larger touch targets */
@media (max-width: 767.98px) {
    .custom-nav-link {
        padding: 0.75rem 0.95rem;
        font-size: 0.95rem;
        margin: 4px 8px;
    }
}
</style>
