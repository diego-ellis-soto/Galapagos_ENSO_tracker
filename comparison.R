comparison_ui <- function() nav_panel("Comparar con el promedio", h3("¿Cuánto se aparta del promedio?"), p("Compare un día o mes con su promedio estacional de largo plazo. Delta significa valor seleccionado menos promedio: es una diferencia observada, no un pronóstico."),
    layout_columns(col_widths = c(3, 3, 3, 3), selectInput("compare_kind", "Variable", c(`Temperatura del mar` = "sst",
        `Lluvia estimada` = "rain")), conditionalPanel("input.compare_kind == 'sst'", dateInput("compare_day", language = "es",
        "Fecha de temperatura del mar", value = Sys.Date() - 8)), conditionalPanel("input.compare_kind == 'rain'",
        selectInput("compare_month", "Mes de lluvia", choices = character())), actionButton("compare_fetch",
        "Consultar comparación", class = "btn-primary")), checkboxInput("show_normal", "Mostrar el promedio de largo plazo a la izquierda (en lugar del valor seleccionado)",
        FALSE), selectInput("compare_island", "Resumen por isla", islands$island, selected = "Santa Cruz"),
    uiOutput("compare_status"), uiOutput("compare_summary"), layout_columns(col_widths = c(6, 6), card(card_header(textOutput("compare_left_title")),
        leafletOutput("compare_left", height = 470)), card(card_header(textOutput("compare_right_title")),
        leafletOutput("compare_right", height = 470))), p("Ambos mapas comienzan con la misma extensión. Amplíe cualquiera para explorar. Pulse una celda para ver su valor, referencia y diferencia. El gris indica que falta el valor o una referencia adecuada. Las escalas de valores absolutos y diferencias son independientes."),
    downloadButton("compare_csv", "Cuadrícula de comparación (CSV)"), downloadButton("compare_png", "Gráfico de comparación (PNG)"),
    tags$details(tags$summary("Referencia, fuentes e interpretación"), p("Temperatura marina: NOAA CoralTemp v3.1 y su anomalía diaria oficial respecto a 1991–2020. La temperatura de referencia se reconstruye restando la anomalía oficial a la temperatura del mismo producto. La comparación puede tener más retraso que la capa de monitoreo y utiliza la última fecha común verificada."),
        link("Metadatos de la anomalía NOAA respecto a 1991–2020", "https://coastwatch.noaa.gov/erddap/info/noaacrwsstanomalybaselineDaily/index.html"),
        br(), link("Metadatos del producto NOAA de temperatura correspondiente", "https://coastwatch.noaa.gov/erddap/info/noaacrwsstDaily/index.html"),
        p("Lluvia: NASA POWER/MERRA-2. La referencia es el promedio del total del mismo mes calendario durante 1991–2020; se requieren al menos 25 de los 30 años válidos por celda. No se muestran diferencias porcentuales si la lluvia de referencia es inferior a 1 mm/mes. Los mapas muestran diferencias absolutas en mm/mes."),
        p("Una anomalía no demuestra significación estadística ni que la causa sea el ENOS. El promedio histórico incluye años con ENOS y cambios climáticos de largo plazo. Ninguna capa pronostica impactos en las islas.")))
