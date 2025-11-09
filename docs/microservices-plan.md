# Plan de transición a microservicios (sin despliegue aún)

Este documento describe la separación del monolito en tres microservicios iniciales y el `docker-compose` asociado, sin tocar el entorno actual.

## Servicios creados (código)
- `services/payments-service`: API `POST /payments` → publica en `payments.events` (Kafka).
- `services/transfers-service`: API `POST /transfers` → publica en `transfers.events` (Kafka).
- `services/alerts-service`: Kafka Streams → lee `payments.events` y `transfers.events`, filtra por umbral y emite a `alerts.suspect`.

## Configuración
- Cada servicio tiene su `application.yml` con `bootstrap-servers` parametrizable (por defecto `kafka:9092`).
- Dockerfiles por servicio (no ejecutar todavía).
- Compose separado: `docker-compose.microservices.yml` (no ejecutarlo ahora). Usa `networks.kafka-network` como external.

## No se toca el entorno actual
- El `docker-compose.yml` existente no se modifica.
- No se levantan contenedores nuevos.
- No se despliega en Kubernetes.

## Próximos pasos (post-entrevista)
1. Construir los jars:
   - `mvn -f services/payments-service/pom.xml -DskipTests package`
   - `mvn -f services/transfers-service/pom.xml -DskipTests package`
   - `mvn -f services/alerts-service/pom.xml -DskipTests package`
2. Construir imágenes y levantar compose microservicios (opcional):
   - `docker compose -f docker-compose.microservices.yml build`
   - `docker compose -f docker-compose.microservices.yml up -d` (cuando lo decidas)
3. Enlace de API: usar NGINX existente como gateway, o incorporar Spring Cloud Gateway posteriormente.
4. Separación de datos (evolución): esquemas por servicio o `database-per-service`.

### API Gateway local (añadido)
- Servicio: `services/gateway-service` (Spring Cloud Gateway, puerto 9080)
- Rutas:
  - `/api/payments/**` → `payments-service:9101`
  - `/api/transfers/**` → `transfers-service:9102`
  - `/api/alerts/**` → `nginx-load-balancer:8080` (monolito, opcional)
- Compose: incluido en `docker-compose.microservices.yml` (no ejecutar ahora)
- Build rápido: `pwsh ./scripts/build-microservices.ps1 -SkipTests`

## Navegación
- [Mapa del proyecto](project-map.md)
- [Observabilidad](observability-overview.md)
- [Guía de entrevista](guia-entrevista-backend.md)