---
title: Galápagos · Monitoreo del ENOS
emoji: 🌊
colorFrom: blue
colorTo: green
sdk: docker
app_port: 7860
license: bsd-2-clause
pinned: false
---

# Monitoreo del ambiente físico de Galápagos

Aplicación Shiny para el personal del Parque Nacional Galápagos. Las observaciones, los índices y los pronósticos se consultan en servicios remotos de NOAA y NASA. **Requiere internet; no necesita archivos locales de datos, credenciales ni una caché de observaciones en disco.** La interfaz, los gráficos y los encabezados de las descargas están en español. Se conservan los nombres oficiales de productos y las siglas científicas.

## Iniciar la aplicación

En R o RStudio:

```r
install.packages(c("shiny", "bslib", "leaflet", "ggplot2", "httr2", "jsonlite", "xml2", "rvest", "htmlwidgets", "plotly"))
shiny::runApp(".")
```

En otro equipo, cambie la ruta por la de esta carpeta. Requiere R 4.1 o posterior; se verificó con R 4.4.

## Uso

- **Monitoreo:** seleccione isla, variable y fecha. Los marcadores sirven para navegar; no representan estaciones. El mapa muestra las celdas nativas y sus datos faltantes.
- **Historial marino:** selecciona inicialmente la celda marina válida más cercana a menos de 0,5° del marcador. El anillo negro indica la celda utilizada; puede pulsar otra celda. Se consultan 28 días en bloques de siete para reducir fallos del servicio. Los bloques fallidos quedan vacíos.
- **Lluvia:** usa la celda de NASA más cercana. Para ampliar el historial, cambie el año inicial y pulse **Consultar / actualizar datos remotos**. La tasa diaria media se multiplica por los días del mes. Islas cercanas pueden compartir celda.
- **Comparar con el promedio:** muestra el valor seleccionado o la referencia a la izquierda y la diferencia a la derecha. Pulse **Consultar comparación** después de cambiar variable o fecha. El resumen describe una celda, no toda la isla.
- **Pronóstico oficial del ENOS:** consulta directamente el boletín oficial de NOAA en español. Muestra fecha, estado, sinopsis, próxima emisión y probabilidades trimestrales de intensidad RONI. Si los meses de emisión del boletín y las probabilidades difieren, se oculta el gráfico. Las probabilidades no son predicciones de impactos locales.
- **Historial de índices del Pacífico:** ONI, MEI.v2 y anomalías Niño 1+2, 3, 3.4 y 4. Rojo indica signo positivo y azul negativo, no clasificación oficial de episodios. El mapa sitúa Galápagos respecto a cada región. El dominio de MEI no representa pesos espaciales uniformes. El historial RONI se enlaza por separado.
- Las descargas CSV incluyen fuentes y consulta UTC; los vacíos son datos faltantes, no ceros. Los gráficos PNG conservan títulos y unidades en español.

## Fuentes y cobertura

