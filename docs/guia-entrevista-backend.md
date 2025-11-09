# Guía de Entrevista (Backend Engineer) – eda-backend-plus

Este documento es un resumen práctico y en español para explicar, con seguridad, cómo funciona la plataforma y responder preguntas típicas del rol Backend Engineer (Spring/Spring Boot + Kafka Streams/Flink).

## 1. Ideas fuerza (30–60 segundos)
- Arquitectura EDA con Kafka: productores → eventos → procesamiento en streaming → consumidores y persistencia.
- Patrón Outbox + Debezium: consistencia entre BD y Kafka; evita “dual‑write”.
- Observabilidad con OpenTelemetry → APM Server → Kibana (servicio `eda-backend`).
- Alta disponibilidad: NGINX frente a 3 instancias; BD con Patroni + HAProxy (líder/replicas, failover).

## 2. Flujo end‑to‑end (cómo lo cuentas)
1. `POST /events/payments | /events/transfers` persiste en PostgreSQL y registra **outbox** en la misma transacción.
2. Debezium (CDC) detecta el registro en WAL y publica en Kafka (`payments.events` / `transfers.events`).
3. Kafka Streams aplica reglas (umbral) y emite **alertas** a `alerts.suspect`.
4. `AlertsConsumer` persiste en `pos.alerts` (idempotente/UPSERT).
5. APIs: `GET /alerts` (lee de Kafka con timeout) y `GET /alerts-db` (persistidos).

Referencias: `docs/Metodologia.md`, `docs/observabilidad-overview.md`, `specs/openapi.yaml`, `specs/asyncapi.yaml`.

## 3. Kafka – puntos clave
- Claves y particiones: orden por entidad y paralelismo. Escalado por **consumer groups**.
- Exactly‑once en Streams: transacciones productor + commit de offset; sinks idempotentes.
- Lag: `kafka-consumer-groups --describe --group alerts-persist-group` y escalado/KEDA.

## 4. Spring / Spring Boot
- Capas: Controller → Service → Repository → Model; configuración por variables (12‑Factor). 
- JSONB con `@JdbcTypeCode(SqlTypes.JSON)`.
- Contratos: `OpenAPI` (REST) y `AsyncAPI` (eventos Kafka).

## 5. Patrón Outbox (por qué y cómo)
- Garantiza que si BD confirma, el evento se publica (vía Debezium). 
- Evita publicar dentro de la transacción de negocio. Tolerancia a caídas y reintentos.

## 6. Observabilidad (OTel + APM)
- Agente Java OTel adjunto (`-javaagent`) exporta traces/métricas/logs.
- APM Server recibe por OTLP; Kibana muestra el servicio **eda-backend**.
- Data streams: `traces-apm*`, `metrics-apm*`, `logs-apm*`.
- Verificación: `GET http://localhost:5601/api/status`, `GET http://localhost:9200/_data_stream?pretty`.

Notas y credenciales dev: ver `docs/observability-overview.md` (sección “Notas y credenciales”).

## 7. Alta disponibilidad y balanceo
- NGINX (least_conn, health checks) ante 3 instancias.
- BD con Patroni + HAProxy: puertos 5000 (write), 5001 (read), failover automático.

## 8. Seguridad
- JWT para endpoints; exclusiones: `/api/health`, `/auth/*`, `/swagger-ui/**`.
- Producción: OAuth2/OIDC, scopes/roles y rotación de secretos.

## 9. Kubernetes/Openshift (deploy y escalado)
- Charts Helm (`charts/eda-backend`), probes de salud, HPA. 
- KEDA para escalar consumidores según lag de Kafka.

## 10. Testing y calidad
- Unit tests en Services y repos; TopologyTestDriver para Streams. 
- Contract tests contra `OpenAPI/AsyncAPI`; fixtures para ventanas.

## 11. Performance y depuración
- Métricas: latencias p95, throughput, lag, GC, DB pool. 
- Optimización: batching, compresión, `max.poll.records`, índices en `pos.alerts`.

