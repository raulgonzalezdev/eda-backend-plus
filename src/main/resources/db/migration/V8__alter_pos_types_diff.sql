-- Schema: pos
-- Nota: Flyway ejecuta cada migración en una transacción
SET LOCAL search_path TO pos;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum e JOIN pg_type t ON t.oid=e.enumtypid JOIN pg_namespace n ON n.oid=t.typnamespace
    WHERE n.nspname='pos' AND t.typname='subscriptionstatus' AND e.enumlabel='active'
  ) THEN
    EXECUTE 'ALTER TYPE pos.subscriptionstatus ADD VALUE ''active''';
  END IF;
END $$;
