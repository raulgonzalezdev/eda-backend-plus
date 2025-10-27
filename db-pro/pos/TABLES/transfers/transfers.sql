-- Source: jdbc:postgresql://127.0.0.1:5432/sasdatqbox
-- Usuario: sas_user
-- Contenedor: patroni-master
SET LOCAL search_path TO pos;

CREATE TABLE pos.transfers (
  id character varying(255) NOT NULL,
  type character varying(255),
  amount double precision,
  from_account character varying(255),
  to_account character varying(255),
  payload jsonb,
  created_at timestamp with time zone DEFAULT now()
);
ALTER TABLE pos.transfers ADD CONSTRAINT transfers_pkey PRIMARY KEY (id);
CREATE INDEX idx_transfers_from_to ON pos.transfers USING btree (from_account, to_account);
CREATE UNIQUE INDEX transfers_pkey ON pos.transfers USING btree (id);
