-- Flyway callback: beforeEachMigrate
-- Asegura el search_path y registra el contexto para depuración
SET LOCAL search_path TO pos;

DO $$
BEGIN
  RAISE NOTICE 'Flyway beforeEachMigrate: search_path=%', current_setting('search_path');
END $$;