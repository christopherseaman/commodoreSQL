FROM eclipse-temurin:21-jre

ARG METABASE_VERSION=0.58.9
ARG METABASE_DUCKDB_DRIVER_VERSION=1.4.1.0

USER root

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    fontconfig \
    fonts-dejavu \
    gosu \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /app /plugins /metabase-data /home/metabase && \
    chown -R 1000:1000 /app /plugins /metabase-data /home/metabase

ADD --chown=1000:1000 https://downloads.metabase.com/v${METABASE_VERSION}/metabase.jar /app/metabase.jar
ADD --chown=1000:1000 https://github.com/motherduckdb/metabase_duckdb_driver/releases/download/${METABASE_DUCKDB_DRIVER_VERSION}/duckdb.metabase-driver.jar /plugins/duckdb.metabase-driver.jar


WORKDIR /app

ENV MB_PLUGINS_DIR=/plugins \
    MB_DB_FILE=/metabase-data/metabase.db \
    HOME=/home/metabase

EXPOSE 3000

RUN printf '#!/bin/bash\nchown -R 1000:1000 /plugins /metabase-data 2>/dev/null || true\nexec gosu 1000:1000 java -Duser.home=/home/metabase -jar /app/metabase.jar\n' > /start.sh && chmod +x /start.sh

CMD ["/start.sh"]
