# Resultado de las pruebas de esta copia

Carpeta probada: `galapagos-enso-shiny 2`. Fecha: 14 de octubre de 2026.

## Comprobaciones satisfactorias

- Construcción completa de Docker para **linux/amd64** con `quay.io/jupyter/minimal-notebook:ubuntu-24.04` y el instalador de **Carl Boettiger, repo2docker-r**. Se ejecutó en Docker Desktop con emulación en Apple Silicon.
- Inicio de Shiny dentro del contenedor, como UID 1000, escuchando en `0.0.0.0:7860`; apertura por navegador mediante el puerto local 7861.
- Pruebas sin conexión durante la construcción y en R local: unidades, años bisiestos, datos faltantes, exclusión del resumen anual, fechas del boletín español, referencias estacionales, cobertura insuficiente y encabezados CSV.
- `tests.R --live` pasó en R local y en Docker: temperatura NOAA, lluvia NASA, boletín y probabilidades CPC y seis historiales de índices.
- Pruebas de servidor Shiny, tanto locales como dentro de Docker: mapa marino de 4.830 celdas, historial de 28 días, cambio a lluvia y tabla de probabilidades de nueve trimestres.
- Pruebas de servidor de comparación, también dentro de Docker: temperatura del mismo producto frente a su referencia oficial y lluvia mensual frente a 1991–2020; cambio entre variables correcto.
- Descarga CSV por navegador: 4.830 filas, encabezados en español y URL de fuente.
- Mapas locales centrados inicialmente en Galápagos, con Darwin y Wolf incluidos; encuadre mínimo y desplazamiento restringidos. El botón de alejar queda desactivado al alcanzar el encuadre inicial. El mapa de índices conserva el dominio del Pacífico.

## Entorno del contenedor

R 4.6.1; shiny 1.14.0; bslib 0.12.0; leaflet 2.2.3; ggplot2 4.0.3; httr2 1.3.0; jsonlite 2.0.0; xml2 1.6.0; rvest 1.0.5; htmlwidgets 1.6.4.

## Límites de esta validación

No se publicó en GitHub ni Hugging Face. Falta verificar la primera construcción en Spaces y las consultas desde su red. No se realizó una prueba de carga concurrente. Una compilación correcta no garantiza disponibilidad continua de NOAA/NASA; CoastWatch había devuelto errores 502 en la revisión anterior, aunque respondió en estas pruebas. El instalador y los repositorios no están fijados a versiones inmutables, por lo que futuras reconstrucciones pueden diferir.

El llavero local de Docker impidió inicialmente consultar una imagen pública. La compilación se realizó usando una configuración Docker temporal sin credenciales. Las credenciales habituales no se cambiaron.

La aplicación conserva únicamente respuestas remotas en memoria. No se empaquetan archivos locales de observaciones. Consulte `DESPLIEGUE_HF.md` para reproducir la prueba y publicar el repositorio.

## Resumen e informe — 16 de octubre de 2026

- Interfaz local cargada con `monitoring.R`; pruebas existentes y `monitoring-tests.R` satisfactorias.
- Consulta real de Santa Cruz: comparación marina y 90 observaciones diarias; lluvia con 11 de 12 meses disponibles. El mes faltante se mantiene vacío y se informa la última lluvia disponible.
- Prueba de servidor del módulo con esa instantánea: consulta, aviso al cambiar de isla y actualización del resumen correctos.
- Informe HTML autónomo generado y revisado en navegador: español, imágenes integradas, mapa, series, fechas, cobertura y enlaces. Formato compacto A4 para imprimir; la paginación final depende de la configuración del navegador.
- Dockerfile y lista de inclusión `.dockerignore` actualizados para los nuevos archivos. La imagen Docker no se reconstruyó en esta validación; las comprobaciones de contenedor anteriores corresponden a la versión previa.

## Carga diferida — 16 de octubre de 2026

Prueba de servidor con contadores de consultas: en Monitoreo no se solicita lluvia, pronóstico ni historial diario; las consultas se activan con su control correspondiente. Volver a la pestaña del pronóstico reutiliza su resultado. Abrir una sesión no borra la caché compartida. Pasaron también las pruebas existentes y de persistencia. No se ha medido una reducción porcentual ni simulado una conexión de Galápagos.

## Carga SST e historial — corrección del 16 de octubre de 2026

- Se reprodujo una respuesta HTTP 502 del proveedor. Posteriormente NOAA respondió: última fecha 2026-10-15, 4.644 celdas válidas y 28/28 días válidos en la celda de Santa Cruz.
- Pruebas de servidor: carga sin pulsar Actualizar, historial activado al iniciar y cambio de fecha manteniendo la misma celda.
- La interfaz distingue espera, falta de celda y error de consulta. Se añadió reintento manual del historial y un máximo de dos intentos por petición remota ante errores temporales.
- Se comprobó NOAA OISST como posible respaldo, pero su última fecha era 2026-10-01; no se incorporó para evitar presentarlo como SST actual.
