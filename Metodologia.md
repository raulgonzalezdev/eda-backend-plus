# `eda-backend-plus`: Aplicación de Ejemplo para Procesamiento de Eventos en Tiempo Real

Este proyecto es una aplicación backend construida con Spring Boot y Kafka, diseñada para demostrar una arquitectura orientada a eventos (EDA) robusta y escalable. Es un excelente caso de estudio para una entrevista técnica para un puesto de Back-end Engineer centrado en el procesamiento de datos en tiempo real.

A continuación, se desglosan los aspectos más importantes de la aplicación, junto con un cuestionario técnico que podrías encontrar en una entrevista.

## 1. Descripción General de la Aplicación

`eda-backend-plus` simula un sistema de punto de venta (POS) simplificado. Su función principal es procesar transacciones, persistir los datos y publicar eventos en tiempo real para que otros sistemas (como sistemas de inventario, análisis, etc.) puedan reaccionar a ellos.

La arquitectura está diseñada para ser:
*   **Resiliente**: Utiliza patrones como el Outbox Pattern para garantizar que los eventos se entreguen de manera fiable.
*   **Escalable**: Se containeriza con Docker y está preparada para orquestación con Kubernetes (K8s) y escalado automático con KEDA.
*   **Asíncrona**: El núcleo del sistema se basa en la comunicación asíncrona a través de Kafka, lo que desacopla los servicios y mejora el rendimiento.

## 2. Arquitectura y Tecnologías Clave

-   **Lenguaje y Framework**: Java 17, Spring Boot 3.
-   **Mensajería y Event Streaming**: Apache Kafka para la publicación y consumo de eventos.
-   **Base de Datos**: PostgreSQL, utilizada como base de datos principal (primaria) y de réplica (lectura).
-   **Persistencia de Datos**: Spring Data JPA con Hibernate.
-   **Contenedores**: Docker y Docker Compose para el entorno de desarrollo local.
-   **Orquestación (preparado para)**: Kubernetes (con `charts/` de Helm) y KEDA para el autoescalado basado en eventos de Kafka.
-   **Contratos de API**:
    -   **REST API**: OpenAPI (`specs/openapi.yaml`) para la comunicación síncrona.
    -   **Async API**: AsyncAPI (`specs/asyncapi.yaml`) para definir los eventos y canales de Kafka.

## 3. Patrones de Diseño e Implementaciones Notables

### The Outbox Pattern

Este es uno de los patrones más importantes de la aplicación y un gran tema de conversación en una entrevista.

**Pregunta:** *¿Cómo garantizas que un cambio en la base de datos y la publicación de un evento en Kafka ocurran de forma atómica? ¿Qué pasa si la base de datos confirma la transacción pero la aplicación se cae antes de enviar el evento a Kafka?*

**Respuesta:**
Utilizamos el **Outbox Pattern**. En lugar de comunicarnos directamente con Kafka dentro de la misma transacción de la base de datos (lo cual no es posible garantizar atómicamente), hacemos lo siguiente:

1.  **Transacción Atómica Local**: Cuando se procesa una nueva transacción (por ejemplo, una venta), se insertan los datos en la tabla principal (ej. `pos.sales`) y, en la **misma transacción de base de datos**, se inserta un registro del evento en una tabla `outbox`.

2.  **Proceso de Debezium (o similar)**: Un proceso separado (como Debezium, que es un conector de Kafka Connect) monitorea el `Write-Ahead Log` (WAL) de la base de datos. Cuando detecta una nueva entrada en la tabla `outbox`, lee ese registro.

3.  **Publicación en Kafka**: Debezium (o el proceso de CDC - Change Data Capture) publica el evento en el topic de Kafka correspondiente.

4.  **Limpieza**: Una vez que el evento se ha publicado de forma segura, el registro en la tabla `outbox` puede ser eliminado.

Este enfoque garantiza la "Dual Write" (escritura dual) sin los riesgos de inconsistencia. Si la aplicación se cae después del paso 1, el registro en la tabla `outbox` permanece, y cuando el sistema se recupere, el evento será publicado.

**Snippet de código relevante (conceptual):**
Aunque el código exacto de Debezium no está en la app, la lógica de la aplicación se centraría en la transacción atómica.

```java
// ... en un @Service de Spring Boot
@Transactional
public Sale processSale(SaleData data) {
    // 1. Guardar la entidad principal
    Sale sale = new Sale(data);
    saleRepository.save(sale);

    // 2. Crear el evento para el outbox
    OutboxEvent event = new OutboxEvent("sale.created", sale.toJson());
    outboxRepository.save(event);

    // La transacción se confirma aquí, guardando ambas entidades atómicamente.
    return sale;
}
```

