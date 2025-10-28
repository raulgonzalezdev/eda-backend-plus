-- Flyway callback: afterEachMigrate
-- Registra el search_path tras cada migración para facilitar debugging
DO $$
BEGIN
  RAISE NOTICE 'Flyway afterEachMigrate: search_path=%', current_setting('search_path');
END $$;