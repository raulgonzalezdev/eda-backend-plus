-- Source: jdbc:postgresql://127.0.0.1:5432/sasdatqbox
-- Usuario: sas_user
-- Contenedor: patroni-master
SET LOCAL search_path TO pos;

CREATE TABLE pos.payments (
  id character varying(255) NOT NULL,
  type character varying(255),
  amount double precision,
  currency character varying(255),
  account_id character varying(255),
  payload jsonb,
  created_at timestamp with time zone DEFAULT now()
);
ALTER TABLE pos.payments ADD CONSTRAINT payments_pkey PRIMARY KEY (id);
CREATE INDEX idx_payments_account_id ON pos.payments USING btree (account_id);
CREATE UNIQUE INDEX payments_pkey ON pos.payments USING btree (id);
