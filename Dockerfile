FROM quay.io/jupyter/minimal-notebook:ubuntu-24.04

USER root
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Mismo instalador de Carl Boettiger usado por el Space anterior.
# R y paquetes binarios de Ubuntu mediante r2u/bspm.
RUN curl -fsSL https://raw.githubusercontent.com/boettiger-lab/repo2docker-r/refs/heads/main/install_r.sh -o /tmp/install_r.sh \
    && bash /tmp/install_r.sh && Rscript -e 'stopifnot(requireNamespace("bspm", quietly=TRUE))' \
    && rm /tmp/install_r.sh

# RStudio no es necesario para servir la aplicación Shiny.
WORKDIR /code
COPY install.r ./
RUN Rscript install.r

ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 TZ=UTC
COPY --chown=1000:100 app.R sources.R comparison.R monitoring.R monitoring-tests.R tests.R ./
RUN Rscript tests.R && Rscript monitoring-tests.R
USER 1000
EXPOSE 7860
CMD ["Rscript", "-e", "options(sass.cache=FALSE); shiny::runApp('.', host='0.0.0.0', port=7860, launch.browser=FALSE)"]
