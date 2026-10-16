# GitHub y Hugging Face: configuración verificada

Revisión: 14 de octubre de 2026. Esta carpeta se preparó con el esquema de Carl Boettiger que usa el proyecto [iNat_mortality_detector](https://github.com/diego-ellis-soto/iNat_mortality_detector/blob/main/Code/src/Huggingface_Shiny_App/Dockerfile) y su [Space publicado](https://huggingface.co/spaces/diegoellissoto/wildlife-mortality-watch/blob/main/Dockerfile).

## Configuración

- Base: `quay.io/jupyter/minimal-notebook:ubuntu-24.04`.
- Instalación de R: [boettiger-lab/repo2docker-r/install_r.sh](https://github.com/boettiger-lab/repo2docker-r/blob/main/install_r.sh), con r2u/bspm para paquetes binarios.
- `install.r` instala diez paquetes directos y comprueba que se puedan cargar.
- No se instala RStudio, igual que en el Dockerfile del Space publicado; no se necesita para servir Shiny.
- Puerto interno 7860 y dirección `0.0.0.0`, coincidentes con `app_port` del README.
- Ejecución como UID 1000. Las pruebas sin conexión se ejecutan durante la construcción.
- Solo datos remotos NOAA/NASA; sin datos locales, GPU, secretos de proveedores ni almacenamiento persistente.

Se construyó y ejecutó la imagen **Linux amd64** en Docker Desktop, mediante emulación en un Mac Apple Silicon. Las pruebas remotas pasaron tanto en R local como dentro del contenedor. El resultado prueba esta compilación local; la primera construcción y la conectividad desde Hugging Face todavía deben comprobarse allí.

El instalador sigue la rama `main` de repo2docker-r y usa repositorios de paquetes actualizados. Por tanto, una reconstrucción futura puede instalar versiones distintas. En esta prueba se instalaron R 4.6.1, shiny 1.14.0, bslib 0.12.0, leaflet 2.2.3, ggplot2 4.0.3, httr2 1.3.0, jsonlite 2.0.0, xml2 1.6.0, rvest 1.0.5 y htmlwidgets 1.6.4.

## Repetir las pruebas

Desde esta carpeta, con Docker Desktop iniciado:

```sh
docker build --platform linux/amd64 -t galapagos-enos .
docker run --rm --platform linux/amd64 -p 7860:7860 galapagos-enos
```

Abra `http://localhost:7860`. Para repetir las pruebas de fuentes sin iniciar la interfaz:

```sh
docker run --rm --platform linux/amd64 galapagos-enos Rscript tests.R --live
```

Las pruebas sin conexión usan entradas sintéticas y no observaciones locales. Las pruebas `--live` requieren internet y pueden fallar por interrupciones de los proveedores. En este equipo el llavero de Docker impidió descargar una imagen pública inicialmente; se probó con una configuración Docker temporal vacía, sin alterar las credenciales habituales. Esto fue una particularidad local, no un requisito del Space.

## Subir primero a GitHub

Use **el contenido de esta carpeta como raíz del repositorio**, no el ZIP ni la carpeta superior `outputs`. Deben estar en la raíz `Dockerfile`, `README.md`, `install.r`, `.dockerignore`, `.gitignore`, `app.R`, `sources.R`, `comparison.R`, `monitoring.R`, `monitoring-tests.R` y `tests.R`. Incluya también los documentos Markdown.

Esta carpeta todavía no es un repositorio Git. Para un repositorio nuevo:

```sh
git init -b main
git add .
git diff --cached --stat
git commit -m "Monitoreo físico de Galápagos en español"
git remote add origin https://github.com/TU_USUARIO/TU_REPOSITORIO.git
git push -u origin main
```

Sustituya los nombres de ejemplo por un repositorio vacío que haya creado. Si ya tiene un repositorio con historial, incorpore los archivos a ese repositorio; no sustituya su historial.

## Enviar después a Hugging Face

Cree un **Space nuevo con SDK Docker**. No use como destino el Space anterior. El README ya contiene `sdk: docker` y `app_port: 7860`; no hace falta configurar Gradio ni instalar un servidor adicional.

Añada otro remoto al mismo repositorio local:

```sh
git remote add hf https://huggingface.co/spaces/diegoellissoto/NOMBRE_DEL_SPACE
```

Hugging Face puede crear un commit inicial con README. Antes del primer envío:

```sh
git fetch hf
git log --oneline hf/main
```

Si existe ese commit inicial, integre su historial con `git merge hf/main --allow-unrelated-histories`, resuelva cualquier conflicto del README conservando los metadatos de esta aplicación y confirme el resultado. Después:

```sh
git push origin main
git push hf main
```

Si el remoto está completamente vacío, no existe `hf/main`: puede omitir la integración inicial y enviar directamente. Evite `--force`. No hace falta `git subtree` cuando esta carpeta ya es la raíz del repositorio. El flujo de subcarpeta del proyecto anterior solo corresponde si mantiene varias aplicaciones dentro de un repositorio mayor.

En actualizaciones posteriores: confirme los cambios y envíe `main` a ambos remotos. GitHub no se sincroniza automáticamente con Hugging Face por tener dos remotos. La autenticación se realiza con las credenciales configuradas para cada servicio; nunca coloque tokens en estos archivos.

## Comprobaciones del Space

1. En los registros de construcción: instalación de paquetes y pruebas correctas.
2. En ejecución: `Listening on http://0.0.0.0:7860`.
3. Abrir el Space por HTTPS y verificar mapas, interacción Shiny, pronóstico y descargas.
4. Verificar consultas desde esa red a NOAA CoastWatch, CPC, PSL y NASA POWER, y las teselas OpenStreetMap desde el navegador.

La configuración sigue la [documentación de Docker Spaces](https://huggingface.co/docs/hub/spaces-sdks-docker). CPU es suficiente como punto de partida; no se ha medido capacidad con usuarios concurrentes. Las consultas actuales son síncronas y una respuesta lenta puede retrasar otras sesiones. La caché vive en memoria; no equivale a un archivo histórico. Los servicios pueden devolver errores temporales, como los 502 de CoastWatch observados en la revisión anterior.

No se ha creado ni publicado ningún repositorio o Space durante estas pruebas. La visibilidad y la licencia del proyecto quedan por elegir; no se copió automáticamente la licencia del otro proyecto.

Actualización del 15 de octubre de 2026: se añadió Plotly al instalador para los valores interactivos del historial; se reconstruyó la imagen y se verificó el servidor Shiny.
