# Guía de Contribución

¡Gracias por tu interés en contribuir al **Monitor de Actividad de Protocolos de Red**! Este documento establece los lineamientos para asegurar que el desarrollo del proyecto sea ordenado, profesional y de alta calidad.

## 📋 Requisitos Previos

Antes de comenzar, asegúrate de tener configurado tu entorno de desarrollo con las siguientes herramientas:

*   **IDE Recomendado**: Visual Studio 2022 (para Backend/Servicio) y Visual Studio Code (para Frontend/Docs).
*   **Control de Versiones**: Git (última versión estable).
*   **Lenguajes y Frameworks**:
    *   .NET 6.0 SDK o superior.
    *   Node.js v16+ y npm v8+.
    *   MySQL Server 8.0+.
*   **Herramientas Adicionales**:
    *   Postman o Insomnia para pruebas de API.
    *   Wireshark (opcional, para validación de capturas).

## 🔀 Flujo de Trabajo (Git Flow)

Utilizamos una variante simplificada de Git Flow. La rama principal es `main`, que contiene el código estable y listo para producción. La rama de desarrollo es `develop`.

### Ramas
Todas las nuevas ramas deben crearse a partir de `develop` (o `main` si es un hotfix) y seguir esta convención de nombres:

*   `feature/nombre-de-la-funcionalidad`: Para nuevas características (ej. `feature/dashboard-graficas`).
*   `bugfix/descripcion-del-error`: Para corrección de errores no críticos (ej. `bugfix/validacion-ip`).
*   `hotfix/error-critico`: Para errores urgentes en producción (ej. `hotfix/crash-servicio`).
*   `docs/nombre-documentacion`: Para cambios en documentación (ej. `docs/actualizar-readme`).
*   `refactor/nombre-refactor`: Para mejoras de código sin cambios funcionales.

## 💾 Estándar de Commits

Seguimos la convención de **Conventional Commits**. Cada mensaje de commit debe tener el siguiente formato:

```text
<tipo>(<alcance>): <descripción breve>

[Cuerpo opcional con más detalles]
```

### Tipos permitidos:
*   `feat`: Nueva funcionalidad.
*   `fix`: Corrección de errores.
*   `docs`: Cambios en documentación.
*   `style`: Cambios de formato (espacios, puntos y comas, etc.).
*   `refactor`: Refactorización de código.
*   `test`: Añadir o corregir pruebas.
*   `chore`: Tareas de mantenimiento, actualización de dependencias, etc.

**Ejemplos:**
*   `feat(agente): implementar captura de paquetes UDP`
*   `fix(api): corregir error 500 en endpoint de reportes`
*   `docs(readme): agregar sección de instalación`

## 🚀 Instalación y Configuración

### 1. Base de Datos
1.  Crea la base de datos usando el script `db/schema.sql`.
2.  Configura la cadena de conexión en el archivo de configuración del servicio y la API.

### 2. Backend y Servicio
1.  Abre la solución `.sln` en Visual Studio.
2.  Restaura los paquetes NuGet.
3.  Compila el proyecto (`Ctrl + Shift + B`).

### 3. Frontend
1.  Navega a la carpeta `frontend`.
2.  Ejecuta `npm install`.
3.  Ejecuta `npm run dev` para iniciar el servidor local.

## 🎨 Reglas de Estilo de Código

*   **C#**: Seguir las convenciones estándar de Microsoft (.NET Design Guidelines). Usar PascalCase para métodos y clases, camelCase para variables locales.
*   **JavaScript/React**: Usar ESLint con la configuración estándar. Preferir componentes funcionales y Hooks.
*   **SQL**: Palabras clave en MAYÚSCULAS (SELECT, FROM, WHERE). Nombres de tablas en snake_case.
*   **Comentarios**: El código debe ser auto-explicativo, pero se requiere documentación XML (`///`) para métodos públicos complejos.

## 📥 Solicitud de Pull Request (PR)

1.  Asegúrate de que tu rama está actualizada con `develop`.
2.  Ejecuta todas las pruebas locales para asegurar que no hay regresiones.
3.  Sube tus cambios (`git push`).
4.  Crea el Pull Request en GitHub apuntando a `develop`.
5.  **Descripción del PR**:
    *   Enlaza el Issue relacionado (si existe).
    *   Describe qué cambios se hicieron y por qué.
    *   Adjunta capturas de pantalla si es un cambio visual.
6.  Espera la revisión de al menos un mantenedor del proyecto.

## 🧪 Pruebas y Calidad

*   No se aceptarán PRs que rompan la compilación.
*   Si agregas una nueva funcionalidad, idealmente debe incluir pruebas unitarias.
*   Verifica que no haya advertencias (warnings) críticas en la compilación.

---
¡Tu colaboración es vital para el éxito de este proyecto! Si tienes dudas, abre un Issue etiquetado como `question`.
