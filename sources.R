# Remote physical-environment data only. No data files or disk cache are read.
SST_BASE <- "https://coastwatch.noaa.gov/erddap/griddap/noaacwBLENDEDCsstDaily"
SST_INFO <- "https://coastwatch.noaa.gov/erddap/info/noaacwBLENDEDCsstDaily/index.csv"
CPC <- "https://www.cpc.ncep.noaa.gov/products/analysis_monitoring/enso_advisory/ensodisc_Sp.shtml"
STRENGTH <- "https://www.cpc.ncep.noaa.gov/products/analysis_monitoring/enso/roni/strengths/"
POWER <- "https://power.larc.nasa.gov/api/temporal/monthly/regional"
# Approximate island label positions, NOT sampling stations or observation locations.
islands <- data.frame(island = c("Isabela", "Fernandina", "Santa Cruz", "San Cristóbal", "Española", "Floreana",
    "Santiago", "Marchena", "Pinta", "Genovesa", "Santa Fe", "Pinzón", "Darwin", "Wolf"), lon = c(-91.12,
    -91.55, -90.35, -89.43, -89.68, -90.48, -90.77, -90.47, -90.75, -89.96, -90.07, -90.67, -91.99, -91.82),
    lat = c(-0.55, -0.37, -0.63, -0.83, -1.37, -1.29, -0.25, 0.33, 0.58, 0.32, -0.82, -0.61, 1.68, 1.38))
utc_now <- function(time = Sys.time()) format(time, "%Y-%m-%d %H:%M UTC", tz = "UTC")
remote_cache <- new.env(parent = emptyenv())
fetch_text <- function(url, refresh = FALSE) {
    if (!refresh && exists(url, remote_cache, inherits = FALSE)) {
        z <- get(url, remote_cache)
        if (difftime(Sys.time(), z$time, units = "hours") < 1)
            return(z)
    }
    r <- httr2::request(url) |>
        httr2::req_user_agent("GalapagosPhysicalMonitor/1.0") |>
        httr2::req_timeout(25) |>
        httr2::req_retry(max_tries = 2, max_seconds = 30, retry_on_failure = TRUE,
            is_transient = function(resp) httr2::resp_status(resp) %in% c(429, 500, 502, 503, 504),
            backoff = function(n) 1) |>
        httr2::req_perform()
    z <- list(text = httr2::resp_body_string(r), time = Sys.time(), url = url)
    assign(url, z, remote_cache)
    z
}
fetch_result <- function(fun) tryCatch(list(ok = TRUE, data = fun(), fetched = utc_now(), error = NULL), error = function(e) list(ok = FALSE,
    data = NULL, fetched = utc_now(), error = if (inherits(e, c("httr2_error", "curl_error"))) "No se pudo consultar el servicio remoto. Revise la conexión y vuelva a intentarlo." else conditionMessage(e)))
