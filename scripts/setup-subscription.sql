-- 🔄 Script de configuración de suscripción para postgres-backup
-- Este script configura postgres-backup como suscriptor de postgres-local

-- ========================================
-- CONFIGURACIÓN DE SUSCRIPCIÓN
-- ========================================

-- Crear suscripción a postgres-local
CREATE SUBSCRIPTION postgres_local_sub
CONNECTION 'host=postgres-local port=5432 dbname=sasdatqbox user=replication_user password=repl_pass_2024!'
PUBLICATION all_tables_pub
WITH (
    enabled = true,
    create_slot = false,
    slot_name = 'postgres_backup_slot',
    synchronous_commit = 'off',
    connect = true
);

-- ========================================
-- VERIFICACIÓN DE SUSCRIPCIÓN
-- ========================================

-- Verificar que la suscripción fue creada
SELECT subname, subenabled, subconninfo FROM pg_subscription;

-- Verificar el estado de la replicación
SELECT 
    s.subname,
    s.subenabled,
    sr.srsubstate,
    sr.srrelid::regclass as table_name
FROM pg_subscription s
LEFT JOIN pg_subscription_rel sr ON s.oid = sr.srsubid;

-- ========================================
-- MONITOREO DE REPLICACIÓN
-- ========================================

-- Query para monitorear el lag de replicación
SELECT 
    client_addr,
    client_hostname,
    client_port,
    state,
    sent_lsn,
    write_lsn,
    flush_lsn,
    replay_lsn,
    write_lag,
    flush_lag,
    replay_lag
FROM pg_stat_replication;

-- Verificar estadísticas de suscripción
SELECT 
    subname,
    pid,
    received_lsn,
    last_msg_send_time,
    last_msg_receipt_time,
    latest_end_lsn,
    latest_end_time
FROM pg_stat_subscription;