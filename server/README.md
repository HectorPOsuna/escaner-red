# Backend Server - Escáner de Red

Servidor Node.js para recibir, validar y almacenar los resultados del escáner de red.

## 📋 Requisitos

- Node.js v14+
- MySQL
- Archivo `.env` en la raíz del proyecto (ver `../database/README.md` o `.env.example`)

## 🚀 Instalación

```bash
cd server
npm install
```

## ▶️ Ejecución

### Modo Desarrollo (con recarga automática)
```bash
npm run dev
```

### Modo Producción
```bash
npm start
```

El servidor correrá por defecto en `http://localhost:3000`.

## 🛡️ Funcionalidades

### Endpoint: `POST /api/scan-results`

Recibe el JSON del escáner y realiza:

1.  **Validación de Conflictos**:
    - **IP Duplicada**: Si la IP ya existe con otro Hostname/MAC.
    - **MAC Duplicada**: Si la MAC ya existe con otro Hostname.
    - Los conflictos se registran en la tabla `conflictos`.

2.  **Persistencia de Datos**:
    - **Fabricantes**: Se guardan automáticamente si no existen.
    - **Equipos**: Se actualizan (upsert) basados en MAC o IP.
    - **Protocolos**: Se registra el historial de puertos abiertos en `protocolos_usados`.

## 📁 Estructura

- `app.js`: Punto de entrada.
- `routes/`: Definición de endpoints.
- `controllers/`: Lógica de negocio y validación.
- `services/`: Interacción con la base de datos.
