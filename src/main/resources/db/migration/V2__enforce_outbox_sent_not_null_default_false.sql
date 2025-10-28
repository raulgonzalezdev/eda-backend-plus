SET LOCAL search_path TO pos;
-- Enforce NOT NULL and DEFAULT false on pos.outbox.sent and repair existing rows
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='pos' AND table_name='outbox' AND column_name='sent'
  ) THEN
    -- Fix nulls first
    EXECUTE 'UPDATE pos.outbox SET sent=false WHERE sent IS NULL';
    -- Enforce default and NOT NULL
    EXECUTE 'ALTER TABLE IF EXISTS pos.outbox ALTER COLUMN sent SET DEFAULT false';
    EXECUTE 'ALTER TABLE IF EXISTS pos.outbox ALTER COLUMN sent SET NOT NULL';
  END IF;
END$$;