<script setup>
import { useLayout } from './composables/useLayout';
import Sidebar from './components/Sidebar.vue';
import AppTopbar from './components/AppTopbar.vue';
import AppFooter from './components/AppFooter.vue';
import { RouterView } from 'vue-router';

const { isMobile, isTablet, isDesktop, isSidebarOpen, isSidebarCollapsed, toggleSidebar, closeSidebarMobile } = useLayout();
</script>

<template>
    <div class="app-layout">
        <!-- Overlay for mobile drawer -->
        <div
            class="sidebar-overlay"
            :class="{ 'visible': isMobile && isSidebarOpen }"
            @click="closeSidebarMobile"
        ></div>

        <!-- Sidebar -->
        <Sidebar
            :isMobile="isMobile"
            :isTablet="isTablet"
            :isSidebarOpen="isSidebarOpen"
            :isSidebarCollapsed="isSidebarCollapsed"
            @toggle-sidebar="toggleSidebar"
            @close-mobile="closeSidebarMobile"
        />

        <!-- Main Content Area -->
        <div class="main-area"
             :class="{
                 'sidebar-collapsed': (isDesktop || isTablet) && isSidebarCollapsed,
                 'sidebar-expanded': isTablet && !isSidebarCollapsed
             }">
            <AppTopbar @toggle-sidebar="toggleSidebar" />
            <main class="content-area">
                <RouterView />
            </main>
            <AppFooter />
        </div>
    </div>
</template>
