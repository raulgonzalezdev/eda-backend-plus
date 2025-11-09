# Pos schema: DDL e instrucciones

## Navegación
- Inicio: [README](../README.md)
- Metodología: [Metodologia.md](Metodologia.md)
- Observabilidad (APM/OTel): [observability-overview.md](observability-overview.md)
- Resiliencia BD (Patroni + HAProxy): [database-resilience.md](database-resilience.md)
- Balanceador NGINX: [README-LoadBalancer.md](README-LoadBalancer.md)
- Guía de entrevista: [guia-entrevista-backend.md](guia-entrevista-backend.md)
- Contribución (ES): [CONTRIBUTING.es.md](CONTRIBUTING.es.md)
- Contribución (EN): [CONTRIBUTING.md](CONTRIBUTING.md)
- Esquema POS y DDL: [pos_schema_instructions.md](pos_schema_instructions.md)
- OpenAPI: [../specs/openapi.yaml](../specs/openapi.yaml) · AsyncAPI: [../specs/asyncapi.yaml](../specs/asyncapi.yaml)

Este archivo contiene el script DDL para crear el esquema `pos` y las tablas que espera la aplicación, y las instrucciones para aplicarlo.

## Archivos añadidos
- `sql/create_pos_schema_and_tables.sql` — Script SQL para crear el esquema `pos` y las tablas `outbox`, `payments`, `transfers`, `users`, `alerts`.

## Cómo aplicar el script
1. Copia el archivo `sql/create_pos_schema_and_tables.sql` a la máquina donde está tu base de datos PostgreSQL (o accede al contenedor postgres).

2. Desde la máquina con psql:

```bash
psql -h <PG_HOST> -U <PG_USER> -d <PG_DATABASE> -f sql/create_pos_schema_and_tables.sql
```

3. Desde un contenedor Docker que tenga psql y acceso al volumen o ruta con el script:

```bash
docker cp sql/create_pos_schema_and_tables.sql <pg-container>:/tmp/create_pos_schema_and_tables.sql
docker exec -it <pg-container> psql -U <PG_USER> -d <PG_DATABASE> -f /tmp/create_pos_schema_and_tables.sql
```

## Verificaciones
- En psql:
  - `\dn`  — debe aparecer el esquema `pos`
  - `\d pos.outbox` — debe mostrar la estructura de la tabla outbox

- Prueba el endpoint que fallaba:

```bash
curl -v -X POST http://localhost:8080/events/payments \
  -H "Content-Type: application/json" \
  -d '{"id":"p-123","type":"payment","amount":12000,"currency":"EUR","accountId":"acc-1"}'
```

- Si aún falla, habilita logs SQL temporalmente en `src/main/resources/application.properties`:

```properties
logging.level.org.springframework.jdbc.core.JdbcTemplate=DEBUG
```

## Notas
- El script crea las tablas en el esquema `pos`. Si prefieres mantener las tablas en el esquema público, en lugar de ejecutar este script aplica la otra opción: modificar las consultas SQL del código para no usar el prefijo `pos.`.
- El payload se almacena en columnas JSONB; las consultas existentes usan `?::jsonb` al insertar. Asegúrate de que los valores que envías son JSON válidos.

---

Navegación rápida: [Volver al README](../README.md) · [Índice de docs](index.md) · [Mapa del proyecto](project-map.md) · [Guía de entrevista](guia-entrevista-backend.md) · [Observabilidad](observability-overview.md)
