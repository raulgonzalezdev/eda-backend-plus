-- 🔄 Script de configuración para replicación bidireccional PostgreSQL
-- Este script configura la replicación entre postgres-local y postgres-backup

-- ========================================
-- CONFIGURACIÓN DEL USUARIO DE REPLICACIÓN
-- ========================================

-- Crear usuario de replicación con permisos necesarios
CREATE USER replication_user WITH REPLICATION ENCRYPTED PASSWORD 'repl_pass_2024!';

-- Otorgar permisos necesarios
GRANT CONNECT ON DATABASE sasdatqbox TO replication_user;
GRANT USAGE ON SCHEMA public TO replication_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO replication_user;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO replication_user;

-- Configurar permisos para futuras tablas
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO replication_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON SEQUENCES TO replication_user;

-- ========================================
-- CONFIGURACIÓN DE REPLICATION SLOTS
-- ========================================

-- Crear slot de replicación para postgres-backup
SELECT pg_create_logical_replication_slot('postgres_backup_slot', 'pgoutput');

-- Verificar que el slot fue creado
SELECT slot_name, plugin, slot_type, active FROM pg_replication_slots;

-- ========================================
-- CONFIGURACIÓN DE PUBLICACIONES
-- ========================================

-- Crear publicación para todas las tablas
CREATE PUBLICATION all_tables_pub FOR ALL TABLES;

-- Verificar la publicación
SELECT pubname, puballtables FROM pg_publication;

-- ========================================
-- INFORMACIÓN DE CONFIGURACIÓN
-- ========================================

-- Mostrar configuración actual de WAL
SHOW wal_level;
SHOW max_wal_senders;
SHOW max_replication_slots;

-- Mostrar información del servidor
SELECT version();