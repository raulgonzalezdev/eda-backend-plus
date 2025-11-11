-- Idempotent grants and Debezium publication for schema pos
-- Nota: ajusta el usuario si no es 'sas_user'

-- Asegurar propietario del esquema (si existe)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name='pos') THEN
    EXECUTE 'ALTER SCHEMA pos OWNER TO sas_user';
  END IF;
END$$;

-- Asegurar permisos para la tabla de historial de Flyway en schema public
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema='public' AND table_name='flyway_schema_history'
  ) THEN
    -- Otorgar permisos de lectura/escritura a usuario de la app
    EXECUTE 'GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.flyway_schema_history TO sas_user';
    -- Opcionalmente corregir propietario si fue creado por otro rol
    EXECUTE 'ALTER TABLE public.flyway_schema_history OWNER TO sas_user';
  END IF;
END$$;

-- Grants de esquema y tablas/seqs existentes
GRANT USAGE ON SCHEMA pos TO sas_user;
GRANT CREATE ON SCHEMA pos TO sas_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA pos TO sas_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA pos TO sas_user;

-- Default privileges para objetos futuros en el esquema pos
ALTER DEFAULT PRIVILEGES IN SCHEMA pos GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO sas_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA pos GRANT USAGE, SELECT ON SEQUENCES TO sas_user;

-- === Grants para el esquema public (necesarios para migraciones en public) ===
-- Nota: algunos entornos dejan el esquema public con permisos restringidos;
-- aseguramos que el usuario de la app pueda crear objetos allí.
GRANT USAGE ON SCHEMA public TO sas_user;
GRANT CREATE ON SCHEMA public TO sas_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO sas_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO sas_user;

-- Otorgar privilegio CREATE sobre la base de datos actual a sas_user
DO $$
DECLARE dbname text := current_database();
BEGIN
  EXECUTE format('GRANT CREATE ON DATABASE %I TO %I', dbname, 'sas_user');
END$$;

-- Corregir propietario de tablas existentes a sas_user (idempotente)
DO $$
DECLARE r record;
BEGIN
  FOR r IN (
    SELECT quote_ident(n.nspname) AS nsp, quote_ident(c.relname) AS rel
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'pos' AND c.relkind IN ('r','p')
  ) LOOP
    EXECUTE format('ALTER TABLE %s.%s OWNER TO %I', r.nsp, r.rel, 'sas_user');
  END LOOP;
END$$;

-- Corregir propietario de secuencias existentes a sas_user (idempotente)
DO $$
DECLARE r record;
BEGIN
  FOR r IN (
    SELECT quote_ident(n.nspname) AS nsp, quote_ident(c.relname) AS rel
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'pos' AND c.relkind = 'S'
  ) LOOP
    EXECUTE format('ALTER SEQUENCE %s.%s OWNER TO %I', r.nsp, r.rel, 'sas_user');
  END LOOP;
END$$;

-- Corregir propietario de índices existentes a sas_user (idempotente)
DO $$
DECLARE r record;
BEGIN
  FOR r IN (
    SELECT quote_ident(n.nspname) AS nsp, quote_ident(c.relname) AS rel
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'pos' AND c.relkind = 'I'
  ) LOOP
    EXECUTE format('ALTER INDEX %s.%s OWNER TO %I', r.nsp, r.rel, 'sas_user');
  END LOOP;
END$$;

-- Asegurar outbox.sent con default false y NOT NULL; y corregir nulos existentes
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='pos' AND table_name='outbox' AND column_name='sent') THEN
    -- Corregir datos existentes primero
    EXECUTE 'UPDATE pos.outbox SET sent=false WHERE sent IS NULL';
    -- Forzar default y not null
    EXECUTE 'ALTER TABLE IF EXISTS pos.outbox ALTER COLUMN sent SET DEFAULT false';
    EXECUTE 'ALTER TABLE IF EXISTS pos.outbox ALTER COLUMN sent SET NOT NULL';
  END IF;
END$$;

-- Publicación para Debezium (con pgoutput)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'dbz_outbox_pub') THEN
    EXECUTE 'CREATE PUBLICATION dbz_outbox_pub FOR TABLE pos.outbox';
  END IF;
END$$;