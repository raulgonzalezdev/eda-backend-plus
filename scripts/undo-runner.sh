#!/usr/bin/env sh
set -eu

# Ejecuta un script Undo manual para una versión específica (U{version}__*.sql) usando psql vía Docker.
# Útil si no tienes Flyway Teams.

# Variables requeridas:
#  TARGET_VERSION (ej.: 7)
#  FW_URL (jdbc:postgresql://host:port/db)
#  FW_USER, FW_PASSWORD
#  SCHEMA (default pos)

TARGET_VERSION="${TARGET_VERSION:?Define TARGET_VERSION}" # versión a deshacer
FW_URL="${FW_URL:?Define FW_URL}"   # jdbc:postgresql://haproxy:5000/sasdatqbox
FW_USER="${FW_USER:?Define FW_USER}"
FW_PASSWORD="${FW_PASSWORD:?Define FW_PASSWORD}"
SCHEMA="${SCHEMA:-pos}"

REPO_ROOT="$(pwd)"
UNDO_DIR="$REPO_ROOT/src/main/resources/db/undo"
[ -d "$UNDO_DIR" ] || { echo "ERROR: No existe $UNDO_DIR"; exit 1; }

# Parse JDBC
case "$FW_URL" in
  jdbc:postgresql://*/*)
    host_port_db=${FW_URL#jdbc:postgresql://}
    host_port=${host_port_db%%/*}
    db=${host_port_db#*/}
    db=${db%%\?*}
    host=${host_port%%:*}
    port=${host_port#*:}
    ;;
  *) echo "ERROR: URL JDBC no válida: $FW_URL"; exit 1;;
esac

file=$(ls "$UNDO_DIR"/U${TARGET_VERSION}__*.sql 2>/dev/null | head -n1 || true)
[ -n "$file" ] || { echo "ERROR: Falta script $UNDO_DIR/U${TARGET_VERSION}__*.sql"; exit 1; }

echo "[Undo] Ejecutando $file contra $host:$port/$db (schema=$SCHEMA)"

docker run --rm \
  -e PGPASSWORD="$FW_PASSWORD" \
  -v "$REPO_ROOT:/workspace" -w /workspace \
  postgres:16 psql -h "$host" -p "$port" -U "$FW_USER" -d "$db" \
  -v ON_ERROR_STOP=1 -f "$(printf '%s' "$file" | sed "s~$REPO_ROOT~/workspace~")"

echo "Listo: versión $TARGET_VERSION deshecha (manual)."