# EDA Backend

Backend de Spring Boot que implementa una arquitectura EDA (Event-Driven Architecture) usando Kafka y Kafka Streams.

## 1. Desarrollo Local

### Prerrequisitos
- Java 17
- Maven 3.9+
- Docker

### Configuración
Crea un archivo `.env` en la raíz del proyecto con las siguientes variables:

```
# JWT
JWT_SECRET=your-super-secret-key

# Base de datos PostgreSQL
DB_HOST=localhost
DB_PORT=5432
DB_NAME=postgres
DB_USER=postgres
DB_PASSWORD=postgres

# Umbral para alertas de transacciones
ALERT_THRESHOLD=10000
```

### Ejecución
Puedes levantar todo el entorno (app, Kafka, Zookeeper) con Docker Compose:

```bash
docker-compose up --build
```

La aplicación estará disponible en `http://localhost:8080`.

## 2. Endpoints de la API

### Autenticación
- `GET /auth/token?sub=<user>&scope=<scope>`: Genera un token JWT de prueba.

### General
- `GET /api/hello`: Comprobación rápida del servicio.
- `GET /api/health`: Estado del servicio.
- `GET /db/ping`: Verifica la conexión con la base de datos.

### Usuarios
- `GET /users`: Lista todos los usuarios.
- `GET /users/{id}`: Obtiene un usuario por su UUID.
- `POST /users`: Crea un nuevo usuario.
- `PUT /users/{id}`: Actualiza un usuario existente.

### Eventos
- `POST /events/payments`: Persiste un pago y lo publica en Kafka a través del patrón Outbox.
- `POST /events/transfers`: Persiste una transferencia y la publica en Kafka a través del patrón Outbox.

### Alertas
- `GET /alerts?timeoutMs=<ms>`: Consume mensajes del topic `alerts.suspect` de Kafka.
- `GET /alerts-db`: Lista las alertas persistidas en la base de datos.

## 3. Despliegue

### Construcción de Imágenes Docker
El proyecto incluye dos `Dockerfiles`:
- `Dockerfile`: Imagen estándar.
- `Dockerfile.distroless`: Imagen ligera y segura con Distroless.

Para construir una imagen:
```bash
# Estándar
docker build -t rgq/eda-backend:0.1.0 .

# Distroless
docker build -f Dockerfile.distroless -t rgq/eda-backend:0.1.0 .
```

### Helm
Para desplegar la aplicación en un clúster de Kubernetes con Helm:

```bash
helm install eda ./charts/eda-backend \
  --set image.repository=rgq/eda-backend \
  --set image.tag=0.1.0 \
  --set env.kafkaBootstrapServers="kafka-bootstrap.kafka:9092" \
  --set env.jwtSecret="your-jwt-secret" \
  --set env.alertThreshold=10000 \
  --set env.kafkaStreamsAppId="eda-alerts-app"
```

### KEDA (Autoscaling)
Para autoescalar la aplicación basado en el lag de mensajes de Kafka, puedes usar KEDA.

1.  **Instala KEDA en tu clúster:**
    ```bash
    helm repo add kedacore https://kedacore.github.io/charts
    helm repo update
    helm install keda kedacore/keda --namespace keda --create-namespace
    ```

2.  **Aplica el `ScaledObject`:**
    ```bash
    kubectl apply -f k8s/keda-scaledobject.yaml
    ```
