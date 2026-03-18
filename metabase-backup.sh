#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAS_DEST="/media/anenome/data/commodoreSQL"

# --- Metabase H2 backup ---
BACKUP_DIR="$SCRIPT_DIR/metabase-backups"
mkdir -p "$BACKUP_DIR"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
DEST="$BACKUP_DIR/metabase.db-${TIMESTAMP}.mv.db"
docker cp metabase:/metabase-data/metabase.db.mv.db "$DEST"
echo "Metabase backup saved: $DEST"

# --- Rsync to NAS ---
if ! mountpoint -q "$(dirname "$NAS_DEST")"; then
    echo "ERROR: NAS not mounted at $(dirname "$NAS_DEST")" >&2
    exit 1
fi

echo "Syncing to NAS: $NAS_DEST"
rsync -avh --delete "$SCRIPT_DIR/" "$NAS_DEST/"
echo "Sync complete"
