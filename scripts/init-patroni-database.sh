#!/bin/bash

# Script de inicialización automática para Patroni
# Este script se ejecuta cuando Patroni inicializa el cluster por primera vez

set -e

# Usar socket UNIX para autenticación "peer" como usuario postgres
export PGHOST=/var/run/postgresql
export PGUSER=postgres

echo "=== Iniciando configuración automática de base de datos Patroni ==="

# Esperar a que PostgreSQL esté listo (vía socket)
until pg_isready -h "$PGHOST" -p 5432 -U "$PGUSER"; do
  echo "Esperando a que PostgreSQL esté listo..."
  sleep 2
done

echo "PostgreSQL está listo. Iniciando configuración..."

# Crear la base de datos sasdatqbox si no existe (sin depender de sas_user)
psql -tc "SELECT 1 FROM pg_database WHERE datname = 'sasdatqbox'" | grep -q 1 || {
    echo "Creando base de datos sasdatqbox (owner postgres por ahora)..."
    psql -c "CREATE DATABASE sasdatqbox;"
    echo "Base de datos sasdatqbox creada exitosamente."
}

# Ejecutar el script de creación de esquemas y tablas como superusuario
if [ -f "/docker-entrypoint-initdb.d/create_pos_schema_and_tables.sql" ]; then
    echo "Ejecutando script de creación de esquemas y tablas..."
    psql -d sasdatqbox -f /docker-entrypoint-initdb.d/create_pos_schema_and_tables.sql
    echo "Esquemas y tablas creados exitosamente."
else
    echo "Advertencia: No se encontró el script de creación de esquemas."
fi

# Si existe el rol sas_user, asignar propiedad de la BD y otorgar privilegios
if psql -tc "SELECT 1 FROM pg_roles WHERE rolname = 'sas_user'" | grep -q 1; then
  echo "Asignando propiedad de la base de datos a sas_user..."
  psql -c "ALTER DATABASE sasdatqbox OWNER TO sas_user;"
  psql -d sasdatqbox -c "GRANT ALL PRIVILEGES ON SCHEMA public TO sas_user;"
  echo "Propiedad y privilegios asignados a sas_user."
else
  echo "Rol sas_user no existe aún; se mantiene owner postgres."
fi

# Verificar que las tablas se crearon correctamente
echo "Verificando tablas creadas:"
psql -d sasdatqbox -c "\\dt pos.*" || true

echo "=== Configuración automática completada exitosamente ==="