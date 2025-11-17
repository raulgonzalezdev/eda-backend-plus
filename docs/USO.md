# Guía de uso: EDA Backend Plus

Esta guía te explica cómo arrancar los servicios y usar la UI para crear reglas de alertas. Está orientada a Windows con Docker Desktop y Java 17.

## Requisitos
- Docker Desktop (modo Linux, con WSL2 habilitado).
- Java 17 (JDK) y Maven 3.8+.
- Conexión a internet para descargar imágenes de Docker.

## Arranque de infraestructura (Kafka/ZooKeeper)
1. Abre una terminal en la carpeta del proyecto: `D:\eda-backend-plus`.
2. Inicia los contenedores de mensajería:
   - `docker compose up -d zookeeper kafka kafka-init`
3. Verifica que estén arriba:
   - `docker ps` debe mostrar `kafka` y `zookeeper` con estado `Up`.

Notas:
- Los contenedores exponen `kafka:9092` dentro de Docker y `localhost:9092` desde tu host.
- Si usas clientes fuera de Docker (por ejemplo, nuestras apps Spring), usa `localhost:9092` como `KAFKA_BOOTSTRAP_SERVERS`.

## Arranque de `alerts-config-api` (UI + API)
1. Compila si aún no existe el JAR:
   - `cd services/alerts-config-api`
   - `mvn -q -DskipTests package`
2. Arranca el servicio usando Kafka en tu host:
   - `set KAFKA_BOOTSTRAP_SERVERS=localhost:9092`
   - `java -jar target/alerts-config-api-0.1.0.jar`
3. Abre la UI:
   - `http://localhost:8091/`

## Crear una regla desde la UI
En la página “Configurar reglas de alertas” completa:
- `Tipo (key)`: por ejemplo `paymenttest`.
- `Umbral (threshold)`: por ejemplo `100`.
- `Habilitada`: marcado.
Pulsa “Guardar regla”.

Si todo está bien, el backend responde `200` y se muestra confirmación (o un id). Si ves “Error: failed to upsert rule”, consulta la sección de Solución de problemas.

## Probar end‑to‑end con un evento
1. Asegúrate de tener corriendo los servicios de consumo si tu escenario los requiere (`alerts-streams` y `alerts-persist`).
   - Ambos deben arrancarse con `KAFKA_BOOTSTRAP_SERVERS=localhost:9092`.
   - Ejemplo:
     - `cd services/alerts-streams && mvn -q -DskipTests package && set KAFKA_BOOTSTRAP_SERVERS=localhost:9092 && java -jar target/alerts-streams-0.1.0.jar`
     - `cd services/alerts-persist && mvn -q -DskipTests package && set KAFKA_BOOTSTRAP_SERVERS=localhost:9092 && java -jar target/alerts-persist-0.1.0.jar`
2. Produce un evento de prueba al tópico de entrada (por ejemplo `payments.events`). Puedes usar el productor de consola dentro del contenedor:
   - `docker exec -it kafka bash`
   - `kafka-console-producer --bootstrap-server localhost:9092 --topic payments.events`
   - Envía un mensaje JSON (ejemplo):
     - `{ "key": "paymenttest", "amount": 120 }`
3. Observa los logs:
   - `alerts-streams` debe consumir el evento y evaluar la regla.
   - Si `amount >= threshold` y la regla está habilitada, se genera una alerta.
   - `alerts-persist` debe persistir la alerta.

## Verificación rápida vía API (sin UI)
Puedes probar la creación de reglas directamente:
- PowerShell:
  - `Invoke-RestMethod -Uri http://localhost:8091/api/rules -Method Post -ContentType 'application/json' -Body '{"type":"paymenttest","threshold":100,"enabled":true}'`

## Buenas prácticas
- Servicios fuera de Docker: `KAFKA_BOOTSTRAP_SERVERS=localhost:9092`.
- Servicios dentro de Docker Compose: `kafka:9092`.
- Si cambias puertos en `docker-compose.yml`, actualiza las variables de entorno de los servicios.

## Directorios relevantes
- `services/alerts-config-api`: UI y API para crear reglas.
- `services/alerts-streams`: Procesamiento de eventos y generación de alertas.
- `services/alerts-persist`: Persistencia de alertas.
- `docker-compose.yml`: Infraestructura (Kafka/ZooKeeper y tópicos).

## Siguientes pasos sugeridos
- Validaciones de payload en `alerts-config-api`.
- Autenticación JWT para `POST /api/rules`.
- React UI con Vite para una experiencia más rica.