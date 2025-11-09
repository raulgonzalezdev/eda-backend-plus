# Observabilidad en eda-backend-plus

Este documento resume qué hace cada servicio, cómo se conectan y cómo probar trazas/métricas/logs con OpenTelemetry y Elasticsearch/Kibana.

## Servicios principales

- `app1`, `app2`, `app3` (EDA Backend)
  - Spring Boot 3.1.5 con JWT.
  - Endpoints clave: `/auth/token`, `/events/payments`, `/events/transfers`, `/alerts`, `/alerts-db`, `/api/health`.
  - Persistencia en PostgreSQL (esquema `pos`).
  - Kafka Streams: lee `payments.events` y `transfers.events`, evalúa `amount >= threshold` y publica en `alerts.suspect`.
  - Consumidor `AlertsConsumer`: guarda alertas en `pos.alerts`.
  - Instrumentación: agente OpenTelemetry Java adjunto al arranque (ver `entrypoint.sh`).

- `nginx-load-balancer`
  - Balancea tráfico HTTP hacia `app1/app2/app3`.
  - Expuestos: `http://localhost:8080`.

- `kafka`, `kafka2`, `kafka3` + `zookeeper`
  - Cluster Kafka para topics `payments.events`, `transfers.events`, `alerts.suspect`.

- `debezium`
  - Conector PostgreSQL Outbox (CDC): lee `pos.outbox` y publica en Kafka por SMT `EventRouter` (route by `type`).
  - Configuración en `config/debezium-connector*.json`.
  - Conecta vía `haproxy:5000` al líder del cluster Patroni y usa usuario `replicator`.

- `patroni-master`, `patroni-replica1`, `patroni-replica2` + `haproxy-patroni`
  - Cluster PostgreSQL administrado por Patroni.
  - `haproxy:5000` (write) y `haproxy:5001` (read) enrutan a líder/replicas.
  - `wal_level=logical` habilitado para logical decoding.

- `apm-server`
  - Recibe OTLP (HTTP) del agente OTel y reenvía a Elasticsearch.

- `elasticsearch` + `kibana`
  - Almacenamiento y visualización.
  - Kibana UI en `http://localhost:5601/`.

## Flujo de eventos (end-to-end)

1. Cliente llama `POST /events/payments` o `POST /events/transfers` (JWT requerido).
2. Servicio guarda el evento en `pos.payments`/`pos.transfers` y en `pos.outbox`.
3. Debezium Outbox publica el `payload` en Kafka (`payments.events`/`transfers.events`) usando `type`.
4. Kafka Streams (servicio backend) combina pagos y transferencias, filtra por `amount >= threshold` y publica en `alerts.suspect`.
5. `AlertsConsumer` lee `alerts.suspect` y persiste en `pos.alerts`.
6. Cliente consulta `GET /alerts` (lectura directa de Kafka con timeout) o `GET /alerts-db` (persistidos).

## Observabilidad (OTel)

- Agente Java se adjunta en `entrypoint.sh` mediante `-javaagent:/opt/otel/opentelemetry-javaagent.jar`.
- Variables relevantes:
  - `OTEL_SERVICE_NAME` (por defecto `eda-backend`).
  - `OTEL_EXPORTER_OTLP_ENDPOINT` (por defecto `http://apm-server:8200`).
  - `OTEL_EXPORTER_OTLP_PROTOCOL` (por defecto `http/protobuf`).
  - Exporters activos: traces, metrics, logs.

### Ver trazas

1. Genera tráfico con `./scripts/observability_smoke.ps1` (usa `http://localhost:8080`).
2. Abre `http://localhost:5601/` → APM → Services → `eda-backend`.
3. En “Transactions”, filtra por endpoints (`/events/payments`, `/auth/token`, etc.).
4. En “Service map” observa dependencias (HTTP → DB → Kafka) si hay suficiente tráfico.

### Ver índices en Elasticsearch

Consulta `http://localhost:9200/_cat/indices?v` para ver índices disponibles. Con APM y tráfico, se crearán índices gestionados por Elastic.

## JWT y seguridad

