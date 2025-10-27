-- Source: jdbc:postgresql://127.0.0.1:5432/sasdatqbox
-- Usuario: sas_user
-- Contenedor: sasdatqbox-db-1
SET LOCAL search_path TO pos;

CREATE TABLE pos.prices (
  id character varying NOT NULL,
  product_id character varying,
  active boolean,
  description character varying,
  unit_amount bigint,
  currency character varying(3),
  type pricingtype,
  "interval" pricingplaninterval,
  interval_count integer,
  trial_period_days integer,
  metadata json,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone
);
ALTER TABLE pos.prices ADD CONSTRAINT prices_product_id_fkey FOREIGN KEY (product_id) REFERENCES pos.subscription_products(id);
ALTER TABLE pos.prices ADD CONSTRAINT prices_pkey PRIMARY KEY (id);
CREATE UNIQUE INDEX prices_pkey ON pos.prices USING btree (id);
