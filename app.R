if (capabilities("cairo")) options(shiny.useragg = FALSE, shiny.usecairo = FALSE, bitmapType = "cairo")
library(shiny)
library(bslib)
library(leaflet)
library(ggplot2)
source("sources.R", local = TRUE)
source("comparison.R", local = TRUE)
link <- function(label, url) tags$a(label, href = url, target = "_blank", rel = "noopener")
message_box <- function(...) div(class = "notice", ...)
ui <- page_navbar(lang = "es", title = "Galápagos | Ambiente físico", id = "page", fillable = FALSE, theme = bs_theme(version = 5,
    primary = "#126f74", base_font = font_collection("system-ui", "sans-serif")), header = tags$head(tags$script(HTML("document.addEventListener('DOMContentLoaded',function(){function ajustarMapas(){requestAnimationFrame(function(){document.querySelectorAll('.leaflet.html-widget').forEach(function(el){if(el.offsetWidth&&el.offsetHeight){var w=HTMLWidgets.find('#'+el.id);if(w&&w.resize)w.resize(el.offsetWidth,el.offsetHeight);}});});}$(document).on('shown.bs.tab',ajustarMapas);document.addEventListener('shown.bs.tab',ajustarMapas);function traducir(){document.querySelectorAll('[aria-label],[title]').forEach(function(e){['aria-label','title'].forEach(function(a){var v=e.getAttribute(a);if(!v)return;var t=v.replace('Toggle sidebar','Mostrar u ocultar panel').replace('Date format:','Formato de fecha:').replace('download icon','Descargar').replace('Toggle navigation','Mostrar navegación').replace('Resize sidebar','Cambiar ancho del panel').replace('Drag to resize sidebar','Arrastre para cambiar el ancho del panel');if(t!==v)e.setAttribute(a,t);});});}traducir();new MutationObserver(traducir).observe(document.body,{childList:true,subtree:true});});")), tags$style(HTML("body{background:#f3f7f7}.notice{padding:14px 18px;background:#e7f1f1;border-left:4px solid #126f74;margin:12px 0}.small-note{color:#496066;font-size:.9rem}.leaflet-container{background:#d9eaf0}h3{margin-top:18px}.card{margin-top:15px}.shiny-output-error-validation{color:#885818} .leaflet-control{font-size:14px!important}"))),
    nav_panel("Monitoreo", layout_sidebar(sidebar = sidebar(width = 300, h4("Seleccione una isla"), selectInput("island",
        "Isla", islands$island, selected = "Santa Cruz"), radioButtons("layer", "Capa del mapa", c(`Temperatura del mar · diaria` = "sst",
        `Lluvia estimada · mensual` = "rain")), dateInput("sst_date", language = "es", "Fecha de temperatura del mar", value = Sys.Date() -
        2), selectInput("rain_month", "Mes de lluvia", choices = character()), numericInput("rain_start",
        "Historial de lluvia: año inicial", 2024, min = 1981, max = as.integer(format(Sys.Date(), "%Y"))), actionButton("refresh",
        "Consultar / actualizar datos remotos", class = "btn-primary"), p(class = "small-note", "Datos de NOAA y NASA. Las respuestas válidas se conservan en memoria hasta una hora. No se usan archivos locales de observaciones."),
        downloadButton("map_csv", "Datos del mapa (CSV)"), downloadButton("series_csv", "Historial seleccionado (CSV)"), downloadButton("figure",
            "Gráfico del historial (PNG)")), h3("Monitoreo de Galápagos"), p("Seleccione una isla en el mapa o en la lista. Pulse una celda marina para consultar su historial diario."),
        uiOutput("status"), leafletOutput("map", height = 520), uiOutput("coverage"), h4("Historial de la ubicación seleccionada"),
        uiOutput("series_note"), plotOutput("series_plot", height = 290), tags$details(tags$summary("Cobertura por isla: capa y fecha seleccionadas"),
            tableOutput("island_coverage")))), comparison_ui(), nav_panel("Pronóstico oficial del ENOS", h3("Pronóstico oficial más reciente"),
        actionButton("forecast_refresh", "Consultar actualizaciones de NOAA"), uiOutput("forecast"), h4("Probabilidades oficiales de intensidad por trimestre"),
        uiOutput("strength_note"), plotOutput("strength_plot", height = 330), tableOutput("strength_table"),
        downloadButton("forecast_csv", "Datos de probabilidades (CSV)"), message_box(strong("El pronóstico de un índice ENOS no predice los impactos en una isla."),
            p("Estas probabilidades describen el estado del ENOS en el Pacífico tropical. No indican la probabilidad de lluvia, inundaciones ni de una temperatura marina determinada en las islas Galápagos. Esta vista no incluye escenarios hipotéticos.")),
        h4("Qué vigilar en las islas"), p("En episodios intensos de El Niño del pasado, Galápagos ha registrado mares inusualmente cálidos y lluvias abundantes. Consulte los registros locales para comprobar las condiciones: el momento y la magnitud varían entre episodios y lugares. Son condiciones físicas posibles, no un pronóstico local calibrado para esta temporada."),
        p("El relieve, los vientos estacionales y las corrientes generan diferencias importantes entre islas y entre zonas altas y costeras. La cuadrícula de lluvia es demasiado gruesa para resolver esas diferencias o emitir alertas de inundación."),
        link("Clima local y episodios históricos · Fundación Charles Darwin", "https://datazone.darwinfoundation.org/en/climate")),
    nav_panel("Historial de índices del Pacífico", h3("Índices observados del Pacífico"), selectInput("index", "Índice", c(`ONI · anomalía trimestral de Niño 3.4 (°C)` = "ONI",
        `MEI.v2 · estandarizado, períodos bimestrales` = "MEI", `Niño 1+2 · anomalía mensual (°C)` = "Nino12",
        `Niño 3 · anomalía mensual (°C)` = "Nino3", `Niño 3.4 · anomalía mensual (°C)` = "Nino34", `Niño 4 · anomalía mensual (°C)` = "Nino4")),
        dateRangeInput("index_dates", language = "es", separator = "a", "Período del historial", start = "1980-01-01", end = Sys.Date()), uiOutput("index_status"),
        plotly::plotlyOutput("index_plot", height = "350px"), downloadButton("index_csv", "Datos del índice (CSV)"), h4("¿Qué región representa este índice?"),
        uiOutput("index_location"), leafletOutput("index_region_map", height = 330), h4("Elija el índice adecuado para su pregunta"),
        tags$ul(tags$li(strong("RONI: "), "Anomalía trimestral de temperatura en Niño 3.4 relativa al promedio tropical, reajustada para conservar la variabilidad. El CPC la adoptó para el monitoreo operativo del ENOS en febrero de 2026. El pronóstico oficial de intensidad utiliza RONI; sus umbrales no se pueden sustituir por los de ONI."),
            tags$li(strong("ONI: "), "Anomalía trimestral de temperatura en Niño 3.4, en °C. Útil para comparar episodios históricos del ENOS. Las climatologías de referencia y las versiones de los datos difieren de las de RONI."),
            tags$li(strong("MEI.v2: "), "Combina temperatura del mar, presión, vientos y radiación saliente de onda larga en períodos bimestrales superpuestos. Es estandarizado y no tiene unidades: un valor de 2 no significa 2 °C. Las fechas mensuales identifican períodos del índice, no mediciones diarias."),
            tags$li(strong("Índices regionales Niño: "), "Anomalías mensuales de temperatura para distintas regiones del Pacífico. Niño 1+2: 0–10°S, 90–80°O; Niño 3: 5°N–5°S, 150–90°O; Niño 3.4: 5°N–5°S, 170–120°O; Niño 4: 5°N–5°S, 160°E–150°O. Niño 1+2 representa una señal del Pacífico oriental, no una medición de las islas.")),
        p("El historial de RONI se consulta mediante el enlace siguiente; no se mezcla con el de ONI. Ningún índice determina por sí solo las condiciones locales."),
        link("NOAA: definición de RONI y observaciones actuales", "https://www.cpc.ncep.noaa.gov/products/analysis_monitoring/enso/roni/"),
        br(), link("NOAA: métodos de MEI.v2", "https://psl.noaa.gov/enso/mei/")), nav_panel("Fuentes y cobertura",
        h3("Fuentes remotas y limitaciones"), tags$ul(tags$li(link("Metadatos de temperatura marina de NOAA CoastWatch", SST_INFO),
            " — Análisis combinado nocturno de temperatura superficial del mar, diario, de 0,05° (unos 5 km), desde septiembre de 2002. Derivado de satélites; no es un termómetro costero. Las celdas grises carecen de valores válidos. La aplicación no añade interpolación."),
            tags$li(link("Servicio mensual de NASA POWER", "https://power.larc.nasa.gov/docs/services/api/temporal/monthly/"),
                " — Precipitación corregida de MERRA-2, de 0,5° de latitud × 0,625° de longitud, desde 1981. La media mensual en mm/día se multiplica por los días del mes para obtener mm/mes. Es una estimación de reanálisis, no un pluviómetro. Islas cercanas pueden compartir celda."),
            tags$li(link("Pronóstico del CPC de NOAA", CPC), " y ", link("probabilidades de intensidad", STRENGTH), " — se consultan por separado; las fechas de emisión deben coincidir para mostrar los gráficos de probabilidades."),
            tags$li(link("Índices climáticos del PSL de NOAA", "https://psl.noaa.gov/data/climateindices/list/"), " — series históricas remotas; los datos faltantes se conservan como vacíos. RONI no sustituye a ONI."),
            tags$li("Mapa base: OpenStreetMap. Los marcadores de islas son ubicaciones aproximadas para orientarse, no estaciones de monitoreo. El historial marino usa inicialmente la celda válida más cercana a menos de 0,5° del marcador; la celda utilizada se resalta.")),
        message_box("La consulta remota no implica que los datos lleguen hasta hoy. Cada fuente tiene su propio retraso de publicación. Se indican las celdas y meses faltantes y los errores del servicio. Se necesita internet; no se sustituyen los datos por archivos locales."),
        h4("Revisión del proyecto original"), p("Temperatura marina original: cuatro series, enero de 2009–julio de 2026, con 209 meses por serie y dos meses faltantes. Sin coordenadas de muestreo ni metadatos del producto original. Lluvia: enero de 1981–julio de 2026, con 547 registros mensuales sin identificador espacial. Índices del Pacífico: enero de 1950–junio de 2026; MEI comienza en 1979. Estos archivos no se utilizan al ejecutar la aplicación. Consulte DATA_AUDIT.md para la revisión y README.md para las actualizaciones.")))
