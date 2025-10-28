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

### Con Docker Compose (alternativa)

Puedes levantar todo el entorno (app, Kafka, Zookeeper) con Docker Compose:

```bash
docker-compose up --build
```

La aplicación estará disponible en `http://localhost:8080`.

### Cluster de Alta Disponibilidad con Patroni

Para entornos de producción, el proyecto incluye un cluster PostgreSQL de alta disponibilidad usando Patroni + etcd:

```bash
# Levantar cluster Patroni (3 nodos PostgreSQL + etcd + HAProxy)
docker-compose -f docker-compose-patroni.yml up -d --build

# Probar failover automático
.\scripts\test-patroni-failover-simple.ps1
```

**Puertos del Cluster:**
- **HAProxy**: 5000 (escritura), 5001 (lectura), 7000 (stats)
- **PostgreSQL**: 5432 (master), 5433-5434 (replicas)
- **Aplicaciones**: 9084-9086 (3 instancias con balanceador)

Ver documentación completa en [`docs/database-resilience.md`](docs/database-resilience.md).

#### Flujo de Desarrollo con Docker

Para un ciclo de desarrollo más rápido, puedes dejar los servicios de infraestructura (Kafka, Zookeeper) corriendo y solo reconstruir tu aplicación:

1.  **Verificar contenedores activos**:

    ```bash
    docker-compose ps
    ```

2.  **Reconstruir y reiniciar solo la aplicación**:

    ```bash
    docker-compose up -d --no-deps --build app
    ```

## 2. Endpoints de la API

### Autenticación
- `GET /auth/token?sub=<user>&scope=<scope>`: Genera un token JWT de prueba.
- `GET /auth/captcha`: Devuelve un desafío anti-bot con `token`, `question` y `expiresIn`.
- `POST /auth/login`: Inicia sesión. Requiere `email`, `password`, `captchaToken` y `captchaAnswer` válidos.
- `POST /auth/register`: Registro público de usuario. Requiere `email`, `password`, opcional `firstName`, `lastName`. Devuelve un JWT temporal (15 min) junto con los datos básicos del usuario.

### Redis (opcional)
- El sistema puede usar Redis para reforzar seguridad sin romper compatibilidad:
  - CAPTCHA: almacenamiento de retos con TTL de 2 minutos.
  - Rate limiting de login: contador con TTL de 1 minuto (máx. 5 intentos).
- Si Redis no está disponible, hay fallback a memoria local (comportamiento actual).
- Variables de entorno soportadas:
  - `REDIS_HOST` (por defecto `localhost`)
  - `REDIS_PORT` (por defecto `6379`)
  - `REDIS_PASSWORD` (opcional)
- Configuración en `application.yml` bajo `spring.data.redis.*`.
- Para desarrollo rápido: `docker run -p 6379:6379 redis:7-alpine`.

### General
- `GET /api/hello`: Comprobación rápida del servicio.
- `GET /api/health`: Estado del servicio.
- `GET /db/ping`: Verifica la conexión con la base de datos.

### Usuarios
- `GET /users`: Lista todos los usuarios.
- `GET /users/{id}`: Obtiene un usuario por su UUID.
- `POST /users`: Crea un nuevo usuario (requiere autenticación; pensado para administración). Para auto-registro usar `POST /auth/register`.
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
## 4. Gestión de Migraciones de Base de Datos

