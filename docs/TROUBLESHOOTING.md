# Solución de problemas

Esta guía te ayuda a resolver errores comunes al usar la UI y API de `alerts-config-api` con Kafka.

## 1) Error en la UI: `Error: failed to upsert rule`
Indica que el `POST /api/rules` no pudo completar la operación (normalmente por fallo de conexión con Kafka).

Pasos de verificación:
- Confirma que Kafka y ZooKeeper están corriendo:
  - `docker ps` debe listar `kafka` y `zookeeper` con estado `Up`.
- Si no están corriendo:
  - `docker compose up -d zookeeper kafka kafka-init`
- Asegúrate de que `alerts-config-api` use el broker correcto:
  - Fuera de Docker: `set KAFKA_BOOTSTRAP_SERVERS=localhost:9092`
  - Dentro de Docker: `kafka:9092`
- Revisa los logs del servicio:
  - Si aparece `KafkaTimeoutException` o `Connection refused`, el broker no es alcanzable o el puerto es incorrecto.

## 2) `No es posible conectar con el servidor remoto` al hacer POST
- Asegúrate de que `alerts-config-api` esté levantado y escuchando en `8091`.
- Prueba la salud del servicio:
  - `Invoke-RestMethod http://localhost:8091/actuator/health`
- Si falla, reinicia el servicio:
  - `set KAFKA_BOOTSTRAP_SERVERS=localhost:9092`
  - `java -jar services\alerts-config-api\target\alerts-config-api-0.1.0.jar`

## 3) `Se excedió el tiempo de espera de la operación`
- Indica que el backend no respondió a tiempo, suele ocurrir si Kafka está caído.
- Repite el arranque de infraestructura y reinicia `alerts-config-api`.

## 4) `unable to get image 'confluentinc/cp-kafka:7.4.0'`
- Ejecuta `docker compose pull` para descargar las imágenes.
- Verifica conexión a internet y que Docker Desktop esté en modo Linux con WSL2.
- Si persiste, intenta:
  - `docker logout` y `docker login`
  - Reiniciar Docker Desktop.

## 5) Puertos y listeners
- Broker dentro de Docker: `kafka:9092`.
- Host (Windows): `localhost:9092` normalmente publicado por `docker-compose.yml`.
- Fuera de Docker, usa SIEMPRE `localhost:9092`. No uses `localhost:29092` a menos que hayas configurado explícitamente ese listener y el mapeo de puerto en `docker-compose.yml`. En esta stack, `9092` es el valor recomendado.

## 6) Validación rápida
- Crear regla vía API:
  - `Invoke-RestMethod -Uri http://localhost:8091/api/rules -Method Post -ContentType 'application/json' -Body '{"type":"paymenttest","threshold":100,"enabled":true}'`
- Si devuelve un id (UUID), la operación se completó.
- Si falla, revisa los puntos 1–3 y vuelve a intentar.

## 7) Logs útiles
- `alerts-config-api`: confirma recepción del POST y errores de Kafka.
- `alerts-streams`: consumo de `payments.events` y evaluación de reglas.
- `alerts-persist`: persistencia de alertas.

---
Si después de seguir estos pasos sigue el problema, captura los logs completos de `alerts-config-api` y el resultado de `docker ps` y compártelos para diagnóstico adicional.