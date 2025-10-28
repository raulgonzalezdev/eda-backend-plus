-- Crear esquema pos
CREATE SCHEMA IF NOT EXISTS public;

-- Crear tabla de historial de Flyway manualmente para que las migraciones puedan ejecutarse
CREATE TABLE IF NOT EXISTS public.flyway_schema_history (
    installed_rank INT NOT NULL,
    version VARCHAR(50),
    description VARCHAR(200) NOT NULL,
    type VARCHAR(20) NOT NULL,
    script VARCHAR(1000) NOT NULL,
    checksum INT,
    installed_by VARCHAR(100) NOT NULL,
    installed_on TIMESTAMP NOT NULL DEFAULT now(),
    execution_time INT NOT NULL,
    success BOOLEAN NOT NULL,
    CONSTRAINT flyway_schema_history_pk PRIMARY KEY (installed_rank)
);

-- Crear esquema pos y tablas necesarias por la aplicación
CREATE SCHEMA IF NOT EXISTS pos;

-- Tabla outbox (used by OutboxRepository)
CREATE TABLE IF NOT EXISTS pos.outbox (
  id BIGSERIAL PRIMARY KEY,
  aggregate_type VARCHAR(100),
  aggregate_id VARCHAR(100),
  type VARCHAR(200),        -- kafka topic
  payload JSONB,
  sent BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Tabla payments (used by PaymentRepository)
CREATE TABLE IF NOT EXISTS pos.payments (
  id VARCHAR(100) PRIMARY KEY,
  type VARCHAR(100),
  amount NUMERIC,           -- usa NUMERIC/DECIMAL para dinero
  currency VARCHAR(10),
  account_id VARCHAR(100),
  payload JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Tabla transfers (used by TransferRepository)
CREATE TABLE IF NOT EXISTS pos.transfers (
  id VARCHAR(100) PRIMARY KEY,
  type VARCHAR(100),
  amount NUMERIC,
  from_account VARCHAR(100),
  to_account VARCHAR(100),
  payload JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Tabla users (used por UserRepository)
CREATE TABLE IF NOT EXISTS pos.users (
  id UUID PRIMARY KEY,
  email VARCHAR(255) UNIQUE,
  hashed_password VARCHAR(255),
  role VARCHAR(50),
  first_name VARCHAR(100),
  last_name VARCHAR(100),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Tabla alerts (used por AlertsRepository)
CREATE TABLE IF NOT EXISTS pos.alerts (
  id BIGSERIAL PRIMARY KEY,
  event_id VARCHAR(200),
  alert_type VARCHAR(100),
  source_type VARCHAR(100),
  amount NUMERIC,
  payload JSONB,
  kafka_partition BIGINT,
  kafka_offset BIGINT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Índices sugeridos
CREATE INDEX IF NOT EXISTS idx_outbox_sent_created_at ON pos.outbox (sent, created_at);
CREATE INDEX IF NOT EXISTS idx_payments_account_id ON pos.payments (account_id);
CREATE INDEX IF NOT EXISTS idx_transfers_from_to ON pos.transfers (from_account, to_account);

CREATE INDEX IF NOT EXISTS flyway_schema_history_s_idx ON public.flyway_schema_history (success);

-- Idempotent grants and Debezium publication for schema pos
-- Nota: ajusta el usuario si no es 'sas_user'

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'pos') THEN
    CREATE SCHEMA pos;
  END IF;
END$$;

-- Asegurar propietario del esquema (si existe)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name='pos') THEN
    EXECUTE 'ALTER SCHEMA pos OWNER TO sas_user';
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