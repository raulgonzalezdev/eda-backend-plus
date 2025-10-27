#!/bin/bash

# Script de inicialización automática para Patroni
# Este script se ejecuta cuando Patroni inicializa el cluster por primera vez

set -e

echo "=== Iniciando configuración automática de base de datos Patroni ==="

# Esperar a que PostgreSQL esté listo
until pg_isready -h localhost -p 5432 -U postgres; do
  echo "Esperando a que PostgreSQL esté listo..."
  sleep 2
done

echo "PostgreSQL está listo. Iniciando configuración..."

# Crear la base de datos sasdatqbox si no existe
psql -U postgres -tc "SELECT 1 FROM pg_database WHERE datname = 'sasdatqbox'" | grep -q 1 || {
    echo "Creando base de datos sasdatqbox..."
    psql -U postgres -c "CREATE DATABASE sasdatqbox OWNER sas_user;"
    echo "Base de datos sasdatqbox creada exitosamente."
}

# Ejecutar el script de creación de esquemas y tablas
if [ -f "/docker-entrypoint-initdb.d/create_pos_schema_and_tables.sql" ]; then
    echo "Ejecutando script de creación de esquemas y tablas..."
    psql -U sas_user -d sasdatqbox -f /docker-entrypoint-initdb.d/create_pos_schema_and_tables.sql
    echo "Esquemas y tablas creados exitosamente."
else
    echo "Advertencia: No se encontró el script de creación de esquemas."
fi

# Verificar que las tablas se crearon correctamente
echo "Verificando tablas creadas:"
psql -U sas_user -d sasdatqbox -c "\dt pos.*"

echo "=== Configuración automática completada exitosamente ==="