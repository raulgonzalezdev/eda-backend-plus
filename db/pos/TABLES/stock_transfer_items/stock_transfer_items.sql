-- Source: jdbc:postgresql://127.0.0.1:5432/sasdatqbox
-- Usuario: sas_user
-- Contenedor: sasdatqbox-db-1
SET LOCAL search_path TO pos;

CREATE TABLE pos.stock_transfer_items (
  id uuid NOT NULL,
  transfer_id uuid NOT NULL,
  product_id uuid NOT NULL,
  quantity integer NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone
);
ALTER TABLE pos.stock_transfer_items ADD CONSTRAINT stock_transfer_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES pos.products(id);
ALTER TABLE pos.stock_transfer_items ADD CONSTRAINT stock_transfer_items_transfer_id_fkey FOREIGN KEY (transfer_id) REFERENCES pos.stock_transfers(id);
ALTER TABLE pos.stock_transfer_items ADD CONSTRAINT stock_transfer_items_pkey PRIMARY KEY (id);
CREATE UNIQUE INDEX stock_transfer_items_pkey ON pos.stock_transfer_items USING btree (id);
