#!/bin/bash

function usage_mode() {
  echo "Uso correcto: getdb <type> <schema> <object>"
  echo "  type: -p (procedure), -f (function), -v (view), -t (table)"
  echo "  ejemplo: getdb -p pos mi_procedimiento"
}

type=$1
schema=$2
object=$3

if [[ $# -ne 3 ]]; then
  usage_mode; exit 1
fi
if [[ -z $type ]]; then echo "Type not specified"; usage_mode; exit 1; fi
if [[ -z $schema ]]; then echo "schema not specified"; usage_mode; exit 1; fi
if [[ -z $object ]]; then echo "Object not specified"; usage_mode; exit 1; fi

case $type in
  -p) type="PROCEDURES" ;;
  -f) type="FUNCTIONS" ;;
  -v) type="VIEWS" ;;
  -t) type="TABLES" ;;
  *) echo "Type $type not supported"; usage_mode; exit 1 ;;
esac

# Cargar credenciales desde .env.local si existe
if [[ -f ./.env.local ]]; then
  # Exportar solo las variables relevantes
  export $(grep -E '^(DB_HOST|DB_PORT|DB_NAME|DB_USER|DB_PASSWORD|DOCKER_NETWORK|USE_DOCKER)=' ./.env.local | xargs)
fi

DB_HOST=${DB_HOST:-127.0.0.1}
DB_PORT=${DB_PORT:-5432}
DB_NAME=${DB_NAME:-sasdatqbox}
DB_USER=${DB_USER:-sas_user}
DB_PASSWORD=${DB_PASSWORD:-}
DOCKER_NETWORK=${DOCKER_NETWORK:-}
USE_DOCKER=${USE_DOCKER:-true}
DB_CONTAINER_NAME=${DB_CONTAINER_NAME:-}

playbook="ansible/playbooks/get_pg_object.yml"

mkdir -p "./db/$schema/$type/$object"
echo "Descargando $type: $schema.$object en ./db/$schema/$type/$object"

ansible-playbook "$playbook" \
  --extra-vars="current_path=$(pwd) type=$type schema=$schema object=$object db_host=$DB_HOST db_port=$DB_PORT db_name=$DB_NAME db_user=$DB_USER db_password=$DB_PASSWORD use_docker=$USE_DOCKER docker_network=$DOCKER_NETWORK db_container_name=$DB_CONTAINER_NAME"

if [[ $? -ne 0 ]]; then
  echo "Ups... hubo errores descargando $schema.$object"
  exit 1
fi

# Normalizar finales de línea si dos2unix está disponible
if command -v dos2unix >/dev/null 2>&1; then
  dos2unix $(find ./db/$schema/$type/$object/ -type f -exec grep -Iq . {} \; -print)
fi

echo "$schema.$object descargado"