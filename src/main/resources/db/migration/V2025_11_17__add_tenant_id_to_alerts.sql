-- Add tenant_id column to pos.alerts and index for fast filtering
SET LOCAL search_path TO pos;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'pos' AND table_name = 'alerts' AND column_name = 'tenant_id'
  ) THEN
    ALTER TABLE pos.alerts ADD COLUMN tenant_id varchar(64);
  END IF;
END$$;

-- Create index if not exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relname = 'idx_alerts_tenant_id' AND n.nspname = 'pos'
  ) THEN
    CREATE INDEX idx_alerts_tenant_id ON pos.alerts USING btree (tenant_id);
  END IF;
END$$;