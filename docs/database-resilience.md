# Resiliencia de Base de Datos - Cluster Patroni + etcd

## Descripción General

Este documento describe la implementación de alta disponibilidad para PostgreSQL utilizando Patroni como gestor de cluster y etcd como almacén de configuración distribuida. Esta solución proporciona failover automático, replicación streaming y recuperación automática de nodos.

## Arquitectura del Cluster

### Componentes Principales

1. **etcd**: Almacén de configuración distribuida
   - Puerto: 2379 (cliente), 2380 (peer)
   - Función: Coordinación del cluster y almacenamiento de metadatos

2. **Patroni Nodes**:
   - **patroni-master**: Nodo PostgreSQL (puerto 5432)
   - **patroni-replica1**: Nodo PostgreSQL (puerto 5433) 
   - **patroni-replica2**: Nodo PostgreSQL (puerto 5434)
   - API REST: Puerto 8008 en cada nodo

3. **HAProxy**: Load balancer y proxy de conexiones
   - Puerto 5000: Conexiones de escritura (master)
   - Puerto 5001: Conexiones de lectura (replicas)
   - Puerto 7000: Estadísticas y monitoreo

4. **Aplicaciones Backend**: 3 instancias conectadas al cluster
   - app1: Puerto 9084
   - app2: Puerto 9085  
   - app3: Puerto 9086

## Configuración de Patroni

### Archivo de Configuración Principal

```yaml
scope: postgres-cluster
namespace: /db/
name: ${PATRONI_NAME}

restapi:
  listen: 0.0.0.0:8008
  connect_address: ${PATRONI_NAME}:8008

etcd:
  hosts: etcd:2379

bootstrap:
  dcs:
    ttl: 30
    loop_wait: 10
    retry_timeout: 30
    maximum_lag_on_failover: 1048576
    master_start_timeout: 300
    synchronous_mode: false
    postgresql:
      use_pg_rewind: true
      use_slots: true
      parameters:
        wal_level: replica
        hot_standby: "on"
        wal_keep_segments: 8
        max_wal_senders: 10
        max_replication_slots: 10
        wal_log_hints: "on"
        archive_mode: "on"
        archive_timeout: 1800s
        archive_command: mkdir -p ../wal_archive && test ! -f ../wal_archive/%f && cp %p ../wal_archive/%f
        recovery_conf:
          restore_command: cp ../wal_archive/%f %p

  initdb:
  - encoding: UTF8
  - data-checksums

  pg_hba:
  - host replication replicator 127.0.0.1/32 md5
  - host replication replicator patroni-master/32 md5
  - host replication replicator patroni-replica1/32 md5
  - host replication replicator patroni-replica2/32 md5
  - host all all 0.0.0.0/0 md5

  users:
    admin:
      password: admin
      options:
        - createrole
        - createdb

postgresql:
  listen: 0.0.0.0:5432
  connect_address: ${PATRONI_NAME}:5432
  data_dir: /var/lib/postgresql/data
  bin_dir: /usr/lib/postgresql/15/bin
  pgpass: /tmp/pgpass
  authentication:
    replication:
      username: replicator
      password: replicator_password
    superuser:
      username: postgres
      password: postgres_password
  parameters:
    unix_socket_directories: '.'

tags:
    nofailover: false
    noloadbalance: false
    clonefrom: false
    nosync: false
```

### Script de Inicialización

El script `start-patroni.sh` maneja la inicialización correcta de permisos:

```bash
#!/bin/bash
set -e

# Crear directorio de datos si no existe
mkdir -p /var/lib/postgresql/data

# Establecer permisos correctos
chown postgres:postgres /var/lib/postgresql/data
chmod 700 /var/lib/postgresql/data

# Iniciar Patroni
exec patroni /etc/patroni/patroni.yml
```

## Configuración de HAProxy

### Balanceador de Carga

```haproxy
global
    maxconn 100

defaults
    log global
    mode tcp
    retries 2
    timeout client 30m
    timeout connect 4s
    timeout server 30m
    timeout check 5s

listen stats
    mode http
    bind *:7000
    stats enable
    stats uri /stats
    stats refresh 1s

listen postgres_master
    bind *:5000
    option httpchk
    http-check expect status 200
    default-server inter 3s fall 3 rise 2 on-marked-down shutdown-sessions
    server patroni-master patroni-master:5432 maxconn 100 check port 8008 check-path /master
    server patroni-replica1 patroni-replica1:5432 maxconn 100 check port 8008 check-path /master
    server patroni-replica2 patroni-replica2:5432 maxconn 100 check port 8008 check-path /master

listen postgres_replicas
    bind *:5001
    option httpchk
    http-check expect status 200
    default-server inter 3s fall 3 rise 2 on-marked-down shutdown-sessions
    server patroni-master patroni-master:5432 maxconn 100 check port 8008 check-path /replica
    server patroni-replica1 patroni-replica1:5432 maxconn 100 check port 8008 check-path /replica
    server patroni-replica2 patroni-replica2:5432 maxconn 100 check port 8008 check-path /replica
```

## Funcionalidades de Alta Disponibilidad

### 1. Detección Automática de Fallos

- **TTL (Time To Live)**: 30 segundos
- **Loop Wait**: 10 segundos para verificaciones periódicas
- **Retry Timeout**: 30 segundos para reintentos