read_csv_text <- function(txt, ...) read.csv(text = txt, stringsAsFactors = FALSE, check.names = FALSE, ...)
get_sst_meta <- function() {
    d <- read_csv_text(fetch_text(SST_INFO)$text)
    val <- function(n) d$Value[d$`Variable Name` == "NC_GLOBAL" & d$`Attribute Name` == n][1]
    a <- as.Date(substr(val("time_coverage_start"), 1, 10))
    b <- as.Date(substr(val("time_coverage_end"), 1, 10))
    if (anyNA(c(a, b)))
        stop("Los metadatos de temperatura cambiaron; no se puede verificar la cobertura temporal.")
    list(start = a, end = b, source = SST_INFO)
}
erddap_url <- function(query) paste0(SST_BASE, ".csv?", URLencode(query, reserved = TRUE))
parse_sst <- function(txt) {
    d <- read_csv_text(txt)
    if (!all(c("time", "latitude", "longitude", "analysed_sst") %in% names(d)))
        stop("El formato de los datos de temperatura no es el esperado.")
    d <- d[-1, , drop = FALSE]  # ERDDAP unit row
    d$date <- as.Date(substr(d$time, 1, 10))
    for (n in c("latitude", "longitude", "analysed_sst")) d[[n]] <- as.numeric(d[[n]])
    d$analysed_sst[!is.finite(d$analysed_sst) | d$analysed_sst < -3 | d$analysed_sst > 45] <- NA_real_
    if (!nrow(d) || anyNA(d$date))
        stop("La respuesta de temperatura no contiene fechas válidas.")
    d
}
get_sst_map <- function(date) {
    u <- erddap_url(sprintf("analysed_sst[(%sT12:00:00Z)][(-1.575):1:(1.825)][(-92.475):1:(-89.025)]", date))
    response <- fetch_text(u)
    d <- parse_sst(response$text)
    d$source_url <- u
    d$retrieved_utc <- utc_now(fetch_text(u)$time)
    d
}
get_sst_series <- function(lon, lat, start, end) {
    # Small chunks avoid provider timeouts when reading many daily remote files.
    dates <- seq(as.Date(start), as.Date(end), by = "day")
    chunks <- split(dates, ceiling(seq_along(dates)/7))
    out <- lapply(chunks, function(ds) {
        u <- erddap_url(sprintf("analysed_sst[(%sT12:00:00Z):1:(%sT12:00:00Z)][(%s)][(%s)]", min(ds), max(ds),
            lat, lon))
        z <- fetch_result(function() parse_sst(fetch_text(u)$text))
        base <- data.frame(date = ds)
        if (z$ok) {
            d <- merge(base, z$data, by = "date", all.x = TRUE)
            d$request_status <- "Consultado"
        } else {
            d <- base
            d$latitude <- lat
            d$longitude <- lon
            d$analysed_sst <- NA_real_
            d$time <- NA_character_
            d$request_status <- paste("Error del servicio:", z$error)
        }
        d$source_url <- u
        d$retrieved_utc <- if (z$ok)
            utc_now(fetch_text(u)$time) else NA_character_
        d
    })
    do.call(rbind, out)
}
days_in_month <- function(d) as.integer(as.Date(format(d + 32, "%Y-%m-01")) - as.Date(format(d, "%Y-%m-01")))
parse_rain <- function(txt) {
    x <- jsonlite::fromJSON(txt, simplifyVector = FALSE)
    if (is.null(x$features) || x$parameters$PRECTOTCORR$units != "mm/day")
        stop("El formato o las unidades de lluvia de NASA no son los esperados.")
    d <- do.call(rbind, lapply(x$features, function(f) {
        v <- unlist(f$properties$parameter$PRECTOTCORR)
        k <- names(v)
        keep <- grepl("^[0-9]{6}$", k) & substr(k, 5, 6) %in% sprintf("%02d", 1:12)
        data.frame(date = as.Date(paste0(k[keep], "01"), "%Y%m%d"), longitude = f$geometry$coordinates[[1]],
            latitude = f$geometry$coordinates[[2]], rate_mm_day = as.numeric(v[keep]))
    }))
    d$rate_mm_day[d$rate_mm_day == x$header$fill_value | d$rate_mm_day < 0] <- NA_real_
    d$rain_mm <- d$rate_mm_day * days_in_month(d$date)
    d
}
get_rain <- function(start_year, end_year) {
    u <- sprintf("%s?parameters=PRECTOTCORR&community=AG&longitude-min=-92.5&longitude-max=-89&latitude-min=-1.5&latitude-max=2&start=%s&end=%s&format=JSON",
        POWER, start_year, end_year)
    response <- fetch_text(u)
    d <- parse_rain(response$text)
    if (!nrow(d) || !any(is.finite(d$rain_mm)))
        stop("NASA no devolvió valores válidos de lluvia.")
    coords <- unique(d[c("longitude", "latitude")])
    dates <- seq(min(d$date), max(d$date), by = "month")
    grid <- merge(coords, data.frame(date = dates), by = NULL)
    d <- merge(grid, d, by = c("longitude", "latitude", "date"), all.x = TRUE)
    d <- d[order(d$longitude, d$latitude, d$date), ]
    d$source_url <- u
    d$retrieved_utc <- utc_now(fetch_text(u)$time)
    d
}
parse_forecast <- function(txt) {
    doc <- xml2::read_html(txt, encoding = "UTF-8")
    body <- rvest::html_text2(rvest::html_element(doc, "body"))
    months <- c("enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre")
    dates <- regmatches(tolower(body), gregexpr(paste0("[0-9]{1,2} de (", paste(months, collapse = "|"), ") de [0-9]{4}"), tolower(body)))[[1]]
    if (!length(dates) || !grepl("Sinopsis:", body, fixed = TRUE))
        stop("El formato del CPC cambió. Abra el boletín oficial mediante el enlace.")
    parse_date <- function(x) {
        s <- strsplit(x, " de ")[[1]]
        as.Date(sprintf("%s-%02d-%02d", s[3], match(s[2], months), as.integer(s[1])))
    }
    synopsis <- sub(".*Sinopsis:\\s*", "", body)
    synopsis <- regmatches(synopsis, regexpr("^.*?[.!?]( |$)", synopsis, perl = TRUE))
    if (!length(synopsis) || !nzchar(synopsis)) stop("No se pudo verificar la sinopsis del CPC.")
    status <- sub(".*Estatus del Sistema de alerta del ENSO:\\s*", "", body)
    status <- sub("Sinopsis:.*", "", status)
    if (identical(status, body)) stop("No se pudo verificar el estado del ENOS.")
    list(issue = parse_date(dates[1]), next_issue = if (length(dates) > 1) parse_date(tail(dates, 1)) else as.Date(NA),
        synopsis = trimws(synopsis), status = trimws(status), source = CPC)
}
get_forecast <- function() parse_forecast(fetch_text(CPC)$text)
parse_strength <- function(txt) {
    doc <- xml2::read_html(txt, encoding = "UTF-8")
    body <- rvest::html_text2(rvest::html_element(doc, "body"))
    issued <- regmatches(body, regexpr("Issued [A-Za-z]+ [0-9]{4}", body))
    if (!length(issued) || !grepl("Relative Oceanic", body, fixed = TRUE))
        stop("No se pudo verificar la emisión del pronóstico ni su referencia RONI.")
    tables <- rvest::html_table(doc)
    idx <- which(vapply(tables, function(x) ncol(x) == 10 && names(x)[1] == "Season", logical(1)))
    if (length(idx) != 1)
        stop("El formato de la tabla de probabilidades del CPC cambió.")
    d <- as.data.frame(tables[[idx]])
    names(d) <- c("season", "cold_very_strong", "cold_strong", "cold_moderate", "cold_weak", "neutral", "warm_weak",
        "warm_moderate", "warm_strong", "warm_very_strong")
    for (n in names(d)[-1]) d[[n]] <- as.numeric(d[[n]])
    m <- as.matrix(d[-1])
    if (anyNA(m) || any(m < 0 | m > 100) || any(abs(rowSums(m) - 100) > 1))
        stop("Las probabilidades del CPC no superaron la validación.")
    parts <- strsplit(issued, " ")[[1]]
    month_number <- match(parts[2], month.name)
    issue_month <- as.Date(sprintf("%s-%02d-01", parts[3], month_number))
    meses <- c("enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre")
    seasons <- c(DJF="dic–ene–feb", JFM="ene–feb–mar", FMA="feb–mar–abr", MAM="mar–abr–may", AMJ="abr–may–jun", MJJ="may–jun–jul", JJA="jun–jul–ago", JAS="jul–ago–sep", ASO="ago–sep–oct", SON="sep–oct–nov", OND="oct–nov–dic", NDJ="nov–dic–ene")
    d$season <- sub("[[:space:]].*", "", trimws(d$season))
    if (!all(d$season %in% names(seasons))) stop("No se reconocen los trimestres del CPC.")
    for (key in names(seasons)) d$season <- gsub(key, seasons[[key]], d$season, fixed = TRUE)
    list(table = d, issue_month = issue_month, issued = paste("Emitido en", meses[month_number], "de", parts[3]), source = STRENGTH)
}
get_strength <- function() parse_strength(fetch_text(STRENGTH)$text)
index_sources <- c(ONI = "https://psl.noaa.gov/data/correlation/oni.data", MEI = "https://psl.noaa.gov/enso/mei/data/meiv2.data",
    Nino12 = "https://psl.noaa.gov/data/correlation/nina1.anom.data", Nino3 = "https://psl.noaa.gov/data/correlation/nina3.anom.data",
    Nino34 = "https://psl.noaa.gov/data/correlation/nina34.anom.data", Nino4 = "https://psl.noaa.gov/data/correlation/nina4.anom.data")
