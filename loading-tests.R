options(sass.cache=FALSE)
source('app.R')
calls <- new.env(); calls$map <- calls$rain <- calls$forecast <- calls$history <- 0L
get_sst_meta <- function() list(start=as.Date('2026-01-01'),end=as.Date('2026-10-13'))
get_sst_map <- function(date) {calls$map<-calls$map+1L;data.frame(date=as.Date(date),longitude=-90.375,latitude=-.525,analysed_sst=25,retrieved_utc='prueba')}
get_rain <- function(...) {calls$rain<-calls$rain+1L;data.frame(date=as.Date('2026-08-01'),longitude=-90.625,latitude=-.5,rain_mm=5,retrieved_utc='prueba')}
get_sst_series <- function(lon,lat,start,end) {calls$history<-calls$history+1L;calls$history_end<-end;get_sst_map(end)}
get_forecast <- function() {calls$forecast<-calls$forecast+1L;stop('Servicio simulado')}
get_strength <- function() stop('Servicio simulado')
assign('cache-preservada',list(text='prueba',time=Sys.time()),remote_cache)
shiny::testServer(server, {
 session$setInputs(page='Monitoreo',layer='sst',island='Santa Cruz',refresh=0,load_history=FALSE,rain_start=2024)
 stopifnot(calls$map==1L,calls$rain==0L,calls$forecast==0L,calls$history==0L,exists('cache-preservada',remote_cache))
 session$setInputs(load_history=TRUE)
 stopifnot(calls$history==1L)
 session$setInputs(sst_date=as.Date('2026-10-12'))
 stopifnot(calls$history_end==as.Date('2026-10-12'))
 # A second date at the same grid cell must still reload its history.
 session$setInputs(sst_date=as.Date('2026-10-11'))
 stopifnot(calls$history_end==as.Date('2026-10-11'))
 session$setInputs(layer='rain')
 stopifnot(calls$rain==1L)
 session$setInputs(page='Pronóstico oficial del ENOS')
 stopifnot(calls$forecast==1L)
 session$setInputs(page='Monitoreo');session$setInputs(page='Pronóstico oficial del ENOS')
 stopifnot(calls$forecast==1L)
})
cat('Carga diferida y conservación de caché verificadas.\n')

shiny::testServer(server, {
 session$setInputs(page='Monitoreo',layer='sst',island='Santa Cruz',load_history=TRUE,rain_start=2024)
 stopifnot(state$sst$ok, state$history$ok, max(state$sst$data$date)==as.Date('2026-10-13'))
 stopifnot(!grepl('no disponible',output$series_note$html))
})
cat('Inicio sin pulsar actualizar e historial activado al inicio: correctos.\n')
