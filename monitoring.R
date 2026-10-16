# Resumen físico: consultas remotas y una instantánea coherente para pantalla/informe.
monitoring_ui <- function() nav_panel("Estado de Galápagos",
    h3("Estado de Galápagos"),
    selectInput("summary_island", "Isla del resumen", islands$island, selected = "Santa Cruz"),
    p("Resumen de celdas cercanas a la isla seleccionada; no es un promedio del archipiélago."),
    actionButton("summary_fetch", "Actualizar resumen de la isla", class = "btn-primary"),
    uiOutput("summary_status"), uiOutput("summary_values"),
    plotOutput("summary_history", height = 240),
    downloadButton("summary_report", "Informe de una página (HTML / imprimir PDF)"),
    p(class = "small-note", "El informe incluye la última consulta del resumen, aunque cambie después la isla seleccionada."))

# Un vacío interrumpe la secuencia; nunca se cuenta como cero ni se salta.
anomaly_run <- function(d, monthly = FALSE) {
    d <- d[order(d$date), ]
    if (!nrow(d) || !is.finite(tail(d$delta, 1))) return("No calculable: falta el último período.")
    v <- tail(d$delta, 1)
    if (v == 0) return("El último período coincide con el promedio.")
    n <- 1L
    while (n < nrow(d)) {
        i <- nrow(d) - n
        expected <- if (monthly) seq(d$date[i], by = "month", length.out = 2)[2] else d$date[i] + 1
        if (!is.finite(d$delta[i]) || sign(d$delta[i]) != sign(v) || expected != d$date[i+1]) break
        n <- n + 1L
    }
    limited <- n == nrow(d) || !is.finite(d$delta[nrow(d)-n])
    if (!limited && n < nrow(d)) {
        i <- nrow(d)-n
        next_date <- if (monthly) seq(d$date[i], by="month", length.out=2)[2] else d$date[i]+1
        limited <- next_date != d$date[i+1]
    }
    paste0(if (limited) "Al menos " else "", n, if (monthly) " meses" else " días",
        " consecutivos ", if (v > 0) "por encima" else "por debajo", " del promedio",
        if (limited) " (inicio no determinado)." else ".")
}
get_anomaly_history <- function(lon, lat, start, end) {
    days <- seq(start, end, by = "day")
    pieces <- split(days, ceiling(seq_along(days)/15))
    do.call(rbind, lapply(pieces, function(ds) {
        q <- sprintf("sea_surface_temperature_anomaly[(%sT12:00:00Z):1:(%sT12:00:00Z)][(%s)][(%s)]", min(ds), max(ds), lat, lon)
        url <- paste0("https://coastwatch.noaa.gov/erddap/griddap/", DELTA_DATASET, ".csv?", URLencode(q, reserved=TRUE))
        z <- fetch_result(function() {
            x <- read_csv_text(fetch_text(url)$text)
            stopifnot(all(c("time", "sea_surface_temperature_anomaly") %in% names(x)))
            if (!x$sea_surface_temperature_anomaly[1] %in% c("degree_C", "degree_Celsius")) stop("Unidades de anomalía no reconocidas.")
            x <- x[-1, ]
            data.frame(date=as.Date(substr(x$time,1,10)), delta=as.numeric(x$sea_surface_temperature_anomaly))
        })
        d <- data.frame(date=ds, delta=NA_real_)
        if (z$ok) d$delta <- z$data$delta[match(d$date,z$data$date)]
        d$delta[abs(d$delta)>90] <- NA_real_
        d$source_url <- url
        d
    }))
}
summary_snapshot <- function(island) {
    s <- islands[islands$island == island, ]
    stopifnot(nrow(s) == 1)
    sea <- fetch_result(function() {
        meta <- compare_sst_meta()
        grid <- get_sst_comparison(meta$end)
        valid <- grid[is.finite(grid$observed) & is.finite(grid$delta), ]
        distance <- (valid$longitude-s$lon)^2+(valid$latitude-s$lat)^2
        if (!length(distance) || min(distance)>0.25) stop("No hay celda marina válida a menos de 0,5° del marcador.")
        cell <- valid[which.min(distance), ]
        h <- get_anomaly_history(cell$longitude,cell$latitude,max(meta$start,meta$end-89),meta$end)
        list(cell=cell, grid=grid, history=h)
    })
    rain <- fetch_result(function() {
        end <- as.Date(format(Sys.Date(),"%Y-%m-01"))
        end <- seq(end, by="-1 month",length.out=2)[2]
        start <- seq(end, by="-1 month",length.out=12)[12]
        raw <- get_rain(as.integer(format(start,"%Y")),as.integer(format(end,"%Y")))
        base <- get_rain(1991,2020)
        dates <- seq(start,end,by="month")
        raw <- merge(expand.grid(date=dates, longitude=unique(raw$longitude), latitude=unique(raw$latitude)),raw,
            by=c("date","longitude","latitude"),all.x=TRUE)
        grid <- compare_rain(raw,base,end)
        h <- do.call(rbind,lapply(dates,function(dt) nearest_cell(compare_rain(raw,base,as.Date(dt,origin="1970-01-01")),s$lon,s$lat)))
        list(cell=tail(h,1),grid=grid,history=h)
    })
    list(island=island, sea=sea,rain=rain,fetched=utc_now())
}
summary_lines <- function(z) {
    out <- c(paste("Isla:", z$island, "| Consulta:", z$fetched))
    for (key in c("sea","rain")) {
        x <- z[[key]]; sea <- key == "sea"
        label <- if (sea) "Temperatura marina" else "Lluvia estimada"
        if (!x$ok) { out <- c(out,paste(label,": no disponible.",x$error)); next }
        d <- x$data; c <- d$cell
        number <- function(v) if (is.finite(v)) formatC(v,format="f",digits=2,decimal.mark=",") else "sin datos"
        if (!sea && !is.finite(c$observed)) {
            available <- d$history[is.finite(d$history$observed), ]
            if (nrow(available)) {
                last <- tail(available,1)
                out <- c(out, sprintf("Última lluvia disponible · %s: %s mm/mes | promedio: %s | diferencia: %s",last$date,number(last$observed),number(last$baseline),number(last$delta)))
            }
        }
        out <- c(out, sprintf("%s · %s: %s %s | promedio: %s | diferencia: %s",label,c$date,number(c$observed),c$unit,number(c$baseline),number(c$delta)),
            sprintf("Celda %.3f°, %.3f° | cobertura del mapa: %s/%s celdas con diferencia válida.",c$latitude,c$longitude,sum(is.finite(d$grid$delta)),nrow(d$grid)),
            paste(anomaly_run(d$history,!sea),sprintf("Cobertura temporal: %s/%s períodos.",sum(is.finite(d$history$delta)),nrow(d$history))))
    }
    out
}
summary_history_plot <- function(z) {
    frames <- lapply(c("sea","rain"),function(k) {
        x <- z[[k]]
        if (!x$ok) return(NULL)
        h <- x$data$history
        # Preserve missing periods; line groups cannot bridge gaps.
        data.frame(date=h$date,delta=h$delta,group=cumsum(!is.finite(h$delta)),
            variable=if(k=="sea") "Temperatura: diferencia (°C), hasta 90 días" else "Lluvia: diferencia (mm/mes), 12 meses")
    })
    d <- do.call(rbind,frames)
    if (is.null(d)) return(ggplot()+annotate("text",x=0,y=0,label="Sin series disponibles")+theme_void())
    ggplot(d,aes(date,delta))+geom_hline(yintercept=0,color="gray50")+
        geom_line(aes(group=group),color="#126f74",na.rm=TRUE)+geom_point(color="#126f74",size=1,na.rm=TRUE)+
        facet_wrap(~variable,scales="free",ncol=2)+theme_minimal(base_size=10)+labs(x=NULL,y=NULL)+scale_x_date(date_labels="%Y-%m")
}
summary_map_plot <- function(z) {
    x <- if (z$sea$ok) z$sea else z$rain
    if (!x$ok) return(ggplot()+annotate("text",x=0,y=0,label="Mapa sin datos disponibles")+theme_void())
    d <- x$data$grid
    m <- max(abs(d$delta),0.5,na.rm=TRUE)
    ggplot(d,aes(longitude,latitude,fill=delta))+geom_tile(width=if(z$sea$ok) .05 else .625,height=if(z$sea$ok) .05 else .5)+
        geom_point(data=islands,aes(lon,lat),inherit.aes=FALSE,size=1)+
        geom_text(data=islands,aes(lon,lat,label=island),inherit.aes=FALSE,size=2,hjust=0,nudge_x=.03)+
        scale_fill_gradient2(low="#2166ac",mid="white",high="#b2182b",limits=c(-m,m),na.value="gray70")+
        coord_fixed(xlim=c(-92.55,-89),ylim=c(-1.7,1.9))+theme_minimal(base_size=9)+
        labs(title=paste("Diferencia",d$unit[1],"·",d$date[1]),fill=d$unit[1],x=NULL,y=NULL)
}
summary_report_html <- function(z) {
    picture <- function(p,w,h) {
        f <- tempfile(fileext=".png"); on.exit(unlink(f))
        ggsave(f,p,width=w,height=h,dpi=130,device=grDevices::png)
        tags$img(src=paste0("data:image/png;base64,",jsonlite::base64_enc(readBin(f,"raw",n=file.info(f)$size))),style="width:100%;display:block")
    }
    doc <- tags$html(lang="es",tags$head(tags$meta(charset="utf-8"),tags$title("Estado de Galápagos"),
        tags$style(HTML("@page{size:A4;margin:12mm}body{font:11px Arial,sans-serif;color:#173f43;max-width:185mm;margin:auto}h1{font-size:22px;margin:8px 0}p{margin:5px 0;line-height:1.3}a{color:#126f74}.map{width:85mm;margin:auto}img{break-inside:avoid}@media print{button{display:none}}"))),
        tags$body(tags$button(onclick="window.print()","Imprimir / guardar como PDF"),tags$h1("Estado de Galápagos"),
            tags$p(tags$strong("Aplicación creada por Diego Ellis Soto · UC Berkeley y UC Santa Cruz")),
            lapply(summary_lines(z),tags$p),tags$div(class="map",picture(summary_map_plot(z),5,3.1)),
            picture(summary_history_plot(z),7,1.8),
            tags$p("Referencia: 1991–2020. Temperatura: NOAA CoralTemp y anomalía oficial del mismo producto. Lluvia: NASA POWER/MERRA-2, mismo mes calendario; mínimo 25 años válidos."),
            tags$p("Las celdas no representan promedios de las islas. Gris: datos o referencia faltantes. Las fechas de lluvia y temperatura difieren. Un vacío interrumpe la persistencia; una secuencia que llega al inicio de la ventana es una duración mínima. El signo respecto al promedio no define una ola de calor ni demuestra causalidad del ENOS. No es un pronóstico ni una alerta local."),
            tags$p("Fuentes: ",tags$a(href=paste0("https://coastwatch.noaa.gov/erddap/info/",DELTA_DATASET,"/index.html"),"NOAA: anomalías")," · ",
                tags$a(href=paste0("https://coastwatch.noaa.gov/erddap/info/",COMPARE_SST_DATASET,"/index.html"),"NOAA: temperatura")," · ",tags$a(href="https://power.larc.nasa.gov/docs/services/api/temporal/monthly/","NASA POWER"))))
    rendered <- htmltools::renderTags(doc)
    htmltools::HTML(paste0("<!DOCTYPE html>\n", sub('<html lang="es">',
        paste0('<html lang="es"><head>', rendered$head, '</head>'), rendered$html, fixed=TRUE)))
}
monitoring_server <- function(input,output,session) {
    snapshot <- reactiveVal(NULL)
    observeEvent(input$summary_fetch, {
        req(input$summary_island)
        withProgress(message="Consultando el resumen y la referencia climática",value=.1, {
            snapshot(summary_snapshot(input$summary_island)); incProgress(.9)
        })
    })
    output$summary_status <- renderUI({
        z <- snapshot()
        if(is.null(z)) return(p("Pulse Actualizar resumen para consultar los datos remotos. La primera consulta puede tardar."))
        tagList(if(z$island!=input$summary_island) strong(paste("Resumen de",z$island,". Cambió de isla: actualice el resumen.")),
            p("Temperatura: última fecha común de NOAA. Lluvia: último mes calendario completo; puede no estar publicado todavía. Referencia: 1991–2020."))
    })
    output$summary_values <- renderUI({req(snapshot()); tagList(lapply(summary_lines(snapshot()),p),
        p(class="small-note","Persistencia del signo de la anomalía, sin saltar vacíos; no define una ola de calor, significación estadística ni atribución al ENOS."))})
    output$summary_history <- renderPlot({req(snapshot());summary_history_plot(snapshot())},alt="Persistencia de anomalías de temperatura y lluvia")
    output$summary_report <- downloadHandler(filename=function() paste0("galapagos-resumen-",Sys.Date(),".html"),contentType="text/html",content=function(file) {
        req(snapshot());writeLines(as.character(summary_report_html(snapshot())),file,useBytes=TRUE)
    })
}
