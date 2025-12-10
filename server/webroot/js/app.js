/**
 * Core Application Logic
 * Router, State Management, Auth Check
 */

import LoginView from './views/login-view.js';
import DashboardView from './views/dashboard-view.js';

class App {
    constructor() {
        this.root = document.getElementById('app-root');
        this.user = null;
        this.currentView = null;
        
        console.log('[App] Initializing...');
        this.init();
    }

    async init() {
        console.log('[App] Starting initialization...');
        
        // Ocultar loading screen después de un timeout máximo
        const loadingTimeout = setTimeout(() => {
            console.warn('[App] Loading timeout - forcing login view');
            this.hideLoading();
            this.router('/login');
        }, 5000); // 5 segundos máximo
        
        try {
            console.log('[App] Checking authentication...');
            await this.checkAuth();
            clearTimeout(loadingTimeout);
            console.log('[App] Auth check complete');
        } catch (error) {
            console.error('[App] Init error:', error);
            clearTimeout(loadingTimeout);
            this.hideLoading();
            this.router('/login');
        }
    }

    async checkAuth() {
        try {
            console.log('[App] Fetching auth status from API...');
            
            const controller = new AbortController();
            const timeoutId = setTimeout(() => controller.abort(), 10000); // 10s timeout
            
            const res = await fetch('/lisi3309/api/auth/check.php', {
                credentials: 'include',
                signal: controller.signal
            });
            
            clearTimeout(timeoutId);
            
            console.log('[App] Auth response status:', res.status);
            
            if (!res.ok) {
                throw new Error(`HTTP ${res.status}`);
            }
            
            const data = await res.json();
            console.log('[App] Auth data:', data);
            
            if (data.authenticated) {
                this.user = data.user;
                console.log('[App] User authenticated:', this.user.username);
                this.hideLoading();
                this.router('/dashboard');
            } else {
                console.log('[App] User not authenticated');
                this.hideLoading();
                this.router('/login');
            }
        } catch (error) {
            console.error('[App] Auth check failed:', error.message);
            // En caso de error, mostrar login
            this.hideLoading();
            this.router('/login');
        }
    }

    hideLoading() {
        const loadingScreen = document.getElementById('loading-screen');
        if (loadingScreen) {
            loadingScreen.style.display = 'none';
            console.log('[App] Loading screen hidden');
        }
    }

    router(path) {
        console.log('[App] Routing to:', path);
        
        // Limpiar vista actual
        if (this.currentView && this.currentView.destroy) {
            this.currentView.destroy();
        }
        
        this.root.innerHTML = '';
        
        if (path === '/login') {
            this.currentView = new LoginView(this.root, this);
        } else if (path === '/dashboard') {
            if (!this.user) {
                console.warn('[App] No user, redirecting to login');
                return this.router('/login');
            }
            this.currentView = new DashboardView(this.root, this);
        } else {
            // Default route
            this.router(this.user ? '/dashboard' : '/login');
        }
    }

    toast(message, type = 'info') {
        console.log(`[Toast ${type}]:`, message);
        
        const toast = document.createElement('div');
        toast.className = `toast toast-${type}`;
        toast.textContent = message;
        toast.style.cssText = `
            position: fixed;
            bottom: 2rem;
            right: 2rem;
            padding: 1rem 1.5rem;
            background: var(--bg-card);
            border-left: 4px solid var(--${type === 'danger' ? 'danger' : type === 'success' ? 'success' : 'primary'});
            border-radius: 8px;
            box-shadow: var(--shadow-lg);
            z-index: 10000;
            animation: slideIn 0.3s ease;
        `;
        
        document.body.appendChild(toast);
        
        setTimeout(() => {
            toast.style.animation = 'slideOut 0.3s ease';
            setTimeout(() => toast.remove(), 300);
        }, 3000);
    }
}

// Inicializar app cuando el DOM esté listo
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
        console.log('[App] DOM loaded, creating app instance');
        window.app = new App();
    });
} else {
    console.log('[App] DOM already loaded, creating app instance');
    window.app = new App();
}
