/*
 * Dashboard View
 */
export default class DashboardView {
    constructor(root, app) {
        this.root = root;
        this.app = app;
        this.state = {
            devices: [],
            stats: { total: 0, active: 0, conflicts: 0 },
            loading: true,
            sseConnection: null,
            currentModalDevice: null
        };
        this.render();
        this.loadData();
    }

    render() {
        const isAdmin = this.app.user.role === 'admin';
        
        this.root.innerHTML = `
            <!-- Modal para detalles del dispositivo -->
            <div id="device-modal" class="modal" style="display:none;">
                <div class="modal-content" style="max-width: 800px;">
                    <div class="modal-header">
                        <h3 id="modal-title">Detalles del Dispositivo</h3>
                        <button class="close-btn">&times;</button>
                    </div>
                    <div class="modal-body">
                        <div id="modal-loading">Cargando detalles...</div>
                        <div id="modal-content" style="display:none;">
                            <!-- Contenido se llenará dinámicamente -->
                        </div>
                    </div>
                </div>
            </div>

            <header>
                <div class="container header-content">
                    <div class="logo">🛡️ NetworkScanner</div>
                    <div style="display:flex; align-items:center; gap:1rem;">
                        <span>Hola, <b>${this.app.user.username}</b></span>
                        <span class="badge ${isAdmin ? 'badge-admin' : 'badge-user'}">
                            ${isAdmin ? 'Administrador' : 'Usuario'}
                        </span>
                        <button id="logout-btn" class="btn btn-danger">Salir</button>
                    </div>
                </div>
            </header>

            <main class="container">
                <!-- Stats Grid Mejorado -->
                <div class="stats-grid">
                    <div class="stat-card">
                        <div class="stat-title">📊 Equipos Totales</div>
                        <div class="stat-value" id="stat-total">-</div>
                        <div class="stat-subtitle" id="stat-total-sub">Cargando...</div>
                    </div>
                    <div class="stat-card" style="border-left: 4px solid var(--success);">
                        <div class="stat-title">🟢 Activos (5min)</div>
                        <div class="stat-value" id="live-active">-</div>
                        <div class="stat-subtitle" id="active-percentage">-</div>
                    </div>
                    <div class="stat-card" style="border-left: 4px solid var(--warning);">
                        <div class="stat-title">⏱️ Último Escaneo</div>
                        <div class="stat-value" id="last-scan-time">-</div>
                        <div class="stat-subtitle" id="scan-status">-</div>
                    </div>
                    ${isAdmin ? `
                    <div class="stat-card" style="border-left: 4px solid var(--danger);">
                        <div class="stat-title">⚠️ Conflictos</div>
                        <div class="stat-value" id="conflicts-count">-</div>
                        <div class="stat-subtitle" id="conflicts-status">Sin resolver</div>
                    </div>
                    ` : ''}
                </div>

                <!-- Filtros y Búsqueda -->
                <div class="toolbar-container">
                    <div class="search-container">
                        <input type="text" id="search-input" placeholder="Buscar por IP, hostname, MAC o SO..." 
                               class="search-input">
                        <button id="search-btn" class="btn btn-primary">🔍 Buscar</button>
                        <button id="clear-search" class="btn btn-secondary">Limpiar</button>
                    </div>
                    
                    <div class="toolbar-buttons">
                        <button class="btn btn-primary" id="refresh-btn">
                            <span id="refresh-icon">↻</span> Refrescar
                        </button>
                        ${isAdmin ? '<button class="btn btn-success" id="download-btn">📥 Descargar Instalador</button>' : ''}
                    </div>
                </div>

                <!-- Información del Sistema -->
                <div class="system-info">
                    <div class="info-card">
                        <h4>📡 Estado del Sistema</h4>
                        <div class="info-grid">
                            <div class="info-item">
                                <span class="info-label">Servidor:</span>
                                <span class="info-value" id="server-status">🟢 Conectado</span>
                            </div>
                            <div class="info-item">
                                <span class="info-label">SSE:</span>
                                <span class="info-value" id="sse-status">🔵 Conectando...</span>
                            </div>
                            <div class="info-item">
                                <span class="info-label">Última actualización:</span>
                                <span class="info-value" id="last-update">-</span>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Tabla de Dispositivos -->
                <div class="table-container">
                    <div class="table-header">
                        <h3>📋 Dispositivos Detectados</h3>
                        <div class="table-controls">
                            <span id="device-count">0 dispositivos</span>
                            <select id="limit-select" class="form-select">
                                <option value="10">10 por página</option>
                                <option value="25">25 por página</option>
                                <option value="50" selected>50 por página</option>
                                <option value="100">100 por página</option>
                            </select>
                        </div>
                    </div>
                    <table id="devices-table">
                        <thead>
                            <tr>
                                <th>Hostname</th>
                                <th>IP</th>
                                <th>MAC</th>
                                <th>Fabricante</th>
                                <th>Sistema Operativo</th>
                                <th>Última Detección</th>
                                <th>Estado</th>
                                <th>Acciones</th>
                            </tr>
                        </thead>
                        <tbody>
                            <tr><td colspan="8" style="text-align:center;">Cargando dispositivos...</td></tr>
                        </tbody>
                    </table>
                    <div class="table-footer">
                        <div class="pagination" id="pagination">
                            <!-- Paginación se generará aquí -->
                        </div>
                    </div>
                </div>
            </main>
        `;

        // Agregar estilos para el modal
        this.addModalStyles();

        // Event Listeners
        this.root.querySelector('#logout-btn').addEventListener('click', () => this.handleLogout());
        this.root.querySelector('#refresh-btn').addEventListener('click', () => this.loadData());
        this.root.querySelector('#search-btn').addEventListener('click', () => this.handleSearch());
        this.root.querySelector('#clear-search').addEventListener('click', () => this.clearSearch());
        
        const searchInput = this.root.querySelector('#search-input');
        searchInput.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') this.handleSearch();
        });
        
        this.root.querySelector('#limit-select').addEventListener('change', () => this.loadData());
        
        if (isAdmin) {
            const dlBtn = this.root.querySelector('#download-btn');
            if (dlBtn) dlBtn.addEventListener('click', () => this.handleDownload());
        }
        
        // Modal close button
        this.root.querySelector('.close-btn')?.addEventListener('click', () => this.closeModal());
        
        // Close modal when clicking outside
        this.root.querySelector('#device-modal')?.addEventListener('click', (e) => {
            if (e.target.id === 'device-modal') this.closeModal();
        });
        
        // Init SSE
        this.initSSE();
    }

    addModalStyles() {
        const style = document.createElement('style');
        style.textContent = `
            .modal {
                display: none;
                position: fixed;
                z-index: 1000;
                left: 0;
                top: 0;
                width: 100%;
                height: 100%;
                background-color: rgba(0, 0, 0, 0.8);
                animation: fadeIn 0.3s ease;
            }
            
            .modal-content {
                background-color: var(--bg-card);
                margin: 5% auto;
                padding: 0;
                border-radius: 12px;
                box-shadow: var(--shadow-lg);
                border: 1px solid var(--border-color);
                animation: slideIn 0.3s ease;
            }
            
            .modal-header {
                padding: 1.5rem;
                border-bottom: 1px solid var(--border-color);
                display: flex;
                justify-content: space-between;
                align-items: center;
            }
            
            .modal-header h3 {
                margin: 0;
                color: var(--text-primary);
            }
            
            .close-btn {
                background: none;
                border: none;
                font-size: 1.5rem;
                color: var(--text-secondary);
                cursor: pointer;
                padding: 0.5rem;
                line-height: 1;
            }
            
            .close-btn:hover {
                color: var(--text-primary);
            }
            
            .modal-body {
                padding: 1.5rem;
                max-height: 70vh;
                overflow-y: auto;
            }
            
            @keyframes fadeIn {
                from { opacity: 0; }
                to { opacity: 1; }
            }
            
            @keyframes slideIn {
                from { transform: translateY(-20px); opacity: 0; }
                to { transform: translateY(0); opacity: 1; }
            }
            
            .info-section {
                margin-bottom: 2rem;
                padding: 1.5rem;
                background: rgba(255, 255, 255, 0.03);
                border-radius: 8px;
                border-left: 4px solid var(--primary);
            }
            
            .info-section h4 {
                margin-top: 0;
                margin-bottom: 1rem;
                color: var(--text-primary);
                display: flex;
                align-items: center;
                gap: 0.5rem;
            }
            
            .info-grid-modal {
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
                gap: 1rem;
            }
            
            .info-item-modal {
                display: flex;
                justify-content: space-between;
                padding: 0.75rem 0;
                border-bottom: 1px dashed var(--border-light);
            }
            
            .info-item-modal:last-child {
                border-bottom: none;
            }
            
            .ports-grid {
                display: grid;
                grid-template-columns: repeat(auto-fill, minmax(120px, 1fr));
                gap: 0.75rem;
                margin-top: 1rem;
            }
            
            .port-badge {
                background: rgba(59, 130, 246, 0.15);
                border: 1px solid var(--primary);
                border-radius: 6px;
                padding: 0.5rem;
                text-align: center;
                font-family: 'JetBrains Mono', monospace;
            }
            
            .port-badge.open {
                background: rgba(16, 185, 129, 0.15);
                border-color: var(--success);
            }
            
            .port-badge.closed {
                background: rgba(239, 68, 68, 0.15);
                border-color: var(--danger);
                opacity: 0.7;
            }
            
            .port-number {
                font-weight: bold;
                font-size: 1.1rem;
                color: var(--primary);
            }
            
            .port-protocol {
                font-size: 0.8rem;
                color: var(--text-secondary);
            }
            
            .detection-method {
                display: inline-block;
                padding: 0.25rem 0.5rem;
                background: rgba(245, 158, 11, 0.15);
                border-radius: 4px;
                font-size: 0.8rem;
                color: var(--warning);
                margin: 0.25rem;
            }
            
            .history-item {
                padding: 0.75rem;
                background: rgba(255, 255, 255, 0.02);
                border-radius: 6px;
                margin-bottom: 0.5rem;
                border-left: 3px solid var(--info);
            }
        `;
        document.head.appendChild(style);
    }

    async loadData() {
    try {
        const limit = this.root.querySelector('#limit-select').value;
        const search = this.state.searchTerm || '';
        const page = this.state.currentPage || 1;
        
        // Mostrar loading
        const tbody = this.root.querySelector('#devices-table tbody');
        if (tbody) {
            tbody.innerHTML = '<tr><td colspan="8" style="text-align:center; padding: 2rem;">Cargando...</td></tr>';
        }
        
        // Actualizar icono de refresh
        const refreshIcon = this.root.querySelector('#refresh-icon');
        if (refreshIcon) refreshIcon.style.animation = 'spin 1s linear infinite';
        
        const url = `/lisi3309/api/dashboard.php?action=list&limit=${limit}&page=${page}${search ? `&search=${encodeURIComponent(search)}` : ''}`;
        
        console.log("Fetching URL:", url); // DEBUG
        
        const res = await fetch(url, {
            credentials: 'include'
        });
        
        console.log("Response status:", res.status, res.statusText); // DEBUG
        
        if (!res.ok) {
            // Si es error 401, redirigir a login
            if (res.status === 401) {
                console.warn("Sesión expirada, redirigiendo a login");
                this.app.user = null;
                this.app.router('/login');
                return;
            }
            
            const errorText = await res.text();
            console.error("Error response:", errorText);
            throw new Error(`HTTP ${res.status}: ${res.statusText}`);
        }
        
        const json = await res.json();
        
        console.log("Datos recibidos:", json); // DEBUG
        
        if (!json.success) {
            throw new Error(json.error || json.message || 'Error del servidor');
        }
        
        this.state.devices = json.data || [];
        this.state.currentPage = json.page || 1;
        this.state.totalPages = json.pages || 1;
        this.state.totalDevices = json.total || 0;
        
        this.updateTable();
        this.updatePagination();
        this.updateDeviceCount();
        
        // También cargar estadísticas generales
        await this.loadStats();
        
    } catch (e) {
        console.error('Error en loadData:', e);
        this.app.toast('Error cargando datos: ' + e.message, 'danger');
        
        const tbody = this.root.querySelector('#devices-table tbody');
        if (tbody) {
            tbody.innerHTML = `
                <tr>
                    <td colspan="8" style="text-align:center; padding: 2rem; color: var(--danger);">
                        <div>⚠️ Error cargando datos</div>
                        <small style="opacity:0.7;">${e.message}</small>
                        <br>
                        <button class="btn btn-sm btn-primary mt-2" onclick="window.dashboardView?.loadData()">Reintentar</button>
                    </td>
                </tr>
            `;
        }
    } finally {
        // Quitar animación de refresh
        const refreshIcon = this.root.querySelector('#refresh-icon');
        if (refreshIcon) refreshIcon.style.animation = '';
    }
    }


    async loadStats() {
    try {
        const res = await fetch('/lisi3309/api/dashboard.php?action=summary', {
            credentials: 'include'
        });
        
        if (res.status === 401) {
            // Sesión expirada
            return;
        }
        
        const json = await res.json();
        
        if (json.success) {
            const totalEl = document.getElementById('stat-total');
            if (totalEl) {
                totalEl.textContent = json.total_equipos || 0;
            }
            
            // Calcular porcentaje de activos
            const total = json.total_equipos || 1;
            const active = json.activos_5min || 0;
            const percentage = Math.round((active / total) * 100);
            
            const percentageEl = document.getElementById('active-percentage');
            if (percentageEl) {
                percentageEl.textContent = `${percentage}% activos`;
                percentageEl.style.color = percentage > 50 ? 'var(--success)' : 
                                          percentage > 20 ? 'var(--warning)' : 'var(--danger)';
            }
            
            // Actualizar último update
            const lastUpdateEl = document.getElementById('last-update');
            if (lastUpdateEl && json.last_updated) {
                lastUpdateEl.textContent = new Date(json.last_updated).toLocaleTimeString();
            }
        }
    } catch (e) {
        console.warn('Error cargando estadísticas:', e);
    }
}


    updateTable() {
    const tbody = this.root.querySelector('#devices-table tbody');
    if (!tbody) return;
    
    console.log("Actualizando tabla con dispositivos:", this.state.devices); // DEBUG
    
    if (!this.state.devices.length) {
        tbody.innerHTML = `
            <tr>
                <td colspan="8" style="text-align:center; padding: 3rem;">
                    <div style="font-size: 2rem; opacity: 0.5;">📭</div>
                    <div>No se encontraron dispositivos</div>
                    ${this.state.searchTerm ? 
                        `<small>Prueba con otros términos de búsqueda</small>` : 
                        `<small>Esperando datos de escaneo...</small>`
                    }
                </td>
            </tr>
        `;
        return;
    }

    tbody.innerHTML = this.state.devices.map((device, index) => {
        // DEBUG: Ver qué datos tiene cada dispositivo
        console.log(`Dispositivo ${index}:`, {
            hostname: device.hostname,
            id_so: device.id_so,
            so_nombre: device.so_nombre,
            os_hints: device.os_hints,
            ttl: device.ttl
        });
        
        // Determinar estado del dispositivo
        const lastSeen = device.ultima_deteccion ? new Date(device.ultima_deteccion) : null;
        const now = new Date();
        const minutesAgo = lastSeen ? Math.floor((now - lastSeen) / (1000 * 60)) : 999;
        
        let status = '🔴 Inactivo';
        let statusClass = 'badge-danger';
        
        if (minutesAgo < 5) {
            status = '🟢 Activo';
            statusClass = 'badge-success';
        } else if (minutesAgo < 30) {
            status = '🟡 Reciente';
            statusClass = 'badge-warning';
        }
        
        // Formatear fecha
        const lastSeenFormatted = lastSeen ? 
            lastSeen.toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'}) : 
            'Nunca';
        
        // INFORMACIÓN DE SISTEMA OPERATIVO - CORREGIDO
        const soInfo = device.so_nombre || 'Desconocido';
        
        // Información adicional de detección
        let detectionInfo = '';
        if (device.ttl) {
            detectionInfo += `<small class="text-muted">TTL: ${device.ttl}</small><br>`;
        }
        if (device.os_hints) {
            const hints = device.os_hints.split('|').slice(0, 2);
            detectionInfo += `<small class="text-muted">${hints.join(', ')}</small>`;
        }
        
        return `
            <tr>
                <td style="font-weight:500">
                    <div class="device-hostname">${device.hostname || 'Desconocido'}</div>
                    ${device.mac ? `<small class="text-muted">${device.mac}</small>` : ''}
                </td>
                <td>
                    <div class="device-ip">${device.ip || '-'}</div>
                    ${device.subnet ? `<small class="text-muted">${device.subnet}</small>` : ''}
                </td>
                <td style="font-family:monospace; font-size: 0.9em;">
                    <div class="device-mac">${device.mac || 'No disponible'}</div>
                    ${device.mac ? `<small class="text-muted">OUI: ${device.mac.substring(0, 8)}</small>` : ''}
                </td>
                <td>
                    <div class="device-manufacturer">${device.fabricante_nombre || device.fabricante || 'Desconocido'}</div>
                    ${device.fabricante_id && device.fabricante_id !== 1 ? 
                        `<small class="text-muted">ID: ${device.fabricante_id}</small>` : ''
                    }
                </td>
                <td>
                    <div style="font-weight:500; color: var(--primary);">${soInfo}</div>
                    ${detectionInfo}
                    ${device.id_so ? `<small class="text-muted">ID: ${device.id_so}</small>` : ''}
                </td>
                <td>
                    <div>${lastSeenFormatted}</div>
                    <small class="text-muted">${lastSeen ? lastSeen.toLocaleDateString() : ''}</small>
                </td>
                <td>
                    <span class="badge ${statusClass}">${status}</span>
                    <br>
                    <small class="text-muted">${minutesAgo < 999 ? `${minutesAgo} min` : 'Desconocido'}</small>
                </td>
                <td>
                    <button class="btn btn-sm btn-info view-details-btn" data-index="${index}">
                        👁️ Ver Detalles
                    </button>
                </td>
            </tr>
        `;
    }).join('');
    
    // Agregar event listeners a los botones de detalles
    tbody.querySelectorAll('.view-details-btn').forEach(btn => {
        btn.addEventListener('click', (e) => {
            const index = parseInt(e.target.dataset.index);
            this.showDeviceDetails(this.state.devices[index]);
        });
    });
}


    parseOSHints(hintsString) {
        if (!hintsString) return '';
        
        const hints = hintsString.split('|');
        const parsedHints = hints.map(hint => {
            if (hint.startsWith('TTL:')) return `TTL ${hint.substring(4)}`;
            if (hint.startsWith('Hostname:')) return `Hostname pattern`;
            if (hint.startsWith('Port:')) {
                const match = hint.match(/Port:(\d+)=(.+)/);
                if (match) return `Puerto ${match[1]}`;
            }
            return hint;
        });
        
        return parsedHints.slice(0, 2).join(', ');
    }

    async showDeviceDetails(device) {
        try {
            const modal = document.getElementById('device-modal');
            const loading = document.getElementById('modal-loading');
            const content = document.getElementById('modal-content');
            
            // Mostrar modal
            modal.style.display = 'block';
            loading.style.display = 'block';
            content.style.display = 'none';
            
            // Cargar detalles completos
            const res = await fetch(`/lisi3309/api/dashboard.php?action=details&id=${device.id_equipo}`, {
                credentials: 'include'
            });
            const json = await res.json();
            
            if (!json.success) {
                throw new Error(json.message || 'Error al cargar detalles');
            }
            
            const deviceData = json.device;
            const ports = json.ports || [];
            const history = json.detection_history || [];
            
            // Formatear información de detección
            const detectionInfo = this.formatDetectionInfo(deviceData);
            
            // Formatear puertos
            const portsHTML = this.formatPortsHTML(ports);
            
            // Formatear historial
            const historyHTML = this.formatHistoryHTML(history);
            
            // Construir contenido del modal
            content.innerHTML = `
                <div class="info-section">
                    <h4>📱 Información Básica</h4>
                    <div class="info-grid-modal">
                        <div class="info-item-modal">
                            <span class="info-label">Hostname:</span>
                            <span class="info-value">${deviceData.hostname || 'Desconocido'}</span>
                        </div>
                        <div class="info-item-modal">
                            <span class="info-label">IP Address:</span>
                            <span class="info-value" style="font-family:monospace;">${deviceData.ip}</span>
                        </div>
                        <div class="info-item-modal">
                            <span class="info-label">MAC Address:</span>
                            <span class="info-value" style="font-family:monospace;">${deviceData.mac || 'No disponible'}</span>
                        </div>
                        <div class="info-item-modal">
                            <span class="info-label">Fabricante:</span>
                            <span class="info-value">${deviceData.fabricante_nombre || 'Desconocido'}</span>
                        </div>
                    </div>
                </div>
                
                <div class="info-section">
                    <h4>💻 Sistema Operativo</h4>
                    <div class="info-grid-modal">
                        <div class="info-item-modal">
                            <span class="info-label">SO Detectado:</span>
                            <span class="info-value" style="font-weight:bold;">${deviceData.so_nombre || 'Desconocido'}</span>
                        </div>
                        <div class="info-item-modal">
                            <span class="info-label">TTL:</span>
                            <span class="info-value">${deviceData.ttl || 'N/A'}</span>
                        </div>
                        <div class="info-item-modal">
                            <span class="info-label">Última Detección:</span>
                            <span class="info-value">${new Date(deviceData.ultima_deteccion).toLocaleString()}</span>
                        </div>
                    </div>
                    
                    ${detectionInfo ? `
                    <div style="margin-top: 1rem; padding: 1rem; background: rgba(255,255,255,0.05); border-radius: 6px;">
                        <h5 style="margin-top:0; margin-bottom:0.5rem;">🔍 Métodos de Detección</h5>
                        <div>${detectionInfo}</div>
                    </div>
                    ` : ''}
                </div>
                
                ${ports.length > 0 ? `
                <div class="info-section">
                    <h4>🔌 Puertos Escaneados (${ports.length})</h4>
                    <div class="ports-grid">
                        ${portsHTML}
                    </div>
                    <div style="margin-top: 1rem; font-size: 0.9rem; color: var(--text-secondary);">
                        <small>💡 Los puertos en verde están actualmente abiertos</small>
                    </div>
                </div>
                ` : '<div class="info-section"><h4>🔌 Puertos Escaneados</h4><p>No se encontraron puertos escaneados para este dispositivo.</p></div>'}
                
                ${history.length > 0 ? `
                <div class="info-section">
                    <h4>📊 Historial de Detecciones</h4>
                    <div style="max-height: 200px; overflow-y: auto;">
                        ${historyHTML}
                    </div>
                </div>
                ` : ''}
                
                <div class="info-section">
                    <h4>📋 Información Técnica</h4>
                    <div class="info-grid-modal">
                        <div class="info-item-modal">
                            <span class="info-label">ID Equipo:</span>
                            <span class="info-value">${deviceData.id_equipo}</span>
                        </div>
                        <div class="info-item-modal">
                            <span class="info-label">ID Fabricante:</span>
                            <span class="info-value">${deviceData.fabricante_id || 'N/A'}</span>
                        </div>
                        <div class="info-item-modal">
                            <span class="info-label">ID SO:</span>
                            <span class="info-value">${deviceData.id_so || 'N/A'}</span>
                        </div>
                    </div>
                </div>
            `;
            
            // Ocultar loading y mostrar contenido
            loading.style.display = 'none';
            content.style.display = 'block';
            
            // Actualizar título
            document.getElementById('modal-title').textContent = 
                `Detalles: ${deviceData.hostname || deviceData.ip}`;
            
        } catch (error) {
            console.error('Error cargando detalles:', error);
            document.getElementById('modal-content').innerHTML = `
                <div style="text-align:center; padding: 2rem; color: var(--danger);">
                    <div>⚠️ Error cargando detalles</div>
                    <small>${error.message}</small>
                </div>
            `;
        }
    }

    formatDetectionInfo(deviceData) {
        if (!deviceData.os_hints) return '';
        
        const hints = deviceData.os_hints.split('|');
        let html = '<div style="display:flex; flex-wrap:wrap; gap:0.5rem;">';
        
        hints.forEach(hint => {
            if (hint.startsWith('TTL:')) {
                const ttl = hint.substring(4);
                html += `<span class="detection-method">TTL: ${ttl}</span>`;
            } else if (hint.startsWith('Hostname:')) {
                const pattern = hint.substring(9);
                html += `<span class="detection-method">Hostname: ${pattern}</span>`;
            } else if (hint.startsWith('Port:')) {
                const match = hint.match(/Port:(\d+)=(.+)/);
                if (match) {
                    html += `<span class="detection-method">Puerto ${match[1]}: ${match[2]}</span>`;
                }
            } else {
                html += `<span class="detection-method">${hint}</span>`;
            }
        });
        
        html += '</div>';
        return html;
    }

    formatPortsHTML(ports) {
        return ports.map(port => {
            const isOpen = port.estado === 'activo' || port.estado === 'open';
            const statusClass = isOpen ? 'open' : 'closed';
            const statusIcon = isOpen ? '🟢' : '🔴';
            
            return `
                <div class="port-badge ${statusClass}">
                    <div class="port-number">${port.puerto_numero || port.port}</div>
                    <div class="port-protocol">${port.protocolo_nombre || port.protocol || 'Unknown'}</div>
                    <div style="font-size:0.7rem; margin-top:0.25rem;">
                        ${statusIcon} ${isOpen ? 'Abierto' : 'Cerrado'}
                    </div>
                    ${port.categoria ? `<div style="font-size:0.7rem; color:var(--text-tertiary);">${port.categoria}</div>` : ''}
                </div>
            `;
        }).join('');
    }

    formatHistoryHTML(history) {
        return history.map(item => {
            const date = new Date(item.ultima_deteccion);
            return `
                <div class="history-item">
                    <div style="display:flex; justify-content:space-between;">
                        <span style="font-weight:500;">${date.toLocaleString()}</span>
                        ${item.ttl ? `<span style="font-family:monospace;">TTL: ${item.ttl}</span>` : ''}
                    </div>
                    ${item.os_hints ? `
                    <div style="margin-top:0.5rem; font-size:0.9rem; color:var(--text-secondary);">
                        <small>${item.os_hints.split('|').slice(0, 2).join(', ')}</small>
                    </div>
                    ` : ''}
                </div>
            `;
        }).join('');
    }

    closeModal() {
        document.getElementById('device-modal').style.display = 'none';
        this.state.currentModalDevice = null;
    }

    // ... resto del código se mantiene igual hasta el final del archivo ...

    updateDeviceCount() {
        const countEl = this.root.querySelector('#device-count');
        if (countEl) {
            const searchText = this.state.searchTerm ? 
                ` (filtrados: ${this.state.devices.length})` : 
                ` (total: ${this.state.totalDevices})`;
            countEl.textContent = `${this.state.devices.length} dispositivos${searchText}`;
        }
    }

    updatePagination() {
        const paginationEl = this.root.querySelector('#pagination');
        if (!paginationEl || this.state.totalPages <= 1) {
            paginationEl.innerHTML = '';
            return;
        }
        
        const current = this.state.currentPage || 1;
        const total = this.state.totalPages;
        
        let html = '';
        
        // Botón anterior
        html += `<button class="page-btn ${current === 1 ? 'disabled' : ''}" 
                  ${current === 1 ? 'disabled' : `onclick="dashboardView.goToPage(${current - 1})"`}>
                  ← Anterior
                </button>`;
        
        // Páginas
        const start = Math.max(1, current - 2);
        const end = Math.min(total, start + 4);
        
        for (let i = start; i <= end; i++) {
            html += `<button class="page-btn ${i === current ? 'active' : ''}" 
                      onclick="dashboardView.goToPage(${i})">
                      ${i}
                    </button>`;
        }
        
        // Botón siguiente
        html += `<button class="page-btn ${current === total ? 'disabled' : ''}" 
                  ${current === total ? 'disabled' : `onclick="dashboardView.goToPage(${current + 1})"`}>
                  Siguiente →
                </button>`;
        
        paginationEl.innerHTML = html;
        
        // Hacer disponible globalmente para los onclick
        window.dashboardView = this;
    }

    goToPage(page) {
        this.state.currentPage = page;
        this.loadData();
    }

    handleSearch() {
        const searchInput = this.root.querySelector('#search-input');
        const searchTerm = searchInput.value.trim();
        
        if (searchTerm !== this.state.searchTerm) {
            this.state.searchTerm = searchTerm;
            this.state.currentPage = 1;
            this.loadData();
        }
    }

    clearSearch() {
        const searchInput = this.root.querySelector('#search-input');
        searchInput.value = '';
        
        if (this.state.searchTerm) {
            this.state.searchTerm = '';
            this.state.currentPage = 1;
            this.loadData();
        }
    }

    initSSE() {
        // Cerrar conexión anterior si existe
        if (this.sseConnection) {
            this.sseConnection.close();
        }
        
        const sseStatusEl = this.root.querySelector('#sse-status');
        if (sseStatusEl) {
            sseStatusEl.textContent = '🟡 Conectando...';
            sseStatusEl.style.color = 'var(--warning)';
        }
        
        const evtSource = new EventSource('/lisi3309/api/metrics.php', {
            withCredentials: true
        });
        
        evtSource.onopen = () => {
            console.log('SSE: Conexión establecida');
            if (sseStatusEl) {
                sseStatusEl.textContent = '🟢 Conectado';
                sseStatusEl.style.color = 'var(--success)';
            }
        };
        
        evtSource.addEventListener('update', (e) => {
            try {
                const data = JSON.parse(e.data);
                
                // Actualizar estadísticas en tiempo real
                const activeEl = document.getElementById('live-active');
                if (activeEl) {
                    activeEl.textContent = data.active_devices || 0;
                }
                
                const conflictsEl = document.getElementById('conflicts-count');
                if (conflictsEl) {
                    conflictsEl.textContent = data.unresolved_conflicts || 0;
                }
                
                const lastScanEl = document.getElementById('last-scan-time');
                if (lastScanEl) {
                    lastScanEl.textContent = data.last_scan;
                    
                    // Actualizar estado del escaneo
                    const scanStatusEl = document.getElementById('scan-status');
                    if (scanStatusEl) {
                        const scanTime = data.last_scan;
                        if (scanTime === 'Nunca') {
                            scanStatusEl.textContent = 'Nunca escaneado';
                            scanStatusEl.style.color = 'var(--danger)';
                        } else {
                            const now = new Date();
                            const scanDate = new Date(`2000-01-01 ${scanTime}`);
                            scanDate.setFullYear(now.getFullYear(), now.getMonth(), now.getDate());
                            const diffMinutes = Math.floor((now - scanDate) / (1000 * 60));
                            
                            if (diffMinutes < 5) {
                                scanStatusEl.textContent = 'Reciente';
                                scanStatusEl.style.color = 'var(--success)';
                            } else if (diffMinutes < 30) {
                                scanStatusEl.textContent = `${diffMinutes} min atrás`;
                                scanStatusEl.style.color = 'var(--warning)';
                            } else {
                                scanStatusEl.textContent = `${Math.floor(diffMinutes/60)}h atrás`;
                                scanStatusEl.style.color = 'var(--danger)';
                            }
                        }
                    }
                }
                
                // Actualizar porcentaje de activos
                const totalEl = document.getElementById('stat-total');
                if (totalEl && data.total_devices) {
                    const active = data.active_devices || 0;
                    const total = data.total_devices;
                    const percentage = Math.round((active / total) * 100);
                    
                    const percentageEl = document.getElementById('active-percentage');
                    if (percentageEl) {
                        percentageEl.textContent = `${percentage}% activos`;
                    }
                }
                
                // Actualizar última actualización
                const lastUpdateEl = document.getElementById('last-update');
                if (lastUpdateEl) {
                    lastUpdateEl.textContent = new Date().toLocaleTimeString();
                }
                
            } catch (parseError) {
                console.error('Error parseando SSE data:', parseError);
            }
        });
        
        evtSource.addEventListener('error', (e) => {
            console.error('SSE Error:', e);
            
            if (sseStatusEl) {
                sseStatusEl.textContent = '🔴 Desconectado';
                sseStatusEl.style.color = 'var(--danger)';
            }
            
            // Reconectar después de 5 segundos
            setTimeout(() => {
                if (this.sseConnection) {
                    this.sseConnection.close();
                }
                this.initSSE();
            }, 5000);
        });
        
        evtSource.addEventListener('timeout', () => {
            console.log('SSE: Timeout, reconectando...');
            evtSource.close();
            setTimeout(() => this.initSSE(), 2000);
        });
        
        evtSource.addEventListener('close', () => {
            console.log('SSE: Conexión cerrada por el servidor');
            if (sseStatusEl) {
                sseStatusEl.textContent = '⚫ Cerrado';
                sseStatusEl.style.color = 'var(--text-secondary)';
            }
        });
        
        this.sseConnection = evtSource;
    }

    async handleLogout() {
        try {
            await fetch('/lisi3309/api/auth/logout.php', {
                credentials: 'include'
            });
            this.app.user = null;
            this.app.router('/login');
        } catch (e) {
            console.error('Error en logout:', e);
            this.app.toast('Error al cerrar sesión', 'danger');
        }
    }

    handleDownload() {
        window.location.href = '/lisi3309/api/files/download.php?file=NetworkScanner_Setup.exe';
    }

    // Limpiar recursos al destruir
    destroy() {
        if (this.sseConnection) {
            this.sseConnection.close();
        }
        if (window.dashboardView === this) {
            delete window.dashboardView;
        }
    }
}