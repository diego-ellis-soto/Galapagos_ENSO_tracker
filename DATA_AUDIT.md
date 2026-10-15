# Auditoría de los datos físicos originales

Se inspeccionaron los esquemas RDS y las fechas con datos el 13 de octubre de 2026, antes de sustituir las entradas por servicios remotos. Estos archivos no se distribuyen ni se leen al ejecutar la aplicación.

| Archivo original | Resultado | Tratamiento |
|---|---|---|
| `island_sst.rds` | 836 filas: Alcedo, Espanola, SCeast y SCwest; 209 por serie. Enero de 2009–julio de 2026; faltan febrero de 2009 y febrero de 2015 en las cuatro series. Sin duplicados por lugar/mes. Solo campos `ym`, `sst`, `site`, sin coordenadas, versión, resolución ni URL original. | No se interpretaron como estaciones geolocalizadas ni se dedujeron ubicaciones por nombre. Sustituidos por cuadrícula NOAA documentada. |
| `chirps_monthly_spi.rds` | 547 meses, enero de 1981–julio de 2026. Precipitación, días, SPI, promedio mensual y anomalía; sin ubicación ni versión del producto. Muchos totales cero; 136 valores faltantes en SPI01. El nombre sugiere CHIRPS, pero no verifica lugar de extracción ni referencia. | No se representa como pluviómetro. NASA MERRA-2 es una estimación distinta y más gruesa, no continuación de esta serie. |
| `enso_monthly.rds` | 918 meses, enero de 1950–junio de 2026. ONI y regiones Niño. MEI: 348 valores iniciales faltantes y 570 válidos desde 1979. Niño 1+2 trimestral: dos extremos faltantes. | Sustituidos por historiales remotos oficiales. Las clasificaciones derivadas originales no se aplican a RONI. |
| `enso_events.rds` | 42 episodios definidos por ONI desde 1950; el último termina en abril de 2024. | No se utilizan como pronóstico actual ni como episodios RONI. |

## Cobertura espacial nueva

La cuadrícula marina de 0,05° cubre las islas principales y Darwin/Wolf. Se evalúa cada celda en la fecha elegida; las máscaras terrestres y los datos faltantes permanecen vacíos. Los marcadores son etiquetas aproximadas de selección. La celda marina seleccionada se muestra en sus coordenadas reales, sin afirmar que represente toda la isla.

La consulta regional NASA devuelve hasta 56 centros nativos de 0,5° × 0,625°. Los meses seleccionables proceden de valores finitos recibidos, no del año final solicitado. El último mes se presenta por separado de la temperatura. Varias islas pueden compartir celda. El servicio no aporta estaciones propias de cada isla; algunas celdas recientes no tienen referencia histórica coincidente.
