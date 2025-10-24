# EDA Backend scaffold created.

## Extra
### Docker (Distroless)
Para construir con distroless:
```bash
docker build -f Dockerfile.distroless -t rgq/eda-backend:0.1.0 .
```

### Helm
```bash
helm install eda ./charts/eda-backend   --set image.repository=rgq/eda-backend   --set image.tag=0.1.0   --set env.kafkaBootstrapServers="kafka-bootstrap.kafka:9092"   --set env.jwtSecret="cambia-esto"   --set env.alertThreshold=10000   --set env.kafkaStreamsAppId="eda-alerts-app"
```

### KEDA (autoscaling por lag)
Asegúrate de tener KEDA instalado en el clúster:
```bash
helm repo add kedacore https://kedacore.github.io/charts
helm repo update
helm install keda kedacore/keda --namespace keda --create-namespace
```

Aplica el ScaledObject:
```bash
kubectl apply -f k8s/keda-scaledobject.yaml

## EDA Backend (local dev)

Este repositorio contiene un backend Spring Boot que usa Kafka Streams. Estas instrucciones describen cómo obtener un token dev desde Postman, cómo llamar los endpoints protegidos y cómo hacer pruebas rápidas de Streams usando Docker.

Contenido añadido:
- Cómo obtener token (Postman)
- Cómo usar el token contra endpoints protegidos
- Comandos `docker exec` (PowerShell) para producir eventos y consumir alertas
- Opción: añadir endpoints POST para producir eventos desde Postman (requiere cambios)

---

## 1) Obtener token (Postman)

- Método: GET
- URL (local): `http://localhost:8080/auth/token?sub=raul&scope=alerts.read`
- Query params:
	- `sub` (ej. `raul`)
	- `scope` (ej. `alerts.read`)
- Respuesta: el cuerpo es un JWT (texto plano, HS256). Copia el token.

Ejemplo en Postman:
- New request > GET
- URL: `http://localhost:8080/auth/token`
- Params tab: add `sub=raul`, `scope=alerts.read`
- Send -> copiar el token del body

## 2) Usar token contra endpoints protegidos

- Añade header:
	- `Authorization: Bearer <TU_TOKEN>`
- Ejemplo protegido:
	- `GET http://localhost:8080/api/hello`
	- Header: `Authorization: Bearer eyJ...` (token obtenido)

## 3) Comandos Docker (PowerShell) para pruebas de Streams

Usa estos comandos si quieres producir mensajes desde el host al cluster Kafka que corre en Docker.
Confirma el nombre del contenedor Kafka con `docker ps` (se asume `kafka`).

- Producir un pago grande (produce a `payments.events`):
```powershell
docker exec -i kafka bash -c 'cat > /tmp/msg.json <<EOF
{"id":"p-123","type":"payment","amount":12000,"currency":"EUR","accountId":"acc-1"}
EOF
kafka-console-producer --bootstrap-server localhost:9092 --topic payments.events < /tmp/msg.json'
```

- Producir una transferencia grande (produce a `transfers.events`):
```powershell
docker exec -i kafka bash -c 'cat > /tmp/msg.json <<EOF
{"id":"t-456","type":"transfer","amount":15000,"from":"acc-1","to":"acc-2"}
EOF
kafka-console-producer --bootstrap-server localhost:9092 --topic transfers.events < /tmp/msg.json'
```

- Consumir alerts (topic `alerts.suspect`):
```powershell
docker exec -it kafka kafka-console-consumer --bootstrap-server localhost:9092 --topic alerts.suspect --from-beginning --timeout-ms 10000
```

Notas:
- Los `amount` en los ejemplos están por encima del umbral (`ALERT_THRESHOLD`) para forzar alertas.
- Si el contenedor usa otro nombre, reemplaza `kafka` por el nombre correcto.

## 4) Usar solo Postman (opcional)

Si prefieres no usar `docker exec`, puedo añadir dos endpoints protegidos para publicar eventos desde Postman:

- `POST /events/payments`  (body JSON) -> publica a `payments.events`
- `POST /events/transfers` (body JSON) -> publica a `transfers.events`

Esto requiere:
- Implementar `KafkaTemplate<String,String>` y un controlador `EventsController`.
- Rebuild de la app y `docker compose up --build`.

Dime si quieres que lo implemente y lo hago (haré los cambios, compilaré y te doy las rutas exactas).

## 5) Limpieza y recomendaciones

- Reemplazar `web.ignoring()` por `permitAll()` en `SecurityConfig` para evitar warnings.
- Añadir scripts en `scripts/` para repetir las pruebas fácilmente.

---

## Outbox table (DDL)

Si quieres usar el pattern outbox que implementé en el código, crea la tabla:

