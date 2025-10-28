#!/usr/bin/env sh
set -eu

# Genera migraciones Flyway basadas en diferencias entre DDL dev y prod.
# - SRC_DEV: directorio con DDL dev (por defecto db/pos)
# - SRC_PRO: directorio con DDL prod (por defecto db-pro/pos)
# - MIG_DIR: destino de migraciones (por defecto src/main/resources/db/migration)
# - SCHEMA: esquema (por defecto pos)
# - MIG_DEDUP_POLICY: update_existing | skip_if_exists | create_new_version (por defecto update_existing)

SRC_DEV="${SRC_DEV:-db/pos}"
SRC_PRO="${SRC_PRO:-db-pro/pos}"
MIG_DIR="${MIG_DIR:-src/main/resources/db/migration}"
SCHEMA="${SCHEMA:-pos}"
MIG_DEDUP_POLICY="${MIG_DEDUP_POLICY:-update_existing}"

mkdir -p "$MIG_DIR"

# Utils
next_version() {
  max="$(ls -1 "$MIG_DIR"/V*__*.sql 2>/dev/null | sed -E 's#.*/V([0-9]+)__.*#\1#' | sort -n | tail -1 || true)"
  [ -z "${max:-}" ] && max=0
  echo $((max+1))
}

find_existing_by_category() {
  category="$1"
  ls -1 "$MIG_DIR"/V*__"$category".sql 2>/dev/null \
    | sed -E 's#^.*?/V([0-9]+)__.*$#\1 & #' \
    | sort -n \
    | head -1 \
    | cut -d' ' -f2 || true
}

hash_file() {
  f="$1"
  if command -v md5sum >/dev/null 2>&1; then
    md5sum "$f" | awk '{print $1}'
  elif command -v sha1sum >/dev/null 2>&1; then
    sha1sum "$f" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum "$f" | awk '{print $1}'
  elif command -v cksum >/dev/null 2>&1; then
    cksum "$f" | awk '{print $1}'
  else
    wc -c "$f" | awk '{print $1}'
  fi
}

normalize_to_tmp() {
  src="$1"; tmp="$2"
  tr -d '\r' < "$src" | sed -E 's/[[:space:]]+$//' > "$tmp"
}

# Header estándar para todas las migraciones (asegura resolución de tipos/enum en pos)
build_header() {
  cat <<HDR
-- Schema: ${SCHEMA}
-- Nota: Flyway ejecuta cada migración en una transacción
SET LOCAL search_path TO ${SCHEMA};

HDR
}

# Reordenar constraints: primero PK, luego UNIQUE, CHECK y al final FKs
order_constraints() {
  in_file="$1"; out_file="$2"
  [ -f "$in_file" ] || { : > "$out_file"; return 0; }
  awk '
    {
      line=$0; key=50;
      if (line ~ /PRIMARY[[:space:]]+KEY/) key=10;
      else if (line ~ /UNIQUE\b/) key=20;
      else if (line ~ /CHECK\b/) key=30;
      else if (line ~ /FOREIGN[[:space:]]+KEY/) key=40;
      printf("%02d %s\n", key, line);
    }
  ' "$in_file" | sort -n | cut -d' ' -f2- > "$out_file"
}