parse_index <- function(txt) {
    lines <- strsplit(txt, "\n", fixed = TRUE)[[1]]
    lines <- lines[grepl("^\\s*[12][0-9]{3}\\s", lines)]
    rows <- lapply(lines, function(l) scan(text = l, quiet = TRUE))
    rows <- rows[lengths(rows) == 13]
    if (!length(rows))
        stop("El formato de la tabla del índice no es el esperado.")
    d <- do.call(rbind, lapply(rows, function(x) data.frame(date = as.Date(sprintf("%04d-%02d-01", as.integer(x[1]),
        1:12)), value = x[-1])))
    d$value[abs(d$value) > 90] <- NA_real_
    d <- d[d$date <= Sys.Date(), ]
    d
}
get_index <- function(id) {
    u <- index_sources[[id]]
    response <- fetch_text(u)
    d <- parse_index(response$text)
    d$index <- id
    d$source_url <- u
    d$retrieved_utc <- utc_now(fetch_text(u)$time)
    d
}
nearest_cell <- function(d, lon, lat) {
    coords <- unique(d[c("longitude", "latitude")])
    i <- which.min((coords$longitude - lon)^2 + (coords$latitude - lat)^2)
    d[d$longitude == coords$longitude[i] & d$latitude == coords$latitude[i], , drop = FALSE]
}

