# [](https://github.com/HectorPOsuna/escaner-red/compare/v0.1.0...v) (2025-12-08)


### Bug Fixes

* error de sintaxis en networkScanner.ps1 ([2a10349](https://github.com/HectorPOsuna/escaner-red/commit/2a10349997e9dad53f7e5a5f628f36697c132c78))
* Solucion completa del codigo y sus corchetes. ([60e48ef](https://github.com/HectorPOsuna/escaner-red/commit/60e48ef3db5d462cb27319428862fb2405ef6555))
* solucion en la sintaxis de corchetes del codigo. ([4e44ed6](https://github.com/HectorPOsuna/escaner-red/commit/4e44ed6d850a042dfc5afaec521cebf8a2429d12))


### Features

* Add CHANGELOG.md to set up conventional changelog generation. ([43f2c86](https://github.com/HectorPOsuna/escaner-red/commit/43f2c86bad7045b13070abcc8cd36149b51c0e3d))
* add first prototype for network scanner (initial version) ([f6078d7](https://github.com/HectorPOsuna/escaner-red/commit/f6078d7c04a8f78936e57494f32f11836d5f3654))
* Agregar archivos de caché de resultados de escaneo de red, reporte, marcas de tiempo del último escaneo y bloqueo de dependencias del servidor. ([b65bd42](https://github.com/HectorPOsuna/escaner-red/commit/b65bd42932a0f4d2dff4322e2945358ee1c162f6))
* Agregar CHANGELOG.md para configurar la generación de changelog convencional. ([c8bfe0d](https://github.com/HectorPOsuna/escaner-red/commit/c8bfe0ddcf3971c8624752ff517e3e008afe6826))
* Agregar definición de tabla protocolos incluyendo puerto, nombre, categoría e índices. ([611b240](https://github.com/HectorPOsuna/escaner-red/commit/611b24060b07c074733a83446e47ecb3f86714b8))
* agregar dependencia dotenv ([7b1492e](https://github.com/HectorPOsuna/escaner-red/commit/7b1492e9b972dbc35906976a319c4dd7e904a987))
* Agregar esquema BD inicial con tablas para inventario, protocolos, conflictos, logs y datos base. ([fe02448](https://github.com/HectorPOsuna/escaner-red/commit/fe024489c89d4b986970adf6ffe43b90f01a697a))
* agregar módulo de base de datos para gestión de conexiones y carga de datos OUI. ([3fcb474](https://github.com/HectorPOsuna/escaner-red/commit/3fcb474774a8f6f47eae5fb34b011d6a1cc458c2))
* agregar script de inicialización de BD. ([e0c72e2](https://github.com/HectorPOsuna/escaner-red/commit/e0c72e26664e6dfa93022dd1c801dd4ef29ede6b))
* agregar script para inicializar la base de datos ejecutando migraciones SQL ([37ef39f](https://github.com/HectorPOsuna/escaner-red/commit/37ef39fbf7745c2bcfc6774bf1abb0cae5192286))
* Agregar servicio de BD y esquema inicial para gestión de datos del escáner de red. ([815a637](https://github.com/HectorPOsuna/escaner-red/commit/815a637a9a387bbe8c6dd5bbd3a77c2d2a369217))
* Agregar servicio Windows para ejecución periódica del agente de escaneo, con configuración y documentación de integración. ([cb6b252](https://github.com/HectorPOsuna/escaner-red/commit/cb6b252a0c57eb037b98ea2c61c41a9de2e39e0e))
* Agregar tabla conflictos y sus índices para registrar conflictos de red. ([d207589](https://github.com/HectorPOsuna/escaner-red/commit/d207589a6d97013a2c16832f55aae7d44f36ff26))
* Agregar tabla de conflictos y sus índices para logs de red. ([315fc6c](https://github.com/HectorPOsuna/escaner-red/commit/315fc6cf641c925a23e1be582ead1cd110ecdba2))
* agregar tabla pivote protocolos_usados con claves foráneas e índices. ([0c183ef](https://github.com/HectorPOsuna/escaner-red/commit/0c183ef096bc536d3c676206350ff7dcd15a1771))
* Agregar utilidad de conexión a base de datos y script de creación de tabla fabricantes. ([6772db1](https://github.com/HectorPOsuna/escaner-red/commit/6772db1a42cb82dd000b34707dfeee55aefacdf2))
* agregar utilidades de conexión a base de datos iniciales y script de inicialización. ([99c930d](https://github.com/HectorPOsuna/escaner-red/commit/99c930d170f932f31f48bb93d55e1fd7ad4f7ca7))
* añadiendo la dependencia mysql2 ([2f57473](https://github.com/HectorPOsuna/escaner-red/commit/2f5747386b643a65049bc4af35aa9798fddb471f))
* compilacion del windows service ([cb2f5a6](https://github.com/HectorPOsuna/escaner-red/commit/cb2f5a6e544782bd64f1adf2c30aabc5b587d7ba))
* Configuración inicial de solución NetworkScanner con proyectos compartidos, servicios, UI y agente. ([172b229](https://github.com/HectorPOsuna/escaner-red/commit/172b229902170b0e49ebc6945bc2f1d20499834b))
* Crear tabla equipos para inventario de dispositivos de red, incluyendo esquema, clave foránea e índices. ([8b3f258](https://github.com/HectorPOsuna/escaner-red/commit/8b3f258363aa93aa475a4b3516ac69a5e9360a60))
* detect OS based on TTL values ([8d4b929](https://github.com/HectorPOsuna/escaner-red/commit/8d4b92955a4c0874a7dddf8328f761fc625b527d))
* identificacion de protocolos y puertos abiertos para cada host en la red ([4d8736a](https://github.com/HectorPOsuna/escaner-red/commit/4d8736a2adac784a1b43844b52f953359f72ef9c))
* implementacion de la conexion a la api de php ([35bcfb0](https://github.com/HectorPOsuna/escaner-red/commit/35bcfb0b60ebb557144483d0001ba20fd60c7ad1))
* implementacion de mapeo de fabricante con MAC address ([6820aea](https://github.com/HectorPOsuna/escaner-red/commit/6820aea3bf5b8f6b9ed507a510d8c0c32a43f5ce))
* implementacion de modo local para el networkscanner.ps1 ([2ae1316](https://github.com/HectorPOsuna/escaner-red/commit/2ae131636bb5713ab3da4d762b776456cb46bbd4))
* implementacion de timestamp para ver la ultima vez escaneado. ([f176933](https://github.com/HectorPOsuna/escaner-red/commit/f1769331f9efca326f8d91e57f199d00711b6e05))
* implementacion de un formato de hora y reestructuracion de el formato de salida de los puertos. ([6a1a913](https://github.com/HectorPOsuna/escaner-red/commit/6a1a9131b618e122d08c0a9c314c9e473f2464a5))
* implementacion de una nueva categoria de listado en los protocolos de los puertos. ([0f50d53](https://github.com/HectorPOsuna/escaner-red/commit/0f50d531e30f3a7a7994b0d86223beddc646d275))
* implementacion de watchdog para gestion de errores, asi como la construccion de un ejecutable .exe mediante inno setup ([80d11be](https://github.com/HectorPOsuna/escaner-red/commit/80d11be1e51d3d59b1632d576dcd6250dc1421b0))
* Implementar agente de escaneo de red con endpoint API para recepción, validación y documentación de datos. ([8e80b25](https://github.com/HectorPOsuna/escaner-red/commit/8e80b25f3f775250725ca6b7b472f9062387bd2d))
* Implementar agente de escaneo de red, procesamiento en servidor y configuración de BD en lenguaje php ([27773e7](https://github.com/HectorPOsuna/escaner-red/commit/27773e7dc6fdfa2f3418646687dce3576c15bb9d))
* Implementar esquema BD y servicio para gestionar dispositivos, protocolos y conflictos de red. ([c4d98ac](https://github.com/HectorPOsuna/escaner-red/commit/c4d98acaeacdc750b8990e1e429f361f75b302ae))
* Implementar módulo inicial de base de datos con carga de protocolos IANA y endpoint API para resultados de escaneo. ([23da76d](https://github.com/HectorPOsuna/escaner-red/commit/23da76d432674b72eba72d55818adf0b928cfd34))
* Implementar nueva UI WPF para escaneo de red y monitoreo del sistema, y actualizar agente PowerShell para soportar configuración JSON. ([e3c68ff](https://github.com/HectorPOsuna/escaner-red/commit/e3c68ff497b2f2b84cff6a68bc65a07ee2008d88))
* Implementar servicio inicial de base de datos con operaciones CRUD para entidades de red y procesamiento de resultados de escaneo con detección de conflictos. ([da334fc](https://github.com/HectorPOsuna/escaner-red/commit/da334fc663c8b1ece5aaa43e6b6d7036a4930b36))
* Implementar servicio Windows para escaneo de red con script de instalación y lógica de ejecución. ([bc50141](https://github.com/HectorPOsuna/escaner-red/commit/bc5014110cbc6f0cff4eca821f73bd94427c5115))
* Implementar servicios backend para procesar resultados de escaneo de red, gestionar dispositivos de red y detectar conflictos. ([85cf5e2](https://github.com/HectorPOsuna/escaner-red/commit/85cf5e22b48763fe40f0dbbbc7ff011f9913e49c))
* Implementar un script de escaneo de red en PowerShell integral para descubrimiento de hosts, detección de SO, búsqueda de MAC, identificación de fabricantes y escaneo de puertos. ([997fab0](https://github.com/HectorPOsuna/escaner-red/commit/997fab0dd3ce25c09e68e23494c851f00defdb4e))
* Implementar un sistema de escaneo de red con agente PowerShell para detección de IP/puerto/SO y un backend Node.js para almacenamiento de datos y gestión de protocolos. ([b64c4e4](https://github.com/HectorPOsuna/escaner-red/commit/b64c4e4b6f92c2b8f856d42d2c05a385811b115c))
* Inicializar archivo de proyecto .NET para NetworkScannerService. ([c2bccd2](https://github.com/HectorPOsuna/escaner-red/commit/c2bccd2c0e027d84855bf39d1b0c98131c7469fc))
* Inicializar proyecto de servidor con dependencias, definir esquema inicial de base de datos y agregar agente de escaneo de red en PowerShell. ([d647421](https://github.com/HectorPOsuna/escaner-red/commit/d6474216d6099a0d050952a491feed41b32b37c9))
* Inicializar servidor backend Express.js para procesar resultados de escaneo de red y persistir datos en MySQL. ([ea0d678](https://github.com/HectorPOsuna/escaner-red/commit/ea0d6786a019cc120fd99de4ef3168b3c8f76047))
* Introducir procesamiento de resultados de escaneo para detectar conflictos, actualizar/insertar dispositivos y registrar protocolos. ([1a640ab](https://github.com/HectorPOsuna/escaner-red/commit/1a640ab7d004d0b910c888fadc5e86d176cfbe5e))
* Introducir UI de escáner, estructura de proyecto de servicio, resolvedor de rutas compartidas y archivos de datos del agente. ([3b5f813](https://github.com/HectorPOsuna/escaner-red/commit/3b5f813917d5d380b25306f8e2f9319a1f9b0b1d))
* mejoras en el icono, ademas de una UI renovada y mas amigable ([ff6b720](https://github.com/HectorPOsuna/escaner-red/commit/ff6b7209f8f4d9b2cb24a4e91f0217c4329e075e))
* **metadata:** add hostname detection ([2bd8835](https://github.com/HectorPOsuna/escaner-red/commit/2bd883582af9bf5b7c446c7e86d742f52d55c68b))
* retrieve MAC addresses using ARP table ([d779f56](https://github.com/HectorPOsuna/escaner-red/commit/d779f564a98510af4b5b7e488982c9278c776e28))
* se ha implementado el sedeo automaticamente al init-db ([5012637](https://github.com/HectorPOsuna/escaner-red/commit/5012637c8ed6638a37e5670352c9943af9993543))
* set up conventional changelog generation with `conventional-changelog-cli` and `CHANGELOG.md`. ([f312e36](https://github.com/HectorPOsuna/escaner-red/commit/f312e36f5463b5ad64a215b1aa09461419c33416))
* validacion local que evita capturas duplicadas ([9fb0acf](https://github.com/HectorPOsuna/escaner-red/commit/9fb0acffb2843263c398efc61aeb9e91bf2613fd))



# [](https://github.com/HectorPOsuna/escaner-red/compare/v0.1.0...v) (2025-12-04)


### Features

* Add CHANGELOG.md to set up conventional changelog generation. ([43f2c86](https://github.com/HectorPOsuna/escaner-red/commit/43f2c86bad7045b13070abcc8cd36149b51c0e3d))
* add first prototype for network scanner (initial version) ([f6078d7](https://github.com/HectorPOsuna/escaner-red/commit/f6078d7c04a8f78936e57494f32f11836d5f3654))
* Agregar archivos de caché de resultados de escaneo de red, reporte, marcas de tiempo del último escaneo y bloqueo de dependencias del servidor. ([b65bd42](https://github.com/HectorPOsuna/escaner-red/commit/b65bd42932a0f4d2dff4322e2945358ee1c162f6))
* Agregar CHANGELOG.md para configurar la generación de changelog convencional. ([c8bfe0d](https://github.com/HectorPOsuna/escaner-red/commit/c8bfe0ddcf3971c8624752ff517e3e008afe6826))
* Agregar definición de tabla protocolos incluyendo puerto, nombre, categoría e índices. ([611b240](https://github.com/HectorPOsuna/escaner-red/commit/611b24060b07c074733a83446e47ecb3f86714b8))
* agregar dependencia dotenv ([7b1492e](https://github.com/HectorPOsuna/escaner-red/commit/7b1492e9b972dbc35906976a319c4dd7e904a987))
* Agregar esquema BD inicial con tablas para inventario, protocolos, conflictos, logs y datos base. ([fe02448](https://github.com/HectorPOsuna/escaner-red/commit/fe024489c89d4b986970adf6ffe43b90f01a697a))
* agregar módulo de base de datos para gestión de conexiones y carga de datos OUI. ([3fcb474](https://github.com/HectorPOsuna/escaner-red/commit/3fcb474774a8f6f47eae5fb34b011d6a1cc458c2))
* agregar script de inicialización de BD. ([e0c72e2](https://github.com/HectorPOsuna/escaner-red/commit/e0c72e26664e6dfa93022dd1c801dd4ef29ede6b))
* agregar script para inicializar la base de datos ejecutando migraciones SQL ([37ef39f](https://github.com/HectorPOsuna/escaner-red/commit/37ef39fbf7745c2bcfc6774bf1abb0cae5192286))
* Agregar servicio de BD y esquema inicial para gestión de datos del escáner de red. ([815a637](https://github.com/HectorPOsuna/escaner-red/commit/815a637a9a387bbe8c6dd5bbd3a77c2d2a369217))
* Agregar tabla conflictos y sus índices para registrar conflictos de red. ([d207589](https://github.com/HectorPOsuna/escaner-red/commit/d207589a6d97013a2c16832f55aae7d44f36ff26))
* Agregar tabla de conflictos y sus índices para logs de red. ([315fc6c](https://github.com/HectorPOsuna/escaner-red/commit/315fc6cf641c925a23e1be582ead1cd110ecdba2))
* agregar tabla pivote protocolos_usados con claves foráneas e índices. ([0c183ef](https://github.com/HectorPOsuna/escaner-red/commit/0c183ef096bc536d3c676206350ff7dcd15a1771))
* Agregar utilidad de conexión a base de datos y script de creación de tabla fabricantes. ([6772db1](https://github.com/HectorPOsuna/escaner-red/commit/6772db1a42cb82dd000b34707dfeee55aefacdf2))
* agregar utilidades de conexión a base de datos iniciales y script de inicialización. ([99c930d](https://github.com/HectorPOsuna/escaner-red/commit/99c930d170f932f31f48bb93d55e1fd7ad4f7ca7))
* añadiendo la dependencia mysql2 ([2f57473](https://github.com/HectorPOsuna/escaner-red/commit/2f5747386b643a65049bc4af35aa9798fddb471f))
* Crear tabla equipos para inventario de dispositivos de red, incluyendo esquema, clave foránea e índices. ([8b3f258](https://github.com/HectorPOsuna/escaner-red/commit/8b3f258363aa93aa475a4b3516ac69a5e9360a60))
* detect OS based on TTL values ([8d4b929](https://github.com/HectorPOsuna/escaner-red/commit/8d4b92955a4c0874a7dddf8328f761fc625b527d))
* identificacion de protocolos y puertos abiertos para cada host en la red ([4d8736a](https://github.com/HectorPOsuna/escaner-red/commit/4d8736a2adac784a1b43844b52f953359f72ef9c))
* implementacion de mapeo de fabricante con MAC address ([6820aea](https://github.com/HectorPOsuna/escaner-red/commit/6820aea3bf5b8f6b9ed507a510d8c0c32a43f5ce))
* implementacion de timestamp para ver la ultima vez escaneado. ([f176933](https://github.com/HectorPOsuna/escaner-red/commit/f1769331f9efca326f8d91e57f199d00711b6e05))
* implementacion de un formato de hora y reestructuracion de el formato de salida de los puertos. ([6a1a913](https://github.com/HectorPOsuna/escaner-red/commit/6a1a9131b618e122d08c0a9c314c9e473f2464a5))
* Implementar esquema BD y servicio para gestionar dispositivos, protocolos y conflictos de red. ([c4d98ac](https://github.com/HectorPOsuna/escaner-red/commit/c4d98acaeacdc750b8990e1e429f361f75b302ae))
* Implementar módulo inicial de base de datos con carga de protocolos IANA y endpoint API para resultados de escaneo. ([23da76d](https://github.com/HectorPOsuna/escaner-red/commit/23da76d432674b72eba72d55818adf0b928cfd34))
* Implementar servicio inicial de base de datos con operaciones CRUD para entidades de red y procesamiento de resultados de escaneo con detección de conflictos. ([da334fc](https://github.com/HectorPOsuna/escaner-red/commit/da334fc663c8b1ece5aaa43e6b6d7036a4930b36))
* Implementar servicios backend para procesar resultados de escaneo de red, gestionar dispositivos de red y detectar conflictos. ([85cf5e2](https://github.com/HectorPOsuna/escaner-red/commit/85cf5e22b48763fe40f0dbbbc7ff011f9913e49c))
* Implementar un script de escaneo de red en PowerShell integral para descubrimiento de hosts, detección de SO, búsqueda de MAC, identificación de fabricantes y escaneo de puertos. ([997fab0](https://github.com/HectorPOsuna/escaner-red/commit/997fab0dd3ce25c09e68e23494c851f00defdb4e))
* Implementar un sistema de escaneo de red con agente PowerShell para detección de IP/puerto/SO y un backend Node.js para almacenamiento de datos y gestión de protocolos. ([b64c4e4](https://github.com/HectorPOsuna/escaner-red/commit/b64c4e4b6f92c2b8f856d42d2c05a385811b115c))
* Inicializar proyecto de servidor con dependencias, definir esquema inicial de base de datos y agregar agente de escaneo de red en PowerShell. ([d647421](https://github.com/HectorPOsuna/escaner-red/commit/d6474216d6099a0d050952a491feed41b32b37c9))
* Inicializar servidor backend Express.js para procesar resultados de escaneo de red y persistir datos en MySQL. ([ea0d678](https://github.com/HectorPOsuna/escaner-red/commit/ea0d6786a019cc120fd99de4ef3168b3c8f76047))
* Introducir procesamiento de resultados de escaneo para detectar conflictos, actualizar/insertar dispositivos y registrar protocolos. ([1a640ab](https://github.com/HectorPOsuna/escaner-red/commit/1a640ab7d004d0b910c888fadc5e86d176cfbe5e))
* **metadata:** add hostname detection ([2bd8835](https://github.com/HectorPOsuna/escaner-red/commit/2bd883582af9bf5b7c446c7e86d742f52d55c68b))
* retrieve MAC addresses using ARP table ([d779f56](https://github.com/HectorPOsuna/escaner-red/commit/d779f564a98510af4b5b7e488982c9278c776e28))
* se ha implementado el sedeo automaticamente al init-db ([5012637](https://github.com/HectorPOsuna/escaner-red/commit/5012637c8ed6638a37e5670352c9943af9993543))
* set up conventional changelog generation with `conventional-changelog-cli` and `CHANGELOG.md`. ([f312e36](https://github.com/HectorPOsuna/escaner-red/commit/f312e36f5463b5ad64a215b1aa09461419c33416))
* validacion local que evita capturas duplicadas ([9fb0acf](https://github.com/HectorPOsuna/escaner-red/commit/9fb0acffb2843263c398efc61aeb9e91bf2613fd))



# [](https://github.com/HectorPOsuna/escaner-red/compare/v0.1.0...v) (2025-12-01)


### Features

* Add CHANGELOG.md to set up conventional changelog generation. ([43f2c86](https://github.com/HectorPOsuna/escaner-red/commit/43f2c86bad7045b13070abcc8cd36149b51c0e3d))
* add first prototype for network scanner (initial version) ([f6078d7](https://github.com/HectorPOsuna/escaner-red/commit/f6078d7c04a8f78936e57494f32f11836d5f3654))
* Agregar archivos de caché de resultados de escaneo de red, reporte, marcas de tiempo del último escaneo y bloqueo de dependencias del servidor. ([b65bd42](https://github.com/HectorPOsuna/escaner-red/commit/b65bd42932a0f4d2dff4322e2945358ee1c162f6))
* Agregar definición de tabla protocolos incluyendo puerto, nombre, categoría e índices. ([611b240](https://github.com/HectorPOsuna/escaner-red/commit/611b24060b07c074733a83446e47ecb3f86714b8))
* agregar dependencia dotenv ([7b1492e](https://github.com/HectorPOsuna/escaner-red/commit/7b1492e9b972dbc35906976a319c4dd7e904a987))
* agregar módulo de base de datos para gestión de conexiones y carga de datos OUI. ([3fcb474](https://github.com/HectorPOsuna/escaner-red/commit/3fcb474774a8f6f47eae5fb34b011d6a1cc458c2))
* Agregar tabla conflictos y sus índices para registrar conflictos de red. ([d207589](https://github.com/HectorPOsuna/escaner-red/commit/d207589a6d97013a2c16832f55aae7d44f36ff26))
* agregar tabla pivote protocolos_usados con claves foráneas e índices. ([0c183ef](https://github.com/HectorPOsuna/escaner-red/commit/0c183ef096bc536d3c676206350ff7dcd15a1771))
* Agregar utilidad de conexión a base de datos y script de creación de tabla fabricantes. ([6772db1](https://github.com/HectorPOsuna/escaner-red/commit/6772db1a42cb82dd000b34707dfeee55aefacdf2))
* agregar utilidades de conexión a base de datos iniciales y script de inicialización. ([99c930d](https://github.com/HectorPOsuna/escaner-red/commit/99c930d170f932f31f48bb93d55e1fd7ad4f7ca7))
* añadiendo la dependencia mysql2 ([2f57473](https://github.com/HectorPOsuna/escaner-red/commit/2f5747386b643a65049bc4af35aa9798fddb471f))
* Crear tabla equipos para inventario de dispositivos de red, incluyendo esquema, clave foránea e índices. ([8b3f258](https://github.com/HectorPOsuna/escaner-red/commit/8b3f258363aa93aa475a4b3516ac69a5e9360a60))
* detect OS based on TTL values ([8d4b929](https://github.com/HectorPOsuna/escaner-red/commit/8d4b92955a4c0874a7dddf8328f761fc625b527d))
* identificacion de protocolos y puertos abiertos para cada host en la red ([4d8736a](https://github.com/HectorPOsuna/escaner-red/commit/4d8736a2adac784a1b43844b52f953359f72ef9c))
* implementacion de mapeo de fabricante con MAC address ([6820aea](https://github.com/HectorPOsuna/escaner-red/commit/6820aea3bf5b8f6b9ed507a510d8c0c32a43f5ce))
* implementacion de timestamp para ver la ultima vez escaneado. ([f176933](https://github.com/HectorPOsuna/escaner-red/commit/f1769331f9efca326f8d91e57f199d00711b6e05))
* implementacion de un formato de hora y reestructuracion de el formato de salida de los puertos. ([6a1a913](https://github.com/HectorPOsuna/escaner-red/commit/6a1a9131b618e122d08c0a9c314c9e473f2464a5))
* Implementar un script de escaneo de red en PowerShell integral para descubrimiento de hosts, detección de SO, búsqueda de MAC, identificación de fabricantes y escaneo de puertos. ([997fab0](https://github.com/HectorPOsuna/escaner-red/commit/997fab0dd3ce25c09e68e23494c851f00defdb4e))
* Inicializar servidor backend Express.js para procesar resultados de escaneo de red y persistir datos en MySQL. ([ea0d678](https://github.com/HectorPOsuna/escaner-red/commit/ea0d6786a019cc120fd99de4ef3168b3c8f76047))
* **metadata:** add hostname detection ([2bd8835](https://github.com/HectorPOsuna/escaner-red/commit/2bd883582af9bf5b7c446c7e86d742f52d55c68b))
* retrieve MAC addresses using ARP table ([d779f56](https://github.com/HectorPOsuna/escaner-red/commit/d779f564a98510af4b5b7e488982c9278c776e28))
* set up conventional changelog generation with `conventional-changelog-cli` and `CHANGELOG.md`. ([f312e36](https://github.com/HectorPOsuna/escaner-red/commit/f312e36f5463b5ad64a215b1aa09461419c33416))
* validacion local que evita capturas duplicadas ([9fb0acf](https://github.com/HectorPOsuna/escaner-red/commit/9fb0acffb2843263c398efc61aeb9e91bf2613fd))



# [](https://github.com/HectorPOsuna/escaner-red/compare/v0.1.0...v) (2025-11-26)


### Features

* set up conventional changelog generation with `conventional-changelog-cli` and `CHANGELOG.md`. ([f312e36](https://github.com/HectorPOsuna/escaner-red/commit/f312e36f5463b5ad64a215b1aa09461419c33416))



# [](https://github.com/HectorPOsuna/escaner-red/compare/v0.1.0...v) (2025-11-26)