## 12. Preguntas típicas y respuestas modelo
- ¿Cómo garantizas consistencia BD→Kafka? 
  - Outbox + Debezium (CDC). Transacción local; publicación fuera de la transacción por lector WAL; idempotencia en sinks.
- ¿Qué harías si aumenta el lag del grupo `alerts-persist-group`? 
  - Revisar errores/logs; escalar consumidores (réplicas); tuning de `max.poll.interval.ms`/`max.poll.records`; optimizar persistencia; considerar backpressure.
- ¿Qué windows usarías para fraude? 
  - Sliding 5 min con event‑time; agregación por `accountId`; emitir alerta si suma > umbral o patrón sospechoso; DLQ para payload inválido.
- ¿Cómo asegurar “exactly‑once” en Streams? 
  - `processing.guarantee=exactly_once_v2`, transacciones, idempotencia en BD.
- ¿Cómo instrumentaste APM en dev? 
  - Agente OTel, APM Server con seguridad y Fleet; credenciales `apm_writer` con permisos `auto_configure/create_index/write/create_doc`; verificación de data streams.

## 12 bis. Banco de preguntas y respuestas (organizado por bloque)

### Arquitectura EDA
- ¿Qué problema resuelve una arquitectura basada en eventos frente a una arquitectura clásica por llamadas síncronas?
  - Desacopla productores y consumidores, reduce dependencia temporal, permite escalar lectores de forma independiente y habilita reacciones en tiempo real (suscripción/streaming) con tolerancia a fallos mejor distribuida.
- ¿Cómo explicas el flujo end‑to‑end de tu plataforma?
  - `POST /events/*` persiste en BD y outbox → Debezium publica el evento en Kafka → Kafka Streams procesa (umbral) → emite a `alerts.suspect` → `AlertsConsumer` persiste en `pos.alerts` → expongo `GET /alerts` (Kafka directo) y `GET /alerts-db` (persistidos).
- ¿Cómo garantizas consistencia entre escritura en BD y publicación en Kafka?
  - Patrón Outbox + CDC (Debezium): la app escribe entidad + outbox en una misma transacción local; Debezium lee el WAL y publica en Kafka. Evita “dual‑write” no atómico y recupera tras caídas.

### Kafka Fundamentals
- ¿Cuándo usas particiones y claves en Kafka?
  - Para paralelismo y orden por clave. Particiones permiten escalar consumidores; claves garantizan orden por entidad (ej. `accountId`).
- ¿Qué implica “exactly‑once” en Kafka Streams?
  - Transacciones de productor + commit de offsets atómico. Activo `processing.guarantee=exactly_once_v2` y diseño idempotente del lado de sinks.
- ¿Cómo gestionas el “consumer group” y el lag?
  - Cada servicio usa su `group-id` (por ejemplo “alerts-persist-group”) y monitorizo lag con `kafka-consumer-groups --describe`. Cuando hay lag, escalo instancias u optimizo la lógica.

### Kafka Streams/Flink
- ¿Cómo modelas el pipeline de alertas?
  - Origen: `payments.events`, `transfers.events`. Joins/repartitions si aplica; filtro por umbral (ej. `amount >= ALERT_THRESHOLD`) y publicamos en `alerts.suspect`. En `AlertsConsumer` persisto en `pos.alerts`.
- ¿Cuándo usarías ventanas (tumbling, sliding) y qué reloj escogerías?
  - Sliding para agregaciones móviles, tumbling para cortes fijos. Prefiero “event‑time” con marcadores (watermarks) si llegan fuera de orden; si la fuente no emite timestamps fiables, “processing‑time” con cautela.
- ¿Qué es un “repartition” y cuándo lo necesitas?
  - Rehacer partición por una nueva clave antes de joins/aggregations para garantizar co‑localidad de registros por clave.

### Spring / Spring Boot
- ¿Cómo estructuraste la app?
  - Capas: Controller → Service → Repository → Model. Config externa en `docker-compose.yml` (Twelve‑Factor), endpoints principales (`/auth/token`, `/events/*`, `/alerts`, `/alerts-db`, `/api/health`).
