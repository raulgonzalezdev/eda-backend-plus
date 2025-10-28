-- Source: jdbc:postgresql://127.0.0.1:5432/sasdatqbox
-- Usuario: sas_user
-- Contenedor: sasdatqbox-db-1
SET LOCAL search_path TO pos;

CREATE TABLE pos.payments_test_new_2 (
  id character varying(100) NOT NULL,
  type character varying(100),
  amount numeric,
  currency character varying(10),
  account_id character varying(100),
  payload jsonb,
  created_at timestamp with time zone DEFAULT now()
);
ALTER TABLE pos.payments_test_new_2 ADD CONSTRAINT payments_test_new_2_pkey PRIMARY KEY (id);
CREATE UNIQUE INDEX payments_test_new_2_pkey ON pos.payments_test_new_2 USING btree (id);
