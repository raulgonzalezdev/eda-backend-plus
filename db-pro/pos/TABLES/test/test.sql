-- Source: jdbc:postgresql://127.0.0.1:5432/sasdatqbox
-- Usuario: sas_user
-- Contenedor: patroni-master
SET LOCAL search_path TO pos;

CREATE TABLE pos.test (
  id bigint NOT NULL DEFAULT nextval('pos.test_id_seq'::regclass),
  note text,
  created_at timestamp with time zone DEFAULT now()
);
ALTER TABLE pos.test ADD CONSTRAINT test_pkey PRIMARY KEY (id);
CREATE INDEX idx_test_created_at ON pos.test USING btree (created_at);
CREATE UNIQUE INDEX test_pkey ON pos.test USING btree (id);
