# Manual de Usuario - Escáner de Red

## Introducción
Bienvenido al sistema de **Monitor de Actividad de Protocolos de Red**. Este manual te guiará en el uso del Panel de Control (Dashboard) y la aplicación de monitoreo en segundo plano.

---

## 1. Aplicación de Bandeja (System Tray App)

El sistema cuenta con un "Agente" silencioso que se ejecuta en tu computadora para escanear la red. Lo verás como un icono en la barra de tareas (cerca del reloj).

### Estados del Icono
*   🟢 **Verde (Activo)**: El servicio está corriendo y escaneando la red periódicamente.
*   🔴 **Rojo (Detenido)**: El servicio está pausado. No se están actualizando datos.
*   🟡 **Amarillo (Alerta)**: Se ha detectado un error o advertencia en el último escaneo.

### Acciones del Menú Contextual
Al dar clic derecho sobre el icono podrás:

1.  **Iniciar Servicio**: Reactiva el escaneo automático.
2.  **Detener Servicio**: Pausa temporalmente el escaneo.
3.  **Ver Logs**: Abre una ventana con el registro detallado de actividades (útil si hay problemas).
4.  **Abrir Dashboard**: Lanza el panel web en tu navegador predeterminado.
5.  **Salir**: Cierra completamente la aplicación (dejará de escanear).

---

## 2. Panel de Control Web (Dashboard)

El Dashboard es donde puedes ver todos los dispositivos conectados a tu red. Se accede típicamente vía `http://localhost/escaner-red` (o la dirección que te haya dado el administrador).

### 2.1 Vista Principal (Resumen)

En la parte superior encontrarás métricas clave:
*   **Total Dispositivos**: Número de equipos únicos vistos en la red.
*   **Conflictos Activos**: Alerta roja si hay direcciones IP duplicadas.
*   **Protocolos Inseguros**: Conteo de puertos abiertos que representan riesgo (ej. Telnet, FTP).

### 2.2 Lista de Dispositivos

La tabla principal muestra cada equipo encontrado:

*   **Estado**:
    *   🟢 Online (Visto hace menos de 10 minutos).
    *   ⚪ Offline.
*   **Hostname**: Nombre del equipo.
*   **IP / MAC**: Identificadores de red.
*   **Fabricante**: Marca del dispositivo (ej. Apple, Dell, Intel), detectada automáticamente.
*   **Sistema Operativo**: El sistema intenta adivinar si es Windows, Linux, Impresora, etc.
*   **Puertos/Servicios**: Iconos que indican qué tiene abierto ese equipo:
    *   🌐 Web (HTTP/HTTPS)
    *   📁 Archivos (SMB/FTP)
    *   💻 Remoto (RDP/SSH)
    *   🖨️ Impresora

### 2.3 Gestión de Conflictos

Si el sistema detecta que dos equipos usan la misma IP:
1.  Aparecerá una alerta en la sección **Conflictos**.
2.  Verás la IP afectada y las dos direcciones MAC que compiten por ella.
3.  **Acción Recomendada**: Verificar esos dos equipos físicamente o revisar la configuración DHCP de tu router.

---

## 3. Preguntas Frecuentes (FAQ)

**P: ¿Por qué dice "Sistema Operativo: Desconocido"?**
R: Algunos dispositivos tienen firewall activado y no responden al escaneo profundo. El sistema necesita al menos un puerto abierto o respuesta al ping para adivinar el SO.

**P: ¿El escáner alenta mi internet?**
R: No. El escaneo está diseñado para ser ligero y ocurre solo periódicamente.

**P: ¿Cómo soluciono un conflicto de IP?**
R: Generalmente, reiniciando los dos equipos afectados para que pidan una nueva IP al router se soluciona. Si persiste, verifica que no tengan configurada una IP fija (Estática) idéntica.