- ¿Cómo expones APIs y documentas contratos?
  - Síncrono: `specs/openapi.yaml` (REST, JSON). Asíncrono: `specs/asyncapi.yaml` (topics, mensajes, canales).
- ¿Cómo manejas JSONB y JPA?
  - Uso `@JdbcTypeCode(SqlTypes.JSON)` en entidades para columnas `jsonb`, evitando mapeos frágiles.

### Persistencia y patrones
- ¿Por qué Debezium y no publicar directamente desde la app?
  - Desacopla la publicación del commit de BD; no dependes de red/Kafka dentro de la transacción; reduces riesgo de “lost events”. CDC garantiza que lo que se comprometió en BD termina en Kafka.
- ¿Cómo evitas duplicados en sinks persistentes?
  - Idempotencia por clave natural o UPSERT (constraint única). Si se reintenta, no duplica.

### Observabilidad (OpenTelemetry + Elasticsearch/Kibana)
- ¿Qué instrumentaste y cómo?
  - Agente OTel Java via `-javaagent` captura trazas/métricas/logs; exporto OTLP a `apm-server`; Kibana APM muestra el servicio `eda-backend`.
- ¿Qué métricas y trazas observarías para detectar problemas?
  - Latencias por endpoint, tasa de errores, throughput del servicio, lag del consumer group, health de APM, data streams (`traces-apm*`, `metrics-apm*`, `logs-apm*`).
- ¿Qué problemas resolviste en APM?
  - APM 8.x requiere integración instalada; habilité seguridad en ES/Kibana, instalé APM vía Fleet, y configuré credenciales en `apm-server.yml` (usuario `apm_writer` con permisos `auto_configure/create_index/write/create_doc`). Validé ingesta con `POST /v1/*` 200 y data streams creados.

### Seguridad (OAuth, OIDC, JWT)
- ¿Cómo implementaste el control de acceso?
  - JWT para endpoints de negocio; `SecurityConfig` permite `/api/health`, `/auth/*`, `/swagger-ui/**` sin token. Para producción: OAuth2/OIDC (Keycloak, Cognito) con roles/claims por scope.
- ¿Qué riesgos comunes mitigas?
  - Expiración y rotación de tokens, CORS, rate limiting en login, CAPTCHAs y registro protegido, secretos en variables de entorno (no en código).

### OpenAPI y AsyncAPI
- ¿Cómo versionas contratos?
  - `specs/openapi.yaml` para REST (modelos, respuestas, errores) y `specs/asyncapi.yaml` para eventos (schemas por versión, cambios compatibles, Avro como opción para schema registry).
- ¿Qué pruebas automáticas harías?
  - Validar payloads contra schemas, contract tests consumidores‑productores, lint de especificaciones, generación de clientes/stubs.

### Kubernetes/Openshift
- ¿Cómo desplegarías y escalarías?
  - Charts Helm (`charts/eda-backend`), readiness/liveness probes, HPA por CPU/RAM; con Kafka Streams, escalar pods del consumer y ajustar reparticionamiento.
- ¿Qué usarías para autoscaling por lag?
  - KEDA: escalado de consumidores basado en lag de `alerts.suspect`.

### Testing y Calidad
- ¿Qué cubren tus tests unitarios?
  - Lógica de negocio en Services, filtros de umbral, serialización de payloads, repositorios con H2/containers, contract tests de endpoint.
- ¿Cómo probarías Streams?
  - TopologyTestDriver (Kafka Streams), fixtures de mensajes y ventanas, asserts sobre outputs.

### Depuración y Rendimiento
- ¿Cómo detectas un “hot spot” en el procesamiento?
  - Métricas de latencia/CPU por endpoint, lag creciente, pausas de GC; trazas APM con spans (DB, Kafka, Debezium).
- ¿Qué optimizaciones aplicarías?
  - Batching, backpressure en consumers, ajustar `max.poll.interval.ms`, producir con compresión, tuning de Hikari pool, indexación en `pos.alerts`.

