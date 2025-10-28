-- Schema: pos
-- Nota: Flyway ejecuta cada migración en una transacción
SET LOCAL search_path TO pos;

CREATE TABLE IF NOT EXISTS pos.payments_test (
  id character varying(100) NOT NULL,
  type character varying(100),
  amount numeric,
  currency character varying(10),
  account_id character varying(100),
  payload jsonb,
  created_at timestamp with time zone DEFAULT now()
);