# Same-product SST comparison: do not subtract a CoralTemp normal from another SST analysis.
DELTA_DATASET <- "noaacrwsstanomalybaselineDaily"
COMPARE_SST_DATASET <- "noaacrwsstDaily"
grid_meta <- function(dataset) {
    u <- paste0("https://coastwatch.noaa.gov/erddap/info/", dataset, "/index.csv")
    d <- read_csv_text(fetch_text(u)$text)
    val <- function(n) d$Value[d$`Variable Name` == "NC_GLOBAL" & d$`Attribute Name` == n][1]
    list(start = as.Date(substr(val("time_coverage_start"), 1, 10)), end = as.Date(substr(val("time_coverage_end"),
        1, 10)), source = u, description = val("summary"))
}
compare_sst_meta <- function() {
    a <- grid_meta(DELTA_DATASET)
    b <- grid_meta(COMPARE_SST_DATASET)
    if (!grepl("1991-2020", a$description, fixed = TRUE))
        stop("La referencia de la anomalía oficial cambió.")
    list(start = max(a$start, b$start), end = min(a$end, b$end))
}
get_grid <- function(dataset, variable, date, descending = FALSE) {
    lat <- if (descending)
        "[(1.825):1:(-1.575)]" else "[(-1.575):1:(1.825)]"
    query <- sprintf("%s[(%sT12:00:00Z)]%s[(-92.475):1:(-89.025)]", variable, date, lat)
    u <- paste0("https://coastwatch.noaa.gov/erddap/griddap/", dataset, ".csv?", URLencode(query, reserved = TRUE))
    response <- fetch_text(u)
    d <- read_csv_text(response$text)
    if (!all(c("time", "latitude", "longitude", variable) %in% names(d)))
        stop("El formato de la cuadrícula de comparación cambió.")
    if (!d[[variable]][1] %in% c("degree_C", "degree_Celsius"))
        stop("Las unidades de temperatura no se reconocen.")
    d <- d[-1, ]
    d$date <- as.Date(substr(d$time, 1, 10))
    for (n in c("latitude", "longitude", variable)) d[[n]] <- as.numeric(d[[n]])
    d$value <- d[[variable]]
    d$value[!is.finite(d$value) | abs(d$value) > 90] <- NA_real_
    d$source_url <- u
    d$retrieved_utc <- utc_now(response$time)
    d
}
get_sst_comparison <- function(date) {
    a <- get_grid(COMPARE_SST_DATASET, "analysed_sst", date)
    b <- get_grid(DELTA_DATASET, "sea_surface_temperature_anomaly", date, TRUE)
    names(a)[names(a) == "value"] <- "observed"
    names(b)[names(b) == "value"] <- "delta"
    d <- merge(a[c("date", "longitude", "latitude", "observed", "source_url", "retrieved_utc")], b[c("date",
        "longitude", "latitude", "delta", "source_url")], by = c("date", "longitude", "latitude"), all = TRUE,
        suffixes = c("", "_anomaly"))
    d$baseline <- d$observed - d$delta
    d$baseline_period <- "1991-2020; climatología diaria de NOAA"
    d$baseline_n <- NA_integer_
    d$percent_delta <- NA_real_
    d$kind <- "sst"
    d$unit <- "°C"
    d
}
compare_rain <- function(observed, baseline, date) {
    month <- format(as.Date(date), "%m")
    b <- baseline[format(baseline$date, "%m") == month & as.integer(format(baseline$date, "%Y")) %in% 1991:2020,
        ]
    # Exactly one value per year/cell is required before counting baseline years.
    if (anyDuplicated(b[c("date", "longitude", "latitude")]))
        stop("Hay registros mensuales duplicados por celda en la referencia.")
    groups <- split(b, paste(b$longitude, b$latitude))
    normal <- do.call(rbind, lapply(groups, function(x) {
        n <- sum(is.finite(x$rain_mm))
        data.frame(longitude = x$longitude[1], latitude = x$latitude[1], baseline = if (n >= 25)
            mean(x$rain_mm, na.rm = TRUE) else NA_real_, baseline_n = n)
    }))
    a <- observed[observed$date == as.Date(date), ]
    if (!nrow(a))
        stop("No hay lluvia observada para este mes.")
    a$observed <- a$rain_mm
    d <- merge(a, normal, by = c("longitude", "latitude"), all.x = TRUE)
    d$delta <- d$observed - d$baseline
    d$percent_delta <- ifelse(is.finite(d$baseline) & d$baseline >= 1, 100 * d$delta/d$baseline, NA_real_)
    d$baseline_period <- "1991-2020; mismo mes calendario; al menos 25 años válidos"
    d$source_url_baseline <- unique(baseline$source_url)[1]
    d$kind <- "rain"
    d$unit <- "mm/mes"
    d
}
# Longitudes are 0–360 to show a continuous Pacific-centered map.
index_regions <- data.frame(index = c("ONI", "MEI", "Nino12", "Nino3", "Nino34", "Nino4"), west = c(190, 100,
    270, 210, 190, 160), east = c(240, 290, 280, 270, 240, 210), south = c(-5, -30, -10, -5, -5, -5), north = c(5,
    30, 0, 5, 5, 5))