### 2. Failover Automático

Cuando el nodo master falla:
1. etcd detecta la pérdida del lease del master
2. Los nodos replica compiten por convertirse en nuevo master
3. El nodo con menor lag se promociona automáticamente
4. HAProxy redirige el tráfico al nuevo master
5. Las aplicaciones continúan funcionando sin interrupción

### 3. Replicación Streaming

- **Modo**: Asíncrono por defecto
- **WAL Senders**: Máximo 10 conexiones simultáneas
- **Replication Slots**: Hasta 10 slots para garantizar retención de WAL
- **WAL Keep Segments**: 8 segmentos mínimos retenidos

### 4. Recuperación Automática

Cuando un nodo recuperado se reintegra:
1. Patroni detecta el nodo disponible
2. Se sincroniza automáticamente con el master actual
3. Se reintegra como replica sin intervención manual
4. HAProxy lo incluye automáticamente en el pool de replicas

## Pruebas de Failover

### Script de Pruebas Automatizadas

Se incluye el script `test-patroni-failover-simple.ps1` que:

1. **Identifica el master actual** mediante API REST
2. **Verifica el estado de las aplicaciones** antes del failover
3. **Simula un fallo** deteniendo el contenedor master
4. **Espera el failover automático** (30 segundos)
5. **Verifica el nuevo master** y continuidad del servicio
6. **Recupera el nodo original** y verifica reintegración
7. **Genera un reporte completo** del proceso

### Resultados de Pruebas

**Última Prueba Ejecutada:**
- Master inicial: `patroni-replica1`
- Failover: **EXITOSO** 
- Nuevo Master: `patroni-replica2`
- Tiempo de failover: ~30 segundos
- Recuperación: **COMPLETADA**

## Monitoreo y Diagnóstico

### API REST de Patroni

Cada nodo expone endpoints en el puerto 8008:

- `GET /cluster`: Estado completo del cluster
- `GET /master`: Información del nodo master
- `GET /replica`: Información de nodos replica
- `GET /health`: Estado de salud del nodo

### Comandos de Diagnóstico

```bash
# Verificar estado del cluster
curl -s http://localhost:8008/cluster | jq

# Verificar replicación desde el master
docker exec patroni-replica1 psql -U postgres -c "SELECT application_name, state, sync_state FROM pg_stat_replication;"

# Verificar estadísticas de HAProxy
curl -s http://localhost:7000/stats

# Verificar logs de Patroni
docker logs patroni-master
docker logs patroni-replica1
docker logs patroni-replica2
```

### Métricas Clave

1. **Lag de Replicación**: Diferencia en bytes entre master y replicas
2. **Estado de Conexiones**: Número de conexiones activas por nodo
3. **Tiempo de Respuesta**: Latencia de las consultas
4. **Disponibilidad**: Porcentaje de tiempo operativo del cluster

## Configuración de Aplicaciones

### Cadenas de Conexión

```properties
# Para operaciones de escritura (master)
spring.datasource.write.url=jdbc:postgresql://localhost:5000/eda_backend
spring.datasource.write.username=postgres
spring.datasource.write.password=postgres_password

# Para operaciones de lectura (replicas)
spring.datasource.read.url=jdbc:postgresql://localhost:5001/eda_backend
spring.datasource.read.username=postgres
spring.datasource.read.password=postgres_password
```

### Manejo de Reconexiones

Las aplicaciones deben implementar:
- **Connection pooling** con validación de conexiones
- **Retry logic** para reconexiones automáticas
- **Circuit breaker** para fallos temporales
- **Health checks** para monitoreo proactivo

## Backup y Recuperación

### Estrategia de Backup

1. **WAL Archiving**: Archivado continuo de logs de transacciones
2. **Base Backups**: Respaldos completos programados
3. **Point-in-Time Recovery**: Recuperación a cualquier momento específico

### Comandos de Backup

```bash
# Backup completo
docker exec patroni-master pg_basebackup -U postgres -D /backup/base -Ft -z -P

# Verificar archivos WAL
docker exec patroni-master ls -la /var/lib/postgresql/wal_archive/
```

## Troubleshooting

### Problemas Comunes

1. **Split-brain**: Verificar conectividad con etcd
2. **Lag excesivo**: Revisar recursos de red y disco
3. **Failover lento**: Ajustar parámetros de TTL y timeouts
4. **Conexiones rechazadas**: Verificar configuración de HAProxy

### Logs Importantes

```bash
# Logs de Patroni
docker logs patroni-master 2>&1 | grep -E "(ERROR|FATAL|WARNING)"

# Logs de etcd
docker logs etcd 2>&1 | grep -E "(ERROR|FATAL|WARNING)"

# Logs de HAProxy
docker logs haproxy-patroni 2>&1 | grep -E "(ERROR|FATAL|WARNING)"
```

## Conclusiones

La implementación de Patroni + etcd proporciona:

✅ **Alta Disponibilidad**: Failover automático en ~30 segundos  
✅ **Escalabilidad**: Múltiples replicas para distribución de carga  
✅ **Consistencia**: Replicación streaming confiable  
✅ **Monitoreo**: APIs REST y métricas detalladas  
✅ **Automatización**: Recuperación sin intervención manual  

Esta solución garantiza la continuidad del servicio y la integridad de los datos en el sistema EDA Backend Plus.