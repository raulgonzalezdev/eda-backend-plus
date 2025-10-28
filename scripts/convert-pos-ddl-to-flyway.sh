#!/usr/bin/env sh
set -eu

# Convierte los DDL exportados en db/pos a migraciones Flyway en src/main/resources/db/migration.
# Ahora con deduplicación: si ya existe una migración por categoría, no se generan
# versiones nuevas; se reutiliza el archivo existente (opcionalmente se actualiza su contenido).
# Categorías:
#  - __create_<schema>_schema.sql
#  - __create_<schema>_tables.sql
#  - __add_<schema>_constraints.sql
#  - __create_<schema>_indexes.sql
#  - __create_<schema>_views.sql
#  - __create_<schema>_routines.sql

SRC_DIR="${SRC_DIR:-db/pos}"
MIG_DIR="${MIG_DIR:-src/main/resources/db/migration}"
SCHEMA="${SCHEMA:-pos}"
# Política de deduplicación: update_existing | skip_if_exists | create_new_version
MIG_DEDUP_POLICY="${MIG_DEDUP_POLICY:-update_existing}"

mkdir -p "$MIG_DIR"

# Utilidades
next_version() {
  max="$(ls -1 "$MIG_DIR"/V*__*.sql 2>/dev/null | sed -E 's#.*/V([0-9]+)__.*#\1#' | sort -n | tail -1 || true)"
  [ -z "${max:-}" ] && max=0
  echo $((max+1))
}

find_existing_by_category() {
  category="$1" # ejemplo: create_pos_tables
  # Seleccionar el archivo existente con menor versión numérica y devolver la ruta completa
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
  category="$1"    # p.ej. create_pos_tables
  content_tmp="$2" # archivo temporal con contenido

  # Evitar crear/actualizar archivos si el contenido está vacío o solo espacios
  if [ ! -s "$content_tmp" ] || ! grep -qE '[^[:space:]]' "$content_tmp"; then
    echo "[SKIP] $category: contenido vacío; no se crea/actualiza archivo"
    return 0
  fi

  # Modo dry-run: mostrar qué ocurriría según la política de deduplicación
  if [ "${DRY_RUN:-0}" = "1" ]; then
    # Componer contenido final con header
    final_tmp="$(mktemp)"
    build_header > "$final_tmp"
    cat "$content_tmp" >> "$final_tmp"
    existing="$(find_existing_by_category "$category")"
    if [ -n "${existing:-}" ] && [ -f "$existing" ]; then
      new_norm="$(mktemp)"; old_norm="$(mktemp)"
      normalize_to_tmp "$final_tmp" "$new_norm"
      normalize_to_tmp "$existing" "$old_norm"
      new_h="$(hash_file "$new_norm")"
      old_h="$(hash_file "$old_norm")"
      rm -f "$new_norm" "$old_norm"
      if [ "$new_h" = "$old_h" ]; then
        echo "[DRY-RUN] $category: sin cambios; reutilizaría $existing"
        rm -f "$final_tmp"; return 0
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

  existing="$(find_existing_by_category "$category")"
  if [ -n "${existing:-}" ] && [ -f "$existing" ]; then
    # Comparar contenido normalizado
    new_norm="$(mktemp)"; old_norm="$(mktemp)"
    # Componer contenido final con header
    final_tmp="$(mktemp)"
    build_header > "$final_tmp"
    cat "$content_tmp" >> "$final_tmp"
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
    rm -f "$final_tmp"
  else
    v="$(next_version)"
    target="$MIG_DIR/V${v}__${category}.sql"
    final_tmp="$(mktemp)"
    build_header > "$final_tmp"
    cat "$content_tmp" >> "$final_tmp"
    cp "$final_tmp" "$target"
    rm -f "$final_tmp"
    echo "[CREATE] $category: creado $target"
  fi
}

# Construir contenidos en temporales
schema_tmp="$(mktemp)"
tables_tmp="$(mktemp)"
constraints_tmp="$(mktemp)"
indexes_tmp="$(mktemp)"
views_tmp="$(mktemp)"
routines_tmp="$(mktemp)"

printf 'CREATE SCHEMA IF NOT EXISTS %s;\n' "$SCHEMA" > "$schema_tmp"
: > "$tables_tmp"
: > "$constraints_tmp"
: > "$indexes_tmp"
: > "$views_tmp"
: > "$routines_tmp"

# Tablas: recoger CREATE TABLE (idempotente), luego constraints y finalmente índices (filtrando *_pkey)
for f in "$SRC_DIR"/TABLES/*/*.sql; do
  [ -f "$f" ] || continue
  # CREATE TABLE block con IF NOT EXISTS para evitar conflictos si ya existe
  awk 'BEGIN{p=0} 
    /^CREATE[ \t]+TABLE/{p=1; sub(/^CREATE[ \t]+TABLE/, "CREATE TABLE IF NOT EXISTS"); print; next}
    {if(p) print}
    /^\);/{if(p){print ""; p=0}}' "$f" >> "$tables_tmp"
  # Constraints
  grep -E '^ALTER TABLE' "$f" >> "$constraints_tmp" || true
  # Indexes (skip PK idx names *_pkey)
  grep -E '^CREATE (UNIQUE )?INDEX' "$f" | grep -Ev '_pkey\b' | sed -E 's/^CREATE (UNIQUE )?INDEX/CREATE \1INDEX IF NOT EXISTS/' >> "$indexes_tmp" || true
done

# Reordenar constraints para garantizar PK/UNIQUE antes de FKs
constraints_ord_tmp="$(mktemp)"
order_constraints "$constraints_tmp" "$constraints_ord_tmp"
mv "$constraints_ord_tmp" "$constraints_tmp"

# Vistas
if [ -d "$SRC_DIR/VIEWS" ]; then
  for f in "$SRC_DIR"/VIEWS/*/*.sql; do
    [ -f "$f" ] || continue
    if grep -qE '^CREATE OR REPLACE VIEW' "$f"; then
      grep -E '^CREATE OR REPLACE VIEW' "$f" >> "$views_tmp"
      printf '\n' >> "$views_tmp"
    else
      cat "$f" >> "$views_tmp"
      printf '\n' >> "$views_tmp"
    fi
  done
fi

# Funciones
if [ -d "$SRC_DIR/FUNCTIONS" ]; then
  for f in "$SRC_DIR"/FUNCTIONS/*/*.sql; do
    [ -f "$f" ] || continue
    cat "$f" >> "$routines_tmp"
    printf '\n' >> "$routines_tmp"
  done
fi

# Procedimientos
if [ -d "$SRC_DIR/PROCEDURES" ]; then
  for f in "$SRC_DIR"/PROCEDURES/*/*.sql; do
    [ -f "$f" ] || continue
    cat "$f" >> "$routines_tmp"
    printf '\n' >> "$routines_tmp"
  done
fi

# Escribir migraciones con deduplicación
# Lógica normal: omitir siempre la creación de schema (se asume existente)
echo "[SKIP] create_${SCHEMA}_schema: omitido (schema existente)"
write_migration "create_${SCHEMA}_tables" "$tables_tmp"
write_migration "add_${SCHEMA}_constraints" "$constraints_tmp"
write_migration "create_${SCHEMA}_indexes" "$indexes_tmp"
write_migration "create_${SCHEMA}_views" "$views_tmp"
write_migration "create_${SCHEMA}_routines" "$routines_tmp"

# Limpiar temporales
rm -f "$schema_tmp" "$tables_tmp" "$constraints_tmp" "$indexes_tmp" "$views_tmp" "$routines_tmp"

echo "Deduplicación completada."