index_location_notes <- c(ONI = "ONI utiliza Niño 3.4, muy al oeste de Galápagos. Las islas están fuera de esta región del Pacífico central.",
    MEI = "Galápagos está dentro del amplio dominio del MEI en el Pacífico tropical, cerca de su extremo oriental. MEI combina patrones espaciales de toda la región; el rectángulo solo muestra el dominio de análisis, no los pesos. Se excluyen las zonas terrestres y del Atlántico.",
    Nino12 = "El archipiélago cruza el límite occidental de Niño 1+2 (90°O). Partes de las islas orientales al sur del ecuador están dentro; las islas occidentales y septentrionales quedan fuera. Este promedio regional no es una medición de las islas.",
    Nino3 = "Galápagos se encuentra en el extremo oriental de Niño 3 (90°O). Las islas occidentales están dentro de su intervalo de longitudes; partes orientales del archipiélago quedan fuera.",
    Nino34 = "Niño 3.4 está en el Pacífico ecuatorial central, muy al oeste de Galápagos. Las islas quedan fuera de esa región.",
    Nino4 = "Niño 4 está en el Pacífico ecuatorial centro-occidental, muy al oeste de Galápagos. Las islas quedan fuera de esa región.")

# Nombres de columnas en las descargas; las claves internas de los servicios se conservan.
export_csv <- function(x, file, ...) {
    labels <- c(time="fecha_hora", date="fecha", latitude="latitud", longitude="longitud", analysed_sst="temperatura_mar_C", value="valor", source_url="url_fuente", retrieved_utc="consulta_UTC", request_status="estado_consulta", rate_mm_day="lluvia_mm_dia", rain_mm="lluvia_mm_mes", index="indice", season="trimestre", cold_very_strong="nina_muy_fuerte_pct", cold_strong="nina_fuerte_pct", cold_moderate="nina_moderada_pct", cold_weak="nina_debil_pct", neutral="neutral_pct", warm_weak="nino_debil_pct", warm_moderate="nino_moderado_pct", warm_strong="nino_fuerte_pct", warm_very_strong="nino_muy_fuerte_pct", issue_date="fecha_emision", observed="valor_seleccionado", baseline="promedio_referencia", delta="diferencia", source_url_anomaly="url_fuente_anomalia", baseline_period="periodo_referencia", baseline_n="anos_validos_referencia", percent_delta="diferencia_porcentual", kind="variable", unit="unidad", source_url_baseline="url_fuente_referencia")
    if ("kind" %in% names(x)) x$kind <- ifelse(x$kind == "sst", "temperatura_mar", "lluvia")
    matched <- names(x) %in% names(labels)
    names(x)[matched] <- unname(labels[names(x)[matched]])
    write.csv(x, file, ..., fileEncoding = "UTF-8")
}
leaflet_es <- function(...) htmlwidgets::onRender(leaflet::leaflet(...), "function(el,x){el.querySelectorAll('.leaflet-control-zoom-in').forEach(e=>{e.title='Acercar';e.setAttribute('aria-label','Acercar')});el.querySelectorAll('.leaflet-control-zoom-out').forEach(e=>{e.title='Alejar';e.setAttribute('aria-label','Alejar')})}")
mapa_base <- function(map) leaflet::addTiles(map, urlTemplate = "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", attribution = '&copy; <a href="https://www.openstreetmap.org/copyright">Colaboradores de OpenStreetMap</a>')