server <- function(input, output, session) {
    state <- reactiveValues(meta = NULL, sst = NULL, rain = NULL, forecast = NULL, strength = NULL, point = NULL,
        history = NULL)
    observeEvent(input$refresh, {
        rm(list = ls(remote_cache), envir = remote_cache)
        withProgress(message = "Consultando cobertura y datos remotos", value = 0, {
            state$meta <- fetch_result(get_sst_meta)
            incProgress(0.2)
            if (state$meta$ok) {
                m <- state$meta$data
                updateDateInput(session, "sst_date", min = m$start, max = m$end, value = m$end)
                state$sst <- fetch_result(function() get_sst_map(m$end))
            } else state$sst <- state$meta
            incProgress(0.4)
            yr <- as.integer(input$rain_start)
            cur <- as.integer(format(Sys.Date(), "%Y"))
            if (is.na(yr) || yr < 1981 || yr > cur)
                state$rain <- list(ok = FALSE, error = "Seleccione un año inicial de lluvia entre 1981 y el año actual.",
                  fetched = utc_now()) else state$rain <- fetch_result(function() get_rain(yr, cur))
            if (state$rain$ok) {
                d <- state$rain$data
                months <- sort(unique(d$date[is.finite(d$rain_mm)]))
                updateSelectInput(session, "rain_month", choices = as.character(months), selected = as.character(tail(months,
                  1)))
            }
            incProgress(0.4)
        })
    }, ignoreNULL = FALSE)
    observeEvent(input$sst_date, {
        req(state$meta$ok)
        d <- as.Date(input$sst_date)
        m <- state$meta$data
        if (d < m$start || d > m$end) {
            state$sst <- list(ok = FALSE, error = "La fecha seleccionada está fuera de la cobertura de NOAA.", fetched = utc_now())
            return()
        }
        if (!is.null(state$sst) && state$sst$ok && all(state$sst$data$date == d))
            return()
        state$sst <- fetch_result(function() get_sst_map(d))
    }, ignoreInit = TRUE)
    focus_island <- function(id) {
        req(length(id) == 1, id %in% islands$island)
        s <- islands[islands$island == id, ]
        zoom <- switch(id, Isabela = 9, Santiago = 10, Fernandina = 10,
            Darwin = 13, Wolf = 13, 11)
        leafletProxy("map", session = session) |>
            setView(lng = s$lon, lat = s$lat, zoom = zoom)
    }
    observeEvent(input$map_marker_click, {
        id <- input$map_marker_click$id
        if (length(id) == 1 && id %in% islands$island) {
            updateSelectInput(session, "island", selected = id)
            # También permite volver a acercarse a la isla ya seleccionada.
            focus_island(id)
        }
    })
    observeEvent(input$island, {
        focus_island(input$island)
    }, ignoreInit = TRUE)
    map_data <- reactive({
        if (input$layer == "sst") {
            req(state$sst$ok)
            state$sst$data
        } else {
            req(state$rain$ok, input$rain_month)
            d <- state$rain$data
            d[d$date == as.Date(input$rain_month), ]
        }
    })
    layer_result <- reactive(if (input$layer == "sst")
        state$sst else state$rain)
    output$status <- renderUI({
        z <- layer_result()
        if (is.null(z))
            return(message_box("Todavía no se han consultado los datos."))
        if (!z$ok)
            return(message_box(strong("Servicio remoto no disponible. "), z$error, p("No se han sustituido las observaciones. Pulse Consultar / actualizar para volver a intentarlo.")))
        d <- map_data()
        v <- if (input$layer == "sst")
            d$analysed_sst else d$rain_mm
        message_box(strong(if (input$layer == "sst")
            "Temperatura marina de NOAA · " else "Lluvia estimada de NASA · "), paste(unique(d$date), collapse = ", "), p(sprintf("%s de %s celdas tienen datos. Consulta: %s (servicio remoto o memoria temporal).",
            sum(is.finite(v)), length(v), z$fetched)))
    })
    output$map <- renderLeaflet({
        z <- layer_result()
        req(z)
        p <- mapa_galapagos()
        if (z$ok) {
            d <- map_data()
            sst <- input$layer == "sst"
            v <- if (sst)
                d$analysed_sst else d$rain_mm
            pal <- colorNumeric(if (sst)
                "YlOrRd" else "Blues", domain = if (sst)
                if (any(is.finite(v)))
                  range(v, na.rm = TRUE) else c(15, 35) else c(0, max(300, v, na.rm = TRUE)), na.color = "#9da9ad")
            dx <- if (sst)
                0.025 else 0.3125
            dy <- if (sst)
                0.025 else 0.25
            lab <- sprintf("%s · %s<br>Centro de celda: %.3f, %.3f<br>%s<br>%s", if (sst)
                "Análisis de temperatura marina de NOAA" else "Lluvia estimada de NASA MERRA-2", d$date, d$latitude, d$longitude, ifelse(is.finite(v), paste(round(v,
                2), if (sst)
                "°C" else "mm/mes"), "Sin datos válidos"), if (sst)
                "Cuadrícula de 0,05°; pulse para ver el historial" else "Cuadrícula de 0,5° × 0,625°; no es una estación")
            p <- p |>
                addRectangles(lng1 = d$longitude - dx, lat1 = d$latitude - dy, lng2 = d$longitude + dx, lat2 = d$latitude +
                  dy, fillColor = pal(v), fillOpacity = 0.7, color = "#777777", weight = if (sst)
                  0 else 0.7, layerId = paste(d$longitude, d$latitude, sep = "|"), popup = lab) |>
                addLegend(pal = pal, values = v, title = if (sst)
                  "Temperatura del mar (°C)" else "Lluvia (mm/mes)", na.label = "Sin datos / enmascarado")
        }
        p <- p |>
            addCircleMarkers(data = islands, lng = ~lon, lat = ~lat, layerId = ~island, label = ~island, labelOptions = labelOptions(noHide = TRUE,
                direction = "auto", textOnly = TRUE), radius = 7, color = "#173d46", fillColor = "white",
                fillOpacity = 1, weight = 2) |>
            addControl("Marcadores de islas: selección, no estaciones<br>Gris: sin datos/enmascarado; fuera de la cuadrícula: sin consultar",
                position = "bottomleft")
        htmlwidgets::onRender(p,
            "function(el,x){this.whenReady(function(){Shiny.setInputValue('map_ready',Date.now(),{priority:'event'});});}")
    })
    selected_island <- reactive(islands[islands$island == input$island, ])
    observeEvent(list(input$island, state$sst), {
        req(state$sst$ok)
        d <- state$sst$data
        s <- selected_island()
        d <- d[is.finite(d$analysed_sst), ]
        dist <- (d$longitude - s$lon)^2 + (d$latitude - s$lat)^2
        if (!length(dist) || min(dist) > 0.5^2) {
            state$point <- NULL
            state$history <- NULL
            return()
        }
        state$point <- d[which.min(dist), c("longitude", "latitude")]
    })
    observeEvent(input$map_shape_click, {
        req(input$layer == "sst", state$sst$ok, input$map_shape_click$id)
        v <- as.numeric(strsplit(input$map_shape_click$id, "|", fixed = TRUE)[[1]])
        if (length(v) == 2 && all(is.finite(v)))
            state$point <- data.frame(longitude = v[1], latitude = v[2])
    })
    observeEvent(state$point, {
        req(state$point, state$meta$ok, state$sst$ok)
        p <- state$point
        end <- max(state$sst$data$date)
        start <- max(state$meta$data$start, end - 27)
        state$history <- fetch_result(function() get_sst_series(p$longitude, p$latitude, start, end))
    })
    observe({
        req(state$point, input$layer == "sst", input$map_ready)
        map_data()
        leafletProxy("map") |>
            clearGroup("selected") |>
            addCircleMarkers(lng = state$point$longitude, lat = state$point$latitude, radius = 10, color = "#000000",
                fill = FALSE, weight = 3, group = "selected", label = "Celda marina seleccionada")
    })
    selected_series <- reactive({
        if (input$layer == "sst") {
            req(state$history$ok)
            d <- state$history$data
            d$value <- d$analysed_sst
        } else {
            req(state$rain$ok)
            s <- selected_island()
            d <- nearest_cell(state$rain$data, s$lon, s$lat)
            d$value <- d$rain_mm
        }
        d
    })
    output$coverage <- renderUI({
        z <- layer_result()
        req(z$ok)
        d <- map_data()
        tagList(if (input$layer == "sst")
            p(class = "small-note", "Fuente: ", link("NOAA CoastWatch", SST_INFO), ". Análisis nocturno diario; se dibujan las celdas completas de 0,05°. La tierra enmascarada y las celdas marinas sin datos aparecen en gris. El marcador de isla no representa una medición.") else p(class = "small-note", "Fuente: ", link("NASA POWER / MERRA-2", "https://power.larc.nasa.gov/docs/services/api/temporal/monthly/"),
            ". Cada rectángulo grande representa una celda de 0,5° × 0,625°. Islas cercanas pueden compartir estimación. Fechas disponibles: ",
            format(min(state$rain$data$date[is.finite(state$rain$data$rain_mm)])), " a ", format(max(state$rain$data$date[is.finite(state$rain$data$rain_mm)]))),
            p("Fuera del área dibujada: datos no solicitados. Un dato faltante no equivale a cero."))
    })
    output$series_note <- renderUI({
        if (input$layer == "sst" && (is.null(state$history) || !state$history$ok))
            return(message_box("Historial marino no disponible. ", if (!is.null(state$history)) state$history$error))
        d <- selected_series()
        p(sprintf("%s · centro real de celda %.3f°, %.3f°; %s registros válidos. %s", input$island, d$latitude[1],
            d$longitude[1], sum(is.finite(d$value)), if (input$layer == "sst")
                "Celda marina cercana o seleccionada en el mapa; no es un promedio de la isla. Últimos 28 días. Los vacíos pueden deberse al enmascarado o a consultas remotas fallidas." else "Celda más cercana de la cuadrícula gruesa; totales mensuales calculados a partir de la media diaria."))
    })
    series_chart <- reactive({
        d <- selected_series()
        validate(need(any(is.finite(d$value)), "No hay valores válidos en esta celda."))
        ggplot(d, aes(date, value)) + geom_line(color = "#126f74", na.rm = TRUE) + labs(x = NULL, y = if (input$layer ==
            "sst")
            "Temperatura del mar (°C)" else "Lluvia estimada (mm/mes)", title = paste(input$island, "·", if (input$layer == "sst")
            "celda marina seleccionada" else "celda de lluvia más cercana"), subtitle = sprintf("Centro de celda %.3f, %.3f", d$latitude[1], d$longitude[1]),
            caption = paste(if (input$layer == "sst")
                "NOAA CoastWatch" else "NASA POWER / MERRA-2", "· consulta", d$retrieved_utc[1])) + scale_x_date(date_labels = "%Y-%m-%d") + theme_minimal(base_size = 13)
    })
    output$series_plot <- renderPlot(series_chart(), alt = "Historial de la ubicación seleccionada")
    output$island_coverage <- renderTable({
        z <- layer_result()
        validate(need(!is.null(z) && z$ok, "Capa remota no disponible."))
        d <- map_data()
        do.call(rbind, lapply(seq_len(nrow(islands)), function(i) {
            s <- islands[i, ]
            v <- nearest_cell(d, s$lon, s$lat)
            data.frame(Isla = s$island, Fecha = as.character(v$date[1]), Estado = if (is.finite(if (input$layer ==
                "sst") v$analysed_sst[1] else v$rain_mm[1]))
                "La celda más cercana tiene datos" else "Sin datos / máscara terrestre", Latitud = v$latitude[1], Longitud = v$longitude[1])
        }))
    }, digits = 3)
    observeEvent(input$forecast_refresh, {
        state$forecast <- fetch_result(function() {
            fetch_text(CPC, refresh = TRUE)
            get_forecast()
        })
        state$strength <- fetch_result(function() {
            fetch_text(STRENGTH, refresh = TRUE)
            get_strength()
        })
    }, ignoreNULL = FALSE)
    output$forecast <- renderUI({
        z <- state$forecast
        if (is.null(z) || !z$ok)
            return(message_box("No se pudo cargar o verificar el pronóstico oficial. ", link("Abrir el CPC de NOAA",
                CPC)))
        f <- z$data
        tagList(message_box(strong(f$status), h4(paste("Emitido", f$issue)), p(f$synopsis), p("Consulta: ",
            z$fetched, ". Próximo boletín previsto: ", as.character(f$next_issue), "."), if (!is.na(f$next_issue) &&
            Sys.Date() >= f$next_issue)
            strong("Hay una actualización prevista. Consulte NOAA antes de utilizar este pronóstico."), if (Sys.Date() - f$issue >
            40)
            strong(" Este boletín tiene más de 40 días.")), link("Leer el boletín oficial de NOAA",
            CPC))
    })
    strength_data <- reactive({
        req(state$strength, state$forecast)
        validate(need(state$strength$ok, "Servicio de probabilidades no disponible; utilice el enlace de NOAA."), need(state$forecast$ok,
            "No se pudo verificar la fecha de emisión del boletín."))
        s <- state$strength$data
        f <- state$forecast$data
        expected <- as.Date(format(f$issue, "%Y-%m-01"))
        validate(need(s$issue_month == expected, "Las fechas de emisión difieren: las probabilidades no se muestran hasta que las fuentes coincidan."))
        s$table
    })
    output$strength_note <- renderUI({
        req(state$strength)
        tagList(p("Índice: RONI trimestral (°C). El Niño débil: 0,5–<1; moderado: 1–<1,5; fuerte: 1,5–<2; muy fuerte: ≥2. Los intervalos negativos correspondientes describen La Niña. Son categorías, no un único máximo previsto."),
            p(if (state$strength$ok)
                state$strength$data$issued else state$strength$error), link("Fuente oficial de probabilidades y definiciones", STRENGTH))
    })
    output$strength_plot <- renderPlot(alt = "Probabilidades oficiales de intensidad del ENOS por trimestre", {
        d <- strength_data()
        n <- names(d)[-1]
        long <- do.call(rbind, lapply(n, function(k) data.frame(season = d$season, category = k, probability = d[[k]])))
        long$season <- factor(long$season, levels = d$season)
        long$category <- factor(long$category, levels = n)
        ggplot(long, aes(season, probability, fill = category)) + geom_col() + scale_fill_manual(values = c("#123b75",
            "#2464a4", "#579ac7", "#a6c9e1", "#b5bcbc", "#f7c79a", "#ef965d", "#d9503e", "#9e1b32"), labels = c("La Niña muy fuerte",
            "La Niña fuerte", "La Niña moderada", "La Niña débil", "Neutral", "El Niño débil", "El Niño moderado",
            "El Niño fuerte", "El Niño muy fuerte")) + labs(x = "Trimestres superpuestos", y = "Probabilidad (%)",
            fill = NULL, subtitle = state$strength$data$issued) + theme_minimal(base_size = 12) + theme(legend.position = "bottom")
    })
    output$strength_table <- renderTable({
        d <- strength_data()
        data.frame(Trimestre = d$season, `La Niña (%)` = rowSums(d[2:5]), `Neutral (%)` = d$neutral, `El Niño (%)` = rowSums(d[7:10]),
            `El Niño fuerte o muy fuerte (%)` = d$warm_strong + d$warm_very_strong, check.names = FALSE)
    })
    comparison_server(input, output, session, state)
    output$index_location <- renderUI(tagList(p(index_location_notes[[input$index]]), p("Rojo: valores positivos / fase cálida; azul: valores negativos / fase fría. El color indica el signo, no la clasificación oficial de un episodio ENOS. Los índices regionales son promedios de áreas, no mediciones de estaciones locales.")))
    output$index_region_map <- renderLeaflet({
        r <- index_regions[index_regions$index == input$index, ]
        leaflet_es(options = leafletOptions(minZoom = 1, worldCopyJump = FALSE)) |>
            mapa_base() |>
            fitBounds(95, -35, 295, 35) |>
            addRectangles(lng1 = r$west, lat1 = r$south, lng2 = r$east, lat2 = r$north, fillColor = "#126f74",
                color = "#126f74", fillOpacity = 0.22, weight = 2, popup = paste(index_label(input$index), "región de análisis")) |>
            addCircleMarkers(lng = 269.65, lat = -0.63, radius = 7, color = "#111111", fillColor = "#f4b942",
                fillOpacity = 1, label = "Galápagos", labelOptions = labelOptions(noHide = TRUE, direction = "right")) |>
            addControl(paste(index_label(input$index), "región · Galápagos en amarillo"), position = "bottomleft")
    })
    idx <- reactive(fetch_result(function() get_index(input$index)))
    idx_data <- reactive({
        z <- idx()
        validate(need(z$ok, "Fuente del índice no disponible."))
        d <- z$data
        d[d$date >= input$index_dates[1] & d$date <= input$index_dates[2], ]
    })
    output$index_status <- renderUI({
        z <- idx()
        if (!z$ok)
            return(message_box(z$error))
        d <- z$data
        v <- d$date[is.finite(d$value)]
        p("Cobertura del índice observado: ", as.character(min(v)), " a ", as.character(max(v)), ". Consulta: ",
            z$fetched, ". ", link("Archivo de origen", index_sources[[input$index]]))
    })
    output$index_plot <- plotly::renderPlotly({
        d <- idx_data()
        validate(need(any(is.finite(d$value)), "No hay valores en este período."))
        tip <- paste0("<b>", index_label(input$index), "</b><br>Fecha del período: ",
            format(d$date, "%Y-%m"), "<br>Valor: ",
            formatC(d$value, format = "f", digits = 2, decimal.mark = ","),
            if (input$index == "MEI") " (estandarizado; sin unidades)" else " °C")
        p <- plotly::plot_ly()
        # Los tramos separados conservan las interrupciones por datos faltantes.
        runs <- cumsum(!is.finite(d$value))
        for (rows in split(which(is.finite(d$value)), runs[is.finite(d$value)])) {
            z <- d[rows, ]
            p <- plotly::add_trace(p, x = z$date, y = pmax(z$value, 0),
                type = "scatter", mode = "lines", fill = "tozeroy",
                line = list(color = "#b2182b", width = 2),
                fillcolor = "rgba(178,24,43,0.25)", hoverinfo = "skip", showlegend = FALSE)
            p <- plotly::add_trace(p, x = z$date, y = pmin(z$value, 0),
                type = "scatter", mode = "lines", fill = "tozeroy",
                line = list(color = "#2166ac", width = 2),
                fillcolor = "rgba(33,102,172,0.25)", hoverinfo = "skip", showlegend = FALSE)
        }
        p <- plotly::add_trace(p, x = d$date, y = d$value, text = tip,
            type = "scatter", mode = "markers", inherit = FALSE,
            marker = list(size = 10, opacity = 0), showlegend = FALSE,
            hovertemplate = "%{text}<extra></extra>", connectgaps = FALSE)
        p <- plotly::layout(p, hovermode = "closest", dragmode = FALSE,
            title = list(text = paste("Observaciones históricas ·", index_label(input$index))),
            xaxis = list(title = "", type = "date", tickformat = "%Y-%m", fixedrange = TRUE),
            yaxis = list(title = if (input$index == "MEI") "MEI.v2 estandarizado" else "Anomalía (°C)",
                zeroline = TRUE, zerolinecolor = "#777777", fixedrange = TRUE),
            margin = list(l = 65, r = 20, t = 45, b = 45),
            hoverlabel = list(bgcolor = "white", font = list(size = 14)))
        plotly::config(p, displayModeBar = FALSE, showTips = FALSE, scrollZoom = FALSE)
    })
    output$map_csv <- downloadHandler(filename = function() paste0("galapagos-", if (input$layer == "sst") "temperatura-mar" else "lluvia", "-mapa.csv"),
        content = function(file) export_csv(map_data(), file, row.names = FALSE, na = ""))
    output$series_csv <- downloadHandler(filename = function() paste0(input$island, "-", if (input$layer == "sst") "temperatura-mar" else "lluvia", "-historial.csv"),
        content = function(file) export_csv(selected_series(), file, row.names = FALSE, na = ""))
    output$figure <- downloadHandler(filename = function() paste0(input$island, "-", input$layer, ".png"),
        content = function(file) ggsave(file, series_chart(), device = grDevices::png, width = 10, height = 4.5, dpi = 180))
    output$forecast_csv <- downloadHandler(filename = function() "noaa-enos-intensidad.csv", content = function(file) {
        d <- strength_data()
        d$issue_date <- as.character(state$forecast$data$issue)
        d$index <- "RONI"
        d$source_url <- STRENGTH
        d$retrieved_utc <- state$strength$fetched
        export_csv(d, file, row.names = FALSE)
    })
    output$index_csv <- downloadHandler(filename = function() paste0(input$index, "-historial.csv"), content = function(file) export_csv(idx_data(),
        file, row.names = FALSE, na = ""))
}
shinyApp(ui, server)
