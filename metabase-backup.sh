#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$SCRIPT_DIR/metabase-backups"
mkdir -p "$BACKUP_DIR"

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
DEST="$BACKUP_DIR/metabase.db-${TIMESTAMP}.mv.db"

docker cp metabase:/metabase-data/metabase.db.mv.db "$DEST"
echo "Backup saved: $DEST"
