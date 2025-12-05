# API REST - Documentación

## Endpoint de Recepción de Datos

### URL
```
POST http://TU_IP_O_DOMINIO/server/api/receive.php
```

### Headers
```
Content-Type: application/json
```

### Formato de Petición

```json
{
  "Devices": [
    {
      "IP": "192.168.1.100",
      "MAC": "AA:BB:CC:DD:EE:FF",
      "Hostname": "PC-EJEMPLO",
      "OpenPorts": "80,443,3306"
    },
    {
      "IP": "192.168.1.101",
      "MAC": "11:22:33:44:55:66",
      "Hostname": "SERVER-01",
      "OpenPorts": "22,80,443"
    }
  ]
}
```

### Campos

| Campo | Tipo | Requerido | Descripción |
|-------|------|-----------|-------------|
| `Devices` | Array | Sí | Lista de dispositivos detectados |
| `Devices[].IP` | String | Sí | Dirección IP del dispositivo |
| `Devices[].MAC` | String | No | Dirección MAC (formato: XX:XX:XX:XX:XX:XX o XX-XX-XX-XX-XX-XX) |
| `Devices[].Hostname` | String | No | Nombre del host |
| `Devices[].OpenPorts` | String | No | Puertos abiertos separados por comas (ej: "80,443,3306") |

### Respuestas

#### Éxito (200 OK)
```json
{
  "success": true,
  "message": "Datos recibidos correctamente",
  "summary": {
    "processed": 2,
    "conflicts": 0,
    "errors": 0
  }
}
```

#### Error de Validación (400 Bad Request)
```json
{
  "success": false,
  "message": "Datos inválidos",
  "errors": [
    "Dispositivo #0: IP es requerida",
    "Dispositivo #1: MAC '12:34:56' no es válida"
  ]
}
```

#### Error del Servidor (500 Internal Server Error)
```json
{
  "success": false,
  "message": "Error del servidor: <detalle>"
}
```

## Configuración del Agente

### Archivo: `agent/config.ps1`

```powershell
# Modo de Operación
# - "local": Procesa localmente con cron_process.php
# - "api": Envía a API remota
# - "hybrid": Intenta API primero, fallback a local
$OperationMode = "hybrid"

# Configuración de API
$ApiEnabled = $true
$ApiUrl = "http://localhost/escaner-red/server/api/receive.php"
$ApiTimeout = 10  # segundos
$ApiRetries = 3
$ApiRetryDelay = 2  # segundos entre reintentos
```

## Modos de Operación

### 1. Modo Local
- Guarda resultados en `scan_results.json`
- Ejecuta `cron_process.php` localmente
- No requiere conectividad de red

### 2. Modo API
- Envía datos directamente a la API REST
- Requiere conectividad con el servidor
- Reintentos automáticos en caso de fallo

### 3. Modo Híbrido (Recomendado)
- Intenta enviar a la API primero
- Si falla después de los reintentos, procesa localmente
- Mejor de ambos mundos: robustez + centralización

## Logs

Los logs de la API se guardan en:
```
logs/api_requests.log
```

Formato:
```
[2025-12-04 17:00:00] Petición recibida | Data: {"ip":"192.168.1.1","devices_count":5}
[2025-12-04 17:00:01] Procesamiento exitoso | Data: {"processed":5,"conflicts":0,"errors":0}
```

## Ejemplo de Uso con cURL

```bash
curl -X POST http://localhost/escaner-red/server/api/receive.php \
  -H "Content-Type: application/json" \
  -d '{
    "Devices": [
      {
        "IP": "192.168.1.100",
        "MAC": "AA:BB:CC:DD:EE:FF",
        "Hostname": "PC-TEST",
        "OpenPorts": "80,443"
      }
    ]
  }'
```

## Ejemplo de Uso con PowerShell

```powershell
$payload = @{
    Devices = @(
        @{
            IP = "192.168.1.100"
            MAC = "AA:BB:CC:DD:EE:FF"
            Hostname = "PC-TEST"
            OpenPorts = "80,443"
        }
    )
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost/escaner-red/server/api/receive.php" `
    -Method Post `
    -Body $payload `
    -ContentType "application/json"
```

## Seguridad

### CORS
La API acepta peticiones desde cualquier origen (`Access-Control-Allow-Origin: *`). 
Para producción, considera restringir esto a dominios específicos.

### Autenticación
Actualmente no implementada. Para producción, considera agregar:
- API Keys
- JWT Tokens
- IP Whitelisting

### Rate Limiting
No implementado actualmente. Considera agregar límites de peticiones por IP para prevenir abuso.

## Troubleshooting

### Error: "could not find driver"
- Solución: Habilita `extension=pdo_mysql` en `php.ini`

### Error: "Connection refused"
- Verifica que el servidor web (Apache/Nginx) esté corriendo
- Verifica que la URL sea correcta
- Verifica firewall/permisos

### Error: "Datos inválidos"
- Revisa el formato JSON
- Asegúrate de que el campo `Devices` sea un array
- Verifica que las IPs sean válidas