comparison_server <- function(input, output, session, monitor_state) {
    comp <- reactiveValues(result = NULL, meta = NULL)
    observe({
        req(monitor_state$rain$ok)
        d <- monitor_state$rain$data
        months <- sort(unique(d$date[is.finite(d$rain_mm)]))
        updateSelectInput(session, "compare_month", choices = as.character(months), selected = as.character(tail(months,
            1)))
    })
    observeEvent(list(input$page, input$compare_fetch), {
        req(input$page == "Comparar con el promedio")
        withProgress(message = "Consultando la comparación estacional remota", value = 0.1, {
            if (input$compare_kind == "sst") {
                comp$result <- fetch_result(function() {
                  m <- compare_sst_meta()
                  day <- if (is.null(comp$meta))
                    m$end else as.Date(input$compare_day)
                  comp$meta <- m
                  updateDateInput(session, "compare_day", min = m$start, max = m$end, value = day)
                  if (is.na(day) || day < m$start || day > m$end)
                    stop(paste("Seleccione una fecha entre", m$start, "y", m$end))
                  get_sst_comparison(day)
                })
            } else {
                comp$result <- fetch_result(function() {
                  if (is.null(monitor_state$rain))
                    monitor_state$rain <- fetch_result(function() get_rain(as.integer(input$rain_start), as.integer(format(Sys.Date(), "%Y"))))
                  if (!monitor_state$rain$ok) stop(monitor_state$rain$error)
                  baseline <- get_rain(1991, 2020)
                  month <- input$compare_month
                  if (is.null(month) || !nzchar(month)) {
                    rain <- monitor_state$rain$data
                    month <- max(rain$date[is.finite(rain$rain_mm)])
                  }
                  compare_rain(monitor_state$rain$data, baseline, month)
                })
            }
            incProgress(0.9)
        })
    }, ignoreNULL = FALSE)
    data <- reactive({
        req(comp$result)
        validate(need(comp$result$ok, comp$result$error))
        comp$result$data
    })
    output$compare_status <- renderUI({
        if (is.null(comp$result))
            return(message_box("Seleccione una variable y consulte la comparación."))
        if (!comp$result$ok)
            return(message_box("Comparación no disponible: ", comp$result$error))
        d <- data()
        message_box(strong(paste(if (d$kind[1] == "sst")
            "Comparación de temperatura marina" else "Comparación de lluvia", unique(d$date))), p(paste("Referencia:", d$baseline_period[1])), p(sprintf("%s de %s celdas tienen valor seleccionado y referencia. Consulta: %s.",
            sum(is.finite(d$delta)), nrow(d), comp$result$fetched)), if (input$compare_kind != d$kind[1])
            strong("La variable cambió: pulse Consultar comparación para actualizar los mapas."))
    })
    output$compare_summary <- renderUI({
        d <- data()
        s <- islands[islands$island == input$compare_island, ]
        if (d$kind[1] == "sst") {
            valid <- d[is.finite(d$delta), ]
            dist <- (valid$longitude - s$lon)^2 + (valid$latitude - s$lat)^2
            if (!length(dist) || min(dist) > 0.25)
                return(p("No hay una celda marina cercana con referencia válida."))
            r <- valid[which.min(dist), ]
        } else r <- nearest_cell(d, s$lon, s$lat)
        if (!is.finite(r$delta[1]))
            return(p("La celda más cercana no tiene una referencia adecuada."))
        message_box(strong(sprintf("%s: %+.2f %s respecto al promedio", s$island, r$delta[1], r$unit[1])),
            p(sprintf("Valor seleccionado: %.2f · promedio: %.2f · centro de celda: %.3f°, %.3f°. Es un resumen de la celda, no un promedio de la isla.",
                r$observed[1], r$baseline[1], r$latitude[1], r$longitude[1])), if (d$kind[1] == "rain")
                p(sprintf("Referencia: %s de 30 años válidos.%s", r$baseline_n[1], if (is.finite(r$percent_delta[1]))
                  sprintf(" Diferencia: %+.1f%%.", r$percent_delta[1]) else " No se muestra el porcentaje porque el promedio es cercano a cero.")))
    })
    output$compare_left_title <- renderText(if (input$show_normal)
        "Promedio estacional de largo plazo" else "Día / mes seleccionado")
    output$compare_right_title <- renderText("Diferencia respecto al promedio estacional")
    build_map <- function(d, which) {
        sst <- d$kind[1] == "sst"
        value <- d[[which]]
        absvalues <- c(d$observed, d$baseline)
        domain <- if (any(is.finite(absvalues)))
            range(absvalues, na.rm = TRUE) else c(0, 1)
        if (which == "delta") {
            m <- max(abs(d$delta), if (sst) 0.5 else 1, na.rm = TRUE)
            pal <- colorNumeric(if (sst)
                c("#2166ac", "#f7f7f7", "#b2182b") else c("#a6611a", "#f5f5f5", "#018571"), c(-m, m), na.color = "#969fa3")
        } else pal <- colorNumeric(if (sst)
            "YlOrRd" else "Blues", domain, na.color = "#969fa3")
        dx <- if (sst)
            0.025 else 0.3125
        dy <- if (sst)
            0.025 else 0.25
        popup <- sprintf("Celda %.3f, %.3f<br>%s<br>Valor seleccionado: %s %s<br>Promedio: %s<br>Diferencia: %s<br>Referencia: %s",
            d$latitude, d$longitude, d$date, round(d$observed, 2), d$unit, round(d$baseline, 2), ifelse(is.finite(d$delta),
                sprintf("%+.2f", d$delta), "Sin datos"), d$baseline_period)
        mapa_galapagos() |>
            addRectangles(lng1 = d$longitude - dx, lat1 = d$latitude - dy, lng2 = d$longitude + dx, lat2 = d$latitude +
                dy, fillColor = pal(value), fillOpacity = 0.8, weight = if (sst)
                0 else 0.8, color = "#777", popup = popup) |>
            addCircleMarkers(data = islands, lng = ~lon, lat = ~lat, radius = 4, color = "#173d46", fillColor = "white",
                fillOpacity = 1, label = ~island) |>
            addLegend(pal = pal, values = if (which == "delta")
                c(-m, m) else domain, title = paste(if (which == "delta")
                "Diferencia" else "Valor", d$unit[1]), na.label = "Sin datos") |>
            addControl(if (which == "delta")
                if (sst)
                  "Azul: más frío · Rojo: más cálido" else "Marrón: más seco · Verde: más lluvioso" else paste(unique(d$date)), position = "bottomleft")
    }
    output$compare_left <- renderLeaflet(build_map(data(), if (input$show_normal)
        "baseline" else "observed"))
    output$compare_right <- renderLeaflet(build_map(data(), "delta"))
    output$compare_csv <- downloadHandler(filename = function() "galapagos-comparacion-estacional.csv", content = function(file) export_csv(data(),
        file, row.names = FALSE, na = ""))
    output$compare_png <- downloadHandler(filename = function() "galapagos-delta.png", content = function(file) {
        d <- data()
        m <- max(abs(d$delta), 0.5, na.rm = TRUE)
        p <- ggplot(d, aes(longitude, latitude, fill = delta)) + geom_tile(width = if (d$kind[1] == "sst")
            0.05 else 0.625, height = if (d$kind[1] == "sst")
            0.05 else 0.5) + geom_point(data = islands, aes(lon, lat), inherit.aes = FALSE, size = 1.5) + geom_text(data = islands,
            aes(lon, lat, label = island), inherit.aes = FALSE, size = 2.5, hjust = 0, nudge_x = 0.04) + scale_fill_gradient2(low = if (d$kind[1] ==
            "sst")
            "#2166ac" else "#a6611a", mid = "white", high = if (d$kind[1] == "sst")
            "#b2182b" else "#018571", limits = c(-m, m), na.value = "gray65") + coord_fixed() + theme_minimal(base_size = 12) +
            labs(title = paste("Galápagos · delta", unique(d$date)), subtitle = d$baseline_period[1], fill = paste("Diferencia",
                d$unit[1]), x = "Longitud", y = "Latitud", caption = paste(if (d$kind[1] == "sst")
                "NOAA CoralTemp + anomalía oficial" else "NASA POWER / MERRA-2", "· consulta", d$retrieved_utc[1]))
        ggsave(file, p, device = grDevices::png, width = 8, height = 8, dpi = 180)
    })
}
