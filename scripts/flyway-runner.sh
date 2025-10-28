#!/usr/bin/env sh
set -eu

# Ejecuta acciones de Flyway (clean/migrate/info/validate) contra una BD usando CLI local o Docker.
# Configuración vía variables de entorno para simplicidad.
#
# Variables:
#  FW_URL (jdbc:postgresql://host:port/db)
#  FW_USER, FW_PASSWORD
#  FW_SCHEMAS (p.ej. "public,pos")
#  FW_ACTIONS (por defecto "migrate,info")
#  FW_LOCATIONS (por defecto src/main/resources/db/migration,src/main/resources/db/callbacks)
#  FW_USE_DOCKER (1 para usar docker flyway/flyway)
#  FW_VALIDATE (1 por defecto)
#  FW_NAME (nombre para reportes)

REPO_ROOT="$(pwd)"
FW_URL="${FW_URL:-}"
FW_USER="${FW_USER:-}"
FW_PASSWORD="${FW_PASSWORD:-}"
FW_SCHEMAS="${FW_SCHEMAS:-public,pos}"
FW_ACTIONS="${FW_ACTIONS:-migrate,info}"
MIG_DIR_DEFAULT="$REPO_ROOT/src/main/resources/db/migration"
[ "${FW_TEST:-0}" = "1" ] && MIG_DIR_DEFAULT="$REPO_ROOT/src/main/resources/db/migration-test"
FW_LOCATIONS="${FW_LOCATIONS:-$MIG_DIR_DEFAULT,$REPO_ROOT/src/main/resources/db/callbacks}"
FW_USE_DOCKER="${FW_USE_DOCKER:-0}"
FW_VALIDATE="${FW_VALIDATE:-1}"
FW_NAME="${FW_NAME:-default}"

# Directorio de revisión previa (por defecto migration; si FW_TEST=1 usa migration-test)
REVIEW_MIG_DIR="${REVIEW_MIG_DIR:-src/main/resources/db/migration}"
[ "${FW_TEST:-0}" = "1" ] && REVIEW_MIG_DIR="src/main/resources/db/migration-test"
FW_PREVIEW_ONLY="${FW_PREVIEW_ONLY:-0}"

if [ -z "$FW_URL" ] || [ -z "$FW_USER" ] || [ -z "$FW_PASSWORD" ]; then
  echo "ERROR: Define FW_URL, FW_USER y FW_PASSWORD" >&2
  exit 1
fi

# Preflight: revisión de migraciones si existe script
if [ -f "scripts/review-migrations.sh" ]; then
  echo "[Preflight] Revisando migraciones..."
  MIG_DIR="$REVIEW_MIG_DIR" SCHEMA="pos" EXIT_ON_WARN="0" sh scripts/review-migrations.sh || true
fi

# Modo solo revisión: salir tras preflight
if [ "$FW_PREVIEW_ONLY" = "1" ]; then
  echo "[Preflight] Modo solo revisión activo; no se ejecutarán acciones de Flyway."
  exit 0
fi

report_dir="$REPO_ROOT/target/flyway/reports"
mkdir -p "$report_dir"
ts="$(date +%Y%m%d_%H%M%S)"

IFS=','
set -- $FW_ACTIONS
for action in "$@"; do
  if [ "$FW_USE_DOCKER" = "1" ]; then
    locs_docker=$(printf '%s' "$FW_LOCATIONS" | sed "s~$REPO_ROOT~/workspace~g" | tr '\\' '/' )
    cmd_op=(docker run --rm -v "$REPO_ROOT:/workspace" -w /workspace flyway/flyway:10.10 "$action"
      "-url=$FW_URL" "-user=$FW_USER" "-password=$FW_PASSWORD" "-schemas=$FW_SCHEMAS"
      "-locations=$(printf '%s' "$locs_docker")" "-outputType=json")
    if [ "$FW_VALIDATE" = "1" ]; then cmd_op+=("-validateOnMigrate=true"); fi
    out_file="$report_dir/${FW_NAME}-${action}-${ts}.json"
    echo "[RUN] docker ${cmd_op[*]}"
    docker "${cmd_op[@]}" 2>&1 | tee "$out_file"
  else
    out_file="$report_dir/${FW_NAME}-${action}-${ts}.json"
    cmd="flyway $action -url=$FW_URL -user=$FW_USER -password=$FW_PASSWORD -schemas=$FW_SCHEMAS -locations=$(printf '%s' "$FW_LOCATIONS") -outputType=json"
    [ "$FW_VALIDATE" = "1" ] && cmd="$cmd -validateOnMigrate=true"
    echo "[RUN] $cmd"
    sh -c "$cmd" 2>&1 | tee "$out_file"
  fi
  echo "[OK] Reporte: $out_file"
done

echo "Listo. Reportes en $report_dir"