-- Source: jdbc:postgresql://127.0.0.1:5432/sasdatqbox
-- Usuario: sas_user
-- Contenedor: patroni-master
SET LOCAL search_path TO pos;

CREATE TABLE pos.businesses (
  id uuid NOT NULL,
  name character varying NOT NULL,
  address character varying,
  phone character varying,
  email character varying,
  tax_number character varying,
  owner_id uuid NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone
);
ALTER TABLE pos.businesses ADD CONSTRAINT businesses_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES pos.users(id);
ALTER TABLE pos.businesses ADD CONSTRAINT businesses_pkey PRIMARY KEY (id);
CREATE UNIQUE INDEX businesses_pkey ON pos.businesses USING btree (id);
