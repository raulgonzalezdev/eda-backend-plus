#!/usr/bin/env sh
set -eu

# Orquesta en un solo paso:
# 1) Exportar DDL del esquema desde el contenedor Postgres usando psql
# 2) Copiar artefactos al host en db/pos
# 3) Convertir DDL a migraciones Flyway en src/main/resources/db/migration

# Carga de variables desde .env.local si existe
if [ -f .env.local ]; then
  # Desactivar expansión de historial para valores con '!'
  # Solo en bash: en /bin/sh (dash/posix) no existe la opción -H
  if [ -n "${BASH_VERSION:-}" ]; then
    set +H
  fi
  # Normalizar CRLF -> LF para evitar errores al source en shells
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

# Variables producción (siempre se usan para comparar)
PROD_DB_CONTAINER_NAME="${PROD_DB_CONTAINER_NAME:-patroni-master}"
PROD_DB_NAME="${PROD_DB_NAME:-sasdatqbox}"
PROD_DB_USER="${PROD_DB_USER:-sas_user}"
PROD_DB_PASSWORD="${PROD_DB_PASSWORD:-ML!gsx90l02}"

OUT_DIR_IN_CONTAINER="${OUT_DIR_IN_CONTAINER:-/tmp/pg_ddl_export}"
SRC_DIR_HOST="${SRC_DIR_HOST:-db/pos}"
MIG_DIR_HOST="${MIG_DIR_HOST:-src/main/resources/db/migration}"
MIG_DEDUP_POLICY="${MIG_DEDUP_POLICY:-create_new_version}"
MIG_FORCE_BASE="${MIG_FORCE_BASE:-0}"

# Perfil opcional: si es 'test' redirige salida a migration-test (solo visualización)
PROFILE="${1:-${MIG_PROFILE:-}}"
if [ "${PROFILE:-}" = "test" ] || [ "${TEST:-0}" = "1" ]; then
  MIG_DIR_HOST="src/main/resources/db/migration-test"
  echo "[Modo] Visualización activa: las migraciones se escribirán en $MIG_DIR_HOST"
fi

# Chequeo de integridad (por defecto activo)
INTEGRITY_CHECK="${INTEGRITY_CHECK:-1}"
# Tablas a verificar rápidamente (PK presente y FKs existentes)
CHECK_TABLES_DEFAULT="appointments appointment_documents conversations"
CHECK_TABLES="${CHECK_TABLES:-$CHECK_TABLES_DEFAULT}"

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
MSYS_NO_PATHCONV=1 docker exec \
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

echo "[3.1] Exportando DDL de producción (si el contenedor existe)"
if docker inspect "$PROD_DB_CONTAINER_NAME" >/dev/null 2>&1; then
  echo "Copiando export-pos-schema.sh al contenedor PROD $PROD_DB_CONTAINER_NAME"
  docker cp scripts/export-pos-schema.sh "$PROD_DB_CONTAINER_NAME:/tmp/export-pos-schema.sh"
  echo "Ejecutando exportación en PROD (schema=$SCHEMA, db=$PROD_DB_NAME)"
  MSYS_NO_PATHCONV=1 docker exec \
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
  echo "[Aviso] Contenedor PROD '$PROD_DB_CONTAINER_NAME' no encontrado. Se omite exportación y se usará '$PRO_SRC_DIR_HOST' si ya existe en el host."
fi

pro_ddl_count=0
if [ -d "$PRO_SRC_DIR_HOST" ]; then
  # Contar archivos .sql exportados de PRO para detectar esquema vacío
  pro_ddl_count=$(find "$PRO_SRC_DIR_HOST" -type f -name '*.sql' 2>/dev/null | wc -l | tr -d ' ')
fi

# Convertir DDL a migraciones Flyway (diff)
DRY_RUN="${DRY_RUN:-0}"  # 0 para escribir, 1 para simular

# Exportar variables de entorno para el script de conversión
export SRC_DEV="db/pos"
export SRC_PRO="db-pro/pos"
export MIG_DIR="$MIG_DIR_HOST"
export SCHEMA="pos"
export MIG_DEDUP_POLICY="create_new_version"
export PROD_DB_HOST="${PROD_DB_HOST:-localhost}"
export PROD_DB_PORT="${PROD_DB_PORT:-5432}"
export PROD_DB_NAME="${PROD_DB_NAME:-sasdatqbox}"
export PROD_DB_USER="${PROD_DB_USER:-sas_user}"
export PROD_DB_PASSWORD="${PROD_DB_PASSWORD:-}"
export PROD_CONTAINER_NAME="${PROD_CONTAINER_NAME:-patroni-master}"

# Contenedor de desarrollo (local)
DEV_CONTAINER_NAME="${DEV_CONTAINER_NAME:-eda-backend-plus-db-1}"

echo "Convirtiendo DDL (dev vs. pro) a migraciones Flyway (en $MIG_DIR)..."
DRY_RUN="${DRY_RUN:-0}" bash scripts/convert-pos-diff-to-flyway.sh

# Validar migraciones generadas (si no es dry-run)
if [ "$DRY_RUN" = "0" ]; then
  echo "Validando migraciones generadas..."
fi

echo "Hecho."

# Chequeo rápido de integridad (PKs presentes y FKs existentes)
if [ "$INTEGRITY_CHECK" = "1" ]; then
  echo "[Post] Chequeo rápido de integridad en BD actual ($DB_CONTAINER_NAME, schema=$SCHEMA)"
  for t in $CHECK_TABLES; do
    sql="WITH pk AS (
      SELECT 1 FROM pg_constraint ct
      JOIN pg_class c ON c.oid=ct.conrelid
      JOIN pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname='${SCHEMA}' AND c.relname='${t}' AND ct.contype='p'
    ), fks AS (
      SELECT count(*) AS cnt FROM pg_constraint ct
      JOIN pg_class c ON c.oid=ct.conrelid
      JOIN pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname='${SCHEMA}' AND c.relname='${t}' AND ct.contype='f'
    )
    SELECT '${SCHEMA}.${t}' AS table,
           CASE WHEN EXISTS(SELECT 1 FROM pk) THEN 'OK' ELSE 'MISSING' END AS pk,
           (SELECT cnt FROM fks) AS fk_count;"
    docker exec "$DB_CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -c "$sql" || true
  done
  echo "[Post] Chequeo de integridad completado (PK/FK)."
fi

# Revisión opcional de migraciones generadas (patrones peligrosos y cabeceras)
if [ "${REVIEW_MIGRATIONS:-1}" = "1" ]; then
  echo "[Post] Revisando migraciones generadas en $MIG_DIR_HOST (schema=$SCHEMA)"
  MIG_DIR="$MIG_DIR_HOST" SCHEMA="$SCHEMA" bash scripts/review-migrations.sh || true
  echo "[Post] Revisión de migraciones completada."
fi