Este proyecto utiliza [Flyway](https://flywaydb.org/) para gestionar la evolución del esquema de la base de datos de forma automática y versionada.

### Flujo de Trabajo

El proceso de migración está diseñado para ser robusto y predecible, asegurando que los cambios en la base de datos de desarrollo se trasladen correctamente a producción.

1.  **Generación de Migraciones (Desarrollo)**:
    -   Para generar las migraciones, se utiliza el script `scripts/build-migrations.sh`.
    -   Este script compara el esquema de la base de datos de desarrollo (definida en tu entorno local) con la base de datos de producción. Las credenciales de producción están directamente configuradas en el script para garantizar consistencia.
    -   El resultado es un conjunto de archivos SQL de "diferencias" (ej. `V3__create_pos_tables_diff.sql`) que se guardan en `src/main/resources/db/migration`. Estos archivos contienen únicamente los cambios necesarios, como `CREATE TABLE` para tablas nuevas o `ALTER TABLE` para columnas nuevas.

2.  **Aplicación de Migraciones (Despliegue)**:
    -   Cuando se construye la imagen Docker de la aplicación, la carpeta `src/main/resources/db/migration` con todos los scripts de migración se incluye en la imagen.
    -   Al iniciar el contenedor de la aplicación (por ejemplo, con `docker-compose up`), Flyway se ejecuta automáticamente al arrancar.
    -   Flyway detecta y aplica cualquier migración pendiente (que no se haya ejecutado previamente) sobre la base de datos de destino (configurada a través de las variables de entorno en `docker-compose.yml`).
    -   Esto garantiza que el esquema de la base de datos de producción siempre esté sincronizado con la versión del código que se está desplegando.

  3. aplicar migraciones directamnete  
    ```powershell
   ./scripts/apply-migrations-pro.ps1 -Actions migrate,info -Schemas pos -ValidateOnMigrate -Password 'ML!gsx90l02'
  
    ```

### Simulación de Migraciones (Dry-run)

Puedes previsualizar qué migraciones se crearían/actualizarían sin escribir archivos usando el modo dry-run. Esto es útil para revisar los cambios que se aplicarían en producción cuando trabajas con la política `update_existing`.

- Variables clave:
  - `MIG_DEDUP_POLICY`: `update_existing` | `skip_if_exists` | `create_new_version` (recomendado: `update_existing`)
  - `DRY_RUN`: `1` para activar la simulación, `0` (o sin definir) para escritura normal
  - `PROD_DB_CONTAINER_NAME`: nombre del contenedor Postgres de producción (por ejemplo `patroni-master`)

- Ejemplos de ejecución:
  - Windows PowerShell:
    - Dry-run completo (export dev/prod + agregadas + diffs, sin escribir archivos):
      ```powershell
      $env:MIG_DEDUP_POLICY = 'update_existing'
      $env:DRY_RUN = '1'
      $env:PROD_DB_CONTAINER_NAME = 'patroni-master'
      bash scripts/build-migrations.sh
      ```
    - Solo diffs dev vs prod (sin escribir archivos):
      ```powershell
      $env:MIG_DEDUP_POLICY = 'update_existing'
      $env:DRY_RUN = '1'
      bash scripts/convert-pos-diff-to-flyway.sh
      ```
    - Ejecución normal (escribe/actualiza archivos con `update_existing`):
      ```powershell
      $env:MIG_DEDUP_POLICY = 'update_existing'
      $env:DRY_RUN = '0'
      $env:PROD_DB_CONTAINER_NAME = 'patroni-master'
      bash scripts/build-migrations.sh
      ```

  - Git Bash / WSL / Linux:
    - Dry-run completo:
      ```bash
      MIG_DEDUP_POLICY=update_existing DRY_RUN=1 PROD_DB_CONTAINER_NAME=patroni-master bash scripts/build-migrations.sh
      ```
    - Solo diffs:
      ```bash
      MIG_DEDUP_POLICY=update_existing DRY_RUN=1 bash scripts/convert-pos-diff-to-flyway.sh
      ```

- Qué muestra el dry-run:
  - Para cada categoría (`create_<schema>_schema(_diff)`, `create_<schema>_tables(_diff)`, `add_<schema>_constraints(_diff)`, `create_<schema>_indexes(_diff)`, `create_<schema>_views(_diff)`, `create_<schema>_routines(_diff)`), se indica si:
    - “sin cambios; reutilizaría …”
    - “se actualizaría …” (con `update_existing`)
    - “se crearía …” (primera vez o `create_new_version`)
    - “se saltaría … (política=skip_if_exists)”
  - En diffs, se imprime un resumen con cuentas:
    - Tablas nuevas
    - Columnas nuevas via `ALTER TABLE … ADD COLUMN …`
    - Constraints nuevas
    - Índices nuevos
    - Vistas y rutinas a reemplazar

- Notas:
  - El dry-run no limpia archivos vacíos ni modifica migraciones; es 100% no destructivo.
  - Para cambios complejos (renombres, tipos), crea migraciones manuales seguras; el diff automatiza altas de columnas, índices y constraints.

## 5. API de Chat

El backend incluye una funcionalidad de chat en tiempo real que utiliza WebSockets para la comunicación y Kafka para la distribución de mensajes. Los mensajes también se persisten en la base de datos.

### Comunicación por WebSockets

Para recibir mensajes en tiempo real, un cliente debe conectarse al siguiente endpoint de WebSockets:

- **Endpoint**: `/ws`

Una vez conectado, el cliente puede suscribirse al siguiente tema para recibir mensajes públicos:

- **Tema**: `/topic/public`

Para enviar un mensaje, el cliente debe enviar un mensaje al siguiente destino:

- **Destino**: `/app/chat.sendMessage`

El cuerpo del mensaje debe ser un objeto JSON con el siguiente formato:

```json
{
  "content": "Hello, world!",
  "sender": "user123",
  "type": "CHAT"
}
```

### Endpoints REST

La API de chat también proporciona los siguientes endpoints REST para gestionar conversaciones y mensajes:

- `GET /api/chat/conversations`: Obtiene una lista de todas las conversaciones.
- `GET /api/chat/conversations/{id}`: Obtiene una conversación por su ID.
- `GET /api/chat/conversations/{id}/messages`: Obtiene una lista de todos los mensajes de una conversación específica.
