-- Source: jdbc:postgresql://127.0.0.1:5432/sasdatqbox
-- Usuario: sas_user
-- Contenedor: patroni-master
SET LOCAL search_path TO pos;

CREATE TABLE pos.products (
  id uuid NOT NULL,
  name character varying NOT NULL,
  description character varying,
  price double precision NOT NULL,
  sku character varying,
  business_id uuid NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone
);
ALTER TABLE pos.products ADD CONSTRAINT products_business_id_fkey FOREIGN KEY (business_id) REFERENCES pos.businesses(id);
ALTER TABLE pos.products ADD CONSTRAINT products_pkey PRIMARY KEY (id);
ALTER TABLE pos.products ADD CONSTRAINT products_sku_key UNIQUE (sku);
CREATE UNIQUE INDEX products_pkey ON pos.products USING btree (id);
CREATE UNIQUE INDEX products_sku_key ON pos.products USING btree (sku);
