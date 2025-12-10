/**
 * Dashboard View
 */
export default class DashboardView {
    constructor(root, app) {
        this.root = root;
        this.app = app;
        this.state = {
            devices: [],
            stats: { total: 0 },
            loading: true
        };
        this.render();
        this.loadData();
    }

    render() {
        const isAdmin = this.app.user.role === 'admin';
        
        this.root.innerHTML = `
            <header>
                <div class="container header-content">
                    <div class="logo">🛡️ NetworkScanner</div>
                    <div style="display:flex; align-items:center; gap:1rem;">
                        <span>hola, <b>${this.app.user.username}</b></span>
                        <button id="logout-btn" class="btn btn-danger">Salir</button>
                    </div>
                </div>
            </header>

            <main class="container">
                <!-- Stats -->
                <div class="stats-grid">
                    <div class="stat-card">
                        <div class="stat-title">Equipos Detectados</div>
                        <div class="stat-value" id="stat-total">-</div>
                    </div>
                     <div class="stat-card" style="border-left: 4px solid var(--success);">
                        <div class="stat-title">Online Ahora</div>
                        <div class="stat-value" id="live-active">-</div>
                    </div>
                </div>

                <!-- Toolbar -->
                <div style="display:flex; justify-content:space-between; margin-bottom:1rem;">
                    <button class="btn btn-primary" id="refresh-btn">Refrescar</button>
                    ${isAdmin ? '<button class="btn btn-success" id="download-btn">📥 Descargar Instalador</button>' : ''}
                </div>

                <!-- Table -->
                <div class="table-container">
                    <table id="devices-table">
                        <thead>
                            <tr>
                                <th>Hostname</th>
                                <th>IP</th>
                                <th>MAC</th>
                                <th>Fabricante</th>
                                <th>Estado</th>
                            </tr>
                        </thead>
                        <tbody>
                            <tr><td colspan="5" style="text-align:center;">Cargando...</td></tr>
                        </tbody>
                    </table>
                </div>
            </main>
        `;

        this.root.querySelector('#logout-btn').addEventListener('click', () => this.handleLogout());
        this.root.querySelector('#refresh-btn').addEventListener('click', () => this.loadData());
        if(isAdmin) {
             const dlBtn = this.root.querySelector('#download-btn');
             if(dlBtn) dlBtn.addEventListener('click', () => this.handleDownload());
        }
        
        // Init SSE
        this.initSSE();
    }

    async loadData() {
        try {
            const res = await fetch('api/dashboard.php?action=list&limit=50');
            const json = await res.json();
            this.state.devices = json.data;
            this.updateTable();
            
            const resStats = await fetch('api/dashboard.php?action=summary');
            const jsonStats = await resStats.json();
            document.getElementById('stat-total').textContent = jsonStats.total_equipos;
            
        } catch (e) {
            console.error(e);
            this.app.toast('Error cargando datos', 'danger');
        }
    }

    updateTable() {
        const tbody = document.getElementById('devices-table').querySelector('tbody');
        if (!this.state.devices.length) {
            tbody.innerHTML = '<tr><td colspan="5" style="text-align:center;">No hay datos</td></tr>';
            return;
        }

        tbody.innerHTML = this.state.devices.map(d => `
            <tr>
                <td style="font-weight:500">${d.hostname || 'Desconocido'}</td>
                <td>${d.ip}</td>
                <td style="font-family:monospace; color:var(--text-sec);">${d.mac || '-'}</td>
                <td>${d.fabricante || '-'}</td>
                <td><span class="badge badge-secure">Registrado</span></td>
            </tr>
        `).join('');
    }

    initSSE() {
        const evtSource = new EventSource('api/metrics.php');
        evtSource.onmessage = (e) => {
             const data = JSON.parse(e.data);
             // Update Realtime Stat
             const el = document.getElementById('live-active');
             if(el) el.textContent = data.active_devices ?? 0;
        };
        // Clean up on unmount (simulated)
    }

    async handleLogout() {
        await fetch('api/auth/logout.php');
        this.app.user = null;
        this.app.router('/login');
    }

    handleDownload() {
        // En un entorno real, primero listamos versiones con api/files/list.php
        // Aquí asumimos directo por simplicidad o abrimos el listado.
        // Simulamos descarga de archivo conocido
        window.location.href = 'api/files/download.php?file=NetworkScanner_Setup.exe';
    }
}
