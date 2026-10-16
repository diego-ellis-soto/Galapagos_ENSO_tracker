source("sources.R")
source("monitoring.R")
d <- data.frame(date=as.Date("2020-01-01")+0:4,delta=c(-1,1,1,1,1))
stopifnot(grepl("^4 días",anomaly_run(d)))
d$delta[2] <- NA
stopifnot(grepl("^Al menos 3 días",anomaly_run(d)))
d$delta[5] <- NA
stopifnot(grepl("No calculable",anomaly_run(d)))
d$delta <- 1
stopifnot(grepl("^Al menos 5",anomaly_run(d)))
d$delta[5] <- 0
stopifnot(grepl("coincide",anomaly_run(d)))
d <- data.frame(date=as.Date(c("2019-12-01","2020-01-01","2020-02-01")),delta=c(1,-1,-2))
stopifnot(grepl("^2 meses",anomaly_run(d,TRUE)))
# A missing calendar date must stop a run even if values have the same sign.
d <- data.frame(date=as.Date(c("2020-01-01","2020-01-03")),delta=c(1,1))
stopifnot(!grepl("2 días",anomaly_run(d)))
cat("Persistencia: cambios de signo, ceros, vacíos, límite temporal y cambio de año correctos.\n")
