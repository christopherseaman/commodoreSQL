FROM metabase/metabase:latest AS source

FROM eclipse-temurin:21-jre

USER root

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl \
    fontconfig \
    fonts-dejavu \
    gosu \
    && rm -rf /var/lib/apt/lists/*

COPY --from=source /app/metabase.jar /app/metabase.jar

RUN mkdir -p /plugins /metabase-data /home/metabase && \
    chown -R 1000:1000 /app /plugins /metabase-data /home/metabase

WORKDIR /app

ENV MB_PLUGINS_DIR=/plugins \
    MB_DB_FILE=/metabase-data/metabase.db

EXPOSE 3000

RUN printf '#!/bin/bash\nchown -R 1000:1000 /plugins /metabase-data 2>/dev/null || true\nexec gosu 1000:1000 java -jar /app/metabase.jar\n' > /start.sh && chmod +x /start.sh

CMD ["/start.sh"]