```sql
CREATE TABLE IF NOT EXISTS pos.outbox (
	id BIGSERIAL PRIMARY KEY,
	aggregate_type VARCHAR(100),
	aggregate_id VARCHAR(100),
	type VARCHAR(200), -- kafka topic
	payload JSONB,
	sent BOOLEAN DEFAULT false,
	created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
```


## Extra
### Docker (Distroless)
Para construir con distroless:
```bash
docker build -f Dockerfile.distroless -t rgq/eda-backend:0.1.0 .
```

### Helm
```bash
helm install eda ./charts/eda-backend   --set image.repository=rgq/eda-backend   --set image.tag=0.1.0   --set env.kafkaBootstrapServers="kafka-bootstrap.kafka:9092"   --set env.jwtSecret="cambia-esto"   --set env.alertThreshold=10000   --set env.kafkaStreamsAppId="eda-alerts-app"
```

### KEDA (autoscaling por lag)
Asegúrate de tener KEDA instalado en el clúster:
```bash
helm repo add kedacore https://kedacore.github.io/charts
helm repo update
helm install keda kedacore/keda --namespace keda --create-namespace
```

Aplica el ScaledObject:
```bash
kubectl apply -f k8s/keda-scaledobject.yaml
```

```
 (fragmento: Endpoints)
### Endpoints disponibles

- GET /api/hello  
  - Descripción: Comprobación rápida del servicio.  
  - Respuesta: { "ok": true, "service": "eda-backend" }

- GET /api/health  
  - Descripción: Estado del servicio.

- GET /auth/token?sub=<user>&scope=<scope>  
  - Descripción: Genera un token JWT de prueba. Parámetros opcionales `sub` y `scope`.  

- GET /alerts?timeoutMs=<ms>  
  - Descripción: Consume mensajes del topic `alerts.suspect` de Kafka (lee directamente de Kafka en tiempo real).  
  - Nota: requiere acceso al bootstrap Kafka configurado por variable `KAFKA_BOOTSTRAP_SERVERS`.

- GET /alerts-db  
  - Descripción: Lista de registros de la tabla `alerts` (lee desde la BD).

- GET /db/ping  
  - Descripción: Ejecuta `SELECT 1` para comprobar conectividad con la base de datos.

- GET /users  
  - Descripción: Lista usuarios (depende de la tabla `users` en la BD).  
  - Posibles errores: 500 si la tabla `users` no existe o la BD no es accesible.

- GET /users/{id}  
  - Descripción: Obtiene usuario por UUID.

- POST /users  
  - Descripción: Crea usuario. Body JSON esperado: `{ "email":"x", "password":"x", "firstName":"x", "lastName":"x", "role":"PATIENT" }`

- PUT /users/{id}  
  - Descripción: Actualiza usuario.

- POST /events/payments  
  - Descripción: Persiste un payment y lo encola en outbox para publicación en Kafka. Body ejemplo:
    ```json
    {"id":"p-123","type":"payment","amount":12000,"currency":"EUR","accountId":"acc-1"}
    ```
  - Nota: requiere tablas `payments` y `outbox` (o `pos.payments`/`pos.outbox` si usas esquema pos).

- POST /events/transfers  
  - Descripción: Persiste transfer y encola en outbox. Body ejemplo:
    ```json
    {"id":"t-456","type":"transfer","amount":15000,"from":"acc-1","to":"acc-2"}
    ```

#### Notas sobre dependencias DB/Kafka
- Endpoints que acceden a la BD (reads/writes): `/db/ping`, `/users*`, `/alerts-db`, `/events/*`.
- Endpoints que acceden a Kafka: `/alerts` (consumer directo), `/events/*` (produce mediante outbox/kafka).
- Si usas esquema `pos` en la base de datos, asegúrate de ejecutar `sql/create_pos_schema_and_tables.sql` provisto o de cambiar las consultas para usar el esquema público.

#### Cómo probar y depurar (comandos)
1. Probar DB ping:
   - `curl -sS http://localhost:8080/db/ping`
2. Probar listar usuarios:
   - `curl -sS http://localhost:8080/users`
3. Probar crear payment:
   - `curl -v -X POST http://localhost:8080/events/payments -H "Content-Type: application/json" -d '{"id":"p-123","type":"payment","amount":12000,"currency":"EUR","accountId":"acc-1"}'`
4. Habilitar logs para depuración (temporal):
   - En `src/main/resources/application.properties` añade:
     ```
     logging.level.com.rgq.edabank=DEBUG
     logging.level.org.springframework.jdbc.core.JdbcTemplate=DEBUG
     ```
   - Reinicia la app y reproduce el error; copia aquí el stacktrace si necesitas ayuda adicional.
