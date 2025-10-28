-- Schema: pos
-- Nota: Flyway ejecuta cada migración en una transacción
SET LOCAL search_path TO pos;

DO 1879
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_enum e JOIN pg_type t ON t.oid=e.enumtypid JOIN pg_namespace n ON n.oid=t.typnamespace
    WHERE n.nspname='pos' AND t.typname='documenttype' AND e.enumlabel='SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace'
  ) THEN
    EXECUTE 'ALTER TYPE pos.documenttype ADD VALUE ''SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace''';
  END IF;
END 1879;