write_migration() {
  category="$1"    # p.ej. create_pos_tables_diff
  content_tmp="$2" # archivo temporal con contenido

  # Evitar crear/actualizar archivos si el contenido está vacío o solo espacios
  if [ ! -s "$content_tmp" ] || ! grep -qE '[^[:space:]]' "$content_tmp"; then
    echo "[SKIP] $category: contenido vacío; no se crea/actualiza archivo"
    return 0
  fi

  # Componer contenido final con header
  final_tmp="$(mktemp)"
  build_header > "$final_tmp"
  cat "$content_tmp" >> "$final_tmp"
  existing="$(find_existing_by_category "$category")"

  # Modo dry-run: mostrar qué ocurriría según la política de deduplicación
  if [ "${DRY_RUN:-0}" = "1" ]; then
    if [ -n "${existing:-}" ] && [ -f "$existing" ]; then
      new_norm="$(mktemp)"; old_norm="$(mktemp)"
      normalize_to_tmp "$final_tmp" "$new_norm"
      normalize_to_tmp "$existing" "$old_norm"
      new_h="$(hash_file "$new_norm")"
      old_h="$(hash_file "$old_norm")"
      rm -f "$new_norm" "$old_norm"
      if [ "$new_h" = "$old_h" ]; then
        echo "[DRY-RUN] $category: sin cambios; reutilizaría $existing"
        return 0
      fi
      case "$MIG_DEDUP_POLICY" in
        update_existing)
          echo "[DRY-RUN] $category: se actualizaría $existing"
          ;;
        skip_if_exists)
          echo "[DRY-RUN] $category: se saltaría (existe $existing); política=skip_if_exists"
          ;;
        create_new_version)
          v="$(next_version)"; target="$MIG_DIR/V${v}__${category}.sql"
          echo "[DRY-RUN] $category: se crearía $target (nueva versión)"
          ;;
        *)
          echo "ERROR: MIG_DEDUP_POLICY desconocida: $MIG_DEDUP_POLICY" >&2; exit 1
          ;;
      esac
    else
      v="$(next_version)"; target="$MIG_DIR/V${v}__${category}.sql"
      echo "[DRY-RUN] $category: se crearía $target"
    fi
    rm -f "$final_tmp"; return 0
  fi
  if [ -n "${existing:-}" ] && [ -f "$existing" ]; then
    new_norm="$(mktemp)"; old_norm="$(mktemp)"
    normalize_to_tmp "$final_tmp" "$new_norm"
    normalize_to_tmp "$existing" "$old_norm"
    new_h="$(hash_file "$new_norm")"
    old_h="$(hash_file "$old_norm")"
    rm -f "$new_norm" "$old_norm"

    if [ "$new_h" = "$old_h" ]; then
      echo "[SKIP] $category: sin cambios; reutilizando $existing"
      rm -f "$final_tmp"; return 0
    fi

    case "$MIG_DEDUP_POLICY" in
      update_existing)
        cp "$final_tmp" "$existing"
        echo "[UPDATE] $category: actualizado contenido en $existing"
        ;;
      skip_if_exists)
        echo "[SKIP] $category: ya existe ($existing); política=skip_if_exists"
        ;;
      create_new_version)
        v="$(next_version)"
        target="$MIG_DIR/V${v}__${category}.sql"
        cp "$final_tmp" "$target"
        echo "[NEW] $category: creado $target"
        ;;
      *)
        echo "ERROR: MIG_DEDUP_POLICY desconocida: $MIG_DEDUP_POLICY" >&2
        exit 1
        ;;
    esac
  else
    v="$(next_version)"
    target="$MIG_DIR/V${v}__${category}.sql"
    cp "$final_tmp" "$target"
    echo "[CREATE] $category: creado $target"
  fi
  rm -f "$final_tmp"
}

# Helpers para diffs de sets
sort_unique() { awk '{gsub(/[[:space:]]+$/,""); print}' | sort -u; }

set_diff() {
  # imprime líneas en dev_set que no están en pro_set
  dev_set="$1"; pro_set="$2"
  if command -v comm >/dev/null 2>&1; then
    comm -23 "$dev_set" "$pro_set"
  else
    grep -F -x -v -f "$pro_set" "$dev_set" || true
  fi
}

# Extraer definiciones de columnas (nombre|definición) desde un archivo CREATE TABLE exportado
parse_columns_defs() {
  file="$1"
  sed -n '1,/^CREATE[ \t]\+TABLE/d; /^);/q; /^[ \t]*$/d; s/^[ \t]*//; s/,[ \t]*$//; p' "$file" \
    | awk '{print $1 "|" $0}'
}

