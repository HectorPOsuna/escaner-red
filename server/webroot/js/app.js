/**
 * Core Application Logic
 * Router, State Management, Auth Check
 */

import LoginView from './views/login-view.js';
import DashboardView from './views/dashboard-view.js';

class App {
    constructor() {
        this.appEl = document.getElementById('app');
        this.user = null;
        this.init();
    }

    async init() {
        try {
            await this.checkAuth();
        } catch (e) {
            console.error("Init Error", e);
            this.router('/login');
        }
    }

    async checkAuth() {
        const res = await fetch('./api/auth/check.php');
        const data = await res.json();
        
        if (data.authenticated) {
            this.user = data.user;
            this.router('/dashboard');
        } else {
            this.router('/login');
        }
    }

    router(path) {
        // Simple Router
        this.appEl.innerHTML = ''; // Clear
        
        switch (path) {
            case '/login':
                if (this.user) {
                    this.router('/dashboard');
                    return;
                }
                new LoginView(this.appEl, this);
                break;
                
            case '/dashboard':
                if (!this.user) {
                    this.router('/login');
                    return;
                }
                new DashboardView(this.appEl, this);
                break;
                
            default:
                this.router(this.user ? '/dashboard' : '/login');
        }
    }

    // Shared Methods
    toast(msg, type = 'info') {
        const div = document.createElement('div');
        div.className = `toast toast-${type}`;
        div.textContent = msg;
        document.body.appendChild(div);
        setTimeout(() => div.remove(), 3000);
    }
}

// Start
new App();
