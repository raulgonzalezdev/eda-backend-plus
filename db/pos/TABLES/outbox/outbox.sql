-- Source: jdbc:postgresql://127.0.0.1:5432/sasdatqbox
-- Usuario: sas_user
-- Contenedor: sasdatqbox-db-1
SET LOCAL search_path TO pos;

CREATE TABLE pos.outbox (
  id bigint NOT NULL DEFAULT nextval('pos.outbox_id_seq'::regclass),
  aggregate_type character varying(255),
  aggregate_id character varying(255),
  type character varying(255),
  payload jsonb,
  sent boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  event_type character varying(255)
);
ALTER TABLE pos.outbox ADD CONSTRAINT outbox_pkey PRIMARY KEY (id);
CREATE INDEX idx_outbox_sent_created_at ON pos.outbox USING btree (sent, created_at);
CREATE UNIQUE INDEX outbox_pkey ON pos.outbox USING btree (id);
