# Pos schema: DDL e instrucciones

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