## 4. Configuración y Despliegue

**Pregunta:** *Veo que la aplicación usa Docker. ¿Cómo gestionas la configuración para diferentes entornos (desarrollo, producción) sin tener que reconstruir la imagen de Docker?*

**Respuesta:**
La configuración se externaliza utilizando **variables de entorno**, siguiendo los principios de "The Twelve-Factor App". La imagen de Docker se construye una sola vez y es inmutable. La configuración específica del entorno se inyecta en el momento del despliegue.

En el archivo `application.properties`, en lugar de valores fijos (hardcoded), usamos placeholders que se resuelven a partir de variables de entorno.

**Snippet de código relevante (`application.properties`):**
```properties
# Configuración de la base de datos primaria
spring.datasource.primary.url=jdbc:postgresql://${DB_HOST}:${DB_PORT}/${DB_NAME}
spring.datasource.primary.username=${DB_USER}
spring.datasource.primary.password=${DB_PASSWORD}

# Configuración de Kafka
spring.kafka.bootstrap-servers=${KAFKA_BOOTSTRAP_SERVERS}
```

En `docker-compose.yml`, inyectamos estas variables:
```yaml
services:
  app:
    build: .
    ports:
      - "8080:8080"
    environment:
      - DB_HOST=postgres-db # Nombre del servicio de la BBDD en Docker
      - DB_PORT=5432
      - DB_NAME=pos
      - DB_USER=user
      - DB_PASSWORD=password
      - KAFKA_BOOTSTRAP_SERVERS=kafka:9092
```
Esto permite que la misma imagen se conecte a una base de datos local en desarrollo y a una base de datos gestionada (como AWS RDS) en producción, simplemente cambiando las variables de entorno.

**Pregunta:** *Durante el desarrollo, notamos que la aplicación fallaba al iniciarse con un `SchemaManagementException`. ¿Cuál fue la causa y cómo se solucionó?*

**Respuesta:**
La propiedad `spring.jpa.hibernate.ddl-auto` estaba configurada en `validate`. Esto le dice a Hibernate que verifique si el esquema de la base de datos coincide con las entidades JPA al arrancar. Si no coincide (por ejemplo, falta una tabla), la aplicación falla.

Esto es una buena práctica para producción para evitar cambios inesperados en el esquema. Sin embargo, durante el desarrollo o en el primer despliegue, el esquema puede no existir.

La solución fue cambiarlo a `update`.
```properties
spring.jpa.hibernate.ddl-auto=update
```
Con `update`, Hibernate comparará el esquema con las entidades y creará o modificará las tablas que falten. Para un primer despliegue, esto es muy útil. En un entorno de producción maduro, se preferiría usar una herramienta de migración de base de datos como Flyway o Liquibase para un control más granular del esquema.

## 5. Cuestionario Técnico Adicional

**P: ¿Por qué usar una base de datos de réplica (`replica`)?**
**R:** Para escalar las lecturas. Las operaciones de escritura (`INSERT`, `UPDATE`, `DELETE`) van a la base de datos primaria, mientras que las consultas de solo lectura (`SELECT`) pueden dirigirse a una o más réplicas. Esto reduce la carga en la base de datos primaria y mejora el rendimiento de las lecturas, especialmente en sistemas con alta demanda de consultas.

**P: ¿Qué es KEDA y por qué es útil en esta arquitectura?**
**R:** KEDA (Kubernetes-based Event-Driven Autoscaling) es un componente que permite escalar cualquier contenedor en Kubernetes basándose en el número de eventos en una cola (como un topic de Kafka). En nuestra aplicación, si hay un pico de transacciones y los mensajes se acumulan en un topic de Kafka, KEDA puede aumentar automáticamente el número de pods del servicio consumidor para procesar los mensajes más rápido. Cuando la cola se vacía, KEDA puede reducir los pods a cero para ahorrar costos.

**P: ¿Cuál es el propósito de `asyncapi.yaml`?**
**R:** Así como `openapi.yaml` define el contrato para nuestra API REST (endpoints, métodos, parámetros, respuestas), `asyncapi.yaml` define el contrato para nuestra API asíncrona. Documenta los canales (topics de Kafka), los mensajes que se publican o consumen, y el formato (payload) de esos mensajes. Esto es crucial para que los equipos que desarrollan otros servicios sepan cómo interactuar con nuestros eventos sin tener que mirar el código fuente.

---