# Preparar temporales
schema_tmp="$(mktemp)"; : > "$schema_tmp"
tables_tmp="$(mktemp)"; : > "$tables_tmp"
constraints_tmp="$(mktemp)"; : > "$constraints_tmp"
indexes_tmp="$(mktemp)"; : > "$indexes_tmp"
views_tmp="$(mktemp)"; : > "$views_tmp"
routines_tmp="$(mktemp)"; : > "$routines_tmp"
types_create_tmp="$(mktemp)"; : > "$types_create_tmp"
types_alter_tmp="$(mktemp)"; : > "$types_alter_tmp"
col_types_tmp="$(mktemp)"; : > "$col_types_tmp"

# SCHEMA
printf 'CREATE SCHEMA IF NOT EXISTS %s;\n' "$SCHEMA" >> "$schema_tmp"

# Tablas: crear solo las que existen en dev y NO en prod
# Si existe una migración base de tablas (create_<schema>_tables), evitamos duplicar CREATEs en *_diff
base_tables_mig="$(find_existing_by_category "create_${SCHEMA}_tables")"
for f in "$SRC_DEV"/TABLES/*/*.sql; do
  [ -f "$f" ] || continue
  base="$(basename "$f")"
  dir="$(basename "$(dirname "$f")")"
  f_pro="$SRC_PRO/TABLES/$dir/$base"
  if [ ! -f "$f_pro" ]; then
    # Copiar bloque CREATE TABLE y hacerlo idempotente con IF NOT EXISTS
    awk 'BEGIN{p=0} 
      /^CREATE[ \t]+TABLE/{p=1; sub(/^CREATE[ \t]+TABLE/, "CREATE TABLE IF NOT EXISTS"); print; next}
      {if(p) print}
      /^\);/{if(p){print ""; p=0}}' "$f" >> "$tables_tmp"
  fi
done

# Columnas nuevas: para tablas que existen en dev y prod, generar ALTER TABLE ADD COLUMN
for f in "$SRC_DEV"/TABLES/*/*.sql; do
  [ -f "$f" ] || continue
  base="$(basename "$f")"
  tname="$(basename "$(dirname "$f")")"
  f_pro="$SRC_PRO/TABLES/$tname/$base"
  if [ -f "$f_pro" ]; then
    dev_defs_set="$(mktemp)"; pro_defs_set="$(mktemp)"
    parse_columns_defs "$f" | tr -d '\r' | sort -u > "$dev_defs_set" || true
    parse_columns_defs "$f_pro" | tr -d '\r' | sort -u > "$pro_defs_set" || true
    dev_names="$(mktemp)"; pro_names="$(mktemp)"
    cut -d'|' -f1 "$dev_defs_set" | sort -u > "$dev_names"
    cut -d'|' -f1 "$pro_defs_set" | sort -u > "$pro_names"
    missing_cols="$(mktemp)"
    if command -v comm >/dev/null 2>&1; then
      comm -23 "$dev_names" "$pro_names" > "$missing_cols"
    else
      grep -F -x -v -f "$pro_names" "$dev_names" > "$missing_cols" || true
    fi
    while IFS= read -r col; do
      [ -n "$col" ] || continue
      def_line="$(awk -F'|' -v col="$col" '$1==col{print substr($0, index($0, "|")+1); exit}' "$dev_defs_set")"
      [ -n "$def_line" ] || continue
      printf 'ALTER TABLE %s.%s ADD COLUMN %s;\n' "$SCHEMA" "$tname" "$def_line" >> "$tables_tmp"
    done < "$missing_cols"
    rm -f "$dev_defs_set" "$pro_defs_set" "$dev_names" "$pro_names" "$missing_cols"
  fi
done

# Cambios de tipo de columna: para tablas que existen en dev y prod, generar ALTER TABLE ALTER COLUMN TYPE
extract_col_type() {
  # Entrada: línea completa de definición de columna ("colname type [mods] ...")
  # Salida: tipo y modificadores hasta antes de DEFAULT/NOT/GENERATED
  sed -E 's/^[^|]*\|[[:space:]]*//; s/^[[:space:]]*//; s/[[:space:]]+DEFAULT.*$//; s/[[:space:]]+NOT[[:space:]]+NULL.*$//; s/[[:space:]]+NULL.*$//; s/[[:space:]]+GENERATED.*$//; s/,[[:space:]]*$//' | sed -E 's/^([[:alnum:]_]+)[[:space:]]+/\1 /'
}

