#!/bin/bash
set -e

# Setup steps that should always run
mkdir -p /tmp && chmod 1777 /tmp

# DuckDB workaround and Python dependencies
apt-get update && apt-get install -y gettext-base
curl https://install.duckdb.org | sh
export PATH=/root/.duckdb/cli/latest/:$PATH
pip install duckdb duckdb-engine pillow

# Custom script
cd /scripts
./run.sh
cd /app

# One-time Superset initialization
if [ ! -f /app/superset_home/.initialized ]; then
  superset db upgrade
  superset fab create-admin --username christopher --firstname christopher --email chris@badmath.org --password admin || true
  superset init
  superset set_database_uri -d DuckDB-commodore -u duckdb:///data/commodore.duckdb
  touch /app/superset_home/.initialized
fi

# Start Superset
exec gunicorn --bind 0.0.0.0:8088 'superset.app:create_app()' --workers 4 --timeout 120