| Fuente | Cobertura y tratamiento |
|---|---|
| [NOAA CoastWatch](https://coastwatch.noaa.gov/erddap/info/noaacwBLENDEDCsstDaily/index.csv) | Análisis combinado nocturno de temperatura marina, diario, 0,05° (unos 5 km), desde septiembre de 2002. ERDDAP devuelve subconjuntos CSV de `analysed_sst` en °C. Los metadatos determinan las fechas disponibles. Centros consultados: 92,475–89,025°O y 1,575°S–1,825°N. |
| [NASA POWER](https://power.larc.nasa.gov/docs/services/api/temporal/monthly/) | Precipitación corregida MERRA-2 (`PRECTOTCORR`), desde 1981, 0,5° de latitud × 0,625° de longitud. Consulta regional JSON entre 92,5–89°O y 1,5°S–2°N. Se excluye el resumen anual «mes 13»; valores −999 quedan vacíos. |
| [Boletín del CPC en español](https://www.cpc.ncep.noaa.gov/products/analysis_monitoring/enso_advisory/ensodisc_Sp.shtml) | Se extraen las fechas, el estado y la sinopsis oficial sin traducir automáticamente el pronóstico. Ante cambios de formato se muestra un aviso y el enlace oficial. |
| [Probabilidades de intensidad del CPC](https://www.cpc.ncep.noaa.gov/products/analysis_monitoring/enso/roni/strengths/) | Nueve trimestres superpuestos, categorías RONI. Se validan mes de emisión, dimensiones, valores entre 0 y 100 y sumas. La tabla de origen está en inglés; los trimestres y categorías se presentan en español. Muy fuerte significa RONI ≥2 °C, no el umbral independiente ≥2,5 °C mencionado en algunos boletines. |
| [Índices del PSL de NOAA](https://psl.noaa.gov/data/climateindices/list/) | Archivos remotos de ONI, MEI.v2 y regiones Niño. Las URL exactas están en `sources.R` y los CSV. Sus referencias y períodos de promedio son diferentes; no son escalas intercambiables. |
| [OpenStreetMap](https://www.openstreetmap.org/copyright) | Mapa base remoto con atribución. Las posiciones aproximadas de las etiquetas de islas son configuración, no observaciones. |

Las API recortan los datos en el servidor; no hace falta `/vsicurl/` ni descargar rásteres completos. Las respuestas correctas se conservan únicamente en memoria durante un máximo de una hora. Use los botones de actualización para consultar nuevamente. La fecha de consulta de la vista y la fecha de la observación son distintas. Una interrupción no activa archivos locales como sustituto.

## Comparaciones estacionales

La temperatura compara [NOAA CoralTemp v3.1](https://coastwatch.noaa.gov/erddap/info/noaacrwsstDaily/index.html) con su [anomalía diaria oficial respecto a 1991–2020](https://coastwatch.noaa.gov/erddap/info/noaacrwsstanomalybaselineDaily/index.html). La referencia se reconstruye restando la anomalía a la temperatura del mismo producto. Se utiliza la última fecha común verificada; este producto puede ir más retrasado que el de Monitoreo. No se mezclan productos o fechas.

La lluvia compara el total seleccionado con el promedio del mismo mes calendario de 1991–2020, consultado a NASA. Se requieren al menos 25 años válidos por celda. Sin referencia suficiente, la diferencia queda vacía. Solo se calcula el porcentaje si la referencia es al menos 1 mm/mes. Los colores de temperatura indican más frío (azul) o más cálido (rojo); los de lluvia, más seco (marrón) o más lluvioso (verde). No son pruebas de significación ni atribución al ENOS.

## Límites e interpretación

La temperatura es un análisis satelital, no un termómetro costero. La lluvia es un reanálisis grueso que no resuelve zonas altas, sombras de lluvia o cuencas individuales. No se calculan alertas de inundación ni probabilidades locales. La [base climática de la Fundación Charles Darwin](https://datazone.darwinfoundation.org/en/climate) aporta registros y contexto local; esas estaciones no están integradas en las estimaciones NASA.

En la verificación del 13–14 de octubre de 2026, la temperatura de Monitoreo llegaba al 12 de octubre, la comparación marina al 6 de octubre y la lluvia a agosto. El boletín del CPC era del 8 de octubre, con siguiente emisión prevista el 12 de noviembre. Son resultados de verificación, no fechas fijadas en la aplicación. Cada fuente se actualiza con su propio retraso.

## Actualización y mantenimiento

1. Use los botones de actualización; no hay que reemplazar archivos RDS.
2. Si cambia un servicio, actualice sus constantes o analizadores en `sources.R`, conservando las validaciones de unidades, cobertura y probabilidades.
3. Para añadir una variable física, documente producto, versión, URL, cuadrícula, fechas, unidades, calidad y transformaciones.
4. Desde esta carpeta, ejecute `Rscript tests.R` para las pruebas sin conexión o `Rscript tests.R --live` para verificar servicios remotos. Use una configuración regional UTF-8 en R.
5. Verifique mapas, selección de celdas, fechas y descargas. El servidor Shiny necesita HTTPS saliente a NOAA, NASA y el proveedor cartográfico.

La auditoría original está en `DATA_AUDIT.md`; las verificaciones, en `VALIDATION.md`.

## Publicación en Hugging Face

Se incluyen `Dockerfile`, `install.r` y `.dockerignore`. La comparación con el Space anterior, las comprobaciones pendientes y los pasos de publicación están en `DESPLIEGUE_HF.md`.

Los mapas locales abren centrados en Galápagos, incluyendo Darwin y Wolf. El desplazamiento se limita al área de monitoreo y el zoom mínimo se adapta al tamaño del mapa. Se evitan teselas completamente fuera de esa área. El mapa explicativo de índices conserva la vista del Pacífico. Las consultas de observaciones ya estaban recortadas a Galápagos; esta restricción afecta la navegación y las teselas, no la extensión consultada.

En Monitoreo, pulsar un marcador o cambiar la isla en la lista centra y acerca el mapa automáticamente. La escala se adapta a las islas grandes y pequeñas. Al abrir la aplicación se mantiene la vista inicial del archipiélago.

El historial de índices del Pacífico muestra, al pasar el cursor, el índice, la fecha del período y el valor con dos decimales. MEI se identifica como estandarizado y sin unidades; los demás índices se muestran en °C. Las fechas identifican períodos del índice, no observaciones diarias.

## Autor de la aplicación

Aplicación creada por **Diego Ellis Soto**.

Afiliaciones: Universidad de California, Berkeley (UC Berkeley) y Universidad de California, Santa Cruz (UC Santa Cruz).

## Estado de Galápagos e informe

En la pestaña **Estado de Galápagos**, seleccione una isla y pulse **Actualizar resumen de la isla**.
**Monitoreo** sigue siendo la página inicial, con el mapa y el crédito de autor al pie.
Se consulta una instantánea independiente del día/mes elegido en el mapa:
- Temperatura y anomalía diaria del mismo producto NOAA CoralTemp, última fecha común disponible, referencia 1991–2020. La celda válida más cercana debe quedar a menos de 0,5° del marcador.
- Lluvia de NASA POWER/MERRA-2 para el último mes calendario completo (si no está publicado, se informa como faltante), respecto al mismo mes de 1991–2020, con al menos 25 años válidos.
- Persistencia de anomalías del mismo signo: hasta 90 días de temperatura y 12 meses de lluvia, siempre en la misma celda. Cero y vacíos interrumpen las secuencias; «al menos» significa que no se conoce su inicio. No son umbrales de ola de calor ni atribución al ENOS.

El informe HTML contiene imágenes integradas, mapa de anomalías, dos series, fecha de consulta, cobertura, fuentes y limitaciones. Se puede abrir sin internet después de descargarlo y usar **Imprimir / guardar como PDF**, con papel A4 y escala 100 %. Corresponde a la instantánea consultada; cambiar de isla exige actualizar el resumen. El mapa del informe usa la temperatura y, si falla, la lluvia. Los marcadores son referencias geográficas, no estaciones.

No se incorporan archivos de observaciones ni nuevas dependencias. `monitoring.R` debe acompañar a `app.R`; el Dockerfile lo incluye. Validación adicional: `Rscript monitoring-tests.R`. El botón reutiliza la caché remota en memoria (hasta una hora); **Consultar / actualizar datos remotos** vacía esa caché.

## Carga inicial y conexiones lentas

La página inicial consulta únicamente la cobertura y el mapa diario de temperatura. La lluvia se consulta al seleccionar su capa; el pronóstico oficial, al abrir su pestaña. Para cargar la serie diaria, active **Cargar historial diario de temperatura (28 días)**. El resumen y el informe siguen siendo consultas voluntarias.

Las visitas nuevas conservan la caché remota compartida en memoria (hasta una hora por proceso R). El botón explícito de actualización vacía la caché. No hay archivos locales de observaciones. La primera consulta tras un reinicio todavía depende de NOAA; el navegador también debe descargar Shiny, los mapas y los componentes interactivos. En Hugging Face, las consultas a NOAA/NASA se realizan desde el servidor, no directamente desde la conexión del visitante; el usuario recibe la interfaz y los resultados.

Prueba de carga diferida con servicios simulados: `Rscript loading-tests.R`.

### Inicio y recuperación de consultas SST

La temperatura se consulta automáticamente al iniciar, sin pulsar Actualizar. El selector de fecha aparece después de leer los metadatos de NOAA y muestra su última fecha publicada. El historial espera a que exista una celda válida y se vuelve a consultar si cambia la fecha, aunque la celda sea la misma. Se distingue entre consulta pendiente y error; **Reintentar historial** repite una consulta fallida. Cada petición remota permite como máximo dos intentos ante fallos temporales de conexión o HTTP 429/500/502/503/504. No se sustituyen las observaciones por datos locales ni por productos alternativos más antiguos.
