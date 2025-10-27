-- Source: jdbc:postgresql://127.0.0.1:5432/sasdatqbox
-- Usuario: sas_user
-- Contenedor: sasdatqbox-db-1
SET LOCAL search_path TO pos;

CREATE TABLE pos.subscription_products (
  id character varying NOT NULL,
  active boolean,
  name character varying,
  description character varying,
  image character varying,
  metadata json,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone
);
ALTER TABLE pos.subscription_products ADD CONSTRAINT subscription_products_pkey PRIMARY KEY (id);
CREATE UNIQUE INDEX subscription_products_pkey ON pos.subscription_products USING btree (id);
