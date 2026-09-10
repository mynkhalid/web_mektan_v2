import { ref, computed, onMounted, onUnmounted } from 'vue';

const isMobile = ref(false);
const isTablet = ref(false);
const isSidebarOpen = ref(false);
const isSidebarCollapsed = ref(false);

const isDesktop = computed(() => !isMobile.value && !isTablet.value);

let initialized = false;

function checkBreakpoint() {
    const w = window.innerWidth;
    isMobile.value = w < 768;
    isTablet.value = w >= 768 && w < 1200;
    if (isDesktop.value) {
        isSidebarOpen.value = false;
    }
}

function toggleSidebar() {
    if (isMobile.value) {
        isSidebarOpen.value = !isSidebarOpen.value;
    } else if (isTablet.value) {
        isSidebarCollapsed.value = !isSidebarCollapsed.value;
    } else {
        isSidebarCollapsed.value = !isSidebarCollapsed.value;
    }
}

function closeSidebarMobile() {
    isSidebarOpen.value = false;
}

export function useLayout() {
    onMounted(() => {
        if (!initialized) {
            checkBreakpoint();
            window.addEventListener('resize', checkBreakpoint);
            initialized = true;
        } else {
            checkBreakpoint();
        }
    });

    onUnmounted(() => {
        // Only remove when no other component uses it
    });

    return {
        isMobile,
        isTablet,
        isDesktop,
        isSidebarOpen,
        isSidebarCollapsed,
        toggleSidebar,
        closeSidebarMobile
    };
}