### Drools
- ¿Cuándo usarías Drools en tu caso?
  - Para separar reglas de negocio complejas (umbral dinámico, listas, condiciones basadas en atributos) y permitir cambios sin redeploy. Kafka Streams llama al motor para evaluar el evento.

### Bases de datos (SQL/NoSQL)
- ¿Qué criterios para elegir relacional vs no relacional?
  - Transaccionalidad y relaciones fuertes → relacional (PostgreSQL). Alta escritura con esquemas flexibles o lectura por clave → NoSQL (ej. Redis/Mongo) como complementos.
- ¿Cómo gestionas migraciones?
  - Flyway y scripts versionados (`src/main/resources/db/migration`). Automatiza al levantar contenedores; dry‑run para revisar diffs.

### Balanceador y alta disponibilidad
- ¿Cómo garantizas alta disponibilidad en la capa de servicio?
  - NGINX delante de 3 instancias (least_conn, health checks, failover). HAProxy para DB (5000 write / 5001 read) con Patroni coordinando líder/replicas y failover automático.

### Cloud y Elasticsearch
- ¿Cómo llevarías la solución a AWS/Azure?
  - Kafka/MSK o Confluent Cloud, RDS Aurora/Postgres, Elastic Cloud (APM/Kibana/ES), EKS/AKS para apps, Secrets Manager y IAM/OAuth para seguridad.
- ¿Qué coste base monitorizarías?
  - Throughput y retención de Kafka, storage de ES (data streams), uso de CPU/memoria pods, volumen de traces/logs.

### React y Python (deseables)
- ¿Cómo integrarías un UI mínimo?
  - React para dashboards de alertas con backend REST y WebSocket (si UI tiempo real). Auth con OAuth/OIDC PKCE.
- ¿Qué rol tendría Python?
  - Jobs de data prep o ML streaming con Faust/Flink, scripts para migraciones/ETL y pruebas de performance.

### Preguntas situacionales
- Diseña una alerta de fraude en tiempo real con Kafka Streams.
  - Inputs: transacciones con `accountId`, `amount`, `timestamp`. Ventana sliding 5 minutos; si suma en ventana > umbral o múltiples intentos fallidos seguidos, emite evento a `alerts.suspect` con tags (`risk_level`, `rule_id`). Persistencia idempotente en `pos.alerts`. Métricas de match/latencia, DLQ para payload inválido.
- Hay lag creciente en `alerts-persist-group`. ¿Plan de acción?
  - Verificar consumo y errores; escalar réplicas del consumer; aumentar `max.poll.records`; revisar contención en BD; aplicar backpressure al productor si aplica; inspeccionar GC/CPU; revisar tamaño de mensajes y compresión.
- APM dejó de recibir datos tras activar seguridad. ¿Qué harías?
  - Validar `apm-server.yml` (credenciales/permisos), Fleet APM instalado, ver `/_data_stream` y logs de APM Server, revisar `output.elasticsearch` y permisos (`auto_configure/create_index`), reinstalar paquete APM si no se aplicaron templates.

### Soft Skills y colaboración
- ¿Cómo alineas cambios de contrato con equipos consumidores?
  - Versionado y “consumer‑driven contracts”, reuniones de diseño, canary releases, documentación en `specs/`, avisos proactivos y feature toggles.
- ¿Cómo priorizas en un backlog de plataforma de eventos?
  - Latencia y disponibilidad primero (observabilidad y resiliencia), luego funcionalidad (reglas/automatismos), y optimización de coste.

### Guía para tus respuestas
- Cuenta la historia de tu pipeline actual (Outbox + Debezium + Streams + persistencia + APIs).
- Apóyate en los documentos (README y `docs/*`) con enlaces y comandos concretos para mostrar que sabes “operar” el stack.
- Usa cifras (p.ej. “ventanas de 5 min”, “lag objetivo < 200 ms”, “latencia p95 < 50 ms”).

