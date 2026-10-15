# Run from this directory. Synthetic test inputs only; no runtime data fixtures.
source("sources.R")
stopifnot(identical(days_in_month(as.Date(c("2024-02-01", "2025-02-01", "2026-04-01"))), c(29L, 28L, 30L)))
x <- parse_index("2025 1 2 3 4 5 6 7 8 9 10 -99.99 -999\nmetadata")
stopifnot(nrow(x) == 12, all(is.na(tail(x$value, 2))))
s <- parse_sst("time,latitude,longitude,analysed_sst\nUTC,degrees_north,degrees_east,degree_C\n2026-01-01T12:00:00Z,-1,-90,NaN\n2026-01-01T12:00:00Z,-1,-91,27")
stopifnot(nrow(s) == 2, is.na(s$analysed_sst[1]), s$analysed_sst[2] == 27)
r <- parse_rain("{\"features\":[{\"geometry\":{\"coordinates\":[-90,-1]},\"properties\":{\"parameter\":{\"PRECTOTCORR\":{\"202402\":2,\"202403\":-999,\"202413\":8}}}}],\"parameters\":{\"PRECTOTCORR\":{\"units\":\"mm/day\"}},\"header\":{\"fill_value\":-999}}")
stopifnot(nrow(r) == 2, r$rain_mm[1] == 58, is.na(r$rain_mm[2]))
f <- parse_forecast("<html><body>Discusión Diagnóstica 8 de octubre de 2026 Estatus del Sistema de alerta del ENSO: Advertencia de El Niño Sinopsis: Pronóstico de prueba. Texto adicional. La próxima discusión es el 12 de noviembre de 2026.</body></html>")
synthetic_status <- f$status
stopifnot(f$issue == as.Date("2026-10-08"), f$next_issue == as.Date("2026-11-12"), f$synopsis == "Pronóstico de prueba.")
stopifnot(!fetch_result(function() stop("offline"))$ok)
stopifnot(inherits(try(parse_forecast("<html>changed format</html>"), silent = TRUE), "try-error"))
stopifnot(inherits(try(parse_strength("<html>changed format</html>"), silent = TRUE), "try-error"))
cat("Pruebas de lectura y valores faltantes correctas.\n")
if ("--live" %in% commandArgs(TRUE)) {
    meta <- get_sst_meta()
    sst <- get_sst_map(meta$end)
    stopifnot(nrow(sst) > 1000, any(is.finite(sst$analysed_sst)))
    rain <- get_rain(as.integer(format(Sys.Date(), "%Y")), as.integer(format(Sys.Date(), "%Y")))
    stopifnot(any(is.finite(rain$rain_mm)))
    f <- get_forecast()
    pr <- get_strength()
    stopifnot(nrow(pr$table) == 9)
    for (id in names(index_sources)) {
        d <- get_index(id)
        stopifnot(any(is.finite(d$value)))
    }
    cat("Consultas remotas NOAA/NASA correctas.\n")
}
# Same-month baseline and insufficient-coverage safeguards.
b <- data.frame(date = as.Date(sprintf("%d-08-01", 1991:2020)), longitude = -90, latitude = -1, rain_mm = 10,
    source_url = "synthetic")
o <- data.frame(date = as.Date("2026-08-01"), longitude = -90, latitude = -1, rain_mm = 15, source_url = "synthetic")
c <- compare_rain(o, b, "2026-08-01")
stopifnot(c$baseline_n == 30, c$baseline == 10, c$delta == 5, c$percent_delta == 50)
b$rain_mm[1:6] <- NA_real_
stopifnot(is.na(compare_rain(o, b, "2026-08-01")$delta))
b$rain_mm <- 0
stopifnot(is.na(compare_rain(o, b, "2026-08-01")$percent_delta))
stopifnot(index_regions$east[index_regions$index == "Nino12"] == 280, index_regions$west[index_regions$index ==
    "ONI"] == 190)
cat("Pruebas de referencia estacional y regiones correctas.\n")

# Comprobar que la descarga pública conserve nombres españoles.
file <- tempfile(fileext = ".csv")
export_csv(data.frame(date = as.Date("2026-10-08"), value = 1, source_url = CPC), file, row.names = FALSE)
stopifnot(identical(names(read.csv(file)), c("fecha", "valor", "url_fuente")))
unlink(file)
stopifnot(synthetic_status == "Advertencia de El Niño", index_label("Nino12") == "Niño 1+2")
cat("Traducción del boletín y encabezados CSV correcta.\n")