for f in "$SRC_DEV"/TABLES/*/*.sql; do
  [ -f "$f" ] || continue
  base="$(basename "$f")"
  tname="$(basename "$(dirname "$f")")"
  f_pro="$SRC_PRO/TABLES/$tname/$base"
  if [ -f "$f_pro" ]; then
    dev_defs_set="$(mktemp)"; pro_defs_set="$(mktemp)"
    parse_columns_defs "$f" | tr -d '\r' | sort -u > "$dev_defs_set" || true
    parse_columns_defs "$f_pro" | tr -d '\r' | sort -u > "$pro_defs_set" || true
    # Intersección de columnas comunes
    dev_names="$(mktemp)"; pro_names="$(mktemp)"
    cut -d'|' -f1 "$dev_defs_set" | sort -u > "$dev_names"
    cut -d'|' -f1 "$pro_defs_set" | sort -u > "$pro_names"
    common_cols="$(mktemp)"
    if command -v comm >/dev/null 2>&1; then
      comm -12 "$dev_names" "$pro_names" > "$common_cols"
    else
      # Fallback: filas en dev_names que también están en pro_names
      grep -F -x -f "$pro_names" "$dev_names" > "$common_cols" || true
    fi
    while IFS= read -r col; do
      [ -n "$col" ] || continue
      dev_line="$(awk -F'|' -v col="$col" '$1==col{print $0; exit}' "$dev_defs_set")"
      pro_line="$(awk -F'|' -v col="$col" '$1==col{print $0; exit}' "$pro_defs_set")"
      [ -n "$dev_line" ] && [ -n "$pro_line" ] || continue
      dev_type="$(printf '%s' "$dev_line" | extract_col_type)"
      pro_type="$(printf '%s' "$pro_line" | extract_col_type)"
      # Normalizar espacios múltiples
      dev_type_norm="$(printf '%s' "$dev_type" | tr -s ' ')"
      pro_type_norm="$(printf '%s' "$pro_type" | tr -s ' ')"
      if [ "$dev_type_norm" != "$pro_type_norm" ]; then
        # Generar ALTER con USING para asegurar casteo
        printf 'ALTER TABLE %s.%s ALTER COLUMN %s TYPE %s USING %s::%s;\n' "$SCHEMA" "$tname" "$col" "$dev_type_norm" "$col" "$dev_type_norm" >> "$col_types_tmp"
      fi
    done < "$common_cols"
    rm -f "$dev_defs_set" "$pro_defs_set" "$dev_names" "$pro_names" "$common_cols"
  fi
done

# Constraints: diferencia de líneas ALTER TABLE
dev_cons_set="$(mktemp)"; pro_cons_set="$(mktemp)"
: > "$dev_cons_set"; : > "$pro_cons_set"
for f in "$SRC_DEV"/TABLES/*/*.sql; do
  [ -f "$f" ] || continue
  grep -E '^ALTER TABLE' "$f" || true
done | tr -d '\r' | sort_unique > "$dev_cons_set"
if [ -d "$SRC_PRO/TABLES" ]; then
  for f in "$SRC_PRO"/TABLES/*/*.sql; do
    [ -f "$f" ] || continue
    grep -E '^ALTER TABLE' "$f" || true
  done | tr -d '\r' | sort_unique > "$pro_cons_set"
else
  : > "$pro_cons_set"
fi
set_diff "$dev_cons_set" "$pro_cons_set" >> "$constraints_tmp" || true
rm -f "$dev_cons_set" "$pro_cons_set"

# Reordenar constraints para garantizar PK/UNIQUE antes de FKs
constraints_ord_tmp="$(mktemp)"
order_constraints "$constraints_tmp" "$constraints_ord_tmp"
mv "$constraints_ord_tmp" "$constraints_tmp"

# Indexes: diferencia de líneas CREATE INDEX (omitimos *_pkey)
dev_idx_set="$(mktemp)"; pro_idx_set="$(mktemp)"
: > "$dev_idx_set"; : > "$pro_idx_set"
for f in "$SRC_DEV"/TABLES/*/*.sql; do
  [ -f "$f" ] || continue
  grep -E '^CREATE (UNIQUE )?INDEX' "$f" | grep -Ev '_pkey\b' || true
