# Changelog

Todos los cambios notables en este proyecto serán documentados en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/),
y este proyecto adhiere a [Semantic Versioning](https://semver.org/lang/es/).

## [Unreleased]

### Added
- Soporte para exportación de reportes en formato Excel (.xlsx).
- Nueva métrica de "Ancho de banda por dispositivo" en el Dashboard.

### Changed
- Actualización de la librería de gráficos a Chart.js v4.0 para mejor rendimiento.

## [0.4.0] - 2023-11-15

### Added
- **Base de Datos**: Implementación completa del esquema relacional en MySQL.
- Script `db/schema.sql` para inicialización automática de tablas.
- Procedimientos almacenados para inserción masiva de logs.

### Changed
- El servicio de Windows ahora guarda los datos en MySQL en lugar de archivos locales JSON.
- Refactorización del módulo de conexión a base de datos para usar Entity Framework Core.

## [0.3.0] - 2023-10-20

### Added
- **Validaciones**: Sistema de detección de conflictos de IP duplicada.
- Alerta visual en el Dashboard cuando dos MACs diferentes reclaman la misma IP.
- Validación de integridad de hostname contra registros previos.

### Fixed
- Error que causaba que el servicio se detuviera si la red se desconectaba brevemente.
- Corrección en la lectura de direcciones MAC en adaptadores virtuales.

## [0.2.0] - 2023-09-10

### Added
- **Capturador**: Implementación inicial del agente de captura de paquetes.
- Detección básica de protocolos TCP y UDP.
- Identificación del fabricante del dispositivo basado en la OUI de la MAC.
- Endpoint API `/capturas` para recibir datos del agente.

### Changed
- Mejora en la precisión del timestamp de captura (milisegundos).

## [0.1.0] - 2023-08-01

### Added
- Configuración inicial del repositorio y estructura del proyecto.
- Archivo `README.md` inicial.
- Servicio de Windows básico (esqueleto) que se instala y arranca.
- API REST "Hola Mundo" en Node.js para pruebas de conectividad.