- `GET /auth/token` genera un JWT HS256 con `app.jwt.secret`.
- `SecurityConfig` permite sin JWT: `/api/health`, `/auth/*`, `/swagger-ui/**`.
- Otros endpoints requieren header `Authorization: Bearer <token>`.

## Problemas comunes y soluciones

- 502 en NGINX: backend reiniciando (ver logs), upstream sin salud, o puertos incorrectos.
- Debezium error “recovery”: conectar a líder vía HAProxy write-port.
- Debezium “walsender” error: usar usuario `replicator` o dar rol `REPLICATION` al usuario.
- JSONB en JPA: usar `@JdbcTypeCode(SqlTypes.JSON)` para columnas `jsonb`.

## Cómo explicarlo en entrevista

- Patrón Outbox: desacopla escritura a BD del publish a Kafka; Debezium realiza CDC y enruta eventos.
- Kafka Streams: procesa en tiempo real, aplica reglas (umbral) y emite alertas.
- Observabilidad: agente OTel captura trazas/métricas/logs; APM en Kibana permite ver latencias, errores y dependencias.
- Resiliencia de base de datos: Patroni + HAProxy ofrecen líder/replicas y failover automático.

## Comandos rápidos

- Reconstruir apps: `docker compose up -d --no-deps --build app1 app2 app3`
- Ver estado Debezium: `curl http://localhost:8083/connectors/outbox-connector/status`
- Probar tráfico: `pwsh ./scripts/observability_smoke.ps1 -Count 20`

---

## Notas y credenciales (dev)

Esta sección documenta los cambios aplicados para que APM funcione con seguridad habilitada y Fleet/Integrations instaladas.

- Elasticsearch (docker-compose):
  - `xpack.security.enabled=true`
  - `ELASTIC_PASSWORD=changeme`
  - `xpack.apm_data.enabled=true` (instala plantillas APM sin necesidad de Fleet en entornos aislados)
- Kibana (docker-compose):
  - `ELASTICSEARCH_HOSTS=http://elasticsearch:9200`
  - `ELASTICSEARCH_USERNAME=kibana_system`
  - `ELASTICSEARCH_PASSWORD=changemeKBN`
  - Inicio de sesión en UI: `elastic` / `changeme`
- APM Server (`config/apm-server.yml`):
  - `output.elasticsearch.hosts: ["http://elasticsearch:9200"]`
  - `output.elasticsearch.protocol: "http"`
  - Credenciales de escritura (usuario creado para dev):
    - `output.elasticsearch.username: "apm_writer"`
    - `output.elasticsearch.password: "changemeAPMWRITER"`

### Pasos aplicados (resumen)

1. Habilitar seguridad en Elasticsearch y configurar Kibana con `kibana_system`.
2. Inicializar Fleet e instalar la integración APM v8.14.0 vía API.
3. Resolver errores de autenticación de APM Server (401) y permisos de `auto_create` creando:
   - Rol `apm_writer_role` con privilegios `auto_configure`, `create_index`, `write`, `create_doc` sobre `logs-apm*`, `metrics-apm*`, `traces-apm*`.
   - Usuario `apm_writer` con contraseña `changemeAPMWRITER` y asignarlo al rol.
4. Configurar `apm-server.yml` para usar `apm_writer` y reiniciar el servicio.
5. Verificar que APM Server maneja `POST /v1/traces|metrics|logs` con 200 y que existen data streams.

### Verificaciones útiles

- Estado Kibana: `GET http://localhost:5601/api/status`
- Data streams: `GET http://localhost:9200/_data_stream?pretty` (usar Basic `elastic:changeme`)
- Índices por prefijo:
  - `GET http://localhost:9200/_cat/indices/logs-apm*?v`
  - `GET http://localhost:9200/_cat/indices/metrics-apm*?v`
  - `GET http://localhost:9200/_cat/indices/traces-apm*?v`
- Logs APM Server: `docker compose logs --tail=200 apm-server`

Importante: estas credenciales son solo para desarrollo local. En producción, usar Service Accounts o API Keys con alcance mínimo, TLS, y rotación de secretos.