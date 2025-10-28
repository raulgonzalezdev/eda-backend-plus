-- Schema: pos
-- Nota: Flyway ejecuta cada migración en una transacción
SET LOCAL search_path TO pos;

ALTER TABLE pos.subscriptions ADD CONSTRAINT subscriptions_price_id_fkey FOREIGN KEY (price_id) REFERENCES pos.prices(id);
