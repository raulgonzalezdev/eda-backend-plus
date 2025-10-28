-- Source: jdbc:postgresql://127.0.0.1:5432/sasdatqbox
-- Usuario: sas_user
-- Contenedor: patroni-master
SET LOCAL search_path TO pos;

CREATE TABLE pos.stock_transfers (
  id uuid NOT NULL,
  business_id uuid NOT NULL,
  from_location_id uuid NOT NULL,
  to_location_id uuid NOT NULL,
  status character varying NOT NULL,
  notes character varying,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone
);
ALTER TABLE pos.stock_transfers ADD CONSTRAINT stock_transfers_from_location_id_fkey FOREIGN KEY (from_location_id) REFERENCES pos.business_locations(id);
ALTER TABLE pos.stock_transfers ADD CONSTRAINT stock_transfers_to_location_id_fkey FOREIGN KEY (to_location_id) REFERENCES pos.business_locations(id);
ALTER TABLE pos.stock_transfers ADD CONSTRAINT stock_transfers_business_id_fkey FOREIGN KEY (business_id) REFERENCES pos.businesses(id);
ALTER TABLE pos.stock_transfers ADD CONSTRAINT stock_transfers_pkey PRIMARY KEY (id);
CREATE UNIQUE INDEX stock_transfers_pkey ON pos.stock_transfers USING btree (id);