done | tr -d '\r' | sort_unique > "$dev_idx_set"
if [ -d "$SRC_PRO/TABLES" ]; then
  for f in "$SRC_PRO"/TABLES/*/*.sql; do
    [ -f "$f" ] || continue
    grep -E '^CREATE (UNIQUE )?INDEX' "$f" | grep -Ev '_pkey\b' || true
  done | tr -d '\r' | sort_unique > "$pro_idx_set"
else
  : > "$pro_idx_set"
fi
set_diff "$dev_idx_set" "$pro_idx_set" >> "$indexes_tmp" || true
rm -f "$dev_idx_set" "$pro_idx_set"

# Reescribir índices para que sean idempotentes: CREATE [UNIQUE] INDEX IF NOT EXISTS
if [ -s "$indexes_tmp" ]; then
  tmp_idx="$(mktemp)"
  sed -E 's/^CREATE[[:space:]]+UNIQUE[[:space:]]+INDEX/CREATE UNIQUE INDEX IF NOT EXISTS/; s/^CREATE[[:space:]]+INDEX/CREATE INDEX IF NOT EXISTS/' "$indexes_tmp" > "$tmp_idx"
  mv "$tmp_idx" "$indexes_tmp"
fi

# Vistas: crear/actualizar si faltan o difieren
if [ -d "$SRC_DEV/VIEWS" ]; then
  for f in "$SRC_DEV"/VIEWS/*/*.sql; do
    [ -f "$f" ] || continue
    base="$(basename "$f")"; dir="$(basename "$(dirname "$f")")"
    f_pro="$SRC_PRO/VIEWS/$dir/$base"
    if [ ! -f "$f_pro" ]; then
      # Reescribir a CREATE OR REPLACE VIEW
      sed -E 's/^CREATE[[:space:]]+VIEW/CREATE OR REPLACE VIEW/' "$f" >> "$views_tmp"; printf '\n' >> "$views_tmp"
    else
      new_norm="$(mktemp)"; old_norm="$(mktemp)"
      normalize_to_tmp "$f" "$new_norm"; normalize_to_tmp "$f_pro" "$old_norm"
      if [ "$(hash_file "$new_norm")" != "$(hash_file "$old_norm")" ]; then
        sed -E 's/^CREATE[[:space:]]+VIEW/CREATE OR REPLACE VIEW/' "$f" >> "$views_tmp"; printf '\n' >> "$views_tmp"
      fi
      rm -f "$new_norm" "$old_norm"
    fi
  done
fi

# Rutinas: crear/actualizar si faltan o difieren (FUNCTIONS y PROCEDURES)
for kind in FUNCTIONS PROCEDURES; do
  if [ -d "$SRC_DEV/$kind" ]; then
    for f in "$SRC_DEV"/$kind/*/*.sql; do
      [ -f "$f" ] || continue
      base="$(basename "$f")"; dir="$(basename "$(dirname "$f")")"
      f_pro="$SRC_PRO/$kind/$dir/$base"
      if [ ! -f "$f_pro" ]; then
        sed -E 's/^CREATE[[:space:]]+FUNCTION/CREATE OR REPLACE FUNCTION/; s/^CREATE[[:space:]]+PROCEDURE/CREATE OR REPLACE PROCEDURE/' "$f" >> "$routines_tmp"; printf '\n' >> "$routines_tmp"
      else
        new_norm="$(mktemp)"; old_norm="$(mktemp)"
        normalize_to_tmp "$f" "$new_norm"; normalize_to_tmp "$f_pro" "$old_norm"
        if [ "$(hash_file "$new_norm")" != "$(hash_file "$old_norm")" ]; then
          sed -E 's/^CREATE[[:space:]]+FUNCTION/CREATE OR REPLACE FUNCTION/; s/^CREATE[[:space:]]+PROCEDURE/CREATE OR REPLACE PROCEDURE/' "$f" >> "$routines_tmp"; printf '\n' >> "$routines_tmp"
        fi
        rm -f "$new_norm" "$old_norm"
      fi
done
  fi
done

# Tipos ENUM (TYPES): crear los que faltan en PRO y añadir valores nuevos
parse_enum_from_file() {
  f="$1"
  content="$(tr -d '\r\n' < "$f")"
  # Buscar primera ocurrencia CREATE TYPE pos.<name> AS ENUM (...)
  name="$(printf '%s' "$content" | sed -nE 's/.*CREATE[[:space:]]+TYPE[[:space:]]+pos\.([a-z_]+)[[:space:]]+AS[[:space:]]+ENUM[[:space:]]*\(.*/\1/p' | head -1)"
  vals_raw="$(printf '%s' "$content" | sed -nE 's/.*CREATE[[:space:]]+TYPE[[:space:]]+pos\.[a-z_]+[[:space:]]+AS[[:space:]]+ENUM[[:space:]]*\(([^)]*)\).*/\1/p' | head -1)"
  vals="$(printf '%s' "$vals_raw" | sed -E "s/^[[:space:]]*'//; s/'[[:space:]]*,[[:space:]]*'/\n/g; s/'[[:space:]]*$//" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' | sed '/^$/d')"
  if [ -n "$name" ]; then
    printf '%s\n' "$name"
    printf '%s\n' "$vals" | sed 's/^/|/'
  fi
}

