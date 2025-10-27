#!/usr/bin/env sh
set -eu

# Orquesta en un solo paso:
# 1) Exportar DDL del esquema desde el contenedor Postgres usando psql
# 2) Copiar artefactos al host en db/pos
# 3) Convertir DDL a migraciones Flyway en src/main/resources/db/migration

# Carga de variables desde .env.local si existe
if [ -f .env.local ]; then
  # Desactivar expansión de historial para valores con '!'
  set +H
  # Normalizar CRLF -> LF para evitar errores al source en bash
  ENV_TMP="$(mktemp)"
  sed -e 's/\r$//' .env.local > "$ENV_TMP"
  # exportar automáticamente todas las variables del archivo
  set -a
  . "$ENV_TMP"
  set +a
  rm -f "$ENV_TMP"
fi

# Parámetros con valores por defecto (puedes sobreescribir via entorno)
DB_CONTAINER_NAME="${DB_CONTAINER_NAME:-sasdatqbox-db-1}"
DB_NAME="${DB_NAME:-sasdatqbox}"
DB_USER="${DB_USER:-sas_user}"
DB_PASSWORD="${DB_PASSWORD:-}"
SCHEMA="${SCHEMA:-pos}"

# Variables producción (opcionales)
PROD_DB_CONTAINER_NAME="${PROD_DB_CONTAINER_NAME:-}"
PROD_DB_NAME="${PROD_DB_NAME:-$DB_NAME}"
PROD_DB_USER="${PROD_DB_USER:-$DB_USER}"
PROD_DB_PASSWORD="${PROD_DB_PASSWORD:-$DB_PASSWORD}"

OUT_DIR_IN_CONTAINER="${OUT_DIR_IN_CONTAINER:-/tmp/pg_ddl_export}"
SRC_DIR_HOST="${SRC_DIR_HOST:-db/pos}"
MIG_DIR_HOST="${MIG_DIR_HOST:-src/main/resources/db/migration}"
MIG_DEDUP_POLICY="${MIG_DEDUP_POLICY:-update_existing}"

# Producción
PROD_OUT_DIR_IN_CONTAINER="${PROD_OUT_DIR_IN_CONTAINER:-/tmp/pg_ddl_export}"
PRO_SRC_DIR_HOST="${PRO_SRC_DIR_HOST:-db-pro/pos}"

if [ -z "$DB_PASSWORD" ]; then
  echo "ERROR: Debe definir DB_PASSWORD (en entorno o .env.local)." >&2
  exit 1
fi

echo "[1/4] Copiando export-pos-schema.sh al contenedor $DB_CONTAINER_NAME"
docker cp scripts/export-pos-schema.sh "$DB_CONTAINER_NAME:/tmp/export-pos-schema.sh"

echo "[2/4] Ejecutando exportación en contenedor via psql (schema=$SCHEMA, db=$DB_NAME)"
docker exec \
  -e DB_NAME="$DB_NAME" \
  -e DB_USER="$DB_USER" \
  -e DB_PASSWORD="$DB_PASSWORD" \
  -e SCHEMA="$SCHEMA" \
  -e OUT_DIR="$OUT_DIR_IN_CONTAINER" \
  -e CONTAINER_NAME="$DB_CONTAINER_NAME" \
  "$DB_CONTAINER_NAME" sh /tmp/export-pos-schema.sh

echo "[3/4] Copiando artefactos del contenedor a $SRC_DIR_HOST"
mkdir -p "$SRC_DIR_HOST"
docker cp "$DB_CONTAINER_NAME:$OUT_DIR_IN_CONTAINER/$SCHEMA/." "$SRC_DIR_HOST/"

echo "[3.1] (Opcional) Exportando DDL de producción si credenciales están definidas"
if [ -n "$PROD_DB_PASSWORD" ] && [ -n "$PROD_DB_CONTAINER_NAME" ] && [ -n "$PROD_DB_NAME" ] && [ -n "$PROD_DB_USER" ]; then
  echo "Copiando export-pos-schema.sh al contenedor PROD $PROD_DB_CONTAINER_NAME"
  docker cp scripts/export-pos-schema.sh "$PROD_DB_CONTAINER_NAME:/tmp/export-pos-schema.sh"
  echo "Ejecutando exportación en PROD (schema=$SCHEMA, db=$PROD_DB_NAME)"
  docker exec \
    -e DB_NAME="$PROD_DB_NAME" \
    -e DB_USER="$PROD_DB_USER" \
    -e DB_PASSWORD="$PROD_DB_PASSWORD" \
    -e SCHEMA="$SCHEMA" \
    -e OUT_DIR="$PROD_OUT_DIR_IN_CONTAINER" \
    -e CONTAINER_NAME="$PROD_DB_CONTAINER_NAME" \
    "$PROD_DB_CONTAINER_NAME" sh /tmp/export-pos-schema.sh
  echo "Copiando artefactos PROD del contenedor a $PRO_SRC_DIR_HOST"
  mkdir -p "$PRO_SRC_DIR_HOST"
  docker cp "$PROD_DB_CONTAINER_NAME:$PROD_OUT_DIR_IN_CONTAINER/$SCHEMA/." "$PRO_SRC_DIR_HOST/"
else
  echo "Saltando exportación de producción: definir PROD_DB_CONTAINER_NAME, PROD_DB_NAME, PROD_DB_USER, PROD_DB_PASSWORD"
fi

echo "[4/4] Convirtiendo DDL a migraciones Flyway en $MIG_DIR_HOST (política=$MIG_DEDUP_POLICY)"
DRY_RUN="${DRY_RUN:-0}" MIG_DEDUP_POLICY="$MIG_DEDUP_POLICY" SCHEMA="$SCHEMA" SRC_DIR="$SRC_DIR_HOST" MIG_DIR="$MIG_DIR_HOST" bash scripts/convert-pos-ddl-to-flyway.sh

if [ -d "$PRO_SRC_DIR_HOST" ]; then
  echo "[4.1] Generando migraciones por diferencia dev vs prod en $MIG_DIR_HOST (categorías *_diff)"
  DRY_RUN="${DRY_RUN:-0}" MIG_DEDUP_POLICY="$MIG_DEDUP_POLICY" SCHEMA="$SCHEMA" SRC_DEV="$SRC_DIR_HOST" SRC_PRO="$PRO_SRC_DIR_HOST" MIG_DIR="$MIG_DIR_HOST" bash scripts/convert-pos-diff-to-flyway.sh
else
  echo "Saltando diffs dev vs prod: no existe $PRO_SRC_DIR_HOST"
fi

echo "Listando migraciones generadas:"
ls -1 "$MIG_DIR_HOST"/V*__*.sql | sed 's#^.*/##'

if [ "${DRY_RUN:-0}" = "1" ]; then
  echo "[Dry-run] No se eliminarán migraciones vacías ni se escribirán nuevas; se muestran solo acciones previstas."
else
  # Limpieza: eliminar migraciones vacías (archivos 0 bytes o solo espacios)
  echo "Limpieza de migraciones vacías (si hubiera):"
  removed=0
  for f in "$MIG_DIR_HOST"/V*__*.sql; do
    [ -f "$f" ] || continue
    if [ ! -s "$f" ] || ! grep -qE '[^[:space:]]' "$f"; then
      rm -f "$f"
      removed=$((removed+1))
    fi
  done
  if [ "$removed" -gt 0 ]; then
    echo "Eliminadas $removed migraciones vacías."
  else
    echo "No se encontraron migraciones vacías."
  fi
fi

echo "Hecho."