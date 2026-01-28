#!/bin/bash
# Metabase Docker launcher with DuckDB support
# Based on docker-compose.yml volume mounts for Superset

# Stop and remove existing container (use 'docker restart metabase' if just restarting)
docker stop metabase 2>/dev/null
docker rm metabase 2>/dev/null

docker run -d \
  --name metabase \
  -p 3000:3000 \
  -v "$(pwd)/duckdb:/duckdb:rw" \
  -v "$(pwd)/data:/import_data:ro" \
  -v "$(pwd)/plugins:/plugins:rw" \
  -v metabase-data:/metabase-data \
  -e "MUID=1000" \
  -e "MGID=1000" \
  metabase-duckdb:latest