## 13. Checklist de demo (5 minutos)
1. `pwsh ./scripts/observability_smoke.ps1 -Count 20 -BaseUrl http://localhost:8080`.
2. APM: Kibana → Observability → APM → Services → `eda-backend` (Last 30 min).
3. Kafka: `GET /alerts?timeoutMs=15000` y `GET /alerts-db`.
4. Data streams: `GET http://localhost:9200/_data_stream?pretty` (con `elastic:changeme`).
5. Health: `GET /api/health`.

## 14. Comandos útiles
- Reconstruir apps: `docker compose up -d --no-deps --build app1 app2 app3`.
- Logs APM Server: `docker compose logs --tail=200 apm-server`.
- Consumer group: `docker exec kafka kafka-consumer-groups --bootstrap-server kafka:9092 --describe --group alerts-persist-group`.

## 15. Referencias (navegables)
- Metodología y narrativa: `docs/Metodologia.md`
- Observabilidad (APM/OTel): `docs/observability-overview.md`
- Resiliencia BD (Patroni + HAProxy): `docs/database-resilience.md`
- Balanceador NGINX: `docs/README-LoadBalancer.md`
- Esquema POS y DDL: `docs/pos_schema_instructions.md`
- Contribución: `docs/CONTRIBUTING.es.md` · `docs/CONTRIBUTING.md`
- Contratos: `specs/openapi.yaml` · `specs/asyncapi.yaml`

> Consejo: imprime esta guía, y durante la entrevista apóyate en las secciones 2 (flujo), 6 (observabilidad) y 12 (respuestas modelo).

Meti etxto aca 
 formatea mejor y pordena segun lo que hay 

 Arquitectura EDA

- ¿Qué problema resuelve una arquitectura basada en eventos frente a una arquitectura clásica por llamadas síncronas?
  - Desacopla productores y consumidores, reduce dependencia temporal, permite escalar lectores de forma independiente, y habilita reacciones en tiempo real (suscripción/streaming) con tolerancia a fallos mejor distribuida.
