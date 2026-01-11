# Manual de Usuario - Client System Agent

**Bienvenido** al manual de usuario del **Client System Agent** (Agente de Sistema Cliente).
Esta guía le ayudará a entender qué es este programa, cómo instalarlo y cómo funciona en su computadora.

---

## 1. ¿Qué es este programa?

El **Client System Agent** es una pequeña herramienta de diagnóstico y seguridad diseñada para instituciones y redes corporativas.

Su función principal es realizar un "chequeo de salud" automático de su computadora. Imagine que es como un médico que visita su PC periódicamente para revisar:
*   Quién es (Nombre del equipo y modelo).
*   Dónde está (Dirección IP en la red).
*   Qué "puertas" están abiertas (Puertos de comunicación).

Esta información ayuda a los administradores de red a mantener el inventario actualizado y detectar problemas de seguridad antes de que se conviertan en amenazas.

---

## 2. Requisitos del Sistema

Para que el agente funcione correctamente, su equipo debe cumplir con lo siguiente:

*   **Sistema Operativo:** Windows 10, Windows 11 o Windows Server.
*   **Permisos:** Se requieren permisos de Administrador únicamente para la instalación.
*   **Conexión:** Debe tener conexión a la red interna de la organización (Intranet).

---

## 3. Instalación

La instalación está diseñada para ser rápida y silenciosa, sin interrumpir su trabajo.

### Pasos para instalar:
1.  Recibirá un archivo instalador (generalmente llamado `Setup_ClientAgent.exe`).
2.  Haga doble clic sobre el archivo.
3.  Es posible que Windows le pida confirmación para permitir cambios en el equipo. Haga clic en **Sí** o **Aceptar**.
4.  El instalador configurará todo automáticamente en unos segundos.

**¡Listo!** No verá ventanas emergentes ni iconos en el escritorio. El agente está diseñado para trabajar "bajo el capó".

---

## 4. Funcionamiento General

Una vez instalado, el agente funciona de manera **automática** y **transparente**.

*   **Inicio Automático:** El programa se enciende solo cuando usted prende su computadora.
*   **Segundo Plano:** Trabaja en segundo plano sin mostrar ventanas ni notificaciones que lo distraigan.
*   **Consumo Mínimo:** Está optimizado para usar muy poca memoria y procesador, por lo que no notará que su PC está más lenta.

### ¿Qué hace exactamente?
Cada **5 minutos** (o el tiempo configurado por su administrador), el agente despierta, revisa la configuración de red de su equipo y envía un reporte seguro al servidor central. Luego vuelve a "dormir".

---

## 5. ¿Cómo sé que está funcionando?

Dado que el programa no tiene interfaz visual (ventanas), puede verificar que está corriendo de la siguiente manera:

1.  Presione las teclas `Ctrl + Shift + Esc` para abrir el **Administrador de Tareas**.
2.  Vaya a la pestaña **Servicios**.
3.  Busque en la lista un servicio llamado **"Network Scanner Service"** (o Client System Agent).
4.  El estado debe decir **"En ejecución"** (Running).

---

## 6. Información que Recopila

Por razones de transparencia, listamos aquí los datos que el agente lee de su equipo. **El agente NO lee sus archivos personales, correos ni contraseñas.**

Solo recolecta información técnica:
1.  **Identidad:**
    *   Nombre del equipo (ej. `PC-CONTABILIDAD-01`).
    *   Fabricante (ej. `Dell`, `HP`).
    *   Modelo del sistema.
2.  **Sistema:**
    *   Versión de Windows instalada.
3.  **Red:**
    *   Dirección IP (su "número telefónico" en la red).
    *   Dirección MAC (identificador único de su tarjeta de red).
4.  **Seguridad (Puertos):**
    *   Lista de servicios que están escuchando conexiones (ej. Escritorio Remoto, Carpetas Compartidas).
    *   Esto es vital para saber si su PC tiene "puertas traseras" abiertas.

---

## 7. Preguntas Frecuentes (FAQ)

**P: ¿El programa hará lenta mi computadora?**
**R:** No. El agente es extremadamente ligero y pasa el 99% del tiempo inactivo.

**P: ¿El agente espía lo que hago en internet?**
**R:** No. El agente no monitorea su navegación, ni su historial, ni sus archivos. Solo mira la configuración técnica de la red.

**P: ¿Puedo cerrarlo si necesito más velocidad para un juego o programa pesado?**
**R:** No se recomienda. Al ser un servicio de sistema, está protegido para garantizar la seguridad de la red organizacional. Su consumo es tan bajo que cerrarlo no mejorará el rendimiento de juegos.

**P: ¿Necesito actualizarlo manualmente?**
**R:** No. Si se requiere una actualización, esta será desplegada automáticamente por los administradores de sistemas.

---

## 8. Desinstalación

Si necesita eliminar el agente (por ejemplo, si va a dar de baja el equipo), debe hacerlo desde el Panel de Control, como cualquier otro programa:

1.  Abra el menú Inicio y escriba **"Panel de Control"**.
2.  Vaya a **Programas y Características** (o "Desinstalar un programa").
3.  Busque **"Client System Agent"** en la lista.
4.  Haga clic derecho y seleccione **Desinstalar**.
5.  Siga las instrucciones en pantalla.

---
*Documento generado para uso interno y educativo.*
