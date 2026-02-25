#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="metabase-local:latest"

# Pull upstream and check if newer
echo "Checking for upstream updates..."
PULL_OUTPUT=$(docker pull metabase/metabase:latest 2>&1)
UPDATED=$(echo "$PULL_OUTPUT" | grep -c "Downloaded newer image" || true)

# Build local image if not present or upstream updated
if [[ "$UPDATED" -gt 0 ]] || ! docker image inspect "$IMAGE" &>/dev/null; then
    echo "Building local image..."
    docker build -t "$IMAGE" "$SCRIPT_DIR"
fi

# Stop and remove existing container
docker stop metabase 2>/dev/null || true
docker rm metabase 2>/dev/null || true

docker run -d \
    --name metabase \
    --restart unless-stopped \
    -p 3000:3000 \
    -v "$SCRIPT_DIR/duckdb:/duckdb:rw" \
    -v "$SCRIPT_DIR/data:/import_data:ro" \
    -v "$SCRIPT_DIR/plugins:/plugins:rw" \
    -v metabase-data:/metabase-data \
    -e "MUID=$(id -u)" \
    -e "MGID=$(id -g)" \
    -e "MB_DB_FILE=/metabase-data/metabase.db" \
    -e "TZ=UTC" \
    "$IMAGE"

echo "Metabase starting at http://localhost:3000"
