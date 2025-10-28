#!/usr/bin/env sh
set -eu

# Revisa archivos de migración Flyway en un directorio y reporta:
# - Cabecera con SET LOCAL search_path al esquema esperado
# - Patrones potencialmente peligrosos (DROP/TRUNCATE/ALTER DROP COLUMN)
# - UPDATE/DELETE sin WHERE (heurístico)
# - Uso de BEGIN/COMMIT (no recomendado en Flyway SQL)
# - CREATE TABLE sin esquema explícito
# - CREATE INDEX sin IF NOT EXISTS
# - FOREIGN KEY sin REFERENCES <schema>.
# Inspirado en prácticas recomendadas de revisión previa a migraciones.

MIG_DIR="${MIG_DIR:-src/main/resources/db/migration}"
SCHEMA="${SCHEMA:-pos}"
EXIT_ON_WARN="${EXIT_ON_WARN:-0}"

if [ ! -d "$MIG_DIR" ]; then
  echo "ERROR: Directorio de migraciones no existe: $MIG_DIR" >&2
  exit 1
fi

warn_total=0

echo "== Revisando migraciones en $MIG_DIR (schema=$SCHEMA) =="
for f in "$MIG_DIR"/V*__*.sql; do
  [ -f "$f" ] || continue
  fname="$(basename "$f")"
  content_tmp="$(mktemp)"
  tr -d '\r' < "$f" > "$content_tmp"

  file_warns=0
  echo "\n-- $fname"

  # Cabecera search_path
  if ! grep -q "^SET LOCAL search_path TO ${SCHEMA};" "$content_tmp"; then
    echo "[WARN] Falta 'SET LOCAL search_path TO ${SCHEMA};'"
    file_warns=$((file_warns+1))
  fi

  # Placeholders sin resolver (${...})
  awk 'match($0,/\$\{[^}]+\}/){print NR ": " $0}' "$content_tmp" || true
  if grep -q -E '\$\{[^}]+\}' "$content_tmp"; then
    echo "[WARN] Posibles placeholders sin resolver detectados (\${...}); revisa configuración de Flyway"
    file_warns=$((file_warns+1))
  fi

  # Patrones peligrosos
  grep -n -E '\bDROP[[:space:]]+TABLE\b|\bDROP[[:space:]]+INDEX\b|\bTRUNCATE[[:space:]]+TABLE\b|\bALTER[[:space:]]+TABLE\b[^;]*\bDROP[[:space:]]+COLUMN\b' "$content_tmp" || true
  if grep -q -E '\bDROP[[:space:]]+TABLE\b|\bDROP[[:space:]]+INDEX\b|\bTRUNCATE[[:space:]]+TABLE\b|\bALTER[[:space:]]+TABLE\b[^;]*\bDROP[[:space:]]+COLUMN\b' "$content_tmp"; then
    echo "[WARN] Se detectaron operaciones potencialmente destructivas (ver líneas arriba)"
    file_warns=$((file_warns+1))
  fi

  # UPDATE sin WHERE (heurístico)
  awk 'BEGIN{IGNORECASE=1} /UPDATE[[:space:]]+.*SET/ && !/WHERE/ {print NR ": " $0}' "$content_tmp" || true
  if awk 'BEGIN{IGNORECASE=1} /UPDATE[[:space:]]+.*SET/ && !/WHERE/ {exit 0} END{exit 1}' "$content_tmp"; then
    echo "[WARN] UPDATE sin WHERE detectado (heurístico)"
    file_warns=$((file_warns+1))
  fi

  # DELETE sin WHERE (heurístico)
  awk 'BEGIN{IGNORECASE=1} /DELETE[[:space:]]+FROM/ && !/WHERE/ {print NR ": " $0}' "$content_tmp" || true
  if awk 'BEGIN{IGNORECASE=1} /DELETE[[:space:]]+FROM/ && !/WHERE/ {exit 0} END{exit 1}' "$content_tmp"; then
    echo "[WARN] DELETE sin WHERE detectado (heurístico)"
    file_warns=$((file_warns+1))
  fi

  # BEGIN/COMMIT transaccionales (con punto y coma). No aplicar a BEGIN de DO $$ ... $$
  if grep -q -E '^[[:space:]]*BEGIN[[:space:]]*;[[:space:]]*$|^[[:space:]]*COMMIT[[:space:]]*;[[:space:]]*$|^[[:space:]]*ROLLBACK[[:space:]]*;[[:space:]]*$|^[[:space:]]*START[[:space:]]+TRANSACTION[[:space:]]*;[[:space:]]*$' "$content_tmp"; then
    grep -n -E '^[[:space:]]*BEGIN[[:space:]]*;[[:space:]]*$|^[[:space:]]*COMMIT[[:space:]]*;[[:space:]]*$|^[[:space:]]*ROLLBACK[[:space:]]*;[[:space:]]*$|^[[:space:]]*START[[:space:]]+TRANSACTION[[:space:]]*;[[:space:]]*$' "$content_tmp"
    echo "[WARN] BEGIN/COMMIT/ROLLBACK/START TRANSACTION detectados; Flyway gestiona transacciones"
    file_warns=$((file_warns+1))
  fi

  # CREATE TABLE sin esquema
  awk -v s="$SCHEMA" 'BEGIN{IGNORECASE=1} /CREATE[[:space:]]+TABLE/ && $0 !~ s"[.]" {print NR ": " $0}' "$content_tmp" || true
  if awk -v s="$SCHEMA" 'BEGIN{IGNORECASE=1} /CREATE[[:space:]]+TABLE/ && $0 !~ s"[.]" {exit 0} END{exit 1}' "$content_tmp"; then
    echo "[WARN] CREATE TABLE sin esquema explícito"
    file_warns=$((file_warns+1))
  fi

  # CREATE INDEX sin IF NOT EXISTS
  awk 'BEGIN{IGNORECASE=1} /CREATE[[:space:]]+(UNIQUE[[:space:]]+)?INDEX/ && $0 !~ /IF[[:space:]]+NOT[[:space:]]+EXISTS/ {print NR ": " $0}' "$content_tmp" || true
  if awk 'BEGIN{IGNORECASE=1} /CREATE[[:space:]]+(UNIQUE[[:space:]]+)?INDEX/ && $0 !~ /IF[[:space:]]+NOT[[:space:]]+EXISTS/ {exit 0} END{exit 1}' "$content_tmp"; then
    echo "[WARN] CREATE INDEX sin IF NOT EXISTS"
    file_warns=$((file_warns+1))
  fi

  # FOREIGN KEY sin REFERENCES <schema>.
  awk -v s="$SCHEMA" 'BEGIN{IGNORECASE=1; re="REFERENCES[[:space:]]+\"?" s "[.]"} /FOREIGN[[:space:]]+KEY/ && $0 !~ re {print NR ": " $0}' "$content_tmp" || true
  if awk -v s="$SCHEMA" 'BEGIN{IGNORECASE=1; re="REFERENCES[[:space:]]+\"?" s "[.]"} /FOREIGN[[:space:]]+KEY/ && $0 !~ re {exit 0} END{exit 1}' "$content_tmp"; then
    echo "[WARN] FOREIGN KEY sin REFERENCES con esquema explícito ($SCHEMA)"
    file_warns=$((file_warns+1))
  fi

  rm -f "$content_tmp"
  warn_total=$((warn_total+file_warns))
  if [ "$file_warns" -eq 0 ]; then
    echo "[OK] Sin hallazgos"
  fi
done

echo "\n== Resumen =="
echo "Total de advertencias: $warn_total"
if [ "$EXIT_ON_WARN" = "1" ] && [ "$warn_total" -gt 0 ]; then
  exit 2
fi
exit 0


