# Solo instala programas; no descarga observaciones durante la construcción.
options(repos = c(CRAN = "https://cloud.r-project.org"), timeout = 600)
packages <- c("shiny", "bslib", "leaflet", "ggplot2", "httr2", "jsonlite", "xml2", "rvest", "htmlwidgets", "plotly")
install.packages(packages, Ncpus = 2)
missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("No se instalaron estos paquetes: ", paste(missing, collapse = ", "))
print(vapply(packages, function(x) as.character(packageVersion(x)), character(1)))
