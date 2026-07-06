#!/usr/bin/env bash
# backup.sh
# Creates a timestamped custom-format pg_dump of the local hotel_bookings database.
#
# Usage:
#   ./scripts/backup.sh
#
# Environment variables (all optional, defaults match docker-compose.yml):
#   DB_CONTAINER   docker compose service/container name (default: hotel_bookings_db)
#   DB_NAME        database name (default: hotel_bookings)
#   DB_USER        database user (default: app_user)
#   BACKUP_DIR     where to write the dump file (default: ./backups)

set -euo pipefail

DB_CONTAINER="${DB_CONTAINER:-hotel_bookings_db}"
DB_NAME="${DB_NAME:-hotel_bookings}"
DB_USER="${DB_USER:-app_user}"
BACKUP_DIR="${BACKUP_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/backups}"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.dump"

mkdir -p "${BACKUP_DIR}"

echo "==> Checking that container '${DB_CONTAINER}' is running..."
if ! docker ps --format '{{.Names}}' | grep -q "^${DB_CONTAINER}$"; then
    echo "ERROR: container '${DB_CONTAINER}' is not running. Start it with: docker compose up -d" >&2
    exit 1
fi

echo "==> Dumping database '${DB_NAME}' from container '${DB_CONTAINER}'..."
# Custom format (-Fc): compressed, and restorable with pg_restore in parallel
# or piece-by-piece, which is more flexible than a plain SQL dump.
docker exec -e PGPASSWORD="${PGPASSWORD:-app_password}" "${DB_CONTAINER}" \
    pg_dump -U "${DB_USER}" -d "${DB_NAME}" -Fc > "${BACKUP_FILE}"

if [[ -s "${BACKUP_FILE}" ]]; then
    echo "==> Backup complete: ${BACKUP_FILE}"
    echo "    Size: $(du -h "${BACKUP_FILE}" | cut -f1)"
else
    echo "ERROR: backup file is empty, something went wrong." >&2
    rm -f "${BACKUP_FILE}"
    exit 1
fi