dev_types_list="$(mktemp)"; : > "$dev_types_list"
pro_types_list="$(mktemp)"; : > "$pro_types_list"

if [ -d "$SRC_DEV/TYPES" ]; then
  for f in "$SRC_DEV"/TYPES/*.sql; do [ -f "$f" ] || continue; parse_enum_from_file "$f" >> "$dev_types_list"; done
else
  # Fallback: intentar extraer de migraciones existentes en src/main/resources/db/migration
  for f in "$MIG_DIR"/V*__create_${SCHEMA}_enums.sql "$MIG_DIR"/V*__create_${SCHEMA}_types.sql; do
    [ -f "$f" ] || continue
    parse_enum_from_file "$f" >> "$dev_types_list"
  done
fi

if [ -d "$SRC_PRO/TYPES" ]; then
  for f in "$SRC_PRO"/TYPES/*.sql; do [ -f "$f" ] || continue; parse_enum_from_file "$f" >> "$pro_types_list"; done
fi

# Construir mapas name->values
to_map() {
  in="$1"; out="$2"
  : > "$out"
  awk 'BEGIN{name=""} /^\|/{ if(name!=""){ vals=vals substr($0,2) "\n" } } !/^\|/{ if(name!=""){ print name"|"vals; vals="" } name=$0 } END{ if(name!=""){ print name"|"vals } }' "$in" | while IFS='|' read -r nm vals; do
    printf '%s|' "$nm" > "$out.tmp"
    printf '%s' "$vals" | sed '/^$/d' | tr '\n' '|' >> "$out.tmp"
    printf '\n' >> "$out.tmp"
    cat "$out.tmp" >> "$out"; rm -f "$out.tmp"
  done
}

dev_map="$(mktemp)"; pro_map="$(mktemp)"
to_map "$dev_types_list" "$dev_map"
to_map "$pro_types_list" "$pro_map"

# Funciones para obtener valores por tipo
get_vals() { nm="$1"; file="$2"; awk -F'|' -v n="$nm" '$1==n{for(i=2;i<=NF;i++)if($i!="")print $i}' "$file"; }
has_type() { nm="$1"; file="$2"; awk -F'|' -v n="$nm" '$1==n{print 1; exit}' "$file" >/dev/null 2>&1; }

# Crear tipos faltantes en PRO
awk -F'|' '{print $1}' "$dev_map" | while read -r tnm; do
  [ -n "$tnm" ] || continue
  if ! has_type "$tnm" "$pro_map"; then
    # Construir lista de valores
    vals="$(get_vals "$tnm" "$dev_map" | sed "s/^/'/; s/$/'/" | paste -sd, -)"
    cat >> "$types_create_tmp" <<SQL
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid=t.typnamespace
    WHERE n.nspname='${SCHEMA}' AND t.typname='${tnm}'
  ) THEN
    EXECUTE 'CREATE TYPE ${SCHEMA}.${tnm} AS ENUM (${vals})';
  END IF;
END $$;
SQL
  fi
done

# Añadir valores nuevos presentes en DEV pero no en PRO
awk -F'|' '{print $1}' "$dev_map" | while read -r tnm; do
  [ -n "$tnm" ] || continue
  dev_vals_set="$(mktemp)"; pro_vals_set="$(mktemp)"
  get_vals "$tnm" "$dev_map" | sort -u > "$dev_vals_set"
  if has_type "$tnm" "$pro_map"; then
    get_vals "$tnm" "$pro_map" | sort -u > "$pro_vals_set"
  else
    : > "$pro_vals_set"
  fi
  set_diff "$dev_vals_set" "$pro_vals_set" | while read -r val; do
    [ -n "$val" ] || continue
    cat >> "$types_alter_tmp" <<SQL
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum e JOIN pg_type t ON t.oid=e.enumtypid JOIN pg_namespace n ON n.oid=t.typnamespace
    WHERE n.nspname='${SCHEMA}' AND t.typname='${tnm}' AND e.enumlabel='${val}'
  ) THEN
    EXECUTE 'ALTER TYPE ${SCHEMA}.${tnm} ADD VALUE ''${val}''';
  END IF;
END $$;
SQL
  done
  rm -f "$dev_vals_set" "$pro_vals_set"
done

# Escribir migraciones con categoría "_diff"
# No crear schema por diffs: siempre omitido

write_migration "create_${SCHEMA}_tables_diff" "$tables_tmp"
write_migration "add_${SCHEMA}_constraints_diff" "$constraints_tmp"
write_migration "create_${SCHEMA}_indexes_diff" "$indexes_tmp"
write_migration "create_${SCHEMA}_views_diff" "$views_tmp"
write_migration "create_${SCHEMA}_routines_diff" "$routines_tmp"
write_migration "create_${SCHEMA}_types_diff" "$types_create_tmp"
write_migration "alter_${SCHEMA}_types_diff" "$types_alter_tmp"
write_migration "alter_${SCHEMA}_column_types_diff" "$col_types_tmp"

# Resumen (dry-run)
if [ "${DRY_RUN:-0}" = "1" ]; then
  new_tables_cnt=$(grep -c '^CREATE TABLE' "$tables_tmp" || true)
  add_cols_cnt=$(grep -c '^ALTER TABLE .* ADD COLUMN' "$tables_tmp" || true)
  cons_cnt=$(grep -c '^ALTER TABLE' "$constraints_tmp" || true)
  idx_cnt=$(grep -c '^CREATE \(UNIQUE \)?INDEX' "$indexes_tmp" || true)
  views_cnt=$(grep -c '^CREATE OR REPLACE VIEW' "$views_tmp" || true)
  funcs_cnt=$(grep -c '^CREATE OR REPLACE FUNCTION' "$routines_tmp" || true)
  procs_cnt=$(grep -c '^CREATE OR REPLACE PROCEDURE' "$routines_tmp" || true)
  echo "Resumen (dry-run):"
  echo "- Tablas nuevas: $new_tables_cnt"
  echo "- Columnas nuevas (ALTER ADD COLUMN): $add_cols_cnt"
  echo "- Constraints nuevas: $cons_cnt"
  echo "- Índices nuevos: $idx_cnt"
  echo "- Vistas a reemplazar: $views_cnt"
  echo "- Funciones a reemplazar: $funcs_cnt"
  echo "- Procedimientos a reemplazar: $procs_cnt"
fi

# Limpiar temporales
rm -f "$schema_tmp" "$tables_tmp" "$constraints_tmp" "$indexes_tmp" "$views_tmp" "$routines_tmp"
rm -f "$types_create_tmp" "$types_alter_tmp" "$col_types_tmp" "$dev_types_list" "$pro_types_list" "$dev_map" "$pro_map"

echo "Migraciones por diferencia generadas (categorías *_diff)."