-- Schema: pos
-- Nota: Flyway ejecuta cada migración en una transacción
SET LOCAL search_path TO pos;

ALTER TABLE pos.payments_test ADD CONSTRAINT payments_test_pkey PRIMARY KEY (id);
