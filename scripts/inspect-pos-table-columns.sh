#!/usr/bin/env sh
set -eu

# Inspecciona columnas entre DEV y PRO para una tabla del esquema POS
# Uso:
#   SCHEMA=pos SRC_DEV=db/pos SRC_PRO=db-pro/pos bash scripts/inspect-pos-table-columns.sh alerts
# Variables:
#   - SCHEMA (por defecto: pos)
#   - SRC_DEV (por defecto: db/pos)
#   - SRC_PRO (por defecto: db-pro/pos)

TABLE="${1:-}"
SCHEMA="${SCHEMA:-pos}"
SRC_DEV="${SRC_DEV:-db/pos}"
SRC_PRO="${SRC_PRO:-db-pro/pos}"

if [ -z "$TABLE" ]; then
  echo "Uso: bash scripts/inspect-pos-table-columns.sh <table_name>" >&2
  echo "Ejemplo: bash scripts/inspect-pos-table-columns.sh alerts" >&2
  exit 1
fi

dev_file="$SRC_DEV/TABLES/$TABLE/$TABLE.sql"
pro_file="$SRC_PRO/TABLES/$TABLE/$TABLE.sql"

if [ ! -f "$dev_file" ]; then
  echo "No se encuentra DEV: $dev_file" >&2
  exit 1
fi
if [ ! -f "$pro_file" ]; then
  echo "No se encuentra PRO: $pro_file" >&2
  exit 1
fi

# Extrae definiciones de columnas (nombre|definición) del bloque CREATE TABLE
parse_columns_defs() {
  file="$1"
  tr -d '\r' < "$file" \
    | sed -n '1,/^CREATE[ \t]\+TABLE/d; /^);/q; /^[ \t]*$/d; s/^[ \t]*//; s/,[ \t]*$//; p' \
    | awk '{print $1 "|" $0}'
}

dev_defs_set="$(mktemp)"; pro_defs_set="$(mktemp)"
parse_columns_defs "$dev_file" | sort -u > "$dev_defs_set"
parse_columns_defs "$pro_file" | sort -u > "$pro_defs_set"

dev_names="$(mktemp)"; pro_names="$(mktemp)"
cut -d'|' -f1 "$dev_defs_set" > "$dev_names"
cut -d'|' -f1 "$pro_defs_set" > "$pro_names"

echo "Tabla: $SCHEMA.$TABLE"
echo "DEV columns:"
cut -d'|' -f2- "$dev_defs_set"
echo
echo "PRO columns:"
cut -d'|' -f2- "$pro_defs_set"
echo

missing_cols="$(mktemp)"
if command -v comm >/dev/null 2>&1; then
  comm -23 "$dev_names" "$pro_names" > "$missing_cols"
else
  grep -F -x -v -f "$pro_names" "$dev_names" > "$missing_cols" || true
fi

echo "Columnas faltantes en PRO (para añadir):"
if [ -s "$missing_cols" ]; then
  cat "$missing_cols"
else
  echo "(ninguna)"
fi
echo

echo "Preview ALTER TABLE ADD COLUMN:"
if [ -s "$missing_cols" ]; then
  while IFS= read -r col; do
    [ -n "$col" ] || continue
    def_line="$(awk -F'|' -v col="$col" '$1==col{print substr($0, index($0, "|")+1); exit}' "$dev_defs_set")"
    [ -n "$def_line" ] || continue
    printf 'ALTER TABLE %s.%s ADD COLUMN %s;\n' "$SCHEMA" "$TABLE" "$def_line"
  done < "$missing_cols"
else
  echo "(no se generarían ALTER COLUMN)"
fi

rm -f "$dev_defs_set" "$pro_defs_set" "$dev_names" "$pro_names" "$missing_cols"