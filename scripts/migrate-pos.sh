#!/usr/bin/env sh
set -eu

# Uso: sh scripts/migrate-pos.sh [--test]
# Genera migraciones por diferencia (DEV vs PRO) y ejecuta pre-revisión.

REPO_ROOT="$(pwd)"
SCHEMA="pos"

TEST_MODE="0"
if [ "${1:-}" = "--test" ]; then TEST_MODE="1"; fi

MIG_DIR="$REPO_ROOT/src/main/resources/db/migration"
[ "$TEST_MODE" = "1" ] && MIG_DIR="$REPO_ROOT/src/main/resources/db/migration-test"
mkdir -p "$MIG_DIR"

echo "[POS] Generando diffs en: $MIG_DIR"
SRC_DEV="db/pos" SRC_PRO="db-pro/pos" MIG_DIR="$MIG_DIR" SCHEMA="$SCHEMA" MIG_DEDUP_POLICY="update_existing" sh "$REPO_ROOT/scripts/convert-pos-diff-to-flyway.sh"

echo "[Preflight] Revisando migraciones en: $MIG_DIR"
MIG_DIR="$MIG_DIR" SCHEMA="$SCHEMA" EXIT_ON_WARN="0" sh "$REPO_ROOT/scripts/review-migrations.sh" || true

echo "[List] Archivos generados:"
ls -1 "$MIG_DIR"/V*__*.sql 2>/dev/null | sed 's#^.*/##' | sort || true

echo "Hecho. Para aplicar, usa scripts/flyway-runner.sh con FW_TEST=$TEST_MODE y FW_* parámetros de conexión."