# Arquitectura de Microservicios (propuesta y flujo)

Este documento describe la arquitectura objetivo basada en microservicios construida sobre tu entorno local, sin despliegue en cloud y sin ejecutar contenedores por ahora.

## Visión general
- Servicios de dominio:
  - `payments-service`: recibe pagos y publica eventos en Kafka (`payments.events`).
  - `transfers-service`: recibe transferencias y publica eventos en Kafka (`transfers.events`).
  - `alerts-service` (Kafka Streams): procesa ambos streams, aplica reglas de umbral y emite a `alerts.suspect`.
- API Gateway (`gateway-service`, Spring Cloud Gateway): punto único de entrada local.
- Observabilidad: agente OTel (opcional en cada servicio) → APM Server → Elasticsearch → Kibana.
- CDC Outbox (monolito actual, opcional en transición): Debezium puede convivir mientras migras endpoints.

## Diagrama (texto)
```
                       +---------------------------+
                       |       gateway-service     |
                       |  /api/payments  /api/trans|
                       +-------------+-------------+
                                     | routes
           +-------------------------+--------------------------+
           |                                                    |
----------v----------+                              +----------v----------+
| payments-service    |                              | transfers-service   |
| POST /payments      |                              | POST /transfers     |
| -> Kafka produce    |                              | -> Kafka produce    |
| topic: payments.ev. |                              | topic: transfers.ev.|
----------+----------+                              +----------+----------+
           |                                                     |
           |                             Kafka (zookeeper/kafka)|
           +------------------------+------------+--------------+
                                    |            |
                           +--------v------------v--------+
                           |        alerts-service        |
                           |   Kafka Streams topology     |
                           | filter >= ALERT_THRESHOLD    |
                           | -> topic: alerts.suspect     |
                           +------------------------------+

Observabilidad: OTel agents (services) -> APM Server -> Elasticsearch -> Kibana
Opcional: monolito actual vía NGINX para /api/alerts y /alerts-db durante transición
```

## Flujo de datos
- Entrada:
  - `POST /api/payments` (Gateway) → redirige a `payments-service` → produce evento en `payments.events`.
  - `POST /api/transfers` (Gateway) → redirige a `transfers-service` → produce evento en `transfers.events`.
- Procesamiento:
  - `alerts-service` consume ambos topics, aplica reglas (umbral configurable `ALERT_THRESHOLD`), emite alertas a `alerts.suspect`.
- Salidas/consumo:
  - Los consumidores existentes (monolito) o nuevos servicios podrán leer `alerts.suspect` y persistir/mostrar.

## Contratos y límites
- Síncrono (REST):
  - `payments-service`: `POST /payments` (JSON). 
  - `transfers-service`: `POST /transfers` (JSON).
- Asíncrono (Kafka):
  - `payments.events`, `transfers.events`, `alerts.suspect`.
- Gateway:
  - Rutas definidas en `services/gateway-service/src/main/resources/application.yml`.

## Observabilidad y seguridad
- Instrumentación: adjuntar OTel Java agent por servicio (igual que el monolito).
- APM: validar que `apm-server` y `Kibana` siguen en pie; cada servicio usa su `OTEL_SERVICE_NAME`.
- Seguridad (dev): puedes mantener JWT y validaciones mínimas en el gateway o por servicio cuando migres auth.

## Plan de evolución
- Fase 1 (listo): endpoints de publicación separados (payments/transfers) y procesamiento de alertas en Streams.
- Fase 2: mover persistencia de alertas a un servicio propio (alerts-persistence) y exponer `GET /alerts` desde ese servicio.
- Fase 3: separar esquemas por servicio (database-per-service) y desactivar CDC del monolito.
- Fase 4: observabilidad por servicio (dashboards APM, métricas por servicio) y endurecer seguridad.

## Referencias
- [Plan de microservicios](microservices-plan.md)
- [Mapa del proyecto](project-map.md)
- [Observabilidad](observability-overview.md)
- [Guía de entrevista](guia-entrevista-backend.md)

---

## Resumen 1 página
- Punto único de entrada: `gateway-service` (Spring Cloud Gateway, puerto 9080) con rutas a servicios internos.
- Servicios de dominio:
  - `payments-service` recibe `POST /payments` y publica en Kafka `payments.events`.
  - `transfers-service` recibe `POST /transfers` y publica en Kafka `transfers.events`.
- Procesamiento en streaming: `alerts-service` (Kafka Streams) consume ambos topics, aplica umbral (`ALERT_THRESHOLD`) y emite a `alerts.suspect`.
- Contratos:
  - REST: `/api/payments/**`, `/api/transfers/**` vía Gateway (JSON).
  - Kafka: `payments.events`, `transfers.events`, `alerts.suspect`.
- Observabilidad: OTel Java agent por servicio → `apm-server` → Elasticsearch → Kibana (APM); data streams `traces-apm*`, `metrics-apm*`, `logs-apm*`.
- Seguridad (dev): JWT simple en Gateway o por servicio; producción: OAuth2/OIDC.
- Convivencia con monolito: Gateway puede enrutar `/api/alerts` y `/alerts-db` hacia NGINX/monolito durante transición.
- Despliegue local: compose separado `docker-compose.microservices.yml` y red externa `kafka-network` (no ejecutar ahora).
- Build sin ejecutar: `pwsh ./scripts/build-microservices.ps1 -SkipTests` compila gateway/payments/transfers/alerts.
- Evolución por fases: separar persistencia de alertas → `database-per-service` → dashboards APM por servicio y seguridad endurecida.