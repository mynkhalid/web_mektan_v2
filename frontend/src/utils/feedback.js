import Swal from 'sweetalert2'

const popup = (icon, title, text, timer) =>
    Swal.fire({
        icon,
        title,
        text,
        position: 'center',
        showConfirmButton: false,
        timerProgressBar: true,
        timer,
        backdrop: 'rgba(15, 23, 42, 0.45)',
        allowOutsideClick: false,
        customClass: { popup: 'notify-popup' },
        showClass: { popup: 'notify-popup-in' },
        hideClass: { popup: 'notify-popup-out' }
    });

export const success = (title, text = '') => popup('success', title, text, 2500);

export const error = (title, text = '') => popup('error', title, text, 4000);

export const warning = (title, text = '') => popup('warning', title, text, 4000);

export const confirm = (title, { text = '', confirmText = 'Ya', danger = false } = {}) =>
    Swal.fire({
        title,
        text,
        icon: 'warning',
        showCancelButton: true,
        confirmButtonText: confirmText,
        confirmButtonColor: danger ? '#d33' : '#198754',
        cancelButtonColor: '#6c757d'
    });

export const loading = (title, text = '') =>
    Swal.fire({ title, text, allowOutsideClick: false, didOpen: () => Swal.showLoading() });

export const close = () => Swal.close();