#!/usr/bin/env bash
# restore.sh
# Restores a backup created by backup.sh into a FRESH database on the same
# Postgres instance, so the original database is never touched and restore
# correctness can be verified independently.
#
# Usage:
#   ./scripts/restore.sh                     # restores the most recent backup
#   ./scripts/restore.sh path/to/file.dump   # restores a specific backup
#
# Environment variables (all optional):
#   DB_CONTAINER    docker compose service/container name (default: hotel_bookings_db)
#   DB_USER         database user (default: app_user)
#   RESTORE_DB_NAME name of the fresh database to restore into
#                   (default: hotel_bookings_restore_test)
#   BACKUP_DIR      where backups live (default: ./backups)

set -euo pipefail

DB_CONTAINER="${DB_CONTAINER:-hotel_bookings_db}"
DB_USER="${DB_USER:-app_user}"
RESTORE_DB_NAME="${RESTORE_DB_NAME:-hotel_bookings_restore_test}"
BACKUP_DIR="${BACKUP_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/backups}"
PGPASSWORD="${PGPASSWORD:-app_password}"

BACKUP_FILE="${1:-}"

if [[ -z "${BACKUP_FILE}" ]]; then
    BACKUP_FILE="$(ls -t "${BACKUP_DIR}"/*.dump 2>/dev/null | head -n1 || true)"
    if [[ -z "${BACKUP_FILE}" ]]; then
        echo "ERROR: no backup file found in ${BACKUP_DIR} and none specified." >&2
        exit 1
    fi
    echo "==> No backup file specified, using most recent: ${BACKUP_FILE}"
fi

if [[ ! -f "${BACKUP_FILE}" ]]; then
    echo "ERROR: backup file not found: ${BACKUP_FILE}" >&2
    exit 1
fi

echo "==> Checking that container '${DB_CONTAINER}' is running..."
if ! docker ps --format '{{.Names}}' | grep -q "^${DB_CONTAINER}$"; then
    echo "ERROR: container '${DB_CONTAINER}' is not running. Start it with: docker compose up -d" >&2
    exit 1
fi

CONTAINER_TMP_FILE="/tmp/$(basename "${BACKUP_FILE}")"
echo "==> Copying backup into container..."
docker cp "${BACKUP_FILE}" "${DB_CONTAINER}:${CONTAINER_TMP_FILE}"

echo "==> Dropping and recreating fresh database '${RESTORE_DB_NAME}'..."
docker exec -e PGPASSWORD="${PGPASSWORD}" "${DB_CONTAINER}" \
    psql -U "${DB_USER}" -d postgres -v ON_ERROR_STOP=1 \
    -c "DROP DATABASE IF EXISTS ${RESTORE_DB_NAME};" \
    -c "CREATE DATABASE ${RESTORE_DB_NAME};"

echo "==> Restoring dump into '${RESTORE_DB_NAME}'..."
docker exec -e PGPASSWORD="${PGPASSWORD}" "${DB_CONTAINER}" \
    pg_restore -U "${DB_USER}" -d "${RESTORE_DB_NAME}" --no-owner --no-privileges "${CONTAINER_TMP_FILE}"

echo "==> Cleaning up temp file inside container..."
docker exec "${DB_CONTAINER}" rm -f "${CONTAINER_TMP_FILE}"

echo "==> Verifying restore..."
BOOKING_COUNT=$(docker exec -e PGPASSWORD="${PGPASSWORD}" "${DB_CONTAINER}" \
    psql -U "${DB_USER}" -d "${RESTORE_DB_NAME}" -t -A -c "SELECT count(*) FROM hotel_bookings;")
EVENT_COUNT=$(docker exec -e PGPASSWORD="${PGPASSWORD}" "${DB_CONTAINER}" \
    psql -U "${DB_USER}" -d "${RESTORE_DB_NAME}" -t -A -c "SELECT count(*) FROM booking_events;")

echo "==> Restore complete into database '${RESTORE_DB_NAME}'."
echo "    hotel_bookings rows: ${BOOKING_COUNT}"
echo "    booking_events rows: ${EVENT_COUNT}"
echo ""
echo "Compare these counts against the source database to confirm the restore matches:"
echo "  docker exec -e PGPASSWORD=${PGPASSWORD} ${DB_CONTAINER} psql -U ${DB_USER} -d hotel_bookings -t -A -c \"SELECT count(*) FROM hotel_bookings;\""
