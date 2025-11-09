# Mapa del Proyecto (estructura y componentes)

## Navegación
- Inicio: [README](../README.md)
- Índice docs: [index.md](index.md)
- Metodología: [Metodologia.md](Metodologia.md)
- Observabilidad (APM/OTel): [observability-overview.md](observability-overview.md)
- Resiliencia BD (Patroni + HAProxy): [database-resilience.md](database-resilience.md)
- Balanceador NGINX: [README-LoadBalancer.md](README-LoadBalancer.md)
- Guía de entrevista: [guia-entrevista-backend.md](guia-entrevista-backend.md)
- Contribución (ES): [CONTRIBUTING.es.md](CONTRIBUTING.es.md)
- Contribución (EN): [CONTRIBUTING.md](CONTRIBUTING.md)
- Esquema POS y DDL: [pos_schema_instructions.md](pos_schema_instructions.md)
- OpenAPI: [../specs/openapi.yaml](../specs/openapi.yaml) · AsyncAPI: [../specs/asyncapi.yaml](../specs/asyncapi.yaml)

## Estructura del repositorio (3 niveles)
```
// Resumen de carpetas clave
├── README.md
├── docker-compose.yml
├── config/            # Configuración de servicios (APM Server, Debezium)
├── docs/              # Documentación (metodología, observabilidad, resiliencia, etc.)
├── nginx/             # Config del balanceador NGINX
├── patroni-config/    # Config del cluster PostgreSQL Patroni
├── scripts/           # Utilidades (DB, observabilidad, Kafka, pruebas HA)
├── specs/             # Contratos OpenAPI/AsyncAPI
├── sql/               # DDL y bootstrap de BD
├── src/main/java/     # Código de la app (Spring Boot + Kafka Streams)
├── src/main/resources # Config de la app (application.yml, migraciones Flyway)
└── otel/              # Agente OpenTelemetry Java
```

## Punto de entrada de la aplicación
- Clase principal: `src/main/java/com/rgq/edabank/Application.java`
  - Anotaciones: `@SpringBootApplication`, `@EnableTransactionManagement`, `@EnableKafkaStreams`, `@EnableScheduling`, `@EntityScan`, `@EnableJpaRepositories`
  - Arranque: `SpringApplication.run(Application.class, args);`
- Arranque del contenedor: `entrypoint.sh`
  - Adjunta el agente OTel (`-javaagent:/opt/otel/opentelemetry-javaagent.jar`) y configura variables `OTEL_*`.

## Configuración principal
- App (Spring): `src/main/resources/application.yml` / `config/application-docker.yml`
- Observabilidad: `config/apm-server.yml` (salida a Elasticsearch)
- Debezium Outbox: `config/debezium-connector*.json`
- Patroni (PostgreSQL HA): `patroni-config/patroni.yml`
- HAProxy (DB proxy): `haproxy-patroni.cfg`
- NGINX: `nginx/nginx.conf`
- Variables locales: `.env.local` (credenciales/puertos para desarrollo)

## Servicios (docker-compose)
- etcd1/etcd2/etcd3: consenso para Patroni.
- patroni-master, patroni-replica1, patroni-replica2: cluster PostgreSQL HA.
- haproxy-patroni: puertos `5000` (write) / `5001` (read) / `7000` (stats).
- db-bootstrap: inicialización idempotente del esquema/roles vía `scripts/bootstrap-db.sh`.
- zookeeper, kafka: cluster de mensajería.
- nginx-load-balancer: balanceo HTTP hacia `app1/app2/app3`.
- elasticsearch, kibana, apm-server: observabilidad (APM/OTel + UI Kibana). 

## Contratos y datos
- REST: `specs/openapi.yaml` (endpoints, modelos y respuestas).
- Eventos (Kafka): `specs/asyncapi.yaml` (topics, mensajes, canales).
- Esquema POS: `sql/create_pos_schema_and_tables.sql` + instrucciones en `docs/pos_schema_instructions.md`.

## Dependencias (Maven)
- Spring Boot: `web`, `jdbc`, `data-jpa`, `security`, `validation`, `websocket`, `actuator`.
- Kafka: `spring-kafka`, `kafka-streams`.
- BD: `postgresql` (runtime), `flyway-core` (migraciones), `hibernate` (vía JPA).
- Observabilidad y API: `micrometer-core` + `micrometer-registry-prometheus`, `springdoc-openapi-starter-webmvc-ui`, `jackson-dataformat-yaml`.
- Seguridad/JWT: `nimbus-jose-jwt`, `spring-boot-starter-oauth2-resource-server`.
- Reglas: `drools-core`, `drools-compiler`, `kie-spring`.
- Utilidades: `json-path`, `spring-data-redis`, `lombok` (scope `provided`).

## Scripts útiles
- `scripts/observability_smoke.ps1`: genera tráfico para APM.
- `scripts/create-topics.sh`: crea topics Kafka.
- `scripts/test_load_balancer.ps1`: prueba NGINX y failover.
- `scripts/test-patroni-*.ps1`: pruebas de failover y recuperación del cluster.
- `scripts/bootstrap-db.sh`: prepara esquema y grants en BD.

## Cómo se conectan los componentes (mapa rápido)
- App → BD: HAProxy (`5000/5001`) hacia el líder/replicas Patroni.
- App → Kafka: `kafka:9092` (productor/consumidor + Streams).
- CDC Outbox: Debezium lee WAL de BD y publica en Kafka.
- Observabilidad: OTel (agente) → APM Server (`8200`) → Elasticsearch → Kibana (APM).
- NGINX: balancea `app1/app2/app3` y expone `http://localhost:8080`.

## Inicio rápido
- Levantar stack: `docker-compose up --build -d`
- Generar tráfico: `pwsh ./scripts/observability_smoke.ps1 -Count 20 -BaseUrl http://localhost:8080`
- APM: Kibana → Observability → APM → Services → `eda-backend` (Last 30 min)
- Ver data streams: `GET http://localhost:9200/_data_stream?pretty`

---

Para narrativa y preguntas de entrevista, consulta [guia-entrevista-backend.md](guia-entrevista-backend.md).

---

Navegación rápida: [Volver al README](../README.md) · [Índice de docs](index.md) · [Mapa del proyecto](project-map.md) · [Guía de entrevista](guia-entrevista-backend.md) · [Observabilidad](observability-overview.md)