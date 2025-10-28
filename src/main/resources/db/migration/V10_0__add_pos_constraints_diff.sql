-- Schema: pos
-- Nota: Flyway ejecuta cada migración en una transacción
SET LOCAL search_path TO pos;

ALTER TABLE pos.payments_test_new ADD CONSTRAINT payments_test_new_pkey PRIMARY KEY (id);
ALTER TABLE pos.payments_test_new_2 ADD CONSTRAINT payments_test_new_2_pkey PRIMARY KEY (id);
