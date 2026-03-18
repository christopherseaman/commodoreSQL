#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_SCRIPT="$PROJECT_DIR/metabase-backup.sh"
SYSTEMD_DIR="$HOME/.config/systemd/user"
SERVICE="commodore-backup.service"
TIMER="commodore-backup.timer"

uninstall() {
    echo "Disabling and removing commodore-backup timer..."
    systemctl --user disable --now "$TIMER" 2>/dev/null || true
    rm -f "$SYSTEMD_DIR/$SERVICE" "$SYSTEMD_DIR/$TIMER"
    systemctl --user daemon-reload
    echo "Uninstalled."
}

if [[ "${1:-}" == "--uninstall" ]]; then
    uninstall
    exit 0
fi

mkdir -p "$SYSTEMD_DIR"

cat > "$SYSTEMD_DIR/$SERVICE" <<EOF
[Unit]
Description=CommodoreSQL backup (Metabase H2 + rsync to NAS)
After=network.target

[Service]
Type=oneshot
ExecStart=$BACKUP_SCRIPT
StandardOutput=journal
StandardError=journal
EOF

cat > "$SYSTEMD_DIR/$TIMER" <<EOF
[Unit]
Description=Run CommodoreSQL backup daily

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now "$TIMER"

echo "Installed and enabled."
echo ""
systemctl --user status "$TIMER" --no-pager