index_label <- function(id) unname(c(ONI="ONI", MEI="MEI.v2", Nino12="Niño 1+2", Nino3="Niño 3", Nino34="Niño 3.4", Nino4="Niño 4")[[id]])

# Área de navegación local; incluye Darwin y Wolf.
galapagos_bounds <- list(c(-1.7, -92.55), c(1.9, -89))
mapa_galapagos <- function() {
    m <- leaflet_es(options = leaflet::leafletOptions(preferCanvas = TRUE,
        maxBounds = galapagos_bounds, maxBoundsViscosity = 1)) |>
        leaflet::addTiles(urlTemplate = "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
            options = leaflet::tileOptions(noWrap = TRUE, bounds = galapagos_bounds),
            attribution = '&copy; <a href="https://www.openstreetmap.org/copyright">Colaboradores de OpenStreetMap</a>') |>
        leaflet::fitBounds(-92.55, -1.7, -89, 1.9)
    htmlwidgets::onRender(m, "function(el,x){var map=this;var bounds=L.latLngBounds([[-1.7,-92.55],[1.9,-89]]);function limitar(){var z=map.getBoundsZoom(bounds,false);if(isFinite(z)){map.setMinZoom(z);if(map.getZoom()<z)map.setZoom(z);}}limitar();map.on('resize',limitar);}")
}
