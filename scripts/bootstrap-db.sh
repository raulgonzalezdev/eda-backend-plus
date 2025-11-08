#!/usr/bin/env bash
set -euo pipefail

PGHOST="${PGHOST:-haproxy}"
PGPORT="${PGPORT:-5000}"
PGUSER="${PGUSER:-postgres}"
PG_SUPER_PASS="${PG_SUPER_PASS:-postgres_super_pass}"
APP_DB_NAME="${APP_DB_NAME:-sasdatqbox}"
APP_DB_USER="${APP_DB_USER:-sas_user}"
APP_DB_PASSWORD="${APP_DB_PASSWORD:-ML!gsx90l02}"

export PGPASSWORD="$PG_SUPER_PASS"

wait_for_pg() {
  local host="$1"; local port="$2"; local user="$3"; local tries="${4:-30}"
  echo "[db-bootstrap] Esperando a Postgres en ${host}:${port} como ${user}..."
  for i in $(seq 1 "$tries"); do
    if pg_isready -h "$host" -p "$port" -U "$user" >/dev/null 2>&1; then
      echo "[db-bootstrap] Postgres listo en ${host}:${port}."
      return 0
    fi
    sleep 2
  done
  return 1
}

wait_for_writable_pg() {
  local host="$1"; local port="$2"; local user="$3"; local db="$4"; local tries="${5:-30}"
  echo "[db-bootstrap] Esperando conexión writable en ${host}:${port} para DB ${db}..."
  for i in $(seq 1 "$tries"); do
    if psql -h "$host" -p "$port" -U "$user" -d "$db" -tAc "CREATE TEMP TABLE test_writable (id int); DROP TABLE test_writable;" >/dev/null 2>&1; then
      echo "[db-bootstrap] Conexión writable confirmada en ${host}:${port}."
      return 0
    fi
    echo "[db-bootstrap] Intento $i: Conexión no writable aún, reintentando..."
    sleep 5
  done
  echo "[db-bootstrap] ERROR: No se pudo obtener conexión writable después de $tries intentos." >&2
  return 1
}

# Intento 1: vía HAProxy (master)
if ! wait_for_pg "$PGHOST" "$PGPORT" "$PGUSER" 20; then
  echo "[db-bootstrap] HAProxy no respondió a tiempo; intentando directo al master Patroni..."
  PGHOST="patroni-master"; PGPORT="5432"
  if ! wait_for_pg "$PGHOST" "$PGPORT" "$PGUSER" 30; then
    echo "[db-bootstrap] ERROR: No se pudo alcanzar Postgres ni por HAProxy ni directo al master." >&2
    exit 1
  fi
fi

# Esperar hasta que la conexión sea writable (para evitar errores de read-only transaction)
if ! wait_for_writable_pg "$PGHOST" "$PGPORT" "$PGUSER" "postgres" 30; then
  exit 1
fi

echo "[db-bootstrap] Asegurando base de datos ${APP_DB_NAME}..."
DB_EXISTS=$(psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -tAc "SELECT 1 FROM pg_database WHERE datname='${APP_DB_NAME}'" || true)
if [[ "$DB_EXISTS" != "1" ]]; then
  psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -v ON_ERROR_STOP=1 -c "CREATE DATABASE ${APP_DB_NAME};"
  echo "[db-bootstrap] BD creada."
else
  echo "[db-bootstrap] BD ya existe."
fi

echo "[db-bootstrap] Asegurando rol ${APP_DB_USER}..."
ROLE_EXISTS=$(psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$APP_DB_NAME" -tAc "SELECT 1 FROM pg_roles WHERE rolname='${APP_DB_USER}'" || true)
if [[ "$ROLE_EXISTS" != "1" ]]; then
  psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$APP_DB_NAME" -v ON_ERROR_STOP=1 -c "CREATE ROLE \"${APP_DB_USER}\" LOGIN PASSWORD '${APP_DB_PASSWORD}';"
  echo "[db-bootstrap] Rol creado."
else
  echo "[db-bootstrap] Rol ya existe."
fi

echo "[db-bootstrap] Creando esquema/tablas si faltan..."
psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$APP_DB_NAME" -v ON_ERROR_STOP=1 -f /sql/create_pos_schema_and_tables.sql

echo "[db-bootstrap] Aplicando GRANTs y publicación Debezium..."
psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$APP_DB_NAME" -v ON_ERROR_STOP=1 -f /sql/bootstrap_grants_and_publication.sql

echo "[db-bootstrap] Completado."