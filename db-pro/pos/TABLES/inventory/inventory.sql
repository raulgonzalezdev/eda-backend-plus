-- Source: jdbc:postgresql://127.0.0.1:5432/sasdatqbox
-- Usuario: sas_user
-- Contenedor: patroni-master
SET LOCAL search_path TO pos;

CREATE TABLE pos.inventory (
  id uuid NOT NULL,
  product_id uuid NOT NULL,
  location_id uuid NOT NULL,
  quantity integer NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone
);
ALTER TABLE pos.inventory ADD CONSTRAINT inventory_location_id_fkey FOREIGN KEY (location_id) REFERENCES pos.business_locations(id);
ALTER TABLE pos.inventory ADD CONSTRAINT inventory_pkey PRIMARY KEY (id);
ALTER TABLE pos.inventory ADD CONSTRAINT inventory_product_id_fkey FOREIGN KEY (product_id) REFERENCES pos.products(id);
CREATE UNIQUE INDEX inventory_pkey ON pos.inventory USING btree (id);
