#!/usr/bin/env sh
set -eu

# Entradas vía variables de entorno:
#   DB_NAME, DB_USER, DB_PASSWORD, SCHEMA (por defecto pos), OUT_DIR (por defecto /tmp/pg_ddl_export), CONTAINER_NAME (opcional solo para header)

DB_NAME="${DB_NAME:-sasdatqbox}"
DB_USER="${DB_USER:-sas_user}"
DB_PASSWORD="${DB_PASSWORD:?Debe definir DB_PASSWORD}"
SCHEMA="${SCHEMA:-pos}"
OUT_DIR="${OUT_DIR:-/tmp/pg_ddl_export}"
CONTAINER_NAME="${CONTAINER_NAME:-}" # solo informativo

PSQL() {
  PGPASSWORD="$DB_PASSWORD" psql -h localhost -p 5432 -U "$DB_USER" -d "$DB_NAME" "$@"
}

header() {
  printf -- "-- Source: jdbc:postgresql://127.0.0.1:5432/%s\n" "$DB_NAME"
  printf -- "-- Usuario: %s\n" "$DB_USER"
  if [ -n "$CONTAINER_NAME" ]; then printf -- "-- Contenedor: %s\n" "$CONTAINER_NAME"; fi
  printf -- "SET LOCAL search_path TO %s;\n\n" "$SCHEMA"
}

ensure_dir() { mkdir -p "$1"; }

export_table() {
  t="$1"
  dir="$OUT_DIR/$SCHEMA/TABLES/$t"
  file="$dir/$t.sql"
  ensure_dir "$dir"
  header > "$file"

  # CREATE TABLE
  PSQL -At <<SQL >> "$file"
WITH cols AS (
  SELECT '  '||quote_ident(c.column_name)||' '||format_type(a.atttypid,a.atttypmod)
         || CASE WHEN c.is_identity='YES' THEN ' GENERATED '||c.identity_generation||' AS IDENTITY' ELSE '' END
         || CASE WHEN c.is_nullable='NO' THEN ' NOT NULL' ELSE '' END
         || CASE WHEN c.column_default IS NOT NULL AND c.is_identity<>'YES' THEN ' DEFAULT '||c.column_default ELSE '' END
         || CASE WHEN row_number() OVER (ORDER BY c.ordinal_position) < (SELECT count(*) FROM information_schema.columns WHERE table_schema='${SCHEMA}' AND table_name='${t}') THEN ',' ELSE '' END AS coldef
  FROM information_schema.columns c
  JOIN pg_attribute a ON a.attrelid = '"${SCHEMA}"."${t}"'::regclass AND a.attname=c.column_name
  WHERE c.table_schema='${SCHEMA}' AND c.table_name='${t}'
  ORDER BY c.ordinal_position
)
SELECT 'CREATE TABLE '||quote_ident('${SCHEMA}')||'.'||quote_ident('${t}')||E' (\n'
       || string_agg(coldef, E'\n') || E'\n);'
FROM cols;
SQL

  # Constraints PK/UK/FK
  PSQL -At <<SQL >> "$file"
SELECT 'ALTER TABLE '||quote_ident(n.nspname)||'.'||quote_ident(c.relname)||' ADD CONSTRAINT '
       ||quote_ident(ct.conname)||' '||pg_get_constraintdef(ct.oid)||';'
FROM pg_constraint ct
JOIN pg_class c ON c.oid=ct.conrelid
JOIN pg_namespace n ON n.oid=c.relnamespace
WHERE n.nspname='${SCHEMA}' AND c.relname='${t}' AND ct.contype IN ('p','u','f')
ORDER BY ct.conindid;
SQL

  # Indexes
  PSQL -At <<SQL >> "$file"
SELECT indexdef||';' FROM pg_indexes
WHERE schemaname='${SCHEMA}' AND tablename='${t}'
ORDER BY indexname;
SQL
}

export_view() {
  v="$1"
  dir="$OUT_DIR/$SCHEMA/VIEWS/$v"
  file="$dir/$v.sql"
  ensure_dir "$dir"
  header > "$file"
  PSQL -At <<SQL >> "$file"
SELECT 'CREATE OR REPLACE VIEW '||quote_ident('${SCHEMA}')||'.'||quote_ident('${v}')||E' AS\n'
       ||pg_get_viewdef('"${SCHEMA}"."${v}"'::regclass, true)||';';
SQL
}

sanitize() {
  # para nombres de funciones/procedimientos con argumentos
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -e 's/[ ,()]/_/g' -e 's/\[\]/_/g' -e 's/__\+/_/g'
}

export_routine() {
  kind="$1" # 'f' función, 'p' procedimiento
  name="$2"
  args="$3"
  safe="$(sanitize "${name}_${args}")"
  type_dir="$( [ "$kind" = "p" ] && printf 'PROCEDURES' || printf 'FUNCTIONS' )"
  dir="$OUT_DIR/$SCHEMA/$type_dir/$safe"
  file="$dir/$safe.sql"
  ensure_dir "$dir"
  header > "$file"
  PSQL -At <<SQL >> "$file"
SELECT pg_get_functiondef(p.oid)
FROM pg_proc p
JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='${SCHEMA}' AND p.proname='${name}' AND pg_get_function_identity_arguments(p.oid)='${args}';
SQL
}

discover_and_export() {
  # Tablas
  tables=$(PSQL -At -c "SELECT tablename FROM pg_tables WHERE schemaname='${SCHEMA}' ORDER BY tablename;") || true
  # Vistas
  views=$(PSQL -At -c "SELECT table_name FROM information_schema.views WHERE table_schema='${SCHEMA}' ORDER BY table_name;") || true
  # Funciones
  funcs=$(PSQL -At <<SQL || true
SELECT p.proname||'|'||pg_get_function_identity_arguments(p.oid)
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='${SCHEMA}' AND p.prokind='f'
ORDER BY p.proname, pg_get_function_identity_arguments(p.oid);
SQL
)
  # Procedimientos
  procs=$(PSQL -At <<SQL || true
SELECT p.proname||'|'||pg_get_function_identity_arguments(p.oid)
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='${SCHEMA}' AND p.prokind='p'
ORDER BY p.proname, pg_get_function_identity_arguments(p.oid);
SQL
)

  mkdir -p "$OUT_DIR/$SCHEMA"

  count=0
  for t in $tables; do export_table "$t"; count=$((count+1)); done
  for v in $views; do export_view "$v"; count=$((count+1)); done
  printf '%s\n' "$funcs" | while IFS='|' read -r nm ar; do [ -n "$nm" ] || continue; export_routine f "$nm" "$ar"; count=$((count+1)); done
  printf '%s\n' "$procs" | while IFS='|' read -r nm ar; do [ -n "$nm" ] || continue; export_routine p "$nm" "$ar"; count=$((count+1)); done

  if [ "$count" -eq 0 ]; then
    echo "No se encontraron objetos en el esquema '$SCHEMA' de la BD '$DB_NAME'." >&2
  else
    echo "Exportación completa: $OUT_DIR/$SCHEMA (objetos: $count)"
  fi
}

discover_and_export