#!/bin/bash
# 🔄 Script para configurar pg_hba.conf para replicación bidireccional

echo "🔧 Configurando pg_hba.conf para replicación..."

# Configurar pg_hba.conf para postgres-local
docker exec postgres-local bash -c "
echo '# Configuración de replicación' >> /var/lib/postgresql/data/pg_hba.conf
echo 'host replication replication_user postgres-backup md5' >> /var/lib/postgresql/data/pg_hba.conf
echo 'host sasdatqbox replication_user postgres-backup md5' >> /var/lib/postgresql/data/pg_hba.conf
echo 'host all replication_user 0.0.0.0/0 md5' >> /var/lib/postgresql/data/pg_hba.conf
"

# Configurar pg_hba.conf para postgres-backup
docker exec postgres-backup bash -c "
echo '# Configuración de replicación' >> /var/lib/postgresql/data/pg_hba.conf
echo 'host replication replication_user postgres-local md5' >> /var/lib/postgresql/data/pg_hba.conf
echo 'host sasdatqbox replication_user postgres-local md5' >> /var/lib/postgresql/data/pg_hba.conf
echo 'host all replication_user 0.0.0.0/0 md5' >> /var/lib/postgresql/data/pg_hba.conf
"

echo "✅ Configuración de pg_hba.conf completada"
echo "🔄 Reiniciando servicios PostgreSQL..."

# Reiniciar ambos servicios para aplicar cambios
docker-compose -f docker-compose-ha.yml restart postgres postgres-backup

echo "✅ Servicios reiniciados"