- ¿Cómo explicas el flujo end-to-end de tu plataforma?
  - POST /events/* persiste en BD y outbox → Debezium publica el evento en Kafka → Kafka Streams procesa (umbral) → emite a alerts.suspect → AlertsConsumer persiste en pos.alerts → expongo GET /alerts (Kafka directo) y GET /alerts-db (persistidos).
- ¿Cómo garantizas consistencia entre escritura en BD y publicación en Kafka?
  - Patrón Outbox + CDC (Debezium): la app escribe entidad + outbox en una misma transacción local; Debezium lee el WAL y publica en Kafka. Evita “dual-write” no atómico y recupera tras caídas.
Kafka Fundamentals

- ¿Cuándo usas particiones y claves en Kafka?
  - Para paralelismo y orden por clave. Particiones permiten escalar consumidores; claves garantizan orden por entidad (ej. accountId ).
- ¿Qué implica “exactly-once” en Kafka Streams?
  - Transacciones de productor + commit de offsets atómico. Activo processing.guarantee=exactly_once_v2 y diseño idempotente del lado de sinks.
- ¿Cómo gestionas el “consumer group” y el lag?
  - Cada servicio usa su group-id (“alerts-persist-group”) y monitorizo lag con kafka-consumer-groups --describe . Cuando hay lag, escalo instancias o optimizo la lógica.
Kafka Streams/Flink

- ¿Cómo modelas el pipeline de alertas?
  - Origen: payments.events , transfers.events . Joins/repartitions si aplica; filtro por umbral (ej. amount >= ALERT_THRESHOLD ) y publicamos en alerts.suspect . En AlertsConsumer persisto en pos.alerts .
- ¿Cuándo usarías ventanas (tumbling, sliding) y qué reloj escogerías?
  - Sliding para agregaciones móviles, tumbling para cortes fijos. Prefiero “event-time” con marcadores (watermarks) si llegan fuera de orden; si la fuente no emite timestamps fiables, “processing-time” con cautela.
- ¿Qué es un “repartition” y cuándo lo necesitas?
  - Rehacer partición por una nueva clave antes de joins/aggregations para garantizar co-localidad de registros por clave.
Spring / Spring Boot

- ¿Cómo estructuraste la app?
  - Capas: Controller → Service → Repository → Model. Config externa en docker-compose.yml (Twelve-Factor), endpoints principales ( /auth/token , /events/* , /alerts , /alerts-db , /api/health ).
- ¿Cómo expones APIs y documentas contratos?
  - Síncrono: specs/openapi.yaml (REST, JSON). Asíncrono: specs/asyncapi.yaml (topics, mensajes, canales).
- ¿Cómo manejas JSONB y JPA?
  - Uso @JdbcTypeCode(SqlTypes.JSON) en entidades para columnas jsonb , evitando mapeos frágiles.
Persistencia y patrones

- ¿Por qué Debezium y no publicar directamente desde la app?
  - Desacopla la publicación del commit de BD; no dependes de red/Kafka dentro de la transacción; reduces riesgo de “lost events”. CDC garantiza que lo que se comprometió en BD termina en Kafka.
- ¿Cómo evitas duplicados en sinks persistentes?
  - Idempotencia por clave natural o UPSERT (constraint única). Si se reintenta, no duplica.
Observabilidad (OpenTelemetry + Elasticsearch/Kibana)

- ¿Qué instrumentaste y cómo?
  - Agente OTel Java via -javaagent captura trazas/métricas/logs; exporto OTLP a apm-server ; Kibana APM muestra el servicio eda-backend .
- ¿Qué métricas y trazas observarías para detectar problemas?
  - Latencias por endpoint, tasa de errores, throughput del servicio, lag del consumer group, health de APM, data streams ( traces-apm* , metrics-apm* , logs-apm* ).
- ¿Qué problemas resolviste en APM?
  - APM 8.x requiere integración instalada; habilité seguridad en ES/Kibana, instalé APM vía Fleet, y configuré credenciales en apm-server.yml (usuario apm_writer con permisos auto_configure/create_index/write/create_doc ). Validé ingestion con POST /v1/* 200 y data streams creados.
Seguridad (OAuth, OIDC, JWT)

- ¿Cómo implementaste el control de acceso?
  - JWT para endpoints de negocio; SecurityConfig permite /api/health , /auth/* , /swagger-ui/** sin token. Para producción: OAuth2/OIDC (Keycloak, Cognito) con roles/claims por scope.
- ¿Qué riesgos comunes mitigas?
  - Expiración y rotación de tokens, CORS, rate limiting en login, CAPTCHAs y registro protegido, secretos en variables de entorno (no en código).
OpenAPI y AsyncAPI

- ¿Cómo versionas contratos?
  - specs/openapi.yaml para REST (modelos, responses, errores) y specs/asyncapi.yaml para eventos (schemas por versión, cambios compatbiles, Avro como opción para schema registry).
- ¿Qué pruebas automáticas harías?
  - Validar payloads contra schemas, contract tests consumidores-productores, lint de especificaciones, generación de clientes/stubs.
Kubernetes/Openshift

- ¿Cómo desplegarías y escalarías?
  - Charts Helm ( charts/eda-backend ), readiness/liveness probes, HPA por CPU/RAM; con Kafka Streams, escalar pods del consumer y ajustar reparticionamiento.
- ¿Qué usarías para autoscaling por lag?
  - KEDA: escalado de consumidores basado en lag de alerts.suspect .
Testing y Calidad

- ¿Qué cubren tus tests unitarios?
  - Lógica de negocio en Services, filtros de umbral, serialización de payloads, repositorios con H2/containers, contract tests de endpoint.
- ¿Cómo probarías Streams?
  - TopologyTestDriver (Kafka Streams), fixtures de mensajes y ventanas, asserts sobre outputs.
Depuración y Rendimiento

- ¿Cómo detectas un “hot spot” en el procesamiento?
  - Métricas de latencia/CPU por endpoint, lag creciente, GC pausas; trazas APM con spans (DB, Kafka, Debezium).
- ¿Qué optimizaciones aplicarías?
  - Batching, backpressure en consumers, ajustar max.poll.interval.ms , producir con compresión, tuning de Hikari pool, indexación en pos.alerts .
Drools

- ¿Cuándo usarías Drools en tu caso?
  - Para separar reglas de negocio complejas (umbral dinámico, listas, condiciones basadas en atributos) y permitir cambios sin redeploy. Kafka Streams llama al motor para evaluar el evento.
Bases de datos (SQL/NoSQL)

- ¿Qué criterios para elegir relacional vs no relacional?
  - Transaccionalidad y relaciones fuertes → relacional (PostgreSQL). Alta escritura con esquemas flexibles o lectura por clave → NoSQL (ej. Redis/Mongo) como complementos.
- ¿Cómo gestionas migraciones?
  - Flyway y scripts versionados ( src/main/resources/db/migration ). Automatiza al levantar contenedores; dry-run para revisar diffs.
Balanceador y alta disponibilidad

- ¿Cómo garantizas alta disponibilidad en la capa de servicio?
  - NGINX delante de 3 instancias (least_conn, health checks, failover). HAProxy para DB (5000 write / 5001 read) con Patroni coordinando líder/replicas y failover automático.
Cloud y Elasticsearch

- ¿Cómo llevarías la solución a AWS/Azure?
  - Kafka/MSK o Confluent Cloud, RDS Aurora/Postgres, Elastic Cloud (APM/Kibana/ES), EKS/AKS para apps, Secrets Manager y IAM/OAuth para seguridad.
- ¿Qué coste base monitorizarías?
  - Throughput y retención de Kafka, storage de ES (data streams), uso de CPU/memoria pods, volumen de traces/logs.
React y Python (deseables)

- ¿Cómo integrarías un UI mínimo?
  - React para dashboards de alertas con backend REST y WebSocket (si real-time UI). Auth con OAuth/OIDC PKCE.
- ¿Qué rol tendría Python?
  - Jobs de data prep o ML streaming con Faust/Flink, scripts para migraciones/ETL, y pruebas de performance.
Preguntas Situacionales

- Diseña una alerta de fraude en tiempo real con Kafka Streams.
  - Inputs: transacciones con accountId , amount , timestamp . Ventana sliding 5 minutos; si suma en ventana > umbral o múltiples intentos fallidos seguidos, emite evento a alerts.suspect con tags ( risk_level , rule_id ). Persistencia idempotente en pos.alerts . Métricas de match/latencia, DLQ para payload inválido.
- Hay lag creciente en alerts-persist-group . ¿Plan de acción?
  - Verificar consumo y errores; escalar replicas de consumer; aumentar max.poll.records ; revisar DB contención; backpressure al productor si aplica; inspeccionar GC/CPU; revisar tamaño de mensajes y compresión.
- APM dejó de recibir datos tras activar seguridad. ¿Qué harías?
  - Validar apm-server.yml (credenciales/permisos), Fleet APM instalado, ver /_data_stream y logs de APM Server, revisar output.elasticsearch y permisos ( auto_configure/create_index ), reinstalar paquete APM si no se aplicaron templates.
Soft Skills y colaboración

- ¿Cómo alineas cambios de contrato con equipos consumidores?
  - Versionado y “consumer-driven contracts”, reuniones de diseño, canary releases, documentación en specs/ , avisos proactivos y feature toggles.
- ¿Cómo priorizas en un backlog de plataforma de eventos?
  - Latencia y disponibilidad primero (observabilidad y resiliencia), luego funcionalidad (reglas/automatismos), y optimización de coste.
Guía para tus respuestas

- Cuenta la historia de tu pipeline actual (Outbox + Debezium + Streams + persistencia + APIs).
- Apóyate en los documentos (README y docs/* ) con enlaces y comandos concretos para mostrar que sabes “operar” el stack.
- Usa cifras (p.e. “ventanas de 5 